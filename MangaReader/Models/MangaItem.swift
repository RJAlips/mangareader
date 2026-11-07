//
//  MangaItem.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public enum MangaStatus: String, CaseIterable, Codable {
    case ongoing = "Ongoing"
    case completed = "Completed"
    case hiatus = "On Hiatus"
    case cancelled = "Cancelled"
    case unknown = "Unknown"
}

public enum ContentRating: String, CaseIterable, Codable {
    case safe = "Safe"
    case suggestive = "Suggestive"
    case erotica = "Erotica"
}

public struct MangaItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var sourceID: String
    public var urlOrSlug: String
    public var title: String
    public var alternativeTitles: [String]
    public var author: String?
    public var artist: String?
    public var description: String?
    public var coverURL: URL?
    public var genres: [String]
    public var status: MangaStatus
    public var contentRating: ContentRating
    public var totalChapters: Int
    public var unreadCount: Int
    public var inLibrary: Bool
    public var isFavorite: Bool
    public var categories: [String]
    public var lastReadAt: Date?
    public var lastReadDate: Date? {
        get { lastReadAt }
        set { lastReadAt = newValue }
    }
    public var lastReadChapterID: UUID?
    public var lastReadChapterNumber: Double?
    public var lastReadChapterTitle: String?
    public var lastUpdated: Date
    public var preferredReadingMode: ReadingMode?
    public var customCoverLocalPath: String?
    
    public init(
        id: UUID = UUID(),
        sourceID: String,
        urlOrSlug: String,
        title: String,
        alternativeTitles: [String] = [],
        author: String? = nil,
        artist: String? = nil,
        description: String? = nil,
        coverURL: URL? = nil,
        genres: [String] = [],
        status: MangaStatus = .ongoing,
        contentRating: ContentRating = .safe,
        totalChapters: Int = 0,
        unreadCount: Int = 0,
        inLibrary: Bool = false,
        isFavorite: Bool = false,
        categories: [String] = ["Default"],
        lastReadAt: Date? = nil,
        lastReadChapterID: UUID? = nil,
        lastReadChapterNumber: Double? = nil,
        lastReadChapterTitle: String? = nil,
        lastUpdated: Date = Date(),
        preferredReadingMode: ReadingMode? = nil,
        customCoverLocalPath: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.urlOrSlug = urlOrSlug
        self.title = title
        self.alternativeTitles = alternativeTitles
        self.author = author
        self.artist = artist
        self.description = description
        self.coverURL = coverURL
        self.genres = genres
        self.status = status
        self.contentRating = contentRating
        self.totalChapters = totalChapters
        self.unreadCount = unreadCount
        self.inLibrary = inLibrary
        self.isFavorite = isFavorite
        self.categories = categories
        self.lastReadAt = lastReadAt
        self.lastReadChapterID = lastReadChapterID
        self.lastReadChapterNumber = lastReadChapterNumber
        self.lastReadChapterTitle = lastReadChapterTitle
        self.lastUpdated = lastUpdated
        self.preferredReadingMode = preferredReadingMode
        self.customCoverLocalPath = customCoverLocalPath
    }
}
