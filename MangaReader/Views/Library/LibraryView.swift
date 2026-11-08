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
    @State private var showCategorySheet = false
    @State private var showFilterSheet = false
    @State private var showFileImporter = false
    @State private var importErrorMessage: String? = nil
    @State private var activeReadingItem: ContinueReadingItem? = nil
    
    // Columns for Grids
    private let compactGridColumns = [
        GridItem(.adaptive(minimum: 105, maximum: 140), spacing: Theme.Spacing.md, alignment: .top)
    ]
    private let comfortableGridColumns = [
        GridItem(.adaptive(minimum: 155, maximum: 200), spacing: Theme.Spacing.lg, alignment: .top)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                SearchBarView(
                    text: $viewModel.searchQuery,
                    placeholder: "Search library titles, authors...",
                    onFilterTapped: { showFilterSheet = true }
                )
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xs)
                
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
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Library")
            .onAppear {
                viewModel.refresh()
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.isSelectionMode {
                        Button("Cancel") {
                            viewModel.exitSelectionMode()
                        }
                        .foregroundColor(.mangaAccent)
                    } else {
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
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18))
                                .foregroundColor(.mangaAccent)
                        }
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
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(viewModel.categories) { cat in
                    Button {
                        viewModel.selectedCategory = cat.name
                    } label: {
                        Text(cat.name)
                            .font(.badgeFont)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .foregroundColor(viewModel.selectedCategory == cat.name ? .white : .textSecondary)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedCategory == cat.name ? Color.mangaAccent : Color.surfaceSecondary)
                            )
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentListOrGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // "Continue Reading" Shelf
                if viewModel.searchQuery.isEmpty && !viewModel.isSelectionMode && !viewModel.currentlyReadingItems.isEmpty {
                    continueReadingShelf
                }
                
                // Library Manga View
                switch viewModel.displayMode {
                case .compactGrid:
                    LazyVGrid(columns: compactGridColumns, spacing: Theme.Spacing.md) {
                        ForEach(viewModel.filteredManga) { manga in
                            mangaItemCell(manga: manga)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    
                case .comfortableGrid:
                    LazyVGrid(columns: comfortableGridColumns, spacing: Theme.Spacing.lg) {
                        ForEach(viewModel.filteredManga) { manga in
                            mangaItemCell(manga: manga)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    
                case .list:
                    LazyVStack(spacing: Theme.Spacing.xs) {
                        ForEach(viewModel.filteredManga) { manga in
                            mangaRowCell(manga: manga)
                            Divider().background(Color.borderSubtle)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }
    
    // MARK: - Continue Reading Shelf
    
    private var continueReadingShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .font(.caption)
                    .foregroundColor(.mangaAccent)
                Text("Continue Reading")
                    .font(.bodyEmphasized)
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("\(viewModel.currentlyReadingItems.count)")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.currentlyReadingItems) { item in
                        continueReadingCard(for: item)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
        .padding(.bottom, 6)
    }
    
    private func continueReadingCard(for item: ContinueReadingItem) -> some View {
        Button {
            activeReadingItem = item
        } label: {
            HStack(spacing: 10) {
                AsyncMangaImage(
                    url: item.manga.coverURL,
                    contentMode: .fill,
                    cornerRadius: Theme.CornerRadius.small,
                    showShimmer: false
                )
                .frame(width: 55, height: 78)
                .clipped()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.manga.title)
                        .font(.cardTitle)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text(item.chapter.displayTitle)
                        .font(.cardSubtitle)
                        .foregroundColor(.mangaAccent)
                        .lineLimit(1)
                    
                    let pageCount = max(1, item.progress.pageCount)
                    let currentPage = item.progress.pageIndex + 1
                    Text("Page \(currentPage) of \(pageCount)")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    // Linear progress track
                    let progressFraction = min(1.0, max(0.0, Double(currentPage) / Double(pageCount)))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.surfaceSecondary)
                                .frame(height: 4)
                            Capsule()
                                .fill(Color.mangaAccent)
                                .frame(width: geo.size.width * CGFloat(progressFraction), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 2)
                }
                .frame(width: 140, alignment: .leading)
            }
            .padding(8)
            .background(Color.surfacePrimary)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Color.borderSubtle, lineWidth: 1)
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
                .foregroundColor(.mangaAccent)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
        .background(Color.surfacePrimary.ignoresSafeArea(edges: .bottom))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.borderSubtle), alignment: .top)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "books.vertical.fill",
                title: "Your Library is Empty",
                subtitle: "Discover manga from the Browse tab or import local CBZ/ZIP files.",
                actionTitle: "Import Local Manga",
                action: { showFileImporter = true }
            )
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
                }
            }
        }
    }
}
