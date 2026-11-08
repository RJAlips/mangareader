//
//  NetworkClient.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public enum NetworkError: LocalizedError {
    case invalidURL
    case badServerResponse(statusCode: Int)
    case decodingError(Error)
    case rateLimited
    case noData
    case unauthorized
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "The specified URL is invalid."
        case .badServerResponse(let code): return "Server responded with error code \(code)."
        case .decodingError(let error): return "Failed to parse data: \(error.localizedDescription)"
        case .rateLimited: return "Rate limited by source provider. Please wait a moment."
        case .noData: return "No data received from server."
        case .unauthorized: return "Authentication required. Please check your credentials."
        }
    }
}

public actor NetworkClient {
    public static let shared = NetworkClient()
    
    private let session: URLSession
    private let defaultUserAgent = "MangaReader/1.0 (iOS; Apple; CFNetwork)"
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60
        config.httpAdditionalHeaders = [
            "Accept": "application/json,image/webp,image/png,image/jpeg,image/*,*/*;q=0.8",
            "User-Agent": defaultUserAgent
        ]
        self.session = URLSession(configuration: config)
    }
    
    public func fetchJSON<T: Decodable>(_ type: T.Type, from url: URL, headers: [String: String]? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        if httpResponse.statusCode == 429 {
            throw NetworkError.rateLimited
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw NetworkError.unauthorized
        } else if !(200...299).contains(httpResponse.statusCode) {
            throw NetworkError.badServerResponse(statusCode: httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    public func fetchData(from url: URL, headers: [String: String]? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NetworkError.badServerResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return data
    }

    /// Fetches raw image data, automatically deriving a browser-like `User-Agent`
    /// and a `Referer` (matching the image's own host) unless the caller supplies
    /// explicit overrides.
    ///
    /// Many manga CDNs (MangaDex@Home, custom repository image hosts) reject
    /// requests that lack a `Referer` or send the default `URLSession` UA, replying
    /// with **HTTP 403 Forbidden**. This method guarantees a valid request for every
    /// image host without forcing every caller to know the per-source header rules.
    public func fetchDataWithCDNHeaders(
        from url: URL,
        headers: [String: String]? = nil,
        refererOverride: String? = nil
    ) async throws -> Data {
        var requestHeaders = headers ?? [:]

        // User-Agent — fall back to a desktop Safari UA (CDNs often gate on this).
        if requestHeaders["User-Agent"] == nil {
            requestHeaders["User-Agent"] = defaultUserAgent
        }

        // Referer — default to the image's own origin so CDNs that check Referer
        // (e.g. uploads.mangadex.org, custom repo hosts) see a same-origin referrer.
        if requestHeaders["Referer"] == nil, let host = url.host, !host.isEmpty {
            requestHeaders["Referer"] = refererOverride ?? "https://\(host)/"
        }

        // Accept — ensure binary image types are accepted.
        if requestHeaders["Accept"] == nil {
            requestHeaders["Accept"] = "image/webp,image/png,image/jpeg,image/*,*/*;q=0.8"
        }

        return try await fetchData(from: url, headers: requestHeaders)
    }
}
