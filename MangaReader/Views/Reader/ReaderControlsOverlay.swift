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
                        Text("Prev")
                    }
                    .font(.captionMedium)
                    .foregroundColor(viewModel.hasPreviousChapter ? .white : .textTertiary)
                }
                .disabled(!viewModel.hasPreviousChapter)
                
                Spacer()
                
                Text("\(viewModel.currentPageIndex + 1) / \(max(1, viewModel.pages.count))")
                    .font(.readerCounter)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                
                Spacer()
                
                Button(action: { viewModel.goToNextChapter() }) {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.forward")
                    }
                    .font(.captionMedium)
                    .foregroundColor(viewModel.hasNextChapter ? .white : .textTertiary)
                }
                .disabled(!viewModel.hasNextChapter)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            
            // Page Scrubber Slider
            if viewModel.pages.count > 1 {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.currentPageIndex) },
                        set: { viewModel.onPageChanged(to: Int($0)) }
                    ),
                    in: 0...Double(max(0, viewModel.pages.count - 1)),
                    step: 1
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
