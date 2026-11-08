//
//  HomeView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

private struct IdentifiableContinue: Identifiable {
    var id: UUID { chapter.id }
    let manga: MangaItem
    let chapter: ChapterItem
}

public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var appState = AppState.shared
    @State private var selectedContinueChapter: (manga: MangaItem, chapter: ChapterItem)? = nil
    @State private var showSettingsQuickSheet = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Update Completed Banner Toast
                    if viewModel.showUpdateToast {
                        updateCompletedBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Main Content: Updates or Kaomoji Empty State
                    if viewModel.latestUpdates.isEmpty && !viewModel.isLoading {
                        kaomojiEmptyState
                            .padding(.top, 60)
                    } else {
                        updatesList
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 80) // Tab Bar inset
            }
            .background(appState.currentBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Left Title + Cloud Icon
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Text("Updates")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        Image(systemName: "icloud")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                }
                
                // Right Glass Capsule Toolbar
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.loadHomeData()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.textPrimary)
                        }
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 0.5, height: 14)
                        
                        Menu {
                            Button {
                                viewModel.showUpdateToast.toggle()
                            } label: {
                                Label("Toggle Update Status", systemImage: "bell")
                            }
                            Button {
                                viewModel.loadHomeData()
                            } label: {
                                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.textPrimary)
                        }
                    }
                    .glassCapsule(height: 34, cornerRadius: 17, horizontalPadding: 11)
                }
            }
            .refreshable {
                viewModel.loadHomeData()
            }
            .fullScreenCover(item: Binding(
                get: { selectedContinueChapter.map { IdentifiableContinue(manga: $0.manga, chapter: $0.chapter) } },
                set: { selectedContinueChapter = $0.map { ($0.manga, $0.chapter) } }
            )) { item in
                ReaderContainerView(manga: item.manga, chapter: item.chapter)
            }
        }
    }
    
    // MARK: - Update Completed Banner Toast
    
    private var updateCompletedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.mangaGreen)
                .font(.system(size: 18))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Update completed.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(viewModel.updateSummary)
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundColor(.textTertiary)
            
            Button {
                withAnimation(Theme.Animation.quick) {
                    viewModel.showUpdateToast = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.textSecondary)
                    .padding(4)
            }
        }
        .padding(10)
        .background(Color.surfacePrimary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    // MARK: - Kaomoji Empty State
    
    private var kaomojiEmptyState: some View {
        VStack(spacing: 14) {
            Text("(ˇ•_•ˇ)")
                .font(.system(size: 38, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
            
            Text("No recent chapters")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
            
            Text("Your library is up to date.")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
            
            Button {
                viewModel.loadHomeData()
            } label: {
                Text("Refresh")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.mangaAccentInk)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .background(Color.mangaAccent)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Updates List
    
    private var updatesList: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.latestUpdates) { manga in
                NavigationLink(destination: MangaDetailView(manga: manga)) {
                    HStack(spacing: 12) {
                        AsyncMangaImage(
                            url: manga.coverURL,
                            contentMode: .fill,
                            cornerRadius: 6,
                            showShimmer: false
                        )
                        .frame(width: 48, height: 68)
                        .clipped()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(manga.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                            
                            Text("New Chapter Available")
                                .font(.system(size: 12))
                                .foregroundColor(.mangaAccent)
                            
                            Text(manga.status.rawValue)
                                .font(.system(size: 11))
                                .foregroundColor(.textTertiary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.textTertiary)
                    }
                    .padding(8)
                    .background(Color.surfacePrimary)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
