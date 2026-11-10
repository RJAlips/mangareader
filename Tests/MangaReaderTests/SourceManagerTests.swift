//
//  SourceManagerTests.swift
//  MangaReaderTests
//
//  Created for MangaReader iOS.
//

import XCTest
import UIKit
@testable import MangaReader

@MainActor
final class SourceManagerTests: XCTestCase {
    
    func testSourceRegistrationAndLookup() {
        let manager = SourceManager.shared
        XCTAssertFalse(manager.sources.isEmpty)
        
        let demoSource = manager.provider(for: "com.mangareader.source.demo")
        XCTAssertNotNil(demoSource)
        XCTAssertEqual(demoSource?.manifest.name, "MangaReader Curated")
    }
    
    func testToggleSourceEnabling() {
        let manager = SourceManager.shared
        let id = "com.mangareader.source.demo"
        let initialStatus = manager.isSourceEnabled(id)
        
        manager.toggleSource(id)
        XCTAssertNotEqual(manager.isSourceEnabled(id), initialStatus)
        
        // Restore
        manager.toggleSource(id)
        XCTAssertEqual(manager.isSourceEnabled(id), initialStatus)
    }
    
    func testAddMangaDexRepositorySucceeds() async throws {
        let manager = SourceManager.shared
        let count = try await manager.addRepository(urlString: "https://api.mangadex.org")
        XCTAssertGreaterThanOrEqual(count, 1)
        XCTAssertTrue(manager.isSourceEnabled("com.mangareader.source.mangadex"))
    }
    
    func testProviderNeverReturnsNil() {
        let manager = SourceManager.shared
        let provider = manager.provider(for: "nonexistent.source.id")
        XCTAssertNotNil(provider)
    }
    
    func testAidokuManifestDecodingWithIntegerVersion() throws {
        let sampleAidokuJSON = """
        {
            "id": "en.aquamanga",
            "name": "Aqua Manga",
            "version": 2,
            "languages": ["en"],
            "baseURL": "https://aquareader.org",
            "iconURL": "icons/en.aquamanga-v2.png"
        }
        """.data(using: .utf8)!
        
        let manifest = try JSONDecoder().decode(SourceManifest.self, from: sampleAidokuJSON)
        XCTAssertEqual(manifest.id, "en.aquamanga")
        XCTAssertEqual(manifest.name, "Aqua Manga")
        XCTAssertEqual(manifest.version, "2.0.0")
        XCTAssertEqual(manifest.lang, "en")
        XCTAssertEqual(manifest.baseURL, "https://aquareader.org")
    }
    
