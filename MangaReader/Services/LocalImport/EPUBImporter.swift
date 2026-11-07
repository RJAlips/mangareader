//
//  EPUBImporter.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public final class EPUBImporter {
    public static let shared = EPUBImporter()
    
    private let extractor = ArchiveExtractor.shared
    private let db = DatabaseManager.shared
    
    public init() {}
    
    public func importEPUB(from sourceURL: URL) throws -> MangaItem {
        let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let result = try extractor.extractArchive(at: sourceURL)
        let mangaID = UUID()
        let chapterID = UUID()
        
        let chapter = ChapterItem(
            id: chapterID,
            mangaID: mangaID,
            sourceChapterID: "epub-\(chapterID.uuidString)",
            chapterNumber: 1.0,
            title: result.title,
            scanlator: "EPUB Import",
            releaseDate: Date(),
            pageCount: result.imageURLs.count,
            pageURLs: result.imageURLs,
            isRead: false,
            lastPageRead: 0,
            isDownloaded: true,
            downloadProgress: 1.0,
            localDirectoryPath: result.destinationDirectory.path
        )
        
        let manga = MangaItem(
            id: mangaID,
            sourceID: "com.mangareader.source.local",
            urlOrSlug: mangaID.uuidString,
            title: result.title,
            alternativeTitles: [],
            author: "EPUB Book",
            artist: nil,
            description: "Locally imported EPUB manga/comic archive containing \(result.imageURLs.count) illustration panels.",
            coverURL: result.coverImageURL,
            genres: ["EPUB", "Local"],
            status: .completed,
            contentRating: .safe,
            totalChapters: 1,
            unreadCount: 1,
            inLibrary: true,
            isFavorite: false,
            categories: ["Default"],
            preferredReadingMode: .horizontalRTL
        )
        
        DispatchQueue.main.async {
            self.db.upsertManga(manga)
            self.db.upsertChapters([chapter])
        }
        
        return manga
    }
}
