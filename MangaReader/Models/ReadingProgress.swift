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
    public var pageCount: Int {
        get { totalPages }
        set { totalPages = newValue }
    }
    public var updatedAt: Date
    
    public init(
        chapterID: UUID,
        mangaID: UUID,
        pageIndex: Int,
        totalPages: Int,
        updatedAt: Date = Date()
    ) {
        self.chapterID = chapterID
        self.mangaID = mangaID
        self.pageIndex = pageIndex
        self.totalPages = totalPages
        self.updatedAt = updatedAt
    }
    
    public var progressPercent: Double {
        guard totalPages > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(pageIndex + 1) / Double(totalPages)))
    }
}
