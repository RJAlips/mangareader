//
//  BackupServiceTests.swift
//  MangaReaderTests
//
//  Created for MangaReader iOS.
//

import XCTest
@testable import MangaReader

final class BackupServiceTests: XCTestCase {
    
    func testBackupSerializationRoundtrip() throws {
        let sampleManga = MangaItem(
            sourceID: "test",
            urlOrSlug: "test-slug",
            title: "Test Manga Backup"
        )
        let sampleChapter = ChapterItem(
            mangaID: sampleManga.id,
            sourceChapterID: "ch-1",
            chapterNumber: 1.0
        )
        let sampleCategory = CategoryItem(name: "Favorites", sortOrder: 1)
        let sampleProgress = ReadingProgress(chapterID: sampleChapter.id, mangaID: sampleManga.id, pageIndex: 2, totalPages: 10)
        
        let backup = BackupData(
            libraryManga: [sampleManga],
            chapters: [sampleChapter],
            categories: [sampleCategory],
            history: [sampleProgress]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackupData.self, from: data)
        
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.libraryManga.count, 1)
        XCTAssertEqual(decoded.libraryManga.first?.title, "Test Manga Backup")
        XCTAssertEqual(decoded.chapters.count, 1)
        XCTAssertEqual(decoded.categories.count, 1)
        XCTAssertEqual(decoded.history.count, 1)
    }
}
