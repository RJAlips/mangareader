//
//  HomeViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

public struct MangaUpdateEntry: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var mangaID: UUID
    public var mangaTitle: String
    public var coverURL: URL?
    public var chapterID: UUID
    public var chapterTitle: String
    public var chapterNumber: Double
    public var sourceID: String
    public var date: Date
    public var isDownloaded: Bool
    
    public init(
        id: UUID = UUID(),
        mangaID: UUID,
        mangaTitle: String,
        coverURL: URL? = nil,
        chapterID: UUID,
        chapterTitle: String,
        chapterNumber: Double,
        sourceID: String,
        date: Date = Date(),
        isDownloaded: Bool = false
    ) {
        self.id = id
        self.mangaID = mangaID
        self.mangaTitle = mangaTitle
        self.coverURL = coverURL
        self.chapterID = chapterID
        self.chapterTitle = chapterTitle
        self.chapterNumber = chapterNumber
        self.sourceID = sourceID
        self.date = date
        self.isDownloaded = isDownloaded
    }
}

@MainActor
public final class HomeViewModel: ObservableObject {
    public static let shared = HomeViewModel()
    
    @Published public private(set) var continueReading: [ContinueReadingItem] = []
    @Published public private(set) var recentlyAdded: [MangaItem] = []
    @Published public private(set) var popularManga: [MangaItem] = []
    @Published public private(set) var latestUpdates: [MangaItem] = []
    @Published public var updateEntries: [MangaUpdateEntry] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isRefreshingUpdates: Bool = false
    @Published public private(set) var errorMessage: String? = nil
    
    // Quick statistics
    @Published public private(set) var totalLibraryCount: Int = 0
    @Published public private(set) var totalUnreadChapters: Int = 0
    
    // Updates status banner
    @Published public var showUpdateToast: Bool = true
    @Published public var updateSummary: String = "0 successful, 0 skipped, 0 failed."
    
