//
//  MangaDexSource.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public final class MangaDexSource: MangaSource, @unchecked Sendable {
    public let manifest = SourceManifest(
        id: "com.mangareader.source.mangadex",
        name: "MangaDex (Official API)",
        version: "5.1.0",
        lang: "Multi (EN Default)",
        iconURL: URL(string: "https://mangadex.org/favicon.ico"),
        isEnabled: true,
        isNsfw: false,
        supportsLatest: true,
        supportsSearch: true,
        sourceDescription: "Community-driven manga catalog via documented MangaDex REST API v5"
    )
    
    private let baseURL = "https://api.mangadex.org"
    private let client = NetworkClient.shared
    
    public init() {}
    
    public func fetchPopular(page: Int) async throws -> [MangaItem] {
        let offset = max(0, (page - 1) * 20)
        let endpoint = "\(baseURL)/manga?limit=20&offset=\(offset)&includes[]=cover_art&includes[]=author&order[followedCount]=desc&contentRating[]=safe&contentRating[]=suggestive"
        guard let url = URL(string: endpoint) else { throw NetworkError.invalidURL }
        
        let response = try await client.fetchJSON(MangaDexResponse.self, from: url)
        return response.data.compactMap { self.parseManga(entry: $0) }
    }
    
    public func fetchLatest(page: Int) async throws -> [MangaItem] {
        let offset = max(0, (page - 1) * 20)
        let endpoint = "\(baseURL)/manga?limit=20&offset=\(offset)&includes[]=cover_art&includes[]=author&order[latestUploadedChapter]=desc&contentRating[]=safe&contentRating[]=suggestive"
        guard let url = URL(string: endpoint) else { throw NetworkError.invalidURL }
        
        let response = try await client.fetchJSON(MangaDexResponse.self, from: url)
        return response.data.compactMap { self.parseManga(entry: $0) }
    }
    
    public func search(query: String, page: Int) async throws -> [MangaItem] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        let offset = max(0, (page - 1) * 20)
        let endpoint = "\(baseURL)/manga?title=\(encodedQuery)&limit=20&offset=\(offset)&includes[]=cover_art&includes[]=author&contentRating[]=safe&contentRating[]=suggestive"
        guard let url = URL(string: endpoint) else { throw NetworkError.invalidURL }
        
        let response = try await client.fetchJSON(MangaDexResponse.self, from: url)
        return response.data.compactMap { self.parseManga(entry: $0) }
    }
    
    public func fetchMangaDetail(urlOrSlug: String) async throws -> MangaItem {
        let endpoint = "\(baseURL)/manga/\(urlOrSlug)?includes[]=cover_art&includes[]=author"
        guard let url = URL(string: endpoint) else { throw NetworkError.invalidURL }
        
        let response = try await client.fetchJSON(MangaDexSingleResponse.self, from: url)
        guard let item = parseManga(entry: response.data) else {
            throw NetworkError.badServerResponse(statusCode: 404)
        }
        return item
    }
    
    public func fetchChapters(for urlOrSlug: String) async throws -> [ChapterItem] {
        let endpoint = "\(baseURL)/manga/\(urlOrSlug)/feed?translatedLanguage[]=en&order[chapter]=desc&limit=100"
        guard let url = URL(string: endpoint) else { throw NetworkError.invalidURL }
        
        let response = try await client.fetchJSON(MangaDexChapterFeedResponse.self, from: url)
        return response.data.compactMap { ch in
            guard let chNumStr = ch.attributes.chapter, let chNum = Double(chNumStr) else { return nil }
            return ChapterItem(
                id: UUID(),
                mangaID: UUID(),
                sourceChapterID: ch.id,
                chapterNumber: chNum,
                volumeNumber: ch.attributes.volume != nil ? Double(ch.attributes.volume!) : nil,
                title: ch.attributes.title,
                scanlator: "MangaDex",
                releaseDate: nil,
                pageCount: ch.attributes.pages ?? 0,
                pageURLs: []
            )
        }
    }
    
    public func fetchPageURLs(for chapterSourceID: String) async throws -> [URL] {
        let endpoint = "\(baseURL)/at-home/server/\(chapterSourceID)"
        guard let url = URL(string: endpoint) else { throw NetworkError.invalidURL }
        
        let response = try await client.fetchJSON(MangaDexAtHomeResponse.self, from: url)
        let base = response.baseUrl
        let hash = response.chapter.hash
        
        return response.chapter.data.compactMap { filename in
            URL(string: "\(base)/data/\(hash)/\(filename)")
        }
    }
    
    public func checkHealth() async -> Bool {
        guard let url = URL(string: "\(baseURL)/ping") else { return false }
        do {
            _ = try await client.fetchData(from: url)
            return true
        } catch {
            return false
        }
    }
    
    private func parseManga(entry: MangaDexEntry) -> MangaItem? {
        var resolvedTitle = entry.attributes.title["en"]
        if resolvedTitle == nil, let altList = entry.attributes.altTitles {
            for alt in altList {
                if let en = alt["en"], !en.trimmingCharacters(in: .whitespaces).isEmpty {
                    resolvedTitle = en
                    break
                }
            }
        }
        let finalTitle = resolvedTitle ?? entry.attributes.title.values.first ?? "Untitled Manga"
        let desc = entry.attributes.description?["en"] ?? entry.attributes.description?.values.first
        
        var coverFile: String? = nil
        var authorName: String? = nil
        
        for rel in entry.relationships {
            if rel.type == "cover_art", let filename = rel.attributes?.fileName {
                coverFile = filename
            } else if rel.type == "author", let name = rel.attributes?.name {
                authorName = name
            }
        }
        
        var coverURL: URL? = nil
        if let coverFile = coverFile {
            coverURL = URL(string: "https://uploads.mangadex.org/covers/\(entry.id)/\(coverFile).512.jpg")
        }
        
        let tags = entry.attributes.tags.compactMap { $0.attributes.name["en"] }
        
        return MangaItem(
            sourceID: manifest.id,
            urlOrSlug: entry.id,
            title: finalTitle,
            alternativeTitles: [],
            author: authorName,
            artist: authorName,
            description: desc,
            coverURL: coverURL,
            genres: tags,
            status: entry.attributes.status == "completed" ? .completed : .ongoing,
            contentRating: .safe,
            totalChapters: 0,
            unreadCount: 0
        )
    }
}

