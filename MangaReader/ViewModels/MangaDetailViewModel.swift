//
//  MangaDetailViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

@MainActor
public final class MangaDetailViewModel: ObservableObject {
    @Published public var manga: MangaItem
    @Published public private(set) var chapters: [ChapterItem] = []
    @Published public var sortDescending: Bool = true
    @Published public var chapterSearchQuery: String = ""
    @Published public var isLoading: Bool = false
    @Published public private(set) var isLoadingChapters: Bool = false
    @Published public private(set) var errorMessage: String? = nil
    
    private let db = DatabaseManager.shared
    private let downloadManager = DownloadManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init(manga: MangaItem) {
        self.manga = manga
        
        // Listen to database updates for this manga and its chapters
        db.$mangaList
            .compactMap { list in list.first(where: { $0.id == manga.id }) }
            .sink { [weak self] item in
                self?.manga = item
            }
            .store(in: &cancellables)
        
        db.$chaptersList
            .map { list in list.filter { $0.mangaID == manga.id } }
            .sink { [weak self] chs in
                self?.chapters = chs
            }
            .store(in: &cancellables)
        
        loadChapters()
    }
    
    public var displayedChapters: [ChapterItem] {
        var list = chapters
        if !chapterSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = chapterSearchQuery.lowercased()
            list = list.filter {
                $0.displayTitle.lowercased().contains(q) ||
                $0.formattedNumber.contains(q)
            }
        }
        return list.sorted {
            sortDescending ? $0.chapterNumber > $1.chapterNumber : $0.chapterNumber < $1.chapterNumber
        }
    }
    
    public var nextChapterToRead: ChapterItem? {
        let sortedAscending = chapters.sorted { $0.chapterNumber < $1.chapterNumber }
        // Find first unread chapter, or first chapter if all are read
        return sortedAscending.first(where: { !$0.isRead }) ?? sortedAscending.first
    }
    
    public func loadChapters() {
        // 1. Immediately load from disk cache so opening a manga is never 0 chapters
        if let diskCached = loadCachedChaptersFromDisk(), !diskCached.isEmpty {
            self.chapters = diskCached
        } else {
            let existing = db.chapters(for: manga.id)
            if !existing.isEmpty {
                self.chapters = existing
            }
        }
        
        // 2. Fetch latest chapters in the background
        refreshChapters()
    }
    
    private var chapterCacheFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("chapter_cache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sanitized = manga.id.uuidString
        return dir.appendingPathComponent("\(sanitized).json")
    }
    
    private func loadCachedChaptersFromDisk() -> [ChapterItem]? {
        guard let data = try? Data(contentsOf: chapterCacheFileURL),
              let list = try? JSONDecoder().decode([ChapterItem].self, from: data),
              !list.isEmpty else {
            return nil
        }
        return list
    }
    
    private func saveCachedChaptersToDisk(_ items: [ChapterItem]) {
        guard !items.isEmpty, let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: chapterCacheFileURL, options: .atomic)
    }
    
    public func fetchChapters() {
        refreshChapters()
    }
    
    public func refreshChapters() {
        let clean = manga.sourceID
            .replacingOccurrences(of: "com.rjalips.mangareader.source.", with: "")
            .replacingOccurrences(of: "com.mangareader.source.community.", with: "")
            .replacingOccurrences(of: "com.mangareader.source.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSource = SourceManager.shared.provider(for: manga.sourceID) ?? SourceManager.shared.provider(for: clean)
        guard let source = resolvedSource else {
            isLoading = false
            isLoadingChapters = false
            return
        }
        
        isLoading = true
        isLoadingChapters = true
        errorMessage = nil
        
        Task {
            defer {
                self.isLoading = false
                self.isLoadingChapters = false
            }
            do {
                var slug = self.manga.urlOrSlug
                if slug.trimmingCharacters(in: .whitespaces).isEmpty || (slug.count == 36 && UUID(uuidString: slug) != nil) {
                    // Try looking up in database or history first
                    if let dbSlug = self.db.mangaList.first(where: { $0.id == self.manga.id })?.urlOrSlug, !dbSlug.isEmpty {
                        slug = dbSlug
                        self.manga.urlOrSlug = slug
                    } else if let histSlug = HistoryRepository.shared.historyItems.first(where: { $0.mangaID == self.manga.id })?.urlOrSlug, !histSlug.isEmpty {
                        slug = histSlug
                        self.manga.urlOrSlug = slug
                    } else if let results = try? await source.searchManga(query: self.manga.title, page: 1),
                              let match = results.first(where: { $0.title.lowercased() == self.manga.title.lowercased() }) ?? results.first {
                        slug = match.urlOrSlug
                        self.manga.urlOrSlug = slug
                    }
                    if !slug.isEmpty {
                        self.db.upsertManga(self.manga)
                    }
                }
                guard !slug.isEmpty else { return }
                var fetched = try await source.fetchChapters(for: slug)
                for i in 0..<fetched.count {
                    fetched[i].mangaID = self.manga.id
                }
                if !fetched.isEmpty {
                    self.chapters = fetched
                    self.db.upsertChapters(fetched)
                    self.saveCachedChaptersToDisk(fetched)
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    public func toggleFavorite() {
        db.toggleFavorite(mangaID: manga.id)
    }
    
    public func toggleLibrary() {
        db.toggleLibrary(mangaID: manga.id)
    }
    
    public func toggleChapterRead(_ chapter: ChapterItem) {
        db.setChapterReadStatus(chapterID: chapter.id, isRead: !chapter.isRead)
    }
    
    public func markAllRead(isRead: Bool) {
        db.markAllChaptersRead(mangaID: manga.id, isRead: isRead)
    }
    
    public func downloadChapter(_ chapter: ChapterItem) {
        downloadManager.downloadChapter(chapter, for: manga)
    }
    
    public func downloadAll() {
        let notDownloaded = chapters.filter { !$0.isDownloaded }
        downloadManager.enqueue(chapters: notDownloaded, for: manga)
    }
    
    public func downloadUnread() {
        let unread = chapters.filter { !$0.isRead && !$0.isDownloaded }
        downloadManager.enqueue(chapters: unread, for: manga)
    }
    
    public func downloadAllUnread() {
        downloadUnread()
    }
    
    public func cancelDownloads() {
        downloadManager.cancelDownloads(for: manga.id)
    }
    
    public func deleteDownloaded() {
        downloadManager.deleteDownloadedChapters(for: manga.id)
    }
    
    public func deleteDownload(_ chapter: ChapterItem) {
        downloadManager.deleteDownloadedChapter(chapter)
    }
}
