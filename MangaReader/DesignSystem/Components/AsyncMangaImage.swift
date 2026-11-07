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
    
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var hasFailed: Bool = false
    
    public init(
        url: URL?,
        contentMode: ContentMode = .fill,
        cornerRadius: CGFloat = Theme.CornerRadius.medium,
        showShimmer: Bool = true
    ) {
        self.url = url
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.showShimmer = showShimmer
    }
    
    public init(
        urlString: String?,
        contentMode: ContentMode = .fill,
        cornerRadius: CGFloat = Theme.CornerRadius.medium,
        showShimmer: Bool = true
    ) {
        if let string = urlString, let parsed = URL(string: string) {
            self.init(url: parsed, contentMode: contentMode, cornerRadius: cornerRadius, showShimmer: showShimmer)
        } else {
            self.init(url: nil, contentMode: contentMode, cornerRadius: cornerRadius, showShimmer: showShimmer)
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
        
        // 1. Check local file if file:// scheme
        if url.isFileURL {
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                self.loadedImage = img
                return
            }
        }
        
        // 2. Check Memory & Disk Cache
        if let cached = await ImageCacheManager.shared.image(for: url) {
            self.loadedImage = cached
            return
        }
        
        // 3. Remote Download with fallback
        isLoading = true
        hasFailed = false
        
        do {
            let data = try await NetworkClient.shared.fetchData(from: url)
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
                    if let data = try? await NetworkClient.shared.fetchData(from: fallbackURL),
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
