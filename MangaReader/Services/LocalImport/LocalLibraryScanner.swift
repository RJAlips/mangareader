//
//  LocalLibraryScanner.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public final class LocalLibraryScanner {
    public static let shared = LocalLibraryScanner()
    
    private let extractor = ArchiveExtractor.shared
    private let cbzImporter = CBZImporter.shared
    private let epubImporter = EPUBImporter.shared
    
    public init() {}
    
    public func importFile(at url: URL) throws -> MangaItem {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "cbz", "zip":
            return try cbzImporter.importCBZ(from: url)
        case "epub":
            return try epubImporter.importEPUB(from: url)
        default:
            // Attempt generic archive extraction
            return try cbzImporter.importCBZ(from: url)
        }
    }
    
    public func importFolder(at folderURL: URL) throws -> MangaItem {
        let isSecurityScoped = folderURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let title = folderURL.lastPathComponent
        let images = try extractor.scanAndSortImages(in: folderURL)
        guard !images.isEmpty else {
            throw ArchiveExtractionError.invalidArchive
        }
        
        let mangaID = UUID()
        let chapterID = UUID()
        
        let chapter = ChapterItem(
            id: chapterID,
            mangaID: mangaID,
            sourceChapterID: "folder-\(chapterID.uuidString)",
            chapterNumber: 1.0,
            title: title,
            scanlator: "Local Folder",
            releaseDate: Date(),
            pageCount: images.count,
            pageURLs: images,
            isRead: false,
            lastPageRead: 0,
            isDownloaded: true,
            downloadProgress: 1.0,
            localDirectoryPath: folderURL.path
        )
        
        let manga = MangaItem(
            id: mangaID,
            sourceID: "com.mangareader.source.local",
            urlOrSlug: mangaID.uuidString,
            title: title,
            alternativeTitles: [],
            author: "Local Folder",
            artist: nil,
            description: "Locally imported folder containing \(images.count) images.",
            coverURL: images.first,
            genres: ["Local", "Folder"],
            status: .completed,
            contentRating: .safe,
            totalChapters: 1,
            unreadCount: 1,
            inLibrary: true,
            isFavorite: false,
            categories: ["Default"],
            preferredReadingMode: .webtoon
        )
        
        DispatchQueue.main.async {
            DatabaseManager.shared.upsertManga(manga)
            DatabaseManager.shared.upsertChapters([chapter])
        }
        
        return manga
    }
}
