//
//  ModelTests.swift
//  MangaReaderTests
//
//  Created for MangaReader iOS.
//

import XCTest
@testable import MangaReader

final class ModelTests: XCTestCase {
    
    func testChapterFormatting() {
        let chapterInteger = ChapterItem(
            mangaID: UUID(),
            sourceChapterID: "ch-10",
            chapterNumber: 10.0,
            title: "Awakening"
        )
        XCTAssertEqual(chapterInteger.formattedNumber, "10")
        XCTAssertEqual(chapterInteger.displayTitle, "Ch. 10 - Awakening")
        
        let chapterDecimal = ChapterItem(
            mangaID: UUID(),
            sourceChapterID: "ch-10.5",
            chapterNumber: 10.5,
            title: "Special Chapter"
        )
        XCTAssertEqual(chapterDecimal.formattedNumber, "10.5")
        XCTAssertEqual(chapterDecimal.displayTitle, "Ch. 10.5 - Special Chapter")
        
        let chapterUntitled = ChapterItem(
            mangaID: UUID(),
            sourceChapterID: "ch-1",
            chapterNumber: 1.0,
            title: nil
        )
        XCTAssertEqual(chapterUntitled.displayTitle, "Chapter 1")
    }
    
    func testReadingProgressCalculation() {
        let progress = ReadingProgress(
            chapterID: UUID(),
            mangaID: UUID(),
            pageIndex: 4,
            totalPages: 10
        )
        // 5 / 10 = 0.5 (50%)
        XCTAssertEqual(progress.progressPercent, 0.5, accuracy: 0.001)
        
        let zeroProgress = ReadingProgress(
            chapterID: UUID(),
            mangaID: UUID(),
            pageIndex: 0,
            totalPages: 0
        )
        XCTAssertEqual(zeroProgress.progressPercent, 0.0)
    }
}