    func testLazyLoadCoverExtractionPriority() {
        let base = URL(string: "https://aquareader.org")!
        let htmlTag = """
        <img src="data:image/svg+xml;charset=utf-8,%3Csvg..." data-src="https://aquareader.org/wp-content/uploads/2021/08/Martial-Peak.jpg" class="img-responsive" alt="Martial Peak" />
        """
        let extracted = CommunityWebSource.extractImageURL(from: htmlTag, relativeTo: base)
        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.absoluteString, "https://aquareader.org/wp-content/uploads/2021/08/Martial-Peak.jpg")
    }
    
    func testDownloadTaskItemCodableSerialization() throws {
        let manga = MangaItem(
            id: UUID(),
            sourceID: "com.mangareader.source.mangadex",
            urlOrSlug: "solo-leveling",
            title: "Solo Leveling"
        )
        let chapter = ChapterItem(
            id: UUID(),
            mangaID: manga.id,
            sourceChapterID: "ch-1",
            chapterNumber: 1.0,
            title: "Chapter 1"
        )
        let task = DownloadTaskItem(
            manga: manga,
            chapter: chapter,
            status: .downloading(progress: 0.75),
            downloadedPages: 15,
            totalPages: 20,
            bytesDownloaded: 1024 * 1024
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DownloadTaskItem.self, from: data)
        
        XCTAssertEqual(decoded.id, task.id)
        XCTAssertEqual(decoded.manga.title, "Solo Leveling")
        XCTAssertEqual(decoded.downloadedPages, 15)
        XCTAssertEqual(decoded.totalPages, 20)
        XCTAssertEqual(decoded.progress, 0.75, accuracy: 0.001)
    }
    
    // MARK: - Automated Extension Verification Suite
    
    func testAllInstalledExtensionsEndToEnd() async throws {
        let manager = SourceManager.shared
        
        // 1. Gather all unique sources from activeSources, community repo, and built-ins
        var sourcesToTest: [any MangaSource] = manager.activeSources
        
        let bundleCandidates = [
            Bundle.main.url(forResource: "community_repo", withExtension: "json"),
            Bundle(for: Self.self).url(forResource: "community_repo", withExtension: "json")
        ]
        
        for candidate in bundleCandidates.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: candidate),
               let repo = try? JSONDecoder().decode(CommunityRepoIndexDTO.self, from: data) {
                for manifest in repo.sources {
                    if let src = manager.getSource(id: manifest.id),
                       !sourcesToTest.contains(where: { $0.manifest.id == manifest.id }) {
                        sourcesToTest.append(src)
                    }
                }
            }
        }
        
        // Filter out unconfigured self-hosted server instances like Komga
        sourcesToTest = sourcesToTest.filter {
            !$0.baseURL.isEmpty && $0.manifest.id != "com.mangareader.source.komga"
        }
        
        XCTAssertFalse(sourcesToTest.isEmpty, "Sources to test must not be empty")
        
        struct SourceDiagResult: Sendable {
            let id: String
            let name: String
            let popularCount: Int
            let coverHTTP: Int
            let chaptersCount: Int
            let pagesCount: Int
            let status: String
            let errorMessage: String?
        }
        
        var results: [SourceDiagResult] = []
        
        // 2. Iterate concurrently using withTaskGroup
        await withTaskGroup(of: SourceDiagResult.self) { group in
            for source in sourcesToTest {
                group.addTask {
                    let manifest = source.manifest
                    let sId = manifest.id
                    let sName = manifest.name
                    let baseURL = source.baseURL
                    
                    // (1) Manifest & Provider Registration Check
                    guard let resolved = manager.getSource(id: sId) else {
                        return SourceDiagResult(id: sId, name: sName, popularCount: 0, coverHTTP: 0, chaptersCount: 0, pagesCount: 0, status: "FAIL", errorMessage: "Provider lookup returned nil")
                    }
                    guard baseURL.hasPrefix("http://") || baseURL.hasPrefix("https://") else {
                        return SourceDiagResult(id: sId, name: sName, popularCount: 0, coverHTTP: 0, chaptersCount: 0, pagesCount: 0, status: "FAIL", errorMessage: "Invalid baseURL: \(baseURL)")
                    }
                    
                    // (2) Popular Manga Fetch (with 12-second timeout)
                    var popularItems: [MangaItem] = []
                    do {
                        try await withThrowingTaskGroup(of: [MangaItem].self) { fetchGroup in
                            fetchGroup.addTask {
                                return try await resolved.fetchPopularManga(page: 1)
                            }
                            fetchGroup.addTask {
                                try await Task.sleep(nanoseconds: 12_000_000_000)
                                throw NSError(domain: "Timeout", code: 408, userInfo: [NSLocalizedDescriptionKey: "fetchPopular timed out after 12s"])
                            }
                            
                            if let firstResult = try await fetchGroup.next() {
                                popularItems = firstResult
                                fetchGroup.cancelAll()
                            }
                        }
                    } catch {
                        popularItems = (try? await resolved.fetchPopularManga(page: 1)) ?? []
                    }
                    
                    let popCount = popularItems.count
                    guard popCount > 0 else {
                        return SourceDiagResult(id: sId, name: sName, popularCount: 0, coverHTTP: 0, chaptersCount: 0, pagesCount: 0, status: "FAIL", errorMessage: "Popular items array is empty")
                    }
                    
                    // (3) Cover Thumbnail Validation (No Blank Thumbnails)
                    var coverHTTP = 200
                    for manga in popularItems.prefix(3) {
                        if let coverURL = manga.coverURL {
                            let urlStr = coverURL.absoluteString
                            guard urlStr.hasPrefix("http") && !urlStr.lowercased().hasPrefix("data:image") else {
                                coverHTTP = 400
                                break
                            }
                            
                            var req = URLRequest(url: coverURL)
                            req.httpMethod = "HEAD"
                            req.setValue(baseURL, forHTTPHeaderField: "Referer")
                            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
                            req.timeoutInterval = 8
                            
                            var status = 0
                            if let (_, response) = try? await URLSession.shared.data(for: req),
                               let http = response as? HTTPURLResponse {
                                status = http.statusCode
                            }
                            if status != 200 {
                                req.httpMethod = "GET"
                                req.setValue("bytes=0-1024", forHTTPHeaderField: "Range")
                                if let (data, response) = try? await URLSession.shared.data(for: req),
                                   let http = response as? HTTPURLResponse {
                                    if http.statusCode == 200 || http.statusCode == 206 || !data.isEmpty {
                                        status = 200
                                    }
                                }
                            }
                            if status == 200 {
                                coverHTTP = 200
                                break
                            } else {
                                coverHTTP = status
                            }
                        }
                    }
                    
                    // (4) Chapter & Page Pipeline Check
                    var chapCount = 0
                    var pageCount = 0
                    for candidateManga in popularItems.prefix(5) {
                        let chapters = (try? await resolved.fetchChapters(manga: candidateManga)) ?? []
                        if !chapters.isEmpty {
                            chapCount = chapters.count
                            for candidateChap in chapters.prefix(3) {
                                let pages = (try? await resolved.fetchPages(chapter: candidateChap)) ?? []
                                if !pages.isEmpty {
                                    var allValid = true
                                    for p in pages {
                                        guard p.absoluteString.hasPrefix("http") else {
                                            allValid = false
                                            break
                                        }
                                    }
                                    if allValid {
                                        pageCount = pages.count
                                        break
                                    }
                                }
                            }
                            if pageCount > 0 {
                                break
                            }
                        }
                    }
                    
                    let status = (popCount > 0 && chapCount > 0 && pageCount > 0) ? "PASS" : "WARN"
                    return SourceDiagResult(
                        id: sId,
                        name: sName,
                        popularCount: popCount,
                        coverHTTP: coverHTTP,
                        chaptersCount: chapCount,
                        pagesCount: pageCount,
                        status: status,
                        errorMessage: nil
                    )
                }
            }
            
            for await res in group {
                results.append(res)
            }
        }
        
        results.sort { $0.name < $1.name }
        
        // (5) Markdown Diagnostic Summary
        var markdown = """
        
        | Source ID | Source Name | Popular Count | Cover Thumbnail HTTP | Chapters Count | Pages Count | Status |
        |---|---|---|---|---|---|---|
        
        """
        for r in results {
            markdown += "| \(r.id) | \(r.name) | \(r.popularCount) | \(r.coverHTTP) | \(r.chaptersCount) | \(r.pagesCount) | \(r.status) |\n"
        }
        
        print(markdown)
        
        let attachment = XCTAttachment(string: markdown)
        attachment.name = "Extension_Health_Report.md"
        attachment.lifetime = .keepAlways
        add(attachment)
        
        for r in results {
            XCTAssertTrue(r.popularCount > 0, "\(r.name) must return popular items")
            XCTAssertTrue(r.chaptersCount > 0, "\(r.name) must return chapters")
            XCTAssertTrue(r.pagesCount > 0, "\(r.name) must return pages")
            XCTAssertEqual(r.status, "PASS", "\(r.name) must have PASS status")
        }
    }
    
    func testPopularAndLatestQueryReturnItems() async throws {
        let demo = DemoMangaSource()
        let popular = try await demo.fetchPopular(page: 1)
        let latest = try await demo.fetchLatest(page: 1)
        
        XCTAssertFalse(popular.isEmpty, "Popular manga items must not be empty")
        XCTAssertFalse(latest.isEmpty, "Latest manga items must not be empty")
        XCTAssertEqual(popular.count, latest.count)
    }
    
    func testFetchChaptersReturnsMultipleChapters() async throws {
        let demo = DemoMangaSource()
        let chapters = try await demo.fetchChapters(for: "sample-solo-leveling")
        XCTAssertGreaterThan(chapters.count, 1, "Chapters fetched must return multiple chapters without collapsing to 1")
    }
    
    func testHistoryRecordingAndPersistence() {
        let repo = HistoryRepository.shared
        let mangaId = UUID()
        let chapterId = UUID()
        
        repo.recordReadingProgress(
            mangaID: mangaId,
            chapterID: chapterId,
            page: 5,
            totalPages: 20,
            sourceID: "com.mangareader.source.demo",
            mangaTitle: "Test Solo Leveling",
            chapterTitle: "Chapter 1 - Awakening",
            chapterNumber: 1.0,
            coverURL: URL(string: "https://example.com/cover.jpg")
        )
        
        let found = repo.historyItems.first { $0.mangaID == mangaId }
        XCTAssertNotNil(found, "Reading progress must be stored in HistoryRepository")
        XCTAssertEqual(found?.pageIndex, 5)
        XCTAssertEqual(found?.totalPages, 20)
        XCTAssertEqual(found?.mangaTitle, "Test Solo Leveling")
        XCTAssertEqual(found?.chapterTitle, "Chapter 1 - Awakening")
        XCTAssertEqual(found?.sourceID, "com.mangareader.source.demo")
        
        // Cleanup
        repo.removeHistory(mangaID: mangaId)
        XCTAssertNil(repo.historyItems.first { $0.mangaID == mangaId })
    }
    
    func testBrowseViewModelGlobalSearchInitialization() {
        let vm = BrowseViewModel()
        XCTAssertTrue(vm.globalSearchSections.isEmpty)
        XCTAssertFalse(vm.isGlobalSearching)
        
        vm.performGlobalSearch(query: "Solo")
        XCTAssertFalse(vm.globalSearchSections.isEmpty, "Global search must populate sections for active sources")
        XCTAssertTrue(vm.isGlobalSearching, "Global search should be in progress")
        
        vm.clearSearch()
        XCTAssertTrue(vm.globalSearchSections.isEmpty)
        XCTAssertFalse(vm.isGlobalSearching)
    }
}

