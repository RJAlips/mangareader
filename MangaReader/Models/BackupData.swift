//
//  BackupData.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public struct BackupData: Codable {
    public var version: Int = 1
    public var exportDate: Date = Date()
    public var appVersion: String = "1.0.0"
    public var libraryManga: [MangaItem]
    public var chapters: [ChapterItem]
    public var categories: [CategoryItem]
    public var history: [ReadingProgress]
    public var readerSettings: ReaderSettings
    public var trackingLinks: [String: String] // mangaID UUID string -> external tracker ID
    
    public init(
        libraryManga: [MangaItem],
        chapters: [ChapterItem],
        categories: [CategoryItem],
        history: [ReadingProgress],
        readerSettings: ReaderSettings = ReaderSettings(),
        trackingLinks: [String: String] = [:]
    ) {
        self.libraryManga = libraryManga
        self.chapters = chapters
        self.categories = categories
        self.history = history
        self.readerSettings = readerSettings
        self.trackingLinks = trackingLinks
    }
}
