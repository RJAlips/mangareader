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
    case unknown(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "The specified URL is invalid."
        case .badServerResponse(let code): return "Server responded with error code \(code)."
        case .decodingError(let error): return "Failed to parse data: \(error.localizedDescription)"
        case .rateLimited: return "Rate limited by source provider. Please wait a moment."
        case .noData: return "No data received from server."
        case .unauthorized: return "Authentication required. Please check your credentials."
        case .unknown(let msg): return msg
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
    
    public func fetchData(from url: URL, headers: [String: String]? = nil, timeoutInterval: TimeInterval? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        if let timeout = timeoutInterval {
            request.timeoutInterval = timeout
        }
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NetworkError.badServerResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return data
    }

    /// Fetches raw image data, automatically deriving a browser-like `User-Agent`
    /// and a `Referer` (matching the image's own host or mangadex.org) unless the caller supplies
    /// explicit overrides.
    ///
    /// Many manga CDNs (MangaDex@Home, custom repository image hosts) reject
    /// requests that lack a `Referer` or send the default `URLSession` UA, replying
    /// with **HTTP 403 Forbidden**. This method guarantees a valid request for every
    /// image host without forcing every caller to know the per-source header rules.
    public func fetchDataWithCDNHeaders(
        from url: URL,
        headers: [String: String]? = nil,
        refererOverride: String? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> Data {
        var requestHeaders = headers ?? [:]

        // User-Agent: MangaDex CDN requires dedicated UA, other CDNs require Mobile Safari.
        if requestHeaders["User-Agent"] == nil {
            let host = url.host?.lowercased() ?? ""
            if host.contains("mangadex.org") {
                requestHeaders["User-Agent"] = "MangaReader/1.0.0 (iOS; Apple; CFNetwork)"
            } else {
                requestHeaders["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
            }
        }

        // Referer — MangaDex uploads require https://mangadex.org/, other CDNs use origin or caller override
        if requestHeaders["Referer"] == nil {
            let host = url.host?.lowercased() ?? ""
            if host.contains("mangadex.org") {
                requestHeaders["Referer"] = "https://mangadex.org/"
            } else if let scheme = url.scheme, let rawHost = url.host, !rawHost.isEmpty {
                requestHeaders["Referer"] = refererOverride ?? "\(scheme)://\(rawHost)/"
            } else if let override = refererOverride {
                requestHeaders["Referer"] = override
            }
        }

        // Accept — ensure modern formats (AVIF, WebP) and all image types are accepted
        if requestHeaders["Accept"] == nil {
            requestHeaders["Accept"] = "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"
        }

        return try await fetchData(from: url, headers: requestHeaders, timeoutInterval: timeoutInterval)
    }
}
