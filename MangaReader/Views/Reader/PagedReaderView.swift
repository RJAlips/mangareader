//
//  PagedReaderView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct PagedReaderView: View {
    @ObservedObject public var viewModel: ReaderViewModel
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Interactive Paged Container
                TabView(selection: Binding(
                    get: { viewModel.currentPageIndex },
                    set: { viewModel.onPageChanged(to: $0) }
                )) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, url in
                        pageContent(for: url)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .environment(\.layoutDirection, viewModel.readingMode == .horizontalRTL ? .rightToLeft : .leftToRight)
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
                
                // Tap Zones overlay
                HStack(spacing: 0) {
                    // Left Tap Zone
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: geometry.size.width * 0.28)
                        .onTapGesture {
                            handleTapZone(isLeft: true)
                        }
                    
                    // Center Tap Zone (Toggle Controls)
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: geometry.size.width * 0.44)
                        .onTapGesture {
                            viewModel.toggleControls()
                        }
                        .onTapGesture(count: 2) {
                            withAnimation(Theme.Animation.quick) {
                                finalScale = (finalScale > 1.0) ? 1.0 : 2.0
                                currentScale = 1.0
                            }
                        }
                    
                    // Right Tap Zone
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: geometry.size.width * 0.28)
                        .onTapGesture {
                            handleTapZone(isLeft: false)
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    private func pageContent(for url: URL) -> some View {
        ZStack {
            if url.isFileURL, let localImg = LocalStorageManager.shared.getLocalImage(for: url) {
                Image(uiImage: localImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, viewModel.settings.sidePadding)
            } else {
                AsyncMangaImage(
                    url: url,
                    contentMode: .fit,
                    cornerRadius: 0,
                    showShimmer: true
                )
                .padding(.horizontal, viewModel.settings.sidePadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func handleTapZone(isLeft: Bool) {
        let isRTL = viewModel.readingMode == .horizontalRTL
        let shouldGoNext = isRTL ? isLeft : !isLeft
        
        if shouldGoNext {
            if viewModel.currentPageIndex < viewModel.pages.count - 1 {
                withAnimation(Theme.Animation.quick) {
                    viewModel.onPageChanged(to: viewModel.currentPageIndex + 1)
                }
            } else if viewModel.hasNextChapter {
                viewModel.goToNextChapter()
            }
        } else {
            if viewModel.currentPageIndex > 0 {
                withAnimation(Theme.Animation.quick) {
                    viewModel.onPageChanged(to: viewModel.currentPageIndex - 1)
                }
            } else if viewModel.hasPreviousChapter {
                viewModel.goToPreviousChapter()
            }
        }
    }
}
