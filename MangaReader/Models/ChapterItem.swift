//
//  ChapterItem.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public struct ChapterItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var mangaID: UUID
    public var sourceChapterID: String
    public var chapterNumber: Double
    public var volumeNumber: Double?
    public var title: String?
    public var scanlator: String?
    public var releaseDate: Date?
    public var pageCount: Int
    public var pageURLs: [URL]
    public var isRead: Bool
    public var lastPageRead: Int
    public var isDownloaded: Bool
    public var downloadProgress: Double
    public var localDirectoryPath: String?
    public var dateAdded: Date
    
    public init(
        id: UUID = UUID(),
        mangaID: UUID,
        sourceChapterID: String,
        chapterNumber: Double,
        volumeNumber: Double? = nil,
        title: String? = nil,
        scanlator: String? = nil,
        releaseDate: Date? = nil,
        pageCount: Int = 0,
        pageURLs: [URL] = [],
        isRead: Bool = false,
        lastPageRead: Int = 0,
        isDownloaded: Bool = false,
        downloadProgress: Double = 0.0,
        localDirectoryPath: String? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.mangaID = mangaID
        self.sourceChapterID = sourceChapterID
        self.chapterNumber = chapterNumber
        self.volumeNumber = volumeNumber
        self.title = title
        self.scanlator = scanlator
        self.releaseDate = releaseDate
        self.pageCount = pageCount
        self.pageURLs = pageURLs
        self.isRead = isRead
        self.lastPageRead = lastPageRead
        self.isDownloaded = isDownloaded
        self.downloadProgress = downloadProgress
        self.localDirectoryPath = localDirectoryPath
        self.dateAdded = dateAdded
    }
    
    public var formattedNumber: String {
        if floor(chapterNumber) == chapterNumber {
            return String(format: "%.0f", chapterNumber)
        } else {
            return String(format: "%.1f", chapterNumber)
        }
    }
    
    public var displayTitle: String {
        if let title = title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Ch. \(formattedNumber) - \(title)"
        } else {
            return "Chapter \(formattedNumber)"
        }
    }
}
