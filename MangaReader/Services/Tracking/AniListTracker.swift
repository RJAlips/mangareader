//
//  AniListTracker.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public final class AniListTracker: MangaTracker, @unchecked Sendable {
    public let trackerID = "anilist"
    public let trackerName = "AniList"
    
    private let tokenKey = "anilist_oauth_token"
    private let endpoint = URL(string: "https://graphql.anilist.co")!
    
    public var isLoggedIn: Bool {
        return KeychainHelper.shared.readString(key: tokenKey) != nil
    }
    
    public init() {}
    
    public func login(token: String) async throws {
        _ = KeychainHelper.shared.save(key: tokenKey, string: token)
    }
    
    public func logout() {
        _ = KeychainHelper.shared.delete(key: tokenKey)
    }
    
    public func search(query: String) async throws -> [TrackSearchResult] {
        let queryString = """
        query ($search: String) {
          Page(page: 1, perPage: 10) {
            media(search: $search, type: MANGA) {
              id
              title {
                romaji
                english
              }
              coverImage {
                large
              }
              chapters
              description
            }
          }
        }
        """
        
        let body: [String: Any] = [
            "query": queryString,
            "variables": ["search": query]
        ]
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AniListSearchResponse.self, from: data)
        
        return response.data.page.media.map { media in
            let title = media.title.english ?? media.title.romaji ?? "Untitled"
            let coverURL = media.coverImage?.large != nil ? URL(string: media.coverImage!.large!) : nil
            return TrackSearchResult(
                id: "\(media.id)",
                title: title,
                coverURL: coverURL,
                totalChapters: media.chapters,
                synopsis: media.description
            )
        }
    }
    
    public func updateProgress(remoteID: String, chapterNumber: Int, status: TrackStatus, score: Double?) async throws {
        guard let token = KeychainHelper.shared.readString(key: tokenKey) else {
            throw NetworkError.unauthorized
        }
        guard let mediaId = Int(remoteID) else { return }
        
        let aniStatus: String
        switch status {
        case .current: aniStatus = "CURRENT"
        case .completed: aniStatus = "COMPLETED"
        case .onHold: aniStatus = "PAUSED"
        case .dropped: aniStatus = "DROPPED"
        case .planToRead: aniStatus = "PLANNING"
        }
        
        let mutation = """
        mutation ($mediaId: Int, $progress: Int, $status: MediaListStatus) {
          SaveMediaListEntry (mediaId: $mediaId, progress: $progress, status: $status) {
            id
            progress
            status
          }
        }
        """
        
        let body: [String: Any] = [
            "query": mutation,
            "variables": [
                "mediaId": mediaId,
                "progress": chapterNumber,
                "status": aniStatus
            ]
        ]
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        _ = try await URLSession.shared.data(for: request)
    }
}

// MARK: - Decodables for AniList GraphQL

private struct AniListSearchResponse: Decodable {
    let data: AniListPageContainer
}

private struct AniListPageContainer: Decodable {
    let page: AniListMediaPage
    
    enum CodingKeys: String, CodingKey {
        case page = "Page"
    }
}

private struct AniListMediaPage: Decodable {
    let media: [AniListMedia]
}

private struct AniListMedia: Decodable {
    let id: Int
    let title: AniListTitle
    let coverImage: AniListCover?
    let chapters: Int?
    let description: String?
}

private struct AniListTitle: Decodable {
    let romaji: String?
    let english: String?
}

private struct AniListCover: Decodable {
    let large: String?
}
