//
//  ReaderControlsOverlay.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct ReaderControlsOverlay: View {
    @ObservedObject public var viewModel: ReaderViewModel
    public let onClose: () -> Void
    
    @State private var dragPageValue: Double = 0
    
    public init(viewModel: ReaderViewModel, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack {
            // Top Bar
            topBar
            
            Spacer()
            
            // Bottom Bar with Scrubber
            bottomBar
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .onAppear {
            dragPageValue = Double(viewModel.currentPageIndex)
        }
        .onChange(of: viewModel.currentPageIndex) { newIndex in
            if !viewModel.isScrubbingSlider {
                dragPageValue = Double(newIndex)
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.manga.title)
                    .font(.bodyEmphasized)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(viewModel.currentChapter.displayTitle)
                    .font(.cardSubtitle)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Reading Mode Quick Switcher
            Menu {
                ForEach(ReadingMode.allCases) { mode in
                    Button {
                        viewModel.updateReadingMode(mode)
                    } label: {
                        Label(mode.rawValue, systemImage: mode.iconName)
                    }
                }
            } label: {
                Image(systemName: viewModel.readingMode.iconName)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Circle())
            }
            
            // Settings Sheet Button
            Button {
                viewModel.showSettingsSheet = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 50)
        .padding(.bottom, Theme.Spacing.sm)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.85), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Page Counter & Chapter Navigation
            HStack {
                Button(action: { viewModel.goToPreviousChapter() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                        Text("Prev Ch")
                    }
                    .font(.captionMedium)
                    .foregroundColor(viewModel.hasPreviousChapter ? .white : .textTertiary)
                }
                .disabled(!viewModel.hasPreviousChapter)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { viewModel.stepPage(forward: false) }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(viewModel.currentPageIndex > 0 ? .white : .textTertiary)
                    }
                    .disabled(viewModel.currentPageIndex <= 0)
                    
                    let total = max(1, viewModel.totalPagesInCurrentChapter)
                    let current = viewModel.isScrubbingSlider ? Int(dragPageValue.rounded()) + 1 : viewModel.currentPageIndex + 1
                    Text("\(min(current, total)) / \(total)")
                        .font(.readerCounter)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                    
                    Button(action: { viewModel.stepPage(forward: true) }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(viewModel.currentPageIndex < total - 1 ? .white : .textTertiary)
                    }
                    .disabled(viewModel.currentPageIndex >= total - 1)
                }
                
                Spacer()
                
                Button(action: { viewModel.goToNextChapter() }) {
                    HStack(spacing: 4) {
                        Text("Next Ch")
                        Image(systemName: "chevron.forward")
                    }
                    .font(.captionMedium)
                    .foregroundColor(viewModel.hasNextChapter ? .white : .textTertiary)
                }
                .disabled(!viewModel.hasNextChapter)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            
            // Page Scrubber Slider
            let maxPage = max(0, viewModel.totalPagesInCurrentChapter - 1)
            if maxPage > 0 {
                Slider(
                    value: $dragPageValue,
                    in: 0...Double(maxPage),
                    step: 1,
                    onEditingChanged: { editing in
                        viewModel.isScrubbingSlider = editing
                        if !editing {
                            let target = Int(dragPageValue.rounded())
                            viewModel.seekToPage(target)
                        }
                    }
                )
                .accentColor(.mangaAccent)
                .padding(.horizontal, Theme.Spacing.xl)
            }
        }
        .padding(.bottom, 40)
        .padding(.top, Theme.Spacing.sm)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
}
