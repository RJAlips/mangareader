//
//  HomeView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var searchQuery = ""
    @State private var selectedContinueChapter: (manga: MangaItem, chapter: ChapterItem)? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // Quick Stats & Welcome
                    quickStatsHeader
                    
                    // Continue Reading Section
                    if !viewModel.continueReading.isEmpty {
                        continueReadingSection
                    }
                    
                    // Popular Manga Carousel
                    if !viewModel.popularManga.isEmpty {
                        popularSection
                    }
                    
                    // Latest Updates Section
                    if !viewModel.latestUpdates.isEmpty {
                        latestUpdatesSection
                    }
                    
                    // Recently Added
                    if !viewModel.recentlyAdded.isEmpty {
                        recentlyAddedSection
                    }
                }
                .padding(.bottom, Theme.Spacing.hero)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Discover")
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
    
    // MARK: - Quick Stats Header
    
    private var quickStatsHeader: some View {
        HStack(spacing: Theme.Spacing.md) {
            statCard(
                icon: "books.vertical.fill",
                color: .mangaAccent,
                title: "In Library",
                value: "\(viewModel.totalLibraryCount)"
            )
            
            statCard(
                icon: "bell.badge.fill",
                color: .mangaPurple,
                title: "Unread Chapters",
                value: "\(viewModel.totalUnreadChapters)"
            )
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
    }
    
    private func statCard(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.textPrimary)
                Text(title)
                    .font(.captionMedium)
                    .foregroundColor(.textSecondary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
    }
    
    // MARK: - Continue Reading
    
    private var continueReadingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Continue Reading")
                .font(.sectionTitle)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, Theme.Spacing.lg)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(viewModel.continueReading) { item in
                        continueReadingCard(item: item)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }
    
    private func continueReadingCard(item: ContinueReadingItem) -> some View {
        Button {
            selectedContinueChapter = (item.manga, item.chapter)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                AsyncMangaImage(
                    url: item.manga.coverURL,
                    contentMode: .fill,
                    cornerRadius: Theme.CornerRadius.small
                )
                .frame(width: 60, height: 85)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.manga.title)
                        .font(.bodyEmphasized)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text(item.chapter.displayTitle)
                        .font(.cardSubtitle)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                    
                    // Progress Bar
                    VStack(alignment: .leading, spacing: 3) {
                        ProgressView(value: item.progress.progressPercent)
                            .tint(.mangaAccent)
                        Text("Page \(item.progress.pageIndex + 1) of \(max(1, item.progress.totalPages))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                }
                .frame(width: 140)
            }
            .padding(Theme.Spacing.sm)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.card, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Popular Manga
    
    private var popularSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Popular Manga & Manhwa")
                    .font(.sectionTitle)
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(viewModel.popularManga) { manga in
                        NavigationLink(destination: MangaDetailView(manga: manga)) {
                            MangaCardView(manga: manga, showUnreadBadge: false)
                                .frame(width: 130)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }
    
    // MARK: - Latest Updates
    
    private var latestUpdatesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Latest Releases")
                .font(.sectionTitle)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, Theme.Spacing.lg)
            
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(viewModel.latestUpdates.prefix(5)) { manga in
                    NavigationLink(destination: MangaDetailView(manga: manga)) {
                        MangaRowView(manga: manga)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Divider().background(Color.borderSubtle)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
    
    // MARK: - Recently Added
    
    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Recently Added to Library")
                .font(.sectionTitle)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, Theme.Spacing.lg)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(viewModel.recentlyAdded) { manga in
                        NavigationLink(destination: MangaDetailView(manga: manga)) {
                            MangaCardView(manga: manga)
                                .frame(width: 120)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }
}

private struct IdentifiableContinue: Identifiable {
    var id: UUID { chapter.id }
    let manga: MangaItem
    let chapter: ChapterItem
}
