//
//  ReaderViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import Combine

@MainActor
public final class ReaderViewModel: ObservableObject {
    public let manga: MangaItem
    @Published public private(set) var currentChapter: ChapterItem
    @Published public private(set) var pages: [URL] = []
    @Published public var currentPageIndex: Int = 0
    @Published public var readingMode: ReadingMode
    @Published public var settings: ReaderSettings
    
    // UI Controls Overlay
    @Published public var showControls: Bool = true
    @Published public var showSettingsSheet: Bool = false
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var brightness: Double = 1.0
    @Published public private(set) var isLoadingPages: Bool = false
    @Published public private(set) var errorMessage: String? = nil
    
    private let db = DatabaseManager.shared
    private let downloadManager = DownloadManager.shared
    private let trackerManager = TrackerManager.shared
    private var allMangaChapters: [ChapterItem] = []
    
    public init(manga: MangaItem, chapter: ChapterItem) {
        self.manga = manga
        self.currentChapter = chapter
        self.settings = db.readerSettings
        self.readingMode = manga.preferredReadingMode ?? db.readerSettings.defaultReadingMode
        
        // Restore last read position if available
        if let progress = db.progress(for: chapter.id) {
            self.currentPageIndex = progress.pageIndex
        } else {
            self.currentPageIndex = chapter.lastPageRead
        }
        
        loadAllChapters()
        loadPages(for: chapter)
    }
    
    private func loadAllChapters() {
        self.allMangaChapters = db.chapters(for: manga.id).sorted { $0.chapterNumber < $1.chapterNumber }
    }
    
    public var hasNextChapter: Bool {
        guard let idx = allMangaChapters.firstIndex(where: { $0.id == currentChapter.id }) else { return false }
        return idx < allMangaChapters.count - 1
    }
    
    public var hasPreviousChapter: Bool {
        guard let idx = allMangaChapters.firstIndex(where: { $0.id == currentChapter.id }) else { return false }
        return idx > 0
    }
    
    public func loadPages(for chapter: ChapterItem) {
        self.currentChapter = chapter
        self.isLoadingPages = true
        self.errorMessage = nil
        
        // 1. Check if downloaded locally
        if let localPages = downloadManager.localPagesForChapter(chapter), !localPages.isEmpty {
            self.pages = localPages
            self.isLoadingPages = false
            return
        }
        
        // 2. Check if chapter already has page URLs
        if !chapter.pageURLs.isEmpty {
            self.pages = chapter.pageURLs
            self.isLoadingPages = false
            prefetchUpcomingPages()
            return
        }
        
        // 3. Fetch from source provider
        guard let provider = SourceManager.shared.provider(for: manga.sourceID) else {
            self.isLoadingPages = false
            self.errorMessage = "Content source not found."
            return
        }
        
        Task {
            do {
                let urls = try await provider.fetchPageURLs(for: chapter.sourceChapterID)
                self.pages = urls
                self.isLoadingPages = false
                
                // Update chapter record with fetched page count
                var updated = chapter
                updated.pageURLs = urls
                updated.pageCount = urls.count
                self.db.upsertChapters([updated])
                
                self.prefetchUpcomingPages()
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoadingPages = false
            }
        }
    }
    
    public func goToNextChapter() {
        guard let idx = allMangaChapters.firstIndex(where: { $0.id == currentChapter.id }),
              idx < allMangaChapters.count - 1 else { return }
        let nextChapter = allMangaChapters[idx + 1]
        self.currentPageIndex = 0
        loadPages(for: nextChapter)
    }
    
    public func goToPreviousChapter() {
        guard let idx = allMangaChapters.firstIndex(where: { $0.id == currentChapter.id }),
              idx > 0 else { return }
        let prevChapter = allMangaChapters[idx - 1]
        self.currentPageIndex = 0
        loadPages(for: prevChapter)
    }
    
    public func onPageChanged(to index: Int) {
        guard index >= 0 && index < pages.count else { return }
        self.currentPageIndex = index
        
        // Persist reading progress
        db.updateProgress(
            chapterID: currentChapter.id,
            mangaID: manga.id,
            pageIndex: index,
            totalPages: pages.count
        )
        
        // Sync tracker if at the last page
        if index >= pages.count - 1 {
            Task {
                await trackerManager.syncProgress(
                    mangaID: manga.id,
                    chapterNumber: Int(currentChapter.chapterNumber),
                    isCompleted: true
                )
            }
        }
        
        prefetchUpcomingPages()
    }
    
    public func toggleControls() {
        withAnimation(Theme.Animation.quick) {
            showControls.toggle()
        }
    }
    
    public func updateReadingMode(_ mode: ReadingMode) {
        self.readingMode = mode
        var updatedManga = manga
        updatedManga.preferredReadingMode = mode
        db.upsertManga(updatedManga)
    }
    
    public func updateSettings(_ newSettings: ReaderSettings) {
        self.settings = newSettings
        db.readerSettings = newSettings
        db.saveSettingsToDisk()
    }
    
    private func prefetchUpcomingPages() {
        guard !pages.isEmpty else { return }
        let start = min(currentPageIndex + 1, pages.count)
        let end = min(start + settings.preloadPagesAhead, pages.count)
        
        guard start < end else { return }
        
        Task(priority: .background) {
            for i in start..<end {
                let url = pages[i]
                if !url.isFileURL {
                    _ = try? await NetworkClient.shared.fetchData(from: url)
                }
            }
        }
    }
}