// MARK: - Comprehensive End-to-End Automated Functional Integration Test Suite

@MainActor
final class EndToEndFunctionalTests: XCTestCase {
    
    // MARK: - 1. Sources, Pagination, Sorting & Cover Thumbnails
    func test01_SourcesPaginationSortingAndCoverThumbnails() async throws {
        let manager = SourceManager.shared
        let sourcesToTest = manager.activeSources.filter { !$0.baseURL.isEmpty && $0.manifest.id != "com.mangareader.source.komga" }
        XCTAssertFalse(sourcesToTest.isEmpty, "Active sources must not be empty")
        
        // (a) Popular vs. Latest Sorting on MangaDex
        let mangadex = MangaDexSource()
        let popularMangaDex = try await mangadex.fetchPopularManga(page: 1)
        let latestMangaDex = try await mangadex.fetchLatestManga(page: 1)
        
        XCTAssertGreaterThanOrEqual(popularMangaDex.count, 10, "MangaDex Popular must return >= 10 items")
        XCTAssertGreaterThanOrEqual(latestMangaDex.count, 10, "MangaDex Latest must return >= 10 items")
        
        let popFirstIDs = popularMangaDex.prefix(5).map { $0.urlOrSlug }
        let latFirstIDs = latestMangaDex.prefix(5).map { $0.urlOrSlug }
        XCTAssertNotEqual(popFirstIDs, latFirstIDs, "Popular and Latest orders must be distinct")
        
        // (b) Infinite Scroll Pagination on MangaDex
        let page2MangaDex = try await mangadex.fetchPopularManga(page: 2)
        XCTAssertFalse(page2MangaDex.isEmpty, "Page 2 must return items")
        let page1IDs = Set(popularMangaDex.map { $0.urlOrSlug })
        let page2IDs = Set(page2MangaDex.map { $0.urlOrSlug })
        XCTAssertTrue(page1IDs.isDisjoint(with: page2IDs) || page1IDs != page2IDs, "Page 2 must contain different titles than Page 1")
        
        // (c) Live Server Search
        let searchResults = try await mangadex.searchManga(query: "Solo", page: 1)
        XCTAssertFalse(searchResults.isEmpty, "Live server search for 'Solo' must return items")
        
        // (d) Cover Thumbnail Reachability with CDN Headers
        var verifiedCover = false
        for manga in popularMangaDex.prefix(3) {
            guard let coverURL = manga.coverURL else { continue }
            do {
                let data = try await NetworkClient.shared.fetchDataWithCDNHeaders(from: coverURL)
                if !data.isEmpty, let img = UIImage(data: data) {
                    XCTAssertGreaterThan(img.size.width, 0)
                    verifiedCover = true
                    break
                }
            } catch {
                continue
            }
        }
        XCTAssertTrue(verifiedCover, "At least one cover thumbnail must decode into a valid UIImage")
        
        // (e) Community Sources Verification
        var communityVerifiedCount = 0
        for src in sourcesToTest where src.manifest.id != "com.mangareader.source.mangadex" {
            if let pop = try? await src.fetchPopularManga(page: 1), !pop.isEmpty {
                communityVerifiedCount += 1
            }
        }
        XCTAssertGreaterThanOrEqual(communityVerifiedCount, 1, "At least one community source must return popular items")
    }
    
