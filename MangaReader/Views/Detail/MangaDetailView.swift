//
//  MangaDetailView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import SafariServices

public struct MangaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MangaDetailViewModel
    @ObservedObject private var historyRepo = HistoryRepository.shared
    @ObservedObject private var appState = AppState.shared
    
    @State private var isSynopsisExpanded: Bool = false
    @State private var selectedChapterForReading: ChapterItem? = nil
    @State private var showSafariSheet: Bool = false
    @State private var showTrackingSheet: Bool = false
    @State private var chapterSearchText: String = ""
    @State private var showChapterSearch: Bool = false
    
    public init(manga: MangaItem) {
        self._viewModel = StateObject(wrappedValue: MangaDetailViewModel(manga: manga))
    }
    
    private var filteredChapters: [ChapterItem] {
        let q = chapterSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return viewModel.displayedChapters
        }
        return viewModel.displayedChapters.filter {
            $0.displayTitle.lowercased().contains(q) || $0.formattedNumber.contains(q)
        }
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 1. Hero Header with Blurred Background + Poster + Metadata
                heroHeader
                
                // 2. 3-Button Action Bar
                actionBar
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                
                // 3. Synopsis & Genre Chips
                synopsisAndGenresSection
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                
                // 4. Full-width Periwinkle "Continue reading" Button
                continueReadingButton
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                
                // 5. Chapter Header & Refresh Row
                chaptersHeaderSection
                    .padding(.horizontal, 14)
                    .padding(.top, 18)
                
                // 6. Chapter Rows
                chaptersListSection
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
            }
        }
        .background(appState.currentBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Left: Circular Glass Back Button
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.textPrimary)
                }
                .glassCircle(size: 34)
            }
            
            // Right: Glass Capsule Toolbar (Download Menu + Overflow)
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
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
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 0.5, height: 14)
                    
                    Menu {
                        Button {
                            viewModel.toggleFavorite()
                        } label: {
                            Label(viewModel.manga.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: "heart")
                        }
                        Button {
                            viewModel.toggleLibrary()
                        } label: {
                            Label(viewModel.manga.inLibrary ? "Remove from Library" : "Save to Library", systemImage: "bookmark")
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
        .fullScreenCover(item: $selectedChapterForReading) { chapter in
            ReaderContainerView(manga: viewModel.manga, chapter: chapter, initialPage: chapter.lastPageRead)
        }
        .sheet(isPresented: $showSafariSheet) {
            if let url = URL(string: viewModel.manga.urlOrSlug) ?? URL(string: "https://google.com") {
                SafariView(url: url)
            }
        }
    }
    
    // MARK: - 1. Hero Header
    
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Blurred backdrop cover
            AsyncMangaImage(
                url: viewModel.manga.coverURL,
                contentMode: .fill,
                cornerRadius: 0
            )
            .frame(height: 250)
            .frame(maxWidth: .infinity)
            .clipped()
            .blur(radius: 28)
            .opacity(0.32)
            
            LinearGradient.detailHeroOverlay
                .frame(height: 250)
            
            // Poster & Details HStack
            HStack(alignment: .bottom, spacing: 14) {
                // Poster (105x150pt, cornerRadius: 8)
                AsyncMangaImage(
                    url: viewModel.manga.coverURL,
                    contentMode: .fill,
                    cornerRadius: 8
                )
                .frame(width: 105, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
                
                // Metadata Column
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.manga.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                    
                    if let author = viewModel.manga.author, !author.isEmpty {
                        Text(author)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                    
                    // Status & Source Row
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)
                        Text("\(viewModel.manga.status.rawValue) • \(sourceName)")
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                    
                    // Reading Duration Row
                    HStack(spacing: 5) {
                        Image(systemName: "book")
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)
                        Text(historyRepo.readingDuration(for: viewModel.manga.id))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.mangaAccent)
                    }
                    
                    // Clickable Source Link
                    Button {
                        showSafariSheet = true
                    } label: {
                        Text(viewModel.manga.sourceID)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.mangaAccent)
                            .lineLimit(1)
                    }
                    
                    // Global Search Pill
                    NavigationLink(destination: GlobalSearchView(query: viewModel.manga.title)) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10))
                            Text("Global Search")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }
    
    private var sourceName: String {
        SourceManager.shared.getSource(id: viewModel.manga.sourceID)?.manifest.name ?? viewModel.manga.sourceID
    }
    
    // MARK: - 2. Action Bar (Add to Library | Tracking | Web View)
    
    private var actionBar: some View {
        HStack(spacing: 8) {
            // Add to Library
            Button {
                viewModel.toggleLibrary()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.manga.inLibrary ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.manga.inLibrary ? .mangaRed : .textPrimary)
                    Text(viewModel.manga.inLibrary ? "In Library" : "Add to Library")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color.surfacePrimary)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            }
            
            // Tracking
            Button {
                showTrackingSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.mangaAccent)
                    Text("Tracking")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color.surfacePrimary)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            }
            
            // Web View
            Button {
                showSafariSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .foregroundColor(.mangaBlue)
                    Text("Web View")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color.surfacePrimary)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            }
        }
    }
    
    // MARK: - 3. Synopsis & Genres Section
    
    private var synopsisAndGenresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Expandable Synopsis
            if let desc = viewModel.manga.description, !desc.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .lineLimit(isSynopsisExpanded ? nil : 3)
                    
                    Button {
                        withAnimation(Theme.Animation.quick) {
                            isSynopsisExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(isSynopsisExpanded ? "Less" : "More")
                            Image(systemName: isSynopsisExpanded ? "chevron.up" : "chevron.down")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.mangaAccent)
                    }
                }
            }
            
            // Genre Chips
            if !viewModel.manga.genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.manga.genres, id: \.self) { genre in
                            Text(genre)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.surfacePrimary)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 4. Prominent Periwinkle Continue Reading Button
    
    private var continueReadingButton: some View {
        Button {
            if let nextCh = viewModel.nextChapterToRead {
                selectedChapterForReading = nextCh
            } else if let firstCh = viewModel.chapters.first {
                selectedChapterForReading = firstCh
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 14))
                
                Text(continueReadingTitle)
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundColor(.mangaAccentInk)
            .background(Color.mangaAccent)
            .clipShape(Capsule())
            .shadow(color: Color.mangaAccent.opacity(0.3), radius: 6, x: 0, y: 3)
        }
    }
    
    private var continueReadingTitle: String {
        if let nextCh = viewModel.nextChapterToRead {
            return "Continue reading \(nextCh.displayTitle)"
        } else if let firstCh = viewModel.chapters.first {
            return "Start reading \(firstCh.displayTitle)"
        }
        return "Start reading"
    }
    
    // MARK: - 5. Chapter Header Section
    
    private var chaptersHeaderSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(viewModel.chapters.count) Chapters")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                HStack(spacing: 14) {
                    Button {
                        withAnimation(Theme.Animation.quick) {
                            showChapterSearch.toggle()
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(showChapterSearch ? .mangaAccent : .textSecondary)
                    }
                    
                    Button {
                        viewModel.sortDescending.toggle()
                    } label: {
                        Image(systemName: viewModel.sortDescending ? "arrow.down" : "arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Button {
                        viewModel.downloadAllUnread()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            
            // Chapter Search Input
            if showChapterSearch {
                TextField("Filter chapters...", text: $chapterSearchText)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(Color.surfacePrimary)
                    .cornerRadius(8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Outdated Notice Row
            HStack(spacing: 4) {
                Text("Chapter list may be outdated •")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                
                Button("Refresh") {
                    viewModel.loadChapters()
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.mangaAccent)
                
                Spacer()
            }
            .padding(.top, 2)
        }
    }
    
    // MARK: - 6. Chapter Rows List
    
    private var chaptersListSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoadingChapters {
                ProgressView()
                    .padding()
            } else if filteredChapters.isEmpty {
                Text("No chapters found.")
                    .font(.system(size: 13))
                    .foregroundColor(.textTertiary)
                    .padding(.vertical, 20)
            } else {
                ForEach(filteredChapters) { chapter in
                    ChapterRowView(
                        chapter: chapter,
                        onDownload: { viewModel.downloadChapter(chapter) },
                        onDeleteDownload: { viewModel.deleteDownload(chapter) },
                        onToggleRead: { viewModel.toggleChapterRead(chapter) }
                    )
                    .onTapGesture {
                        selectedChapterForReading = chapter
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
    }
}

// MARK: - Safari View Controller Bridge

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
