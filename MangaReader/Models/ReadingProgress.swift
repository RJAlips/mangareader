//
//  ReadingProgress.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public struct ReadingProgress: Codable, Hashable, Identifiable {
    public var id: UUID { chapterID }
    public var chapterID: UUID
    public var mangaID: UUID
    public var pageIndex: Int
    public var totalPages: Int
    public var lastPageRead: Int {
        get { pageIndex }
        set { pageIndex = newValue }
    }
    public var pageCount: Int {
        get { totalPages }
        set { totalPages = newValue }
    }
    public var readingTimeSeconds: TimeInterval
    public var updatedAt: Date
    
    // Stored metadata for independent history display & offline persistence
    public var mangaTitle: String?
    public var chapterTitle: String?
    public var chapterNumber: Double?
    public var coverURL: URL?
    public var sourceID: String?
    
    public init(
        chapterID: UUID,
        mangaID: UUID,
        pageIndex: Int,
        totalPages: Int,
        readingTimeSeconds: TimeInterval = 0,
        updatedAt: Date = Date(),
        mangaTitle: String? = nil,
        chapterTitle: String? = nil,
        chapterNumber: Double? = nil,
        coverURL: URL? = nil,
        sourceID: String? = nil
    ) {
        self.chapterID = chapterID
        self.mangaID = mangaID
        self.pageIndex = pageIndex
        self.totalPages = totalPages
        self.readingTimeSeconds = readingTimeSeconds
        self.updatedAt = updatedAt
        self.mangaTitle = mangaTitle
        self.chapterTitle = chapterTitle
        self.chapterNumber = chapterNumber
        self.coverURL = coverURL
        self.sourceID = sourceID
    }
    
    public var progressPercent: Double {
        guard totalPages > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(pageIndex + 1) / Double(totalPages)))
    }
    
    public var formattedReadingTime: String {
        let totalMinutes = max(1, Int(readingTimeSeconds) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours) h \(minutes) m"
        } else {
            return "\(minutes) m"
        }
    }
    
    public var displayMangaTitle: String {
        if let title = mangaTitle, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return "Manga"
    }
    
    public var displayChapterTitle: String {
        if let title = chapterTitle, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if let num = chapterNumber {
            if num.truncatingRemainder(dividingBy: 1) == 0 {
                return "Chapter \(Int(num))"
            } else {
                return "Chapter \(num)"
            }
        }
        return "Chapter"
    }
}
