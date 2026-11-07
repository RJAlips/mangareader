//
//  ReaderViewModelTests.swift
//  MangaReaderTests
//
//  Created for MangaReader iOS.
//

import XCTest
@testable import MangaReader

@MainActor
final class ReaderViewModelTests: XCTestCase {
    
    func testReaderInitialState() {
        let manga = MangaItem(
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "test-manga",
            title: "Test Manga",
            preferredReadingMode: .webtoon
        )
        let chapter = ChapterItem(
            mangaID: manga.id,
            sourceChapterID: "ch-1",
            chapterNumber: 1.0,
            pageCount: 5,
            pageURLs: [
                URL(string: "https://example.com/1.jpg")!,
                URL(string: "https://example.com/2.jpg")!
            ]
        )
        
        let vm = ReaderViewModel(manga: manga, chapter: chapter)
        XCTAssertEqual(vm.readingMode, .webtoon)
        XCTAssertEqual(vm.currentPageIndex, 0)
        XCTAssertTrue(vm.showControls)
        
        vm.toggleControls()
        XCTAssertFalse(vm.showControls)
    }
    
    func testPageChangedUpdatesIndex() {
        let manga = MangaItem(
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "test-manga",
            title: "Test Manga"
        )
        let chapter = ChapterItem(
            mangaID: manga.id,
            sourceChapterID: "ch-1",
            chapterNumber: 1.0,
            pageCount: 3,
            pageURLs: [
                URL(string: "https://example.com/1.jpg")!,
                URL(string: "https://example.com/2.jpg")!,
                URL(string: "https://example.com/3.jpg")!
            ]
        )
        let vm = ReaderViewModel(manga: manga, chapter: chapter)
        
        vm.onPageChanged(to: 2)
        XCTAssertEqual(vm.currentPageIndex, 2)
    }
}
