//
//  AsyncMangaImage.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import Combine
import UIKit

public struct AsyncMangaImage: View {
    private let url: URL?
    private let contentMode: ContentMode
    private let cornerRadius: CGFloat
    private let showShimmer: Bool
    private let customHeaders: [String: String]?
    
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var hasFailed: Bool = false
    
    public init(
        url: URL?,
        contentMode: ContentMode = .fill,
        cornerRadius: CGFloat = Theme.CornerRadius.medium,
        showShimmer: Bool = true,
        headers: [String: String]? = nil
    ) {
        self.url = url
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.showShimmer = showShimmer
        self.customHeaders = headers
    }
    
    public init(
        urlString: String?,
        contentMode: ContentMode = .fill,
        cornerRadius: CGFloat = Theme.CornerRadius.medium,
        showShimmer: Bool = true,
        headers: [String: String]? = nil
    ) {
        if let string = urlString, let parsed = URL(string: string) {
            self.init(url: parsed, contentMode: contentMode, cornerRadius: cornerRadius, showShimmer: showShimmer, headers: headers)
        } else {
            self.init(url: nil, contentMode: contentMode, cornerRadius: cornerRadius, showShimmer: showShimmer, headers: headers)
        }
    }
    
    public var body: some View {
        ZStack {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else if hasFailed {
                ZStack {
                    Color.surfaceSecondary
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 24))
                            .foregroundColor(.textTertiary)
                        Text("Unavailable")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                }
            } else {
                ZStack {
                    Color.surfaceSecondary
                    if isLoading && showShimmer {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .mangaAccent))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color.textTertiary.opacity(0.6))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: url) {
            await loadImage()
        }
    }
    
    @MainActor
    private func loadImage() async {
        guard let url = url else {
            hasFailed = true
            return
        }
        
        // 1. Check local file if file:// scheme (local-first rendering)
        if url.isFileURL {
            if let img = UIImage(contentsOfFile: url.path) ?? (try? Data(contentsOf: url)).flatMap({ UIImage(data: $0) }) {
                self.loadedImage = img
                return
            }
        }
        
        // 2. Check Memory & Disk Cache
        if let cached = await ImageCacheManager.shared.image(for: url) {
            self.loadedImage = cached
            return
        }
        
        // 3. Remote Download with fallback & custom CDN headers
        isLoading = true
        hasFailed = false
        
        // Build request headers with Referer & Safari User-Agent
        var requestHeaders: [String: String] = customHeaders ?? [:]
        let host = url.host?.lowercased() ?? ""
        if host.contains("mangadex.org") {
            if requestHeaders["User-Agent"] == nil {
                requestHeaders["User-Agent"] = "MangaReader/1.0.0 (iOS; Apple; CFNetwork)"
            }
        } else {
            if requestHeaders["User-Agent"] == nil {
                requestHeaders["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
            }
            if requestHeaders["Referer"] == nil && !host.isEmpty {
                requestHeaders["Referer"] = "https://\(host)/"
            }
        }
        
        do {
            let data = try await NetworkClient.shared.fetchData(from: url, headers: requestHeaders)
            guard let image = UIImage(data: data) else {
                hasFailed = true
                isLoading = false
                return
            }
            
            await ImageCacheManager.shared.insert(image, for: url, data: data)
            self.loadedImage = image
            self.isLoading = false
        } catch {
            // Fallback: if .512.jpg failed, try .256.jpg or original
            if url.absoluteString.hasSuffix(".512.jpg") {
                let base = String(url.absoluteString.dropLast(8))
                let candidateURLs = ["\(base).256.jpg", base].compactMap { URL(string: $0) }
                for fallbackURL in candidateURLs {
                    if let data = try? await NetworkClient.shared.fetchData(from: fallbackURL, headers: requestHeaders),
                       let image = UIImage(data: data) {
                        await ImageCacheManager.shared.insert(image, for: url, data: data)
                        self.loadedImage = image
                        self.isLoading = false
                        return
                    }
                }
            }
            
            if !Task.isCancelled {
                self.hasFailed = true
                self.isLoading = false
            }
        }
    }
}
