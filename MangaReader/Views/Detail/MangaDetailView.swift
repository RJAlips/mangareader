//
//  MangaDetailView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct MangaDetailView: View {
    @StateObject private var viewModel: MangaDetailViewModel
    @State private var isSynopsisExpanded: Bool = false
    @State private var selectedChapterForReading: ChapterItem? = nil
    
    public init(manga: MangaItem) {
        self._viewModel = StateObject(wrappedValue: MangaDetailViewModel(manga: manga))
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Header with Blurred Background
                heroHeader
                
                // Metadata & Actions
                metadataSection
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                
                // Chapters Header
                chaptersHeader
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.lg)
                
                // Chapters List
                chaptersList
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.hero)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.downloadAll()
                    } label: {
                        Label("Download All", systemImage: "arrow.down.to.line.compact")
                    }
                    
                    Button {
                        viewModel.downloadUnread()
                    } label: {
                        Label("Download Unread", systemImage: "arrow.down.circle")
                    }
                    
                    Divider()
                    
                    Button {
                        viewModel.cancelDownloads()
                    } label: {
                        Label("Cancel Downloads", systemImage: "xmark.circle")
                    }
                    
                    Button(role: .destructive) {
                        viewModel.deleteDownloaded()
                    } label: {
                        Label("Delete Downloaded", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                        .foregroundColor(.mangaAccent)
                }
            }
        }
        .fullScreenCover(item: $selectedChapterForReading) { chapter in
            ReaderContainerView(manga: viewModel.manga, chapter: chapter)
        }
    }
    
    // MARK: - Hero Header
    
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Blurred Backdrop
            AsyncMangaImage(
                url: viewModel.manga.coverURL,
                contentMode: .fill,
                cornerRadius: 0
            )
            .frame(height: 260)
            .clipped()
            .blur(radius: 25)
            .opacity(0.35)
            
            LinearGradient.detailHeroOverlay
                .frame(height: 260)
            
            // Poster & Title Info
            HStack(alignment: .bottom, spacing: Theme.Spacing.lg) {
                AsyncMangaImage(
                    url: viewModel.manga.coverURL,
                    contentMode: .fill,
                    cornerRadius: Theme.CornerRadius.card
                )
                .frame(width: 110, height: 160)
                .shadow(color: Theme.Shadow.deep, radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.manga.title)
                        .font(.heroTitle)
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                    
                    if let author = viewModel.manga.author {
                        Text(author)
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 6) {
                        BadgeView(text: viewModel.manga.status.rawValue, backgroundColor: .surfaceSecondary)
                        BadgeView(text: viewModel.manga.contentRating.rawValue, backgroundColor: .surfaceSecondary)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)
        }
    }
    
    // MARK: - Metadata & Actions
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Genres
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(viewModel.manga.genres, id: \.self) { genre in
                        BadgeView(text: genre, backgroundColor: .surfaceSecondary)
                    }
                }
            }
            
            // Synopsis
            if let desc = viewModel.manga.description {
                VStack(alignment: .leading, spacing: 4) {
                    Text(desc)
                        .font(.bodyRegular)
                        .foregroundColor(.textSecondary)
                        .lineLimit(isSynopsisExpanded ? nil : 3)
                    
                    Button(isSynopsisExpanded ? "Show Less" : "Read More") {
                        withAnimation(Theme.Animation.quick) {
                            isSynopsisExpanded.toggle()
                        }
                    }
                    .font(.captionMedium)
                    .foregroundColor(.mangaAccent)
                }
            }
            
            // Primary Action Buttons
            HStack(spacing: Theme.Spacing.md) {
                // Continue / Start Reading Button
                Button {
                    if let nextCh = viewModel.nextChapterToRead {
                        selectedChapterForReading = nextCh
                    }
                } label: {
                    HStack {
                        Image(systemName: "book.fill")
                        Text(viewModel.nextChapterToRead != nil ? "Continue \(viewModel.nextChapterToRead!.formattedNumber)" : "Read")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(LinearGradient.mangaAccentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
                    .shadow(color: Color.mangaAccent.opacity(0.35), radius: 6, x: 0, y: 3)
                }
                
                // Add to Library Button
                Button {
                    viewModel.toggleLibrary()
                } label: {
                    Image(systemName: viewModel.manga.inLibrary ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.manga.inLibrary ? .mangaAccent : .white)
                        .frame(width: 50, height: 50)
                        .background(Color.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
                }
                
                // Favorite Button
                Button {
                    viewModel.toggleFavorite()
                } label: {
                    Image(systemName: viewModel.manga.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.manga.isFavorite ? .mangaAccent : .white)
                        .frame(width: 50, height: 50)
                        .background(Color.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
                }
            }
        }
    }
    
    // MARK: - Chapters Header
    
    private var chaptersHeader: some View {
        HStack {
            Text("\(viewModel.chapters.count) Chapters")
                .font(.sectionTitle)
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            // Download all unread
            Button {
                viewModel.downloadAllUnread()
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.textSecondary)
            }
            .padding(.trailing, 6)
            
            // Sort Order Toggle
            Button {
                viewModel.sortDescending.toggle()
            } label: {
                Image(systemName: viewModel.sortDescending ? "arrow.down.circle" : "arrow.up.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.mangaAccent)
            }
        }
    }
    
    // MARK: - Chapters List
    
    private var chaptersList: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoadingChapters {
                ProgressView()
                    .padding()
            } else if viewModel.displayedChapters.isEmpty {
                Text("No chapters available.")
                    .font(.bodyRegular)
                    .foregroundColor(.textTertiary)
                    .padding(.vertical, Theme.Spacing.xl)
            } else {
                ForEach(viewModel.displayedChapters) { chapter in
                    ChapterRowView(
                        chapter: chapter,
                        onDownload: { viewModel.downloadChapter(chapter) },
                        onDeleteDownload: { viewModel.deleteDownload(chapter) },
                        onToggleRead: { viewModel.toggleChapterRead(chapter) }
                    )
                    .onTapGesture {
                        selectedChapterForReading = chapter
                    }
                    
                    Divider().background(Color.borderSubtle)
                }
            }
        }
    }
}
