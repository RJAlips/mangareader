//
//  CBZImporter.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public final class CBZImporter {
    public static let shared = CBZImporter()
    
    private let extractor = ArchiveExtractor.shared
    private let db = DatabaseManager.shared
    
    public init() {}
    
    public func importCBZ(from sourceURL: URL) throws -> MangaItem {
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
            sourceChapterID: "local-\(chapterID.uuidString)",
            chapterNumber: 1.0,
            title: result.title,
            scanlator: "Local File",
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
            author: "Local Import",
            artist: nil,
            description: "Locally imported CBZ comic book archive containing \(result.imageURLs.count) pages.",
            coverURL: result.coverImageURL,
            genres: ["Local", "Comic"],
            status: .completed,
            contentRating: .safe,
            totalChapters: 1,
            unreadCount: 1,
            inLibrary: true,
            isFavorite: false,
            categories: ["Default", "Plan to Read"],
            preferredReadingMode: .horizontalLTR
        )
        
        DispatchQueue.main.async {
            self.db.upsertManga(manga)
            self.db.upsertChapters([chapter])
        }
        
        return manga
    }
}
