//
//  SourceManagerTests.swift
//  MangaReaderTests
//
//  Created for MangaReader iOS.
//

import XCTest
@testable import MangaReader

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
}
