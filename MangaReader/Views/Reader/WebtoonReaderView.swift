//
//  WebtoonReaderView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

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
                        AsyncMangaImage(
                            url: url,
                            contentMode: contentModeForScale(viewModel.settings.imageScale),
                            cornerRadius: 0,
                            showShimmer: true
                        )
                        .id(index)
                        .onAppear {
                            viewModel.onPageChanged(to: index)
                        }
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
    
    private func contentModeForScale(_ scaleType: ImageScaleType) -> ContentMode {
        switch scaleType {
        case .fitWidth: return .fit
        case .fitHeight: return .fit
        case .stretch: return .fill
        case .original: return .fit
        }
    }
}
