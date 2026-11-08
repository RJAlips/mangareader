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

/// Resolves relative / scheme-relative / absolute URLs against a base URL.
///
/// Source repositories (Aidoku-style indexes, Komga, custom JSON feeds) frequently
/// return cover-image paths as relative strings such as `"/covers/abc.jpg"`,
/// `"covers/abc.jpg"`, or `"//cdn.example.com/img/512.jpg"`. Passing these
/// directly to `URL(string:)` produces an invalid URL (no scheme / host) which
/// `URLSession` cannot fetch, and which the image cache keys incorrectly —
/// resulting in blank thumbnails in the browsing grid.
///
/// This helper normalises every variant into a fully-qualified absolute URL so
/// the downstream image pipeline (cache key, request, Referer derivation) always
/// operates on a stable, fetchable URL.
public enum URLResolver {

    /// Returns `nil` when the input is empty or cannot be resolved.
    public static func resolve(_ string: String?, relativeTo base: URL?) -> URL? {
        guard let string = string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else {
            return nil
        }

        let cleanString = string.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? string

        // Already an absolute URL with a scheme — use as-is.
        if let url = URL(string: cleanString), url.scheme != nil, url.host != nil {
            return url
        }

        // Scheme-relative: "//cdn.example.com/img.jpg" -> inherit scheme from base or default https.
        if string.hasPrefix("//") {
            let scheme = base?.scheme ?? "https"
            if let resolved = URL(string: "\(scheme):\(cleanString)") {
                return resolved
            }
        }

        // Relative path or absolute path against base URL
        if let base = base {
            if let resolved = URL(string: cleanString, relativeTo: base) {
                return resolved.absoluteURL
            }
        }

        // Last resort: try plain parse
        return URL(string: cleanString) ?? URL(string: string)
    }

    /// Convenience: resolve against the repository's own base URL string.
    public static func resolveCoverURL(_ string: String?, repositoryURL: String?) -> URL? {
        let base = repositoryURL.flatMap { URL(string: $0) }
        return resolve(string, relativeTo: base)
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
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.badServerResponse(statusCode: 500)
        }
        
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 429 {
                throw NetworkError.rateLimited
            } else if http.statusCode == 401 || http.statusCode == 403 {
                throw NetworkError.unauthorized
            }
            throw NetworkError.badServerResponse(statusCode: http.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
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

        // User-Agent: MangaDex CDN requires dedicated UA, other CDNs require Mobile Safari.
        if requestHeaders["User-Agent"] == nil {
            let host = url.host?.lowercased() ?? ""
            if host.contains("mangadex.org") {
                requestHeaders["User-Agent"] = "MangaReader/1.0.0 (iOS; Apple; CFNetwork)"
            } else {
                requestHeaders["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
            }
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
