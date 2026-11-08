//
//  LibraryView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import UniformTypeIdentifiers

public struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @ObservedObject private var appState = AppState.shared
    @State private var showCategorySheet = false
    @State private var showFilterSheet = false
    @State private var showFileImporter = false
    @State private var showSearchField = false
    @State private var importErrorMessage: String? = nil
    @State private var activeReadingItem: ContinueReadingItem? = nil
    
    public init() {}
    
    private var gridColumns: [GridItem] {
        let count = max(2, min(5, appState.itemsPerRow))
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Collapsible Search Bar
                if showSearchField || !viewModel.searchQuery.isEmpty {
                    SearchBarView(
                        text: $viewModel.searchQuery,
                        placeholder: "Search library titles, authors...",
                        onFilterTapped: { showFilterSheet = true }
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)
                    .padding(.bottom, Theme.Spacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Category Pills
                categoryBar
                
                // Content View
                if viewModel.filteredManga.isEmpty && viewModel.currentlyReadingItems.isEmpty {
                    emptyState
                } else {
                    contentListOrGrid
                }
                
                // Batch Selection Bar
                if viewModel.isSelectionMode {
                    batchActionBar
                }
            }
            .background(appState.currentBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.refresh()
            }
            .toolbar {
                // Left Title + Cloud Sync Icon
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Text("Library")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        Image(systemName: "icloud")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                }
                
                // Right Glass Capsule Toolbar
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.isSelectionMode {
                        Button("Cancel") {
                            viewModel.exitSelectionMode()
                        }
                        .foregroundColor(.mangaAccent)
                        .font(.bodyMedium)
                    } else {
                        // Circular Filter Button
                        Button {
                            showFilterSheet = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.textPrimary)
                        }
                        .glassCircle(size: 34)
                        
                        // Glass Capsule with Search & Overflow
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(Theme.Animation.quick) {
                                    showSearchField.toggle()
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(showSearchField ? .mangaAccent : .textPrimary)
                            }
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 0.5, height: 14)
                            
                            Menu {
                                Button {
                                    showFileImporter = true
                                } label: {
                                    Label("Import Archive (CBZ/ZIP/EPUB)", systemImage: "square.and.arrow.down")
                                }
                                
                                Button {
                                    showCategorySheet = true
                                } label: {
                                    Label("Manage Categories", systemImage: "folder.badge.gearshape")
                                }
                                
                                Button {
                                    viewModel.isSelectionMode = true
                                } label: {
                                    Label("Batch Select", systemImage: "checkmark.circle")
                                }
                                
                                Divider()
                                
                                Picker("Display Mode", selection: $viewModel.displayMode) {
                                    ForEach(LibraryDisplayMode.allCases, id: \.self) { mode in
                                        Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                                    }
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
            }
            .sheet(isPresented: $showCategorySheet) {
                CategoryManagementSheet()
            }
            .sheet(isPresented: $showFilterSheet) {
                filterSheet
            }
            .fullScreenCover(item: $activeReadingItem) { item in
                ReaderContainerView(
                    manga: item.manga,
                    chapter: item.chapter,
                    initialPage: item.progress.pageIndex
                )
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.zip, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        _ = try LocalLibraryScanner.shared.importFile(at: url)
                        viewModel.refresh()
                    } catch {
                        self.importErrorMessage = error.localizedDescription
                    }
                case .failure(let err):
                    self.importErrorMessage = err.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Category Bar
    
    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.categories) { cat in
                    let isSelected = viewModel.selectedCategory == cat.name
                    Button {
                        viewModel.selectedCategory = cat.name
                    } label: {
                        Text(cat.name)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .foregroundColor(isSelected ? .mangaAccentInk : .textSecondary)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.mangaAccent : Color.white.opacity(0.06))
                            )
                            .overlay(
                                Capsule().stroke(Color.white.opacity(isSelected ? 0.0 : 0.12), lineWidth: 0.5)
                            )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentListOrGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // "Continue Reading" Shelf
                if viewModel.searchQuery.isEmpty && !viewModel.isSelectionMode && !viewModel.currentlyReadingItems.isEmpty {
                    continueReadingShelf
                }
                
                // Library Manga View
                switch viewModel.displayMode {
                case .compactGrid, .comfortableGrid:
                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(viewModel.filteredManga) { manga in
                            mangaItemCell(manga: manga)
                        }
                    }
                    .padding(.horizontal, 12)
                    
                case .list:
                    LazyVStack(spacing: Theme.Spacing.xs) {
                        ForEach(viewModel.filteredManga) { manga in
                            mangaRowCell(manga: manga)
                            Divider().background(Color.white.opacity(0.06))
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 80) // Floating Tab Bar inset
        }
    }
    
    // MARK: - Continue Reading Shelf
    
    private var continueReadingShelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .font(.caption)
                    .foregroundColor(.mangaAccent)
                Text("Continue Reading")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("\(viewModel.currentlyReadingItems.count)")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 12)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.currentlyReadingItems) { item in
                        continueReadingCard(for: item)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
    
    private func continueReadingCard(for item: ContinueReadingItem) -> some View {
        Button {
            activeReadingItem = item
        } label: {
            HStack(spacing: 10) {
                AsyncMangaImage(
                    url: item.manga.coverURL,
                    contentMode: .fill,
                    cornerRadius: 8,
                    showShimmer: false
                )
                .frame(width: 52, height: 74)
                .clipped()
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.manga.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text(item.chapter.displayTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.mangaAccent)
                        .lineLimit(1)
                    
                    let pageCount = max(1, item.progress.totalPages)
                    let currentPage = item.progress.pageIndex + 1
                    Text("Page \(currentPage) of \(pageCount)")
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondary)
                    
                    // Linear progress track
                    let progressFraction = min(1.0, max(0.0, Double(currentPage) / Double(pageCount)))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 3)
                            Capsule()
                                .fill(Color.mangaAccent)
                                .frame(width: geo.size.width * CGFloat(progressFraction), height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.top, 2)
                }
                .frame(width: 135, alignment: .leading)
            }
            .padding(7)
            .background(Color.surfacePrimary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func mangaItemCell(manga: MangaItem) -> some View {
        if viewModel.isSelectionMode {
            MangaCardView(
                manga: manga,
                isSelected: viewModel.selectedMangaIDs.contains(manga.id),
                isSelectionMode: true
            )
            .onTapGesture {
                viewModel.toggleSelection(for: manga.id)
            }
        } else {
            NavigationLink(destination: MangaDetailView(manga: manga)) {
                MangaCardView(manga: manga)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    @ViewBuilder
    private func mangaRowCell(manga: MangaItem) -> some View {
        if viewModel.isSelectionMode {
            MangaRowView(
                manga: manga,
                isSelected: viewModel.selectedMangaIDs.contains(manga.id),
                isSelectionMode: true
            )
            .onTapGesture {
                viewModel.toggleSelection(for: manga.id)
            }
        } else {
            NavigationLink(destination: MangaDetailView(manga: manga)) {
                MangaRowView(manga: manga)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Batch Action Bar
    
    private var batchActionBar: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Button {
                viewModel.selectAll()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "checklist")
                    Text("Select All").font(.captionMedium)
                }
            }
            
            Spacer()
            
            Button {
                viewModel.batchMarkSelectedRead(isRead: true)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle")
                    Text("Mark Read").font(.captionMedium)
                }
            }
            
            Spacer()
            
            Button {
                viewModel.batchRemoveSelected()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "trash")
                    Text("Remove").font(.captionMedium)
                }
                .foregroundColor(.mangaRed)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.white.opacity(0.12)), alignment: .top)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Σ(ಠ_ಠ)")
                .font(.kaomoji)
                .foregroundColor(.textSecondary)
            Text("Your Library is Empty")
                .font(.sectionTitle)
                .foregroundColor(.textPrimary)
            Text("Discover manga from Browse or import local CBZ/ZIP files.")
                .font(.captionMedium)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showFileImporter = true
            } label: {
                Text("Import Local Manga")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.mangaAccentInk)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.mangaAccent)
                    .clipShape(Capsule())
            }
            .padding(.top, 6)
            Spacer()
        }
    }
    
    // MARK: - Filter Sheet
    
    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Sort By") {
                    Picker("Order", selection: $viewModel.sortOption) {
                        ForEach(LibrarySortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    Toggle("Ascending", isOn: $viewModel.sortAscending)
                }
                
                Section("Filter") {
                    Toggle("Unread Chapters Only", isOn: $viewModel.unreadOnly)
                    Toggle("Downloaded Only", isOn: $viewModel.downloadedOnly)
                }
            }
            .navigationTitle("Sort & Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showFilterSheet = false }
                        .foregroundColor(.mangaAccent)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
