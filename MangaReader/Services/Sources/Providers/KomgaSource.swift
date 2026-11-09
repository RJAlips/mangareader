//
//  KomgaSource.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public final class KomgaSource: MangaSource, @unchecked Sendable {
    public var manifest: SourceManifest {
        SourceManifest(
            id: "com.mangareader.source.komga",
            name: "Komga Server",
            version: "1.0.0",
            lang: "Local/Self-Hosted",
            iconURL: URL(string: "https://raw.githubusercontent.com/gotson/komga/master/komga-webui/src/assets/logo.svg"),
            isEnabled: serverURL != nil,
            isNsfw: false,
            supportsLatest: true,
            supportsSearch: true,
            sourceDescription: "Self-hosted Komga digital media server integration"
        )
    }
    
    public var serverURL: URL?
    public var authHeader: String?
    
    private let client = NetworkClient.shared
    
    public init(serverURL: URL? = nil, username: String? = nil, password: String? = nil) {
        self.serverURL = serverURL
        if let username = username, let password = password {
            let authString = "\(username):\(password)"
            if let data = authString.data(using: .utf8) {
                self.authHeader = "Basic \(data.base64EncodedString())"
            }
        }
    }
    
    public func configure(url: URL, authHeader: String?) {
        self.serverURL = url
        self.authHeader = authHeader
    }
    
    private var headers: [String: String]? {
        guard let auth = authHeader else { return nil }
        return ["Authorization": auth]
    }
    
    public func fetchPopular(page: Int) async throws -> [MangaItem] {
        guard let base = serverURL else { throw NetworkError.unauthorized }
        let endpoint = base.appendingPathComponent("api/v1/series")
        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "page", value: "\(max(0, page - 1))"),
            URLQueryItem(name: "size", value: "40"),
            URLQueryItem(name: "sort", value: "booksCount,desc")
        ]
        guard let url = comps?.url else { throw NetworkError.invalidURL }
        
        let response = try await client.fetchJSON(KomgaSeriesPageResponse.self, from: url, headers: headers)
        return response.content.map { self.seriesToManga($0) }
    }
    
    public func fetchLatest(page: Int) async throws -> [MangaItem] {
        guard let base = serverURL else { throw NetworkError.unauthorized }
        let endpoint = base.appendingPathComponent("api/v1/series/latest")
        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "page", value: "\(max(0, page - 1))"),
            URLQueryItem(name: "size", value: "40")
        ]
        guard let url = comps?.url else { throw NetworkError.invalidURL }
        
        let response = try await client.fetchJSON(KomgaSeriesPageResponse.self, from: url, headers: headers)
        return response.content.map { self.seriesToManga($0) }
    }
    
    public func search(query: String, page: Int) async throws -> [MangaItem] {
        guard let base = serverURL else { throw NetworkError.unauthorized }
        let endpoint = base.appendingPathComponent("api/v1/series")
        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "page", value: "\(max(0, page - 1))"),
            URLQueryItem(name: "size", value: "40")
        ]
        guard let url = comps?.url else { throw NetworkError.invalidURL }
        
        let response = try await client.fetchJSON(KomgaSeriesPageResponse.self, from: url, headers: headers)
        return response.content.map { self.seriesToManga($0) }
    }
    
    public func fetchMangaDetail(urlOrSlug: String) async throws -> MangaItem {
        guard let base = serverURL else { throw NetworkError.unauthorized }
        let url = base.appendingPathComponent("api/v1/series/\(urlOrSlug)")
        let series = try await client.fetchJSON(KomgaSeriesDto.self, from: url, headers: headers)
        return seriesToManga(series)
    }
    
    public func fetchChapters(for urlOrSlug: String) async throws -> [ChapterItem] {
        guard let base = serverURL else { throw NetworkError.unauthorized }
        let url = base.appendingPathComponent("api/v1/series/\(urlOrSlug)/books")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "size", value: "500"),
            URLQueryItem(name: "sort", value: "metadata.numberSort,desc")
        ]
        guard let queryURL = comps?.url else { throw NetworkError.invalidURL }
        
        let booksPage = try await client.fetchJSON(KomgaBooksPageResponse.self, from: queryURL, headers: headers)
        return booksPage.content.enumerated().map { (index, book) in
            let number = book.metadata?.numberSort ?? Double(index + 1)
            let isRead = book.readProgress?.completed ?? false
            let lastPage = book.readProgress?.page ?? 0
            
            return ChapterItem(
                id: UUID(),
                mangaID: UUID(),
                sourceChapterID: book.id,
                chapterNumber: number,
                title: book.name,
                releaseDate: nil,
                pageCount: book.media?.pagesCount ?? 0,
                pageURLs: [],
                isRead: isRead,
                lastPageRead: lastPage
            )
        }
    }
    
    public func fetchPageURLs(for chapterSourceID: String) async throws -> [URL] {
        guard let base = serverURL else { throw NetworkError.unauthorized }
        let url = base.appendingPathComponent("api/v1/books/\(chapterSourceID)/pages")
        let pages = try await client.fetchJSON([KomgaBookPageDto].self, from: url, headers: headers)
        
        return pages.compactMap { page in
            base.appendingPathComponent("api/v1/books/\(chapterSourceID)/pages/\(page.number)")
        }
    }
    
    public func updateReadProgress(bookID: String, page: Int, completed: Bool) async throws {
        guard let base = serverURL else { return }
        let url = base.appendingPathComponent("api/v1/books/\(bookID)/read-progress")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        let payload = ["page": page, "completed": completed] as [String : Any]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        _ = try await URLSession.shared.data(for: request)
    }
    
    public func checkHealth() async -> Bool {
        guard let base = serverURL else { return false }
        let url = base.appendingPathComponent("api/v1/users/me")
        do {
            _ = try await client.fetchData(from: url, headers: headers)
            return true
        } catch {
            return false
        }
    }
    
    private func seriesToManga(_ series: KomgaSeriesDto) -> MangaItem {
        let coverURL = serverURL?.appendingPathComponent("api/v1/series/\(series.id)/thumbnail")
        return MangaItem(
            sourceID: manifest.id,
            urlOrSlug: series.id,
            title: series.name,
            alternativeTitles: [],
            author: series.metadata?.publisher,
            artist: nil,
            description: series.metadata?.summary,
            coverURL: coverURL,
            genres: series.metadata?.genres ?? [],
            status: series.metadata?.status == "ENDED" ? .completed : .ongoing,
            contentRating: .safe,
            totalChapters: series.booksCount ?? 0,
            unreadCount: series.booksUnreadCount ?? 0
        )
    }
}

// MARK: - Komga DTOs

private struct KomgaSeriesPageResponse: Decodable {
    let content: [KomgaSeriesDto]
}

private struct KomgaSeriesDto: Decodable {
    let id: String
    let name: String
    let booksCount: Int?
    let booksUnreadCount: Int?
    let metadata: KomgaSeriesMetadataDto?
}

private struct KomgaSeriesMetadataDto: Decodable {
    let status: String?
    let summary: String?
    let publisher: String?
    let genres: [String]?
}

private struct KomgaBooksPageResponse: Decodable {
    let content: [KomgaBookDto]
}

private struct KomgaBookDto: Decodable {
    let id: String
    let name: String
    let media: KomgaMediaDto?
    let metadata: KomgaBookMetadataDto?
    let readProgress: KomgaReadProgressDto?
}

private struct KomgaMediaDto: Decodable {
    let pagesCount: Int?
}

private struct KomgaBookMetadataDto: Decodable {
    let numberSort: Double?
}

private struct KomgaReadProgressDto: Decodable {
    let page: Int
    let completed: Bool
}

private struct KomgaBookPageDto: Decodable {
    let number: Int
    let fileName: String
    let mediaType: String
    let width: Int?
    let height: Int?
}
