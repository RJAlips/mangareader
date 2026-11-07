//
//  MangaSourceProtocol.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

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
