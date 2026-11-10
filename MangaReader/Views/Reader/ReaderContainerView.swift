//
//  ReaderContainerView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import UIKit

public struct ReaderContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ReaderViewModel
    
    public init(manga: MangaItem, chapter: ChapterItem, initialPage: Int? = nil) {
        self._viewModel = StateObject(wrappedValue: ReaderViewModel(manga: manga, chapter: chapter, initialPage: initialPage))
    }
    
    public var body: some View {
        ZStack {
            // Background Color
            viewModel.settings.backgroundColor.color
                .ignoresSafeArea()
            
            // Reading Content
            if viewModel.isLoadingPages {
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .mangaAccent))
                        .scaleEffect(1.2)
                    Text("Loading chapter pages...")
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(.mangaAccent)
                    Text("Failed to load pages")
                        .font(.sectionTitle)
                        .foregroundColor(.textPrimary)
                    Text(error)
                        .font(.bodyRegular)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                    Button("Retry") {
                        viewModel.loadPages(for: viewModel.currentChapter)
                    }
                    .foregroundColor(.mangaAccent)
                    .fontWeight(.semibold)
                }
            } else if viewModel.pages.isEmpty {
                Text("No pages available.")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
            } else {
                switch viewModel.readingMode {
                case .webtoon:
                    WebtoonReaderView(viewModel: viewModel)
                case .horizontalLTR, .horizontalRTL, .verticalPaged, .doublePage:
                    PagedReaderView(viewModel: viewModel)
                }
            }
            
            // Brightness Dimmer Overlay
            if viewModel.brightness < 1.0 {
                Color.black.opacity(1.0 - viewModel.brightness)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            // Interactive Overlays
            if viewModel.showControls {
                ReaderControlsOverlay(viewModel: viewModel) {
                    dismiss()
                }
            }
        }
        .statusBarHidden(!viewModel.showControls)
        .sheet(isPresented: $viewModel.showSettingsSheet) {
            ReaderSettingsSheet(viewModel: viewModel)
        }
        .onAppear {
            if viewModel.settings.keepScreenAwake {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.saveReadingProgressOnExit()
        }
    }
}
