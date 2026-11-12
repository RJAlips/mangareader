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
        // If chapters are already in DB, skip remote unless empty or only 1 chapter (which is often a preview)
        let existing = db.chapters(for: manga.id)
        if existing.count > 1 {
            self.chapters = existing
            return
        }
        if !existing.isEmpty {
            self.chapters = existing
        }
        
        refreshChapters()
    }
    
    public func fetchChapters() {
        refreshChapters()
    }
    
    public func refreshChapters() {
        guard let source = SourceManager.shared.provider(for: manga.sourceID) else {
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
                if slug.trimmingCharacters(in: .whitespaces).isEmpty {
                    if let results = try? await source.searchManga(query: self.manga.title, page: 1),
                       let match = results.first(where: { $0.title.lowercased() == self.manga.title.lowercased() }) ?? results.first {
                        slug = match.urlOrSlug
                        self.manga.urlOrSlug = slug
                        self.db.upsertManga(self.manga)
                    }
                }
                guard !slug.isEmpty else { return }
                var fetched = try await source.fetchChapters(for: slug)
                for i in 0..<fetched.count {
                    fetched[i].mangaID = self.manga.id
                }
                self.chapters = fetched
                self.db.upsertChapters(fetched)
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
