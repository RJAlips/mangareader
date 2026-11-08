//  URLResolver.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

/// Resolves relative / scheme-relative / absolute URLs against a base URL.
///
/// Source repositories (Aidoku-style indexes, Komga, custom JSON feeds) frequently
/// return cover-image paths as *relative* strings such as `"/covers/abc.jpg"`,
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
        guard let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        // Already an absolute URL with a scheme — use as-is.
        if let url = URL(string: string), url.scheme != nil, url.host != nil {
            return url
        }

        // Scheme-relative: "//cdn.example.com/img.jpg" → inherit scheme from base.
        if string.hasPrefix("//"), let base = base {
            let resolved = URL(string: (base.scheme ?? "https") + ":" + string)
            if let resolved { return resolved }
        }

        // Absolute path: "/covers/abc.jpg" → resolve against base's host.
        if string.hasPrefix("/"), let base = base {
            let resolved = URL(string: string, relativeTo: base)
            if let resolved { return resolved.absoluteURL }
        }

        // Relative path: "covers/abc.jpg" → resolve against base.
        if let base = base {
            let resolved = URL(string: string, relativeTo: base)
            if let resolved { return resolved.absoluteURL }
        }

        // Last resort: try a plain parse (may still be invalid).
        return URL(string: string)
    }

    /// Convenience: resolve against the repository's own base URL.
    public static func resolveCoverURL(_ string: String?, repositoryURL: String?) -> URL? {
        let base = repositoryURL.flatMap { URL(string: $0) }
        return resolve(string, relativeTo: base)
    }
}

public enum NetworkError: LocalizedError {