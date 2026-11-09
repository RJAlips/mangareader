//
//  ReaderViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import Combine

public struct ReaderChapterSegment: Identifiable, Equatable {
    public let id: String
    public let chapter: ChapterItem
    public var pageURLs: [URL]
    
    public init(id: String, chapter: ChapterItem, pageURLs: [URL]) {
        self.id = id
        self.chapter = chapter
        self.pageURLs = pageURLs
    }
    
    public static func == (lhs: ReaderChapterSegment, rhs: ReaderChapterSegment) -> Bool {
        return lhs.id == rhs.id && lhs.pageURLs.count == rhs.pageURLs.count
    }
}

@MainActor
public final class ReaderViewModel: ObservableObject {
    public let manga: MangaItem
    @Published public private(set) var currentChapter: ChapterItem
    @Published public private(set) var pages: [URL] = []
    @Published public private(set) var chapterSegments: [ReaderChapterSegment] = []
    @Published public var currentPageIndex: Int = 0
    @Published public var readingMode: ReadingMode
    @Published public var settings: ReaderSettings
    
    // Slider & Viewport seek synchronization
    @Published public var isScrubbingSlider: Bool = false
    @Published public var scrollTargetPageID: String? = nil
    
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
    private var loadingNextChapterIDs: Set<String> = []
    private var lastSeekTimestamp: Date = Date.distantPast
    private var sessionStartTime: Date = Date()
    
    public var totalPagesInCurrentChapter: Int {
        if let currentSegment = chapterSegments.first(where: { $0.chapter.id == currentChapter.id }), !currentSegment.pageURLs.isEmpty {
            return currentSegment.pageURLs.count
        }
        return max(1, currentChapter.pageCount > 0 ? currentChapter.pageCount : pages.count)
    }
    
