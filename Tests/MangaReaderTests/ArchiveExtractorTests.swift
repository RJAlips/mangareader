//
//  ArchiveExtractorTests.swift
//  MangaReaderTests
//
//  Created for MangaReader iOS.
//

import XCTest
@testable import MangaReader

final class ArchiveExtractorTests: XCTestCase {
    
    func testNaturalSortingOfImageFilenames() {
        let sampleFilenames = [
            URL(fileURLWithPath: "/tmp/page_10.jpg"),
            URL(fileURLWithPath: "/tmp/page_1.jpg"),
            URL(fileURLWithPath: "/tmp/page_2.jpg"),
            URL(fileURLWithPath: "/tmp/page_20.jpg")
        ]
        
        let sorted = sampleFilenames.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        
        XCTAssertEqual(sorted[0].lastPathComponent, "page_1.jpg")
        XCTAssertEqual(sorted[1].lastPathComponent, "page_2.jpg")
        XCTAssertEqual(sorted[2].lastPathComponent, "page_10.jpg")
        XCTAssertEqual(sorted[3].lastPathComponent, "page_20.jpg")
    }
}
