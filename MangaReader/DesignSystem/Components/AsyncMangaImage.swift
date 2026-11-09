//
//  AsyncMangaImage.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import UIKit

public struct AsyncMangaImage: View {
    private let url: URL?
    /// Base URL used to resolve relative cover paths returned by repositories.
    private let baseURL: URL?
    private let contentMode: ContentMode
    private let cornerRadius: CGFloat
    private let showShimmer: Bool
    private let customHeaders: [String: String]?

    @State private var loadedImage: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var hasFailed: Bool = false
    @State private var reloadID = UUID()

    public init(
        url: URL?,
        baseURL: URL? = nil,
        contentMode: ContentMode = .fill,
        cornerRadius: CGFloat = Theme.CornerRadius.medium,
        showShimmer: Bool = true,
        headers: [String: String]? = nil
    ) {
        self.url = URLResolver.resolve(url?.absoluteString, relativeTo: baseURL)
        self.baseURL = baseURL
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.showShimmer = showShimmer
        self.customHeaders = headers
    }

    public init(
        urlString: String?,
        baseURL: URL? = nil,
        contentMode: ContentMode = .fill,
        cornerRadius: CGFloat = Theme.CornerRadius.medium,
        showShimmer: Bool = true,
        headers: [String: String]? = nil
    ) {
        let resolved = URLResolver.resolve(urlString, relativeTo: baseURL)
        self.init(url: resolved, baseURL: baseURL, contentMode: contentMode, cornerRadius: cornerRadius, showShimmer: showShimmer, headers: headers)
    }
    
    public var body: some View {
        ZStack {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .clipped()
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else if hasFailed {
                ZStack {
                    Color.surfaceSecondary
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 24))
                            .foregroundColor(.textTertiary)
                        Text("Retry")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.mangaAccent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    hasFailed = false
                    reloadID = UUID()
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
        .task(id: "\(url?.absoluteString ?? "")_\(reloadID)") {
            await loadImage()
        }
    }
    
    @MainActor
    private func loadImage() async {
        guard let url = url else {
            hasFailed = true
            return
        }
        
        // 1. Check local file if file:// scheme or local path (local-first rendering)
        let urlStr = url.absoluteString
        if url.isFileURL || url.scheme == "file" || urlStr.hasPrefix("file://") || urlStr.hasPrefix("/") || url.path.contains("Downloads/") {
            let path = url.isFileURL ? url.path : (urlStr.hasPrefix("file://") ? String(urlStr.dropFirst(7)) : urlStr)
            if let img = UIImage(contentsOfFile: path) ?? (try? Data(contentsOf: url)).flatMap({ UIImage(data: $0) }) {
                self.loadedImage = img
                return
            }
        }
        
        // 2. Check Memory & Disk Cache
        if let cached = await ImageCacheManager.shared.image(for: url) {
            self.loadedImage = cached
            return
        }
        
        // 3. Remote Download with task concurrency limiter & custom CDN headers
        isLoading = true
        hasFailed = false

        await ImageDownloadLimiter.shared.acquire()
        defer {
            Task { await ImageDownloadLimiter.shared.release() }
        }

        do {
            let data = try await NetworkClient.shared.fetchDataWithCDNHeaders(from: url, headers: customHeaders)
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
                    if let data = try? await NetworkClient.shared.fetchDataWithCDNHeaders(from: fallbackURL, headers: customHeaders),
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