// MARK: - Internal Decodables for MangaDex API

private struct MangaDexResponse: Decodable {
    let data: [MangaDexEntry]
}

private struct MangaDexSingleResponse: Decodable {
    let data: MangaDexEntry
}

private struct MangaDexEntry: Decodable {
    let id: String
    let attributes: MangaDexAttributes
    let relationships: [MangaDexRelationship]
}

private struct MangaDexAttributes: Decodable {
    let title: [String: String]
    let altTitles: [[String: String]]?
    let description: [String: String]?
    let status: String?
    let tags: [MangaDexTag]
}

private struct MangaDexTag: Decodable {
    let attributes: MangaDexTagName
}

private struct MangaDexTagName: Decodable {
    let name: [String: String]
}

private struct MangaDexRelationship: Decodable {
    let id: String
    let type: String
    let attributes: MangaDexRelationshipAttributes?
}

private struct MangaDexRelationshipAttributes: Decodable {
    let fileName: String?
    let name: String?
}

private struct MangaDexChapterFeedResponse: Decodable {
    let data: [MangaDexChapterEntry]
}

private struct MangaDexChapterEntry: Decodable {
    let id: String
    let attributes: MangaDexChapterAttributes
}

private struct MangaDexChapterAttributes: Decodable {
    let volume: String?
    let chapter: String?
    let title: String?
    let pages: Int?
}

private struct MangaDexAtHomeResponse: Decodable {
    let baseUrl: String
    let chapter: MangaDexAtHomeChapter
}

private struct MangaDexAtHomeChapter: Decodable {
    let hash: String
    let data: [String]
}


