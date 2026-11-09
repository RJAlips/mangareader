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
    @State private var selectedReaderTarget: (manga: MangaItem, chapter: ChapterItem)? = nil
    @State private var selectedMangaForDetail: MangaItem? = nil
    
    public init() {}
    
    private var groupedUpdates: [(dateString: String, entries: [MangaUpdateEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.updateEntries) { entry -> Date in
            calendar.startOfDay(for: entry.date)
        }
        let sortedKeys = grouped.keys.sorted(by: >)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        
        return sortedKeys.map { dayStart in
            let label: String
            if calendar.isDateInToday(dayStart) {
                label = "Today"
            } else if calendar.isDateInYesterday(dayStart) {
                label = "Yesterday"
            } else {
                label = dateFormatter.string(from: dayStart)
            }
            let entries = grouped[dayStart]?.sorted(by: { $0.chapterNumber > $1.chapterNumber }) ?? []
            return (dateString: label, entries: entries)
        }
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Update Completed Banner Toast
                    if viewModel.showUpdateToast {
                        updateCompletedBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Main Content: Grouped Updates or Kaomoji Empty State
                    if viewModel.updateEntries.isEmpty && !viewModel.isLoading {
                        kaomojiEmptyState
                            .padding(.top, 60)
                    } else {
                        updatesGroupedList
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
                            Task {
                                await viewModel.refreshLibraryUpdates()
                            }
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
                                Task {
                                    await viewModel.refreshLibraryUpdates()
                                }
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
                await viewModel.refreshLibraryUpdates()
            }
            .navigationDestination(item: $selectedMangaForDetail) { manga in
                MangaDetailView(manga: manga)
            }
            .fullScreenCover(item: Binding(
                get: { selectedReaderTarget.map { IdentifiableContinue(manga: $0.manga, chapter: $0.chapter) } },
                set: { selectedReaderTarget = $0.map { ($0.manga, $0.chapter) } }
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
            Text("(¯\\_(ツ)_/¯)")
                .font(.system(size: 38, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
            
            Text("No recent chapters")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
            
            Text("Your library is up to date.")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
            
            Button {
                Task {
                    await viewModel.refreshLibraryUpdates()
                }
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
    
    // MARK: - Grouped Updates List
    
    private var updatesGroupedList: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(groupedUpdates, id: \.dateString) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.dateString)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    
                    ForEach(group.entries) { entry in
                        updateRow(for: entry)
                    }
                }
            }
        }
    }
    
    private func updateRow(for entry: MangaUpdateEntry) -> some View {
        HStack(spacing: 12) {
            // Tap Cover -> Open MangaDetailView
            Button {
                selectedMangaForDetail = getManga(for: entry)
            } label: {
                AsyncMangaImage(
                    url: entry.coverURL,
                    contentMode: .fill,
                    cornerRadius: 6,
                    showShimmer: false
                )
                .frame(width: 48, height: 68)
                .clipped()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Tap Row Info -> Open ReaderContainerView
            Button {
                let manga = getManga(for: entry)
                let chapter = getChapter(for: entry)
                selectedReaderTarget = (manga, chapter)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.mangaTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text(entry.chapterTitle)
                        .font(.system(size: 12))
                        .foregroundColor(.mangaAccent)
                        .lineLimit(1)
                    
                    Text("Chapter \(HomeViewModel.formatChapterNum(entry.chapterNumber))")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Trailing Download Button
            Button {
                if !viewModel.isChapterDownloaded(entry) {
                    viewModel.downloadChapter(for: entry)
                }
            } label: {
                Image(systemName: viewModel.isChapterDownloaded(entry) ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isChapterDownloaded(entry) ? .mangaGreen : .textSecondary)
                    .padding(6)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(8)
        .background(Color.surfacePrimary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    // MARK: - Resolvers
    
    private func getManga(for entry: MangaUpdateEntry) -> MangaItem {
        if let found = DatabaseManager.shared.mangaList.first(where: { $0.id == entry.mangaID }) {
            return found
        }
        if let found = LibraryRepository.shared.libraryItems.first(where: { $0.id == entry.mangaID }) {
            return found
        }
        return MangaItem(
            id: entry.mangaID,
            sourceID: entry.sourceID,
            urlOrSlug: "",
            title: entry.mangaTitle,
            coverURL: entry.coverURL
        )
    }
    
    private func getChapter(for entry: MangaUpdateEntry) -> ChapterItem {
        if let found = DatabaseManager.shared.chaptersList.first(where: { $0.id == entry.chapterID }) {
            return found
        }
        return ChapterItem(
            id: entry.chapterID,
            mangaID: entry.mangaID,
            sourceChapterID: "\(entry.chapterNumber)",
            chapterNumber: entry.chapterNumber,
            title: entry.chapterTitle
        )
    }
}
