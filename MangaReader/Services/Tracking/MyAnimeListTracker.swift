//
//  MyAnimeListTracker.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public final class MyAnimeListTracker: MangaTracker, @unchecked Sendable {
    public let trackerID = "myanimelist"
    public let trackerName = "MyAnimeList"
    
    private let tokenKey = "mal_oauth_token"
    private let baseURL = "https://api.myanimelist.net/v2"
    
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
        guard let token = KeychainHelper.shared.readString(key: tokenKey) else {
            throw NetworkError.unauthorized
        }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/manga?q=\(encoded)&limit=10&fields=id,title,main_picture,num_chapters,synopsis") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(MALSearchResponse.self, from: data)
        
        return response.data.map { item in
            let coverURL = item.node.mainPicture?.medium != nil ? URL(string: item.node.mainPicture!.medium!) : nil
            return TrackSearchResult(
                id: "\(item.node.id)",
                title: item.node.title,
                coverURL: coverURL,
                totalChapters: item.node.numChapters,
                synopsis: item.node.synopsis
            )
        }
    }
    
    public func updateProgress(remoteID: String, chapterNumber: Int, status: TrackStatus, score: Double?) async throws {
        guard let token = KeychainHelper.shared.readString(key: tokenKey) else {
            throw NetworkError.unauthorized
        }
        guard let url = URL(string: "\(baseURL)/manga/\(remoteID)/my_list_status") else { return }
        
        var malStatus = "reading"
        switch status {
        case .current: malStatus = "reading"
        case .completed: malStatus = "completed"
        case .onHold: malStatus = "on_hold"
        case .dropped: malStatus = "dropped"
        case .planToRead: malStatus = "plan_to_read"
        }
        
        var bodyParams = [
            "status": malStatus,
            "num_chapters_read": "\(chapterNumber)"
        ]
        if let score = score {
            bodyParams["score"] = "\(Int(score))"
        }
        
        let postData = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = postData
        
        _ = try await URLSession.shared.data(for: request)
    }
}

// MARK: - MAL Decodables

private struct MALSearchResponse: Decodable {
    let data: [MALSearchItem]
}

private struct MALSearchItem: Decodable {
    let node: MALNode
}

private struct MALNode: Decodable {
    let id: Int
    let title: String
    let mainPicture: MALPicture?
    let numChapters: Int?
    let synopsis: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, synopsis
        case mainPicture = "main_picture"
        case numChapters = "num_chapters"
    }
}

private struct MALPicture: Decodable {
    let medium: String?
    let large: String?
}