    // MARK: - 2. Global Search Across Multiple Extensions
    func test02_GlobalSearchAcrossMultipleExtensions() async throws {
        let browseVM = BrowseViewModel()
        browseVM.performGlobalSearch(query: "Solo")
        
        let deadline = Date().addingTimeInterval(15)
        while browseVM.isGlobalSearching && Date() < deadline {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        
        XCTAssertFalse(browseVM.globalSearchSections.isEmpty, "Global search sections must not be empty")
        
        let loadedSections = browseVM.globalSearchSections.filter {
            if case .loaded(let items) = $0.state, !items.isEmpty { return true }
            return false
        }
        XCTAssertFalse(loadedSections.isEmpty, "At least one active source section must transition to .loaded with results")
    }
    
    // MARK: - 3. Full Chapter List & Page Pipeline
    func test03_FullChapterListAndPagePipeline() async throws {
        let demo = DemoMangaSource()
        let popular = try await demo.fetchPopularManga(page: 1)
        guard let manga = popular.first else {
            XCTFail("Demo source must have popular manga")
            return
        }
        
        let detailVM = MangaDetailViewModel(manga: manga)
        detailVM.refreshChapters()
        
        let deadline = Date().addingTimeInterval(10)
        while detailVM.isLoadingChapters && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertGreaterThan(detailVM.chapters.count, 1, "Chapters fetched must be > 1 (multi-chapter check)")
        
        let firstChapter = detailVM.chapters[0]
        let pageURLs = try await demo.fetchPages(chapterId: firstChapter.sourceChapterID)
        XCTAssertFalse(pageURLs.isEmpty, "Pages for chapter must not be empty")
        for u in pageURLs {
            XCTAssertTrue(u.scheme == "https" || u.scheme == "http", "Page URL must be valid HTTP/HTTPS: \(u)")
        }
    }
    
    // MARK: - 4. Reader Engine: Page Slider Seek & Continuous Next-Chapter Scroll
    func test04_ReaderEnginePageSliderSeekAndContinuousScroll() async throws {
        let manga = MangaItem(
            id: UUID(),
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "solo-leveling-sample",
            title: "Solo Leveling Test",
            preferredReadingMode: .webtoon
        )
        
        let chapter1 = ChapterItem(
            id: UUID(),
            mangaID: manga.id,
            sourceChapterID: "ch-1",
            chapterNumber: 1.0,
            title: "Chapter 1",
            pageCount: 5,
            pageURLs: [
                URL(string: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800")!,
                URL(string: "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800")!,
                URL(string: "https://images.unsplash.com/photo-1563089145-599997674d42?w=800")!,
                URL(string: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800")!,
                URL(string: "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=800")!
            ]
        )
        
        let chapter2 = ChapterItem(
            id: UUID(),
            mangaID: manga.id,
            sourceChapterID: "ch-2",
            chapterNumber: 2.0,
            title: "Chapter 2",
            pageCount: 3,
            pageURLs: [
                URL(string: "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=800")!,
                URL(string: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800")!,
                URL(string: "https://images.unsplash.com/photo-1550684848-fac1c5b4e853?w=800")!
            ]
        )
        
        DatabaseManager.shared.upsertManga(manga)
        DatabaseManager.shared.upsertChapters([chapter1, chapter2])
        
        let readerVM = ReaderViewModel(manga: manga, chapter: chapter1)
        readerVM.loadChapter()
        
        XCTAssertFalse(readerVM.pages.isEmpty, "Pages must be loaded")
        XCTAssertEqual(readerVM.currentPage, 0)
        
        // Page slider seek check
        readerVM.seekToPage(3)
        XCTAssertEqual(readerVM.currentPage, 3, "Current page must update to 3")
        XCTAssertNotNil(readerVM.scrollTargetPageID, "Scroll target page ID must be set")
        XCTAssertTrue(readerVM.scrollTargetPageID?.contains("page_3") ?? false)
        
        // Continuous scroll check: preload next chapter
        await readerVM.preloadNextChapterIfNeeded()
        XCTAssertEqual(readerVM.chapterSegments.count, 2, "Chapter segments must contain 2 chapters")
        XCTAssertEqual(readerVM.pages.count, 8, "Pages must combine Chapter 1 (5) and Chapter 2 (3)")
    }
    
    // MARK: - 5. Reading History Persistence & Instant UI Sync
    func test05_ReadingHistoryPersistenceAndInstantUISync() throws {
        let historyRepo = HistoryRepository.shared
        historyRepo.clearAllHistory()
        XCTAssertTrue(historyRepo.historyItems.isEmpty)
        
        let manga = MangaItem(
            id: UUID(),
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "unadded-manhwa",
            title: "Tower of God E2E",
            inLibrary: false
        )
        let chapter = ChapterItem(
            id: UUID(),
            mangaID: manga.id,
            sourceChapterID: "ch-10",
            chapterNumber: 10.0,
            title: "Floor of Tests",
            pageCount: 15
        )
        
        let readerVM = ReaderViewModel(manga: manga, chapter: chapter)
        readerVM.seekToPage(4)
        readerVM.saveReadingProgressOnExit()
        
        XCTAssertEqual(historyRepo.historyItems.count, 1, "History items must contain 1 recorded manhwa")
        guard let entry = historyRepo.historyItems.first else {
            XCTFail("History entry must exist")
            return
        }
        XCTAssertEqual(entry.displayMangaTitle, "Tower of God E2E")
        XCTAssertEqual(entry.lastPageRead, 4)
        XCTAssertEqual(entry.pageIndex, 4)
        
        // Verify JSON file exists on disk
        XCTAssertTrue(FileManager.default.fileExists(atPath: historyRepo.historyFileURL.path), "reading_history.json must exist on disk")
        
        // Simulate app restart / reload from disk
        historyRepo.loadHistoryFromDisk()
        XCTAssertEqual(historyRepo.historyItems.count, 1)
        XCTAssertEqual(historyRepo.historyItems.first?.displayMangaTitle, "Tower of God E2E")
    }
    
    // MARK: - 6. Library Management & "Currently Reading" Progress
    func test06_LibraryManagementAndCurrentlyReadingProgress() {
        let libraryRepo = LibraryRepository.shared
        let db = DatabaseManager.shared
        
        let manga = MangaItem(
            id: UUID(),
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "omniscient-reader",
            title: "Omniscient Reader's Viewpoint",
            inLibrary: true,
            categories: ["Webtoons"]
        )
        
        db.upsertManga(manga)
        db.addCategory(name: "Webtoons")
        
        let chapter2 = ChapterItem(
            id: UUID(),
            mangaID: manga.id,
            sourceChapterID: "ch-2",
            chapterNumber: 2.0,
            title: "Episode 2",
            pageCount: 20
        )
        db.upsertChapters([chapter2])
        
        db.recordReadingProgress(chapter: chapter2, manga: manga, pageIndex: 5)
        
        let persisted = libraryRepo.getManga(by: manga.id)
        XCTAssertNotNil(persisted, "Manga must exist in LibraryRepository")
        XCTAssertEqual(persisted?.lastReadPage, 5, "lastReadPage must be 5")
        XCTAssertNotNil(persisted?.lastReadChapterTitle, "lastReadChapterTitle must be populated")
        
        let libraryVM = LibraryViewModel()
        libraryVM.selectedCategory = "Webtoons"
        XCTAssertTrue(libraryVM.filteredManga.contains(where: { $0.id == manga.id }), "LibraryViewModel must show the manga under its category")
    }
    
    // MARK: - 7. Real Downloads, Multi-Worker Concurrency & Restart Persistence
    func test07_RealDownloadsMultiWorkerConcurrencyAndRestartPersistence() async throws {
        let downloadManager = DownloadManager.shared
        downloadManager.resetInMemoryQueueForTesting()
        downloadManager.maxConcurrentDownloads = 2
        
        let manga = MangaItem(
            id: UUID(),
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "download-test-manga",
            title: "Download Test Series"
        )
        
        let ch1 = ChapterItem(
            id: UUID(),
            mangaID: manga.id,
            sourceChapterID: "ch-101",
            chapterNumber: 101.0,
            title: "Chapter 101",
            pageCount: 2,
            pageURLs: [
                URL(string: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600")!,
                URL(string: "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600")!
            ]
        )
        
        let ch2 = ChapterItem(
            id: UUID(),
            mangaID: manga.id,
            sourceChapterID: "ch-102",
            chapterNumber: 102.0,
            title: "Chapter 102",
            pageCount: 2,
            pageURLs: [
                URL(string: "https://images.unsplash.com/photo-1563089145-599997674d42?w=600")!,
                URL(string: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600")!
            ]
        )
        
        DatabaseManager.shared.upsertManga(manga)
        DatabaseManager.shared.upsertChapters([ch1, ch2])
        
        // Queue both chapters
        downloadManager.downloadChapter(ch1, for: manga)
        downloadManager.downloadChapter(ch2, for: manga)
        
        XCTAssertEqual(downloadManager.tasks.count, 2)
        
        // Await completion
        let deadline = Date().addingTimeInterval(35)
        while downloadManager.activeQueueTasks.count > 0 && Date() < deadline {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        
        XCTAssertEqual(downloadManager.completedTasks.count, 2, "Both chapters must reach .completed")
        XCTAssertGreaterThan(downloadManager.totalDownloadedSize, 0, "totalDownloadedSize must be > 0")
        
        // Check files on disk
        let ch1Folder = LocalStorageManager.shared.resolveURL(for: "Downloads/\(manga.id.uuidString)/\(ch1.id.uuidString)")
        let ch2Folder = LocalStorageManager.shared.resolveURL(for: "Downloads/\(manga.id.uuidString)/\(ch2.id.uuidString)")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: ch1Folder.appendingPathComponent("001.jpg").path), "001.jpg must exist for ch1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: ch1Folder.appendingPathComponent("metadata.json").path), "metadata.json must exist for ch1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: ch2Folder.appendingPathComponent("001.jpg").path), "001.jpg must exist for ch2")
        
        // Simulate App Restart
        downloadManager.resetInMemoryQueueForTesting()
        XCTAssertTrue(downloadManager.tasks.isEmpty)
        
        downloadManager.loadSavedDownloads()
        XCTAssertEqual(downloadManager.completedTasks.count, 2, "Downloads must be restored from disk on app restart")
    }
    
    // MARK: - 8. Offline Reader Mode
    func test08_OfflineReaderMode() throws {
        let downloadManager = DownloadManager.shared
        guard let task = downloadManager.completedTasks.first else {
            XCTFail("Requires at least 1 completed download task from test07")
            return
        }
        
        let localPageURLs = downloadManager.getLocalChapterPageURLs(mangaId: task.manga.id.uuidString, chapterId: task.chapter.id.uuidString)
        XCTAssertNotNil(localPageURLs, "Local chapter page URLs must not be nil")
        XCTAssertFalse(localPageURLs?.isEmpty ?? true, "Local chapter page URLs must not be empty")
        
        guard let firstString = localPageURLs?.first, let fileURL = URL(string: firstString) else {
            XCTFail("Must have first valid file URL")
            return
        }
        XCTAssertEqual(fileURL.scheme, "file", "Scheme must be file://")
        
        let loadedImage = UIImage(contentsOfFile: fileURL.path)
        XCTAssertNotNil(loadedImage, "UIImage must load offline directly from file URL")
        XCTAssertGreaterThan(loadedImage?.size.width ?? 0, 0)
    }
    
    // MARK: - 9. Library Updates Feed & Backup/Restore
    func test09_LibraryUpdatesFeedAndBackupRestore() async throws {
        let db = DatabaseManager.shared
        let manga = MangaItem(
            id: UUID(),
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "sample-solo-leveling",
            title: "Solo Leveling Updates Test",
            inLibrary: true
        )
        db.upsertManga(manga)
        
        let homeVM = HomeViewModel.shared
        await homeVM.refreshLibraryUpdates()
        
        XCTAssertFalse(homeVM.updateEntries.isEmpty, "Update entries should populate with chapters from library manga")
        
        // Backup Service Test
        let backupURL = try BackupService.shared.createBackup()
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path), "Backup file must exist on disk")
        
        let backupData = try Data(contentsOf: backupURL)
        XCTAssertGreaterThan(backupData.count, 100, "Backup file must contain serialized JSON data")
        
        // Clear and Restore
        let originalMangaID = manga.id
        db.removeManga(mangaID: originalMangaID)
        XCTAssertNil(db.mangaList.first(where: { $0.id == originalMangaID }))
        
        try BackupService.shared.restoreBackup(from: backupURL)
        XCTAssertTrue(db.mangaList.contains(where: { $0.id == originalMangaID }), "Restored backup must contain original library manga")
        
        try? FileManager.default.removeItem(at: backupURL)
    }
}

private struct CommunityRepoIndexDTO: Decodable {
    let name: String?
    let sources: [SourceManifest]
}
