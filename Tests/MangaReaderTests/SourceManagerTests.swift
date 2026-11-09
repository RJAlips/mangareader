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
}
