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
}
