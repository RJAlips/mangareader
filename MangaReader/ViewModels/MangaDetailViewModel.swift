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
        // If chapters are already in DB, skip remote unless empty
        let existing = db.chapters(for: manga.id)
        if !existing.isEmpty {
            self.chapters = existing
            return
        }
        
        guard let source = SourceManager.shared.provider(for: manga.sourceID) else { return }
        
        isLoadingChapters = true
        errorMessage = nil
        
        Task {
            do {
                var fetched = try await source.fetchChapters(for: manga.urlOrSlug)
                for i in 0..<fetched.count {
                    fetched[i].mangaID = manga.id
                }
                self.chapters = fetched
                self.db.upsertChapters(fetched)
                self.isLoadingChapters = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoadingChapters = false
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
    
    public func downloadAllUnread() {
        let unread = chapters.filter { !$0.isRead && !$0.isDownloaded }
        downloadManager.downloadChapters(unread, for: manga)
    }
    
    public func deleteDownload(_ chapter: ChapterItem) {
        downloadManager.deleteDownloadedChapter(chapter)
    }
}