    private let db = DatabaseManager.shared
    private let historyRepo = HistoryRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var updatesFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("library_updates.json")
    }
    
    public init() {
        setupSubscriptions()
        loadUpdatesFromDisk()
        loadHomeData()
    }
    
    private func setupSubscriptions() {
        historyRepo.$continueReadingItems
            .sink { [weak self] items in
                self?.continueReading = items
            }
            .store(in: &cancellables)
        
        db.$mangaList
            .sink { [weak self] list in
                guard let self = self else { return }
                self.totalLibraryCount = list.filter { $0.inLibrary }.count
                self.totalUnreadChapters = list.filter { $0.inLibrary }.reduce(0) { $0 + $1.unreadCount }
                self.recentlyAdded = Array(list.sorted { $0.lastUpdated > $1.lastUpdated }.prefix(10))
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Disk Persistence for Updates
    
    private func loadUpdatesFromDisk() {
        guard FileManager.default.fileExists(atPath: updatesFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: updatesFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let entries = try decoder.decode([MangaUpdateEntry].self, from: data)
            self.updateEntries = entries.sorted { $0.date > $1.date }
        } catch {
            print("[HomeViewModel] Failed to load library_updates.json: \(error)")
        }
    }
    
    private func saveUpdatesToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(updateEntries)
            try data.write(to: updatesFileURL, options: .atomic)
        } catch {
            print("[HomeViewModel] Failed to save library_updates.json: \(error)")
        }
    }
    
    // MARK: - Data Refreshing
    
    public func loadHomeData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            // 1. Fetch library updates first
            await refreshLibraryUpdates()
            
            // 2. Fetch popular and latest from the primary enabled source for widgets
            if let primarySource = SourceManager.shared.sources.first(where: { SourceManager.shared.isSourceEnabled($0.manifest.id) }) {
                do {
                    async let pop = primarySource.fetchPopular(page: 1)
                    async let lat = primarySource.fetchLatest(page: 1)
                    
                    let (popular, latest) = try await (pop, lat)
                    self.popularManga = popular
                    self.latestUpdates = latest
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
            self.isLoading = false
        }
    }
    
    public func refreshLibraryUpdates() async {
        guard !isRefreshingUpdates else { return }
        isRefreshingUpdates = true
        isLoading = true
        defer {
            isRefreshingUpdates = false
            isLoading = false
        }
        
        let libraryManga = !LibraryRepository.shared.libraryItems.isEmpty ? LibraryRepository.shared.libraryItems : db.mangaList.filter { $0.inLibrary }
        guard !libraryManga.isEmpty else {
            self.updateSummary = "0 successful, 0 skipped, 0 failed."
            self.showUpdateToast = true
            return
        }
        
        var successfulCount = 0
        var skippedCount = 0
        var failedCount = 0
        var newDiscoveredEntries: [MangaUpdateEntry] = []
        
        // Bounded concurrency: maximum 4 concurrent workers
        let maxConcurrent = 4
        
        await withTaskGroup(of: (status: String, entries: [MangaUpdateEntry], newChapters: [ChapterItem], mangaID: UUID?).self) { group in
            var iterator = libraryManga.makeIterator()
            
            for _ in 0..<min(maxConcurrent, libraryManga.count) {
                if let manga = iterator.next() {
                    group.addTask {
                        await self.checkUpdates(for: manga)
                    }
                }
            }
            
            while let result = await group.next() {
                switch result.status {
                case "success":
                    successfulCount += 1
                    newDiscoveredEntries.append(contentsOf: result.entries)
                    if !result.newChapters.isEmpty {
                        self.db.upsertChapters(result.newChapters)
                    }
                case "skipped":
                    skippedCount += 1
                    if !result.newChapters.isEmpty {
                        self.db.upsertChapters(result.newChapters)
                    }
                default:
                    failedCount += 1
                }
                
                if let nextManga = iterator.next() {
                    group.addTask {
                        await self.checkUpdates(for: nextManga)
                    }
                }
            }
        }
        
        // Prepend new discovered entries (deduplicated)
        if !newDiscoveredEntries.isEmpty {
            let existingKeys = Set(self.updateEntries.map { "\($0.mangaID)_\($0.chapterNumber)" })
            let filtered = newDiscoveredEntries.filter { !existingKeys.contains("\($0.mangaID)_\($0.chapterNumber)") }
            self.updateEntries.insert(contentsOf: filtered, at: 0)
            
            // Keep up to 200 entries sorted by date
            self.updateEntries.sort { $0.date > $1.date }
            if self.updateEntries.count > 200 {
                self.updateEntries = Array(self.updateEntries.prefix(200))
            }
            self.saveUpdatesToDisk()
        }
        
        self.updateSummary = "\(successfulCount) successful, \(skippedCount) skipped, \(failedCount) failed."
        self.showUpdateToast = true
    }
    
    private func checkUpdates(for manga: MangaItem) async -> (status: String, entries: [MangaUpdateEntry], newChapters: [ChapterItem], mangaID: UUID?) {
        guard let source = SourceManager.shared.getSource(id: manga.sourceID) else {
            return ("skipped", [], [], manga.id)
        }
        
        do {
            let onlineChapters = try await source.fetchChapters(for: manga.urlOrSlug)
            guard !onlineChapters.isEmpty else {
                return ("skipped", [], [], manga.id)
            }
            
            let localChapters = self.db.chapters(for: manga.id)
            let formattedChapters = onlineChapters.map { ch -> ChapterItem in
                var updated = ch
                updated.mangaID = manga.id
                return updated
            }
            
            if localChapters.isEmpty {
                // Initial seed for newly added library manga: take latest 3 chapters
                let sorted = formattedChapters.sorted { $0.chapterNumber > $1.chapterNumber }
                let initialSeed = Array(sorted.prefix(3))
                let entries = initialSeed.map { ch in
                    MangaUpdateEntry(
                        id: UUID(),
                        mangaID: manga.id,
                        mangaTitle: manga.title,
                        coverURL: manga.coverURL,
                        chapterID: ch.id,
                        chapterTitle: ch.title ?? "Chapter \(Self.formatChapterNum(ch.chapterNumber))",
                        chapterNumber: ch.chapterNumber,
                        sourceID: manga.sourceID,
                        date: ch.releaseDate ?? Date(),
                        isDownloaded: ch.isDownloaded
                    )
                }
                return ("success", entries, formattedChapters, manga.id)
            } else {
                // Detect newly published chapters
                let existingSourceIDs = Set(localChapters.map { $0.sourceChapterID })
                let existingNums = Set(localChapters.map { $0.chapterNumber })
                
                let brandNew = formattedChapters.filter { ch in
                    !existingSourceIDs.contains(ch.sourceChapterID) && !existingNums.contains(ch.chapterNumber)
                }
                
                if brandNew.isEmpty {
                    return ("skipped", [], [], manga.id)
                } else {
                    let entries = brandNew.map { ch in
                        MangaUpdateEntry(
                            id: UUID(),
                            mangaID: manga.id,
                            mangaTitle: manga.title,
                            coverURL: manga.coverURL,
                            chapterID: ch.id,
                            chapterTitle: ch.title ?? "Chapter \(Self.formatChapterNum(ch.chapterNumber))",
                            chapterNumber: ch.chapterNumber,
                            sourceID: manga.sourceID,
                            date: ch.releaseDate ?? Date(),
                            isDownloaded: ch.isDownloaded
                        )
                    }
                    return ("success", entries, brandNew, manga.id)
                }
            }
        } catch {
            return ("failed", [], [], manga.id)
        }
    }
    
    // MARK: - Actions
    
    public func downloadChapter(for entry: MangaUpdateEntry) {
        guard let manga = db.mangaList.first(where: { $0.id == entry.mangaID }) ??
              LibraryRepository.shared.libraryItems.first(where: { $0.id == entry.mangaID }) else {
            return
        }
        
        let chapter = db.chaptersList.first(where: { $0.id == entry.chapterID }) ??
            ChapterItem(
                id: entry.chapterID,
                mangaID: entry.mangaID,
                sourceChapterID: "\(entry.chapterNumber)",
                chapterNumber: entry.chapterNumber,
                title: entry.chapterTitle
            )
        
        DownloadManager.shared.downloadChapter(chapter, for: manga)
        
        if let index = updateEntries.firstIndex(where: { $0.id == entry.id }) {
            updateEntries[index].isDownloaded = true
            saveUpdatesToDisk()
        }
    }
    
    public func isChapterDownloaded(_ entry: MangaUpdateEntry) -> Bool {
        if entry.isDownloaded { return true }
        if let ch = db.chaptersList.first(where: { $0.id == entry.chapterID }), ch.isDownloaded {
            return true
        }
        return DownloadManager.shared.tasks.contains(where: { $0.chapter.id == entry.chapterID && $0.status == .completed })
    }
    
    public static func formatChapterNum(_ num: Double) -> String {
        if num.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(num))"
        } else {
            return "\(num)"
        }
    }
}
