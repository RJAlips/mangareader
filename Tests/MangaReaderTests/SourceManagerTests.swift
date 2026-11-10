//
//  SourceManagerTests.swift
//  MangaReaderTests
//
//  Created for MangaReader iOS.
//

import XCTest
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

private struct CommunityRepoIndexDTO: Decodable {
    let name: String?
    let sources: [SourceManifest]
}
