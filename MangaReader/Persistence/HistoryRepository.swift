//
//  HistoryRepository.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

public struct ContinueReadingItem: Identifiable {
    public var id: UUID { manga.id }
    public let manga: MangaItem
    public let chapter: ChapterItem
    public let progress: ReadingProgress
    
    public init(manga: MangaItem, chapter: ChapterItem, progress: ReadingProgress) {
        self.manga = manga
        self.chapter = chapter
        self.progress = progress
    }
}

@MainActor
public final class HistoryRepository: ObservableObject {
    public static let shared = HistoryRepository()
    
    private let db = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published public var historyItems: [ReadingProgress] = []
    @Published public private(set) var continueReadingItems: [ContinueReadingItem] = []
    @Published public var isIncognitoMode: Bool = AppState.shared.incognitoMode {
        didSet {
            AppState.shared.incognitoMode = isIncognitoMode
        }
    }
    
    public var historyFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("reading_history.json")
    }
    
    private init() {
        self.isIncognitoMode = AppState.shared.incognitoMode
        loadHistoryFromDisk()
        updateContinueReadingItems()
        
        AppState.shared.$incognitoMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] incognito in
                if self?.isIncognitoMode != incognito {
                    self?.isIncognitoMode = incognito
                }
            }
            .store(in: &cancellables)
        
        // Listen to database changes in case external updates occur
        db.$historyList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dbHistory in
                guard let self = self else { return }
                if self.historyItems.isEmpty && !dbHistory.isEmpty {
                    self.historyItems = self.deduplicateByManga(dbHistory)
                    self.updateContinueReadingItems()
                    self.saveHistoryToDiskSync()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Disk Persistence
    
    public func loadHistoryFromDisk() {
        if FileManager.default.fileExists(atPath: historyFileURL.path) {
            do {
                let data = try Data(contentsOf: historyFileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let items = try decoder.decode([ReadingProgress].self, from: data)
                self.historyItems = deduplicateByManga(items)
                if self.historyItems.count != items.count {
                    saveHistoryToDiskSync()
                }
            } catch {
                print("[HistoryRepository] Failed to decode reading_history.json: \(error)")
                self.historyItems = deduplicateByManga(db.historyList)
            }
        } else {
            // Seed from db.historyList if available
            self.historyItems = deduplicateByManga(db.historyList)
            if !self.historyItems.isEmpty {
                saveHistoryToDiskSync()
            }
        }
    }
    
    private func deduplicateByManga(_ items: [ReadingProgress]) -> [ReadingProgress] {
        var grouped: [UUID: [ReadingProgress]] = [:]
        for item in items {
            grouped[item.mangaID, default: []].append(item)
        }
        
        var deduplicated: [ReadingProgress] = []
        for (_, group) in grouped {
            guard let newest = group.max(by: { $0.updatedAt < $1.updatedAt }) else { continue }
            let totalReadingTime = group.reduce(0.0) { $0 + $1.readingTimeSeconds }
            var merged = newest
            merged.readingTimeSeconds = totalReadingTime
            deduplicated.append(merged)
        }
        
        return deduplicated.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    public func saveHistoryToDiskSync() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(historyItems)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("[HistoryRepository] Failed to save reading_history.json: \(error)")
        }
    }
    
    // MARK: - Recording & Management
    
    public func recordReadingProgress(
        mangaID: UUID,
        chapterID: UUID,
        page: Int,
        totalPages: Int,
        sourceID: String? = nil,
        mangaTitle: String? = nil,
        chapterTitle: String? = nil,
        chapterNumber: Double? = nil,
        coverURL: URL? = nil,
        additionalDuration: TimeInterval = 0
    ) {
        if AppState.shared.incognitoMode || isIncognitoMode {
            return
        }
        
        let now = Date()
        let existingDuration = historyItems
            .filter { $0.mangaID == mangaID }
            .reduce(0.0) { $0 + $1.readingTimeSeconds }
        let totalDuration = existingDuration + additionalDuration
        
        let entry = ReadingProgress(
            chapterID: chapterID,
            mangaID: mangaID,
            pageIndex: page,
            totalPages: max(1, totalPages),
            readingTimeSeconds: totalDuration,
            updatedAt: now,
            mangaTitle: mangaTitle,
            chapterTitle: chapterTitle,
            chapterNumber: chapterNumber,
            coverURL: coverURL,
            sourceID: sourceID
        )
        
        historyItems.removeAll(where: { $0.mangaID == mangaID })
        historyItems.insert(entry, at: 0)
        
        if historyItems.count > 300 {
            historyItems = Array(historyItems.prefix(300))
        }
        
        updateContinueReadingItems()
        saveHistoryToDiskSync()
    }
    
    public func recordReadingProgress(
        manga: MangaItem,
        chapter: ChapterItem,
        pageIndex: Int,
        totalPages: Int,
        additionalDuration: TimeInterval = 0
    ) {
        if AppState.shared.incognitoMode || isIncognitoMode {
            return
        }
        
        let now = Date()
        let existingDuration = historyItems
            .filter { $0.mangaID == manga.id }
            .reduce(0.0) { $0 + $1.readingTimeSeconds }
        let totalDuration = existingDuration + additionalDuration
        
        let entry = ReadingProgress(
            chapterID: chapter.id,
            mangaID: manga.id,
            pageIndex: pageIndex,
            totalPages: max(1, totalPages),
            readingTimeSeconds: totalDuration,
            updatedAt: now,
            mangaTitle: manga.title,
            chapterTitle: chapter.displayTitle,
            chapterNumber: chapter.chapterNumber,
            coverURL: manga.coverURL,
            sourceID: manga.sourceID
        )
        
        // Remove existing entry for this manga and prepend newest
        historyItems.removeAll(where: { $0.mangaID == manga.id })
        historyItems.insert(entry, at: 0)
        
        // Keep list bounded to 300 entries
        if historyItems.count > 300 {
            historyItems = Array(historyItems.prefix(300))
        }
        
        // Sync to DatabaseManager
        db.recordReadingProgress(
            chapter: chapter,
            manga: manga,
            pageIndex: pageIndex,
            isComplete: pageIndex >= max(0, totalPages - 1),
            additionalDuration: additionalDuration
        )
        
        updateContinueReadingItems()
        saveHistoryToDiskSync()
    }
    
    private func updateContinueReadingItems() {
        var results: [ContinueReadingItem] = []
        var seenMangaIDs = Set<UUID>()
        
        for entry in historyItems {
            guard !seenMangaIDs.contains(entry.mangaID) else { continue }
            seenMangaIDs.insert(entry.mangaID)
            
            // Resolve MangaItem from DB or create a robust fallback from entry
            let manga = db.mangaList.first(where: { $0.id == entry.mangaID }) ?? MangaItem(
                id: entry.mangaID,
                sourceID: entry.sourceID ?? "",
                urlOrSlug: "",
                title: entry.displayMangaTitle,
                coverURL: entry.coverURL
            )
            
            // Resolve ChapterItem from DB or create a robust fallback from entry
            let chapter = db.chaptersList.first(where: { $0.id == entry.chapterID }) ?? ChapterItem(
                id: entry.chapterID,
                mangaID: entry.mangaID,
                sourceChapterID: "\(entry.chapterNumber ?? 1.0)",
                chapterNumber: entry.chapterNumber ?? 1.0,
                title: entry.displayChapterTitle,
                pageCount: entry.totalPages
            )
            
            results.append(ContinueReadingItem(manga: manga, chapter: chapter, progress: entry))
        }
        
        self.continueReadingItems = results
    }
    
    public func readingProgress(for mangaID: UUID) -> ReadingProgress? {
        return historyItems.first(where: { $0.mangaID == mangaID }) ?? db.historyList.first(where: { $0.mangaID == mangaID })
    }
    
    public func readingProgress(forMangaIdString idString: String) -> ReadingProgress? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return readingProgress(for: uuid)
    }
    
    public func readingDuration(for mangaID: UUID) -> String {
        let entries = historyItems.filter { $0.mangaID == mangaID }
        let totalSeconds = entries.reduce(0.0) { $0 + $1.readingTimeSeconds }
        let totalMinutes = max(1, Int(totalSeconds) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours) h \(minutes) m"
        } else {
            return "\(minutes) m"
        }
    }
    
    public func removeHistory(for mangaID: UUID) {
        historyItems.removeAll(where: { $0.mangaID == mangaID })
        continueReadingItems.removeAll(where: { $0.manga.id == mangaID })
        saveHistoryToDiskSync()
        
        for entry in db.historyList where entry.mangaID == mangaID {
            db.updateProgress(chapterID: entry.chapterID, mangaID: entry.mangaID, pageIndex: 0, totalPages: 0)
        }
        db.saveHistoryToDiskSync()
    }
    
    public func removeHistory(mangaID: UUID) {
        removeHistory(for: mangaID)
    }
    
    public func clearHistory() {
        historyItems.removeAll()
        continueReadingItems.removeAll()
        saveHistoryToDiskSync()
        
        for item in db.historyList {
            db.updateProgress(chapterID: item.chapterID, mangaID: item.mangaID, pageIndex: 0, totalPages: 0)
        }
        db.saveHistoryToDiskSync()
    }
    
    public func clearAllHistory() {
        clearHistory()
    }
}
