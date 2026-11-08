//
//  WebtoonReaderView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import UIKit

public struct WebtoonReaderView: View {
    @ObservedObject public var viewModel: ReaderViewModel
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: viewModel.settings.pageSpacing) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, url in
                        WebtoonPageView(
                            url: url,
                            pageIndex: index,
                            scaleType: viewModel.settings.imageScale,
                            onVisible: {
                                viewModel.onPageChanged(to: index)
                            }
                        )
                        .id(index)
                    }
                }
                .padding(.horizontal, viewModel.settings.sidePadding)
            }
            .scaleEffect(currentScale * finalScale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        currentScale = value
                    }
                    .onEnded { value in
                        finalScale = max(1.0, min(finalScale * value, 3.5))
                        currentScale = 1.0
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(Theme.Animation.quick) {
                    finalScale = (finalScale > 1.0) ? 1.0 : 2.0
                    currentScale = 1.0
                }
            }
            .onTapGesture(count: 1) {
                viewModel.toggleControls()
            }
            .onAppear {
                if viewModel.currentPageIndex > 0 && viewModel.currentPageIndex < viewModel.pages.count {
                    proxy.scrollTo(viewModel.currentPageIndex, anchor: .top)
                }
            }
        }
    }
}

// MARK: - Webtoon Page View Container with Minimum Height & Retry

private struct WebtoonPageView: View {
    let url: URL
    let pageIndex: Int
    let scaleType: ImageScaleType
    let onVisible: () -> Void
    
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var hasFailed: Bool = false
    @State private var reloadKey = UUID()
    
    private var estimatedPageHeight: CGFloat {
        // Realistic minimum aspect ratio (1.4:1) for manhwa/webtoon strips
        // Ensures only 1-2 pages fit in viewport while loading, eliminating prefetch storms
        UIScreen.main.bounds.width * 1.4
    }
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode(for: scaleType))
                    .frame(maxWidth: .infinity)
            } else if hasFailed {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(.mangaAccent)
                    Text("Page \(pageIndex + 1) Failed to Load")
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                    Button {
                        hasFailed = false
                        reloadKey = UUID()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.captionMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.mangaAccent)
                        .cornerRadius(Theme.CornerRadius.small)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: estimatedPageHeight)
                .background(Color.surfaceSecondary)
            } else {
                ZStack {
                    Color.surfaceSecondary
                    VStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .mangaAccent))
                            .scaleEffect(1.2)
                        Text("Page \(pageIndex + 1)")
                            .font(.captionMedium)
                            .foregroundColor(.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: estimatedPageHeight)
            }
        }
        .task(id: "\(url.absoluteString)_\(reloadKey)") {
            await fetchPageImage()
        }
        .onAppear {
            onVisible()
        }
    }
    
    @MainActor
    private func fetchPageImage() async {
        // 1. Check local file if downloaded on disk
        if url.isFileURL, let localImg = LocalStorageManager.shared.getLocalImage(for: url) {
            self.loadedImage = localImg
            return
        }
        let urlStr = url.absoluteString
        if urlStr.contains("Downloads/") || url.scheme == "file" {
            let path = url.isFileURL ? url.path : urlStr
            if let localImg = UIImage(contentsOfFile: path) {
                self.loadedImage = localImg
                return
            }
        }
        
        // 2. Check Memory & Disk Cache
        if let cached = await ImageCacheManager.shared.image(for: url) {
            self.loadedImage = cached
            return
        }
        
        // 3. Remote Download with task concurrency limiter
        isLoading = true
        hasFailed = false
        
        await ImageDownloadLimiter.shared.acquire()
        defer {
            Task { await ImageDownloadLimiter.shared.release() }
        }
        
        do {
            let data = try await NetworkClient.shared.fetchDataWithCDNHeaders(from: url)
            if let img = UIImage(data: data) {
                await ImageCacheManager.shared.insert(img, for: url, data: data)
                self.loadedImage = img
            } else {
                self.hasFailed = true
            }
        } catch {
            self.hasFailed = true
        }
        self.isLoading = false
    }
    
    private func contentMode(for scale: ImageScaleType) -> ContentMode {
        switch scale {
        case .fitWidth, .fitHeight, .original: return .fit
        case .stretch: return .fill
        }
    }
}