    public init(manga: MangaItem, chapter: ChapterItem, initialPage: Int? = nil) {
        self.manga = manga
        self.currentChapter = chapter
        self.settings = db.readerSettings
        self.readingMode = manga.preferredReadingMode ?? db.readerSettings.defaultReadingMode
        
        // Restore last read position or use passed initial page
        if let initP = initialPage, initP >= 0 {
            self.currentPageIndex = initP
            self.scrollTargetPageID = "\(chapter.id.uuidString)_page_\(initP)"
        } else if let progress = db.progress(for: chapter.id) {
            self.currentPageIndex = progress.pageIndex
            self.scrollTargetPageID = "\(chapter.id.uuidString)_page_\(progress.pageIndex)"
        } else {
            self.currentPageIndex = chapter.lastPageRead
            self.scrollTargetPageID = "\(chapter.id.uuidString)_page_\(chapter.lastPageRead)"
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
        self.loadingNextChapterIDs.removeAll()
        
        // 1. Offline-First Resolution: Check DownloadManager for saved sandbox files
        if let localURLs = downloadManager.getLocalChapterPageURLs(mangaId: manga.id.uuidString, chapterId: chapter.id.uuidString), !localURLs.isEmpty {
            let urls = localURLs.compactMap { URL(string: $0) }
            self.pages = urls
            let segment = ReaderChapterSegment(id: chapter.id.uuidString, chapter: chapter, pageURLs: urls)
            self.chapterSegments = [segment]
            self.isLoadingPages = false
            return
        }
        
        // 2. Check LocalStorageManager
        if let localPages = LocalStorageManager.shared.getLocalPages(for: chapter, sourceID: manga.sourceID), !localPages.isEmpty {
            self.pages = localPages
            let segment = ReaderChapterSegment(id: chapter.id.uuidString, chapter: chapter, pageURLs: localPages)
            self.chapterSegments = [segment]
            self.isLoadingPages = false
            return
        }
        
        // 3. Check if chapter already has page URLs in memory
        if !chapter.pageURLs.isEmpty {
            self.pages = chapter.pageURLs
            let segment = ReaderChapterSegment(id: chapter.id.uuidString, chapter: chapter, pageURLs: chapter.pageURLs)
            self.chapterSegments = [segment]
            self.isLoadingPages = false
            prefetchUpcomingPages()
            return
        }
        
        // 4. Remote network image loading fallback
        guard let provider = SourceManager.shared.getSource(id: manga.sourceID) ?? SourceManager.shared.provider(for: manga.sourceID) else {
            self.isLoadingPages = false
            self.errorMessage = "Content source not found."
            return
        }
        
        Task {
            do {
                var cleanChapterId = chapter.sourceChapterID.trimmingCharacters(in: .whitespacesAndNewlines)
                if let lastPart = cleanChapterId.components(separatedBy: "_").last, !lastPart.isEmpty {
                    cleanChapterId = lastPart
                }
                if cleanChapterId.lowercased().hasPrefix("ch_") {
                    cleanChapterId = String(cleanChapterId.dropFirst(3))
                } else if cleanChapterId.lowercased().hasPrefix("chapter_") {
                    cleanChapterId = String(cleanChapterId.dropFirst(8))
                }
                
                let urls = try await provider.fetchPageURLs(for: cleanChapterId)
                self.pages = urls
                let segment = ReaderChapterSegment(id: chapter.id.uuidString, chapter: chapter, pageURLs: urls)
                self.chapterSegments = [segment]
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
    
    // MARK: - Multi-Chapter Seamless Prefetching for Webtoon Mode
    
    public func preloadNextChapterIfNeeded() async {
        guard let lastSegment = chapterSegments.last else { return }
        guard let idx = allMangaChapters.firstIndex(where: { $0.id == lastSegment.chapter.id }),
              idx < allMangaChapters.count - 1 else {
            return
        }
        
        let nextChapter = allMangaChapters[idx + 1]
        let nextChapterKey = nextChapter.id.uuidString
        guard !loadingNextChapterIDs.contains(nextChapterKey) else { return }
        loadingNextChapterIDs.insert(nextChapterKey)
        
        var nextPages: [URL] = []
        
        // 1. Offline check
        if let localURLs = downloadManager.getLocalChapterPageURLs(mangaId: manga.id.uuidString, chapterId: nextChapter.id.uuidString), !localURLs.isEmpty {
            nextPages = localURLs.compactMap { URL(string: $0) }
        } else if let localPages = LocalStorageManager.shared.getLocalPages(for: nextChapter, sourceID: manga.sourceID), !localPages.isEmpty {
            nextPages = localPages
        } else if !nextChapter.pageURLs.isEmpty {
            nextPages = nextChapter.pageURLs
        } else if let provider = SourceManager.shared.getSource(id: manga.sourceID) ?? SourceManager.shared.provider(for: manga.sourceID) {
            var cleanChapterId = nextChapter.sourceChapterID.trimmingCharacters(in: .whitespacesAndNewlines)
            if let lastPart = cleanChapterId.components(separatedBy: "_").last, !lastPart.isEmpty {
                cleanChapterId = lastPart
            }
            if cleanChapterId.lowercased().hasPrefix("ch_") {
                cleanChapterId = String(cleanChapterId.dropFirst(3))
            } else if cleanChapterId.lowercased().hasPrefix("chapter_") {
                cleanChapterId = String(cleanChapterId.dropFirst(8))
            }
            if let fetched = try? await provider.fetchPageURLs(for: cleanChapterId), !fetched.isEmpty {
                nextPages = fetched
                var updated = nextChapter
                updated.pageURLs = fetched
                updated.pageCount = fetched.count
                db.upsertChapters([updated])
            }
        }
        
        guard !nextPages.isEmpty else { return }
        
        // Append segment seamlessly
        let newSegment = ReaderChapterSegment(id: nextChapterKey, chapter: nextChapter, pageURLs: nextPages)
        self.chapterSegments.append(newSegment)
        self.pages.append(contentsOf: nextPages)
    }
    
    // MARK: - Seeking & Slider Two-Way Binding
    
    public func seekToPage(_ pageIndex: Int) {
        let maxPage = totalPagesInCurrentChapter - 1
        guard pageIndex >= 0 && maxPage >= 0 else { return }
        let clamped = min(pageIndex, maxPage)
        self.currentPageIndex = clamped
        self.lastSeekTimestamp = Date()
        self.scrollTargetPageID = "\(currentChapter.id.uuidString)_page_\(clamped)"
        
        onPageChanged(to: clamped, chapter: currentChapter)
    }
    
    public func stepPage(forward: Bool) {
        if forward {
            if currentPageIndex < totalPagesInCurrentChapter - 1 {
                seekToPage(currentPageIndex + 1)
            } else if hasNextChapter {
                goToNextChapter()
            }
        } else {
            if currentPageIndex > 0 {
                seekToPage(currentPageIndex - 1)
            } else if hasPreviousChapter {
                goToPreviousChapter()
            }
        }
    }
    
    public func onPageVisible(index: Int, chapter: ChapterItem) {
        // While user is scrubbing or right after a programmatic seek, ignore viewport tracking
        if isScrubbingSlider || Date().timeIntervalSince(lastSeekTimestamp) < 0.35 {
            return
        }
        
        // Seamless cross-chapter transition
        if chapter.id != currentChapter.id {
            // Mark previous chapter as read
            db.setChapterReadStatus(chapterID: currentChapter.id, isRead: true)
            self.currentChapter = chapter
        }
        
        onPageChanged(to: index, chapter: chapter)
    }
    
    public func onPageChanged(to index: Int, chapter: ChapterItem? = nil) {
        let activeChapter = chapter ?? currentChapter
        guard index >= 0 else { return }
        self.currentPageIndex = index
        
        let total = activeChapter.pageCount > 0 ? activeChapter.pageCount : pages.count
        let isLastPage = (index >= max(0, total - 1))
        
        let elapsed = max(0, min(300, Date().timeIntervalSince(sessionStartTime)))
        sessionStartTime = Date()
        
        // Sync reading progress into database & library automatically
        db.recordReadingProgress(
            chapter: activeChapter,
            manga: manga,
            pageIndex: index,
            isComplete: isLastPage,
            additionalDuration: elapsed
        )
        
        if isLastPage {
            Task {
                await trackerManager.syncProgress(
                    mangaID: manga.id,
                    chapterNumber: Int(activeChapter.chapterNumber),
                    isCompleted: true
                )
            }
        }
        
        prefetchUpcomingPages()
    }
    
    public func goToNextChapter() {
        guard let idx = allMangaChapters.firstIndex(where: { $0.id == currentChapter.id }),
              idx < allMangaChapters.count - 1 else { return }
        
        db.recordReadingProgress(
            chapter: currentChapter,
            manga: manga,
            pageIndex: max(0, pages.count - 1),
            isComplete: true
        )
        
        let nextChapter = allMangaChapters[idx + 1]
        self.currentPageIndex = 0
        self.scrollTargetPageID = "\(nextChapter.id.uuidString)_page_0"
        loadPages(for: nextChapter)
    }
    
    public func goToPreviousChapter() {
        guard let idx = allMangaChapters.firstIndex(where: { $0.id == currentChapter.id }),
              idx > 0 else { return }
        let prevChapter = allMangaChapters[idx - 1]
        self.currentPageIndex = 0
        self.scrollTargetPageID = "\(prevChapter.id.uuidString)_page_0"
        loadPages(for: prevChapter)
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
        guard settings.preloadPagesAhead > 0 else { return }
        guard !pages.isEmpty else { return }
        let start = currentPageIndex + 1
        let end = min(currentPageIndex + settings.preloadPagesAhead, pages.count - 1)
        guard start <= end else { return }
        let nextRange = start...end
        
        Task {
            for idx in nextRange {
                guard idx < pages.count else { continue }
                let url = pages[idx]
                if !url.isFileURL {
                    let cached = await ImageCacheManager.shared.image(for: url)
                    if cached == nil {
                        if let data = try? await NetworkClient.shared.fetchDataWithCDNHeaders(from: url),
                           let img = UIImage(data: data) {
                            await ImageCacheManager.shared.insert(img, for: url, data: data)
                        }
                    }
                }
            }
        }
    }
}
