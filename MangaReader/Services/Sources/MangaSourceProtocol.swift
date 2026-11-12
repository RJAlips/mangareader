//
//  MangaSourceProtocol.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public typealias MangaSourceProtocol = MangaSource

public protocol MangaSource: AnyObject, Sendable {
    var manifest: SourceManifest { get }
    
    func fetchPopular(page: Int) async throws -> [MangaItem]
    func fetchLatest(page: Int) async throws -> [MangaItem]
    func search(query: String, page: Int) async throws -> [MangaItem]
    func fetchMangaDetail(urlOrSlug: String) async throws -> MangaItem
    func fetchChapters(for urlOrSlug: String) async throws -> [ChapterItem]
    func fetchPageURLs(for chapterSourceID: String) async throws -> [URL]
    func checkHealth() async -> Bool
}

// MARK: - Ergonomic Protocol Aliases for Testing & ViewModels
extension MangaSource {
    public var baseURL: String {
        manifest.baseURL
    }
    
    public var popularURL: URL? {
        (self as? CommunityWebSource)?.popularURL.flatMap { URL(string: $0) } ?? URL(string: manifest.baseURL)
    }
    
    public var latestURL: URL? {
        (self as? CommunityWebSource)?.latestURL.flatMap { URL(string: $0) } ?? URL(string: manifest.baseURL)
    }
    
    public func fetchPopularManga(page: Int = 1) async throws -> [MangaItem] {
        return try await fetchPopular(page: page)
    }
    
    public func fetchLatestManga(page: Int = 1) async throws -> [MangaItem] {
        return try await fetchLatest(page: page)
    }
    
    public func searchManga(query: String, page: Int = 1) async throws -> [MangaItem] {
        return try await search(query: query, page: page)
    }
    
    public func fetchChapters(mangaId: UUID) async throws -> [ChapterItem] {
        return try await fetchChapters(for: mangaId.uuidString)
    }
    
    public func fetchChapters(mangaId: String) async throws -> [ChapterItem] {
        return try await fetchChapters(for: mangaId)
    }
    
    public func fetchChapters(manga: MangaItem) async throws -> [ChapterItem] {
        return try await fetchChapters(for: manga.urlOrSlug)
    }
    
    public func fetchPages(chapterId: UUID) async throws -> [URL] {
        return try await fetchPageURLs(for: chapterId.uuidString)
    }
    
    public func fetchPages(chapterId: String) async throws -> [URL] {
        return try await fetchPageURLs(for: chapterId)
    }
    
    public func fetchPages(chapter: ChapterItem) async throws -> [URL] {
        return try await fetchPageURLs(for: chapter.sourceChapterID)
    }
}
