//
//  MainTabView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public enum AppTab: Int, CaseIterable, Identifiable {
    case library = 0
    case updates = 1
    case browse = 2
    case history = 3
    case more = 4
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .library: return "Library"
        case .updates: return "Updates"
        case .browse: return "Browse"
        case .history: return "History"
        case .more: return "More"
        }
    }
    
    public var iconName: String {
        switch self {
        case .library: return "books.vertical.fill"
        case .updates: return "bolt.fill"
        case .browse: return "safari"
        case .history: return "clock.fill"
        case .more: return "gearshape.fill"
        }
    }
    
    public static func from(string: String) -> AppTab? {
        switch string.lowercased() {
        case "library", "0": return .library
        case "updates", "1": return .updates
        case "browse", "sources", "2": return .browse
        case "history", "3": return .history
        case "more", "settings", "4": return .more
        default: return nil
        }
    }
}

public struct MainTabView: View {
    @ObservedObject private var appState = AppState.shared
    @State private var selectedTab: AppTab = {
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-tab"),
           idx + 1 < ProcessInfo.processInfo.arguments.count {
            let tabName = ProcessInfo.processInfo.arguments[idx + 1]
            if let tab = AppTab.from(string: tabName) {
                return tab
            }
        }
        if let tabArg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--tab=") }) {
            let tabName = String(tabArg.dropFirst(6))
            if let tab = AppTab.from(string: tabName) {
                return tab
            }
        }
        return .library
    }()
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Tab Content
            Group {
                switch selectedTab {
                case .library:
                    LibraryView()
                case .updates:
                    HomeView()
                case .browse:
                    BrowseView()
                case .history:
                    HistoryView()
                case .more:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating Liquid Glass 5-Tab Bar
            floatingGlassTabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Floating Liquid Glass Tab Bar
    
    private var floatingGlassTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(Theme.Animation.quick) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .mangaAccent : .textSecondary)
                            
                            // Pending updates red dot badge on Browse
                            if tab == .browse && appState.pendingExtensionUpdatesCount > 0 {
                                Circle()
                                    .fill(Color.mangaRed)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -2)
                            }
                        }
                        .frame(height: 22)
                        
                        Text(tab.title)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .mangaAccent : .textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        isSelected ? Color.white.opacity(0.10) : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - History Screen

public struct HistoryView: View {
    @ObservedObject private var historyRepo = HistoryRepository.shared
    @ObservedObject private var appState = AppState.shared
    @State private var searchQuery: String = ""
    @State private var showSearchField: Bool = false
    @State private var showClearConfirm: Bool = false
    @State private var activeReadingManga: MangaItem? = nil
    @State private var activeReadingChapter: ChapterItem? = nil
    
    public init() {}
    
    private var filteredItems: [ReadingProgress] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return historyRepo.historyItems
        }
        return historyRepo.historyItems.filter {
            $0.displayMangaTitle.lowercased().contains(q) ||
            $0.displayChapterTitle.lowercased().contains(q)
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Collapsible Search
                if showSearchField {
                    SearchBarView(text: $searchQuery, placeholder: "Search reading history...")
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if filteredItems.isEmpty {
                    emptyHistoryView
                } else {
                    historyListView
                }
            }
            .background(appState.currentBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Left Title + Cloud Icon
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Text("History")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: true, vertical: false)
                        Image(systemName: "icloud")
                            .font(.system(size: 15))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
                
                // Right Glass Buttons
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Incognito Mode Toggle Button
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        historyRepo.isIncognitoMode.toggle()
                    } label: {
                        Image(systemName: "eyeglasses")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(historyRepo.isIncognitoMode ? .mangaAccent : Color(hex: "#A0A0AB"))
                    }
                    .glassCircle(size: 34)
                    
                    // Glass Capsule with Search and Trash
                    HStack(spacing: 12) {
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(Theme.Animation.quick) {
                                showSearchField.toggle()
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(showSearchField ? .mangaAccent : .white)
                        }
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 0.5, height: 14)
                        
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            showClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .glassCapsule(height: 34, cornerRadius: 17, horizontalPadding: 11)
                }
            }
            .alert("Clear Reading History?", isPresented: $showClearConfirm) {
                Button("Clear All", role: .destructive) {
                    historyRepo.clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all reading history records. Your library titles and downloaded chapters will be kept.")
            }
            .fullScreenCover(item: Binding(
                get: { activeReadingChapter },
                set: { activeReadingChapter = $0 }
            )) { ch in
                if let manga = activeReadingManga {
                    let page = historyRepo.readingProgress(for: manga.id)?.lastPageRead ?? ch.lastPageRead
                    ReaderContainerView(manga: manga, chapter: ch, initialPage: page)
                }
            }
        }
    }
    
    // MARK: - History List View
    
    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredItems) { item in
                    historyRow(item: item)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 80)
        }
    }
    
    private func historyRow(item: ReadingProgress) -> some View {
        let manga = getManga(for: item)
        let chapter = getChapter(for: item)
        
        return HStack(alignment: .center, spacing: 14) {
            // Left: AsyncMangaImage with exact dimensions (72pt width x 102pt height), cornerRadius: 8, contentMode: .fill, clipped
            NavigationLink(destination: MangaDetailView(manga: manga)) {
                AsyncMangaImage(
                    url: item.coverURL,
                    contentMode: .fill,
                    cornerRadius: 8,
                    showShimmer: false
                )
                .frame(width: 72, height: 102)
                .clipped()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Center VStack(alignment: .leading, spacing: 4)
            Button {
                activeReadingManga = manga
                activeReadingChapter = chapter
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayMangaTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(item.displayChapterTitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "#A0A0AB"))
                        .lineLimit(1)
                    
                    HStack(spacing: 5) {
                        Image(systemName: "book")
                            .font(.system(size: 12))
                        Text(item.formattedReadingTime)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(Color(hex: "#A0A0AB"))
                    .padding(.top, 1)
                    
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(relativeDateString(from: item.updatedAt))
                            .font(.system(size: 13))
                    }
                    .foregroundColor(Color(hex: "#A0A0AB"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Right: Single trash icon button (font size 17, Color(hex: "#A0A0AB"))
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation {
                    historyRepo.removeHistory(for: item.mangaID)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17))
                    .foregroundColor(Color(hex: "#A0A0AB"))
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private func getManga(for progress: ReadingProgress) -> MangaItem {
        if let found = DatabaseManager.shared.mangaList.first(where: { $0.id == progress.mangaID }) {
            return found
        }
        return MangaItem(
            id: progress.mangaID,
            sourceID: progress.sourceID ?? "",
            urlOrSlug: "",
            title: progress.displayMangaTitle,
            coverURL: progress.coverURL
        )
    }
    
    private func getChapter(for progress: ReadingProgress) -> ChapterItem {
        if let found = DatabaseManager.shared.chaptersList.first(where: { $0.id == progress.chapterID }) {
            var updated = found
            updated.lastPageRead = progress.lastPageRead
            return updated
        }
        return ChapterItem(
            id: progress.chapterID,
            mangaID: progress.mangaID,
            sourceChapterID: "\(progress.chapterNumber ?? 1.0)",
            chapterNumber: progress.chapterNumber ?? 1.0,
            title: progress.displayChapterTitle,
            pageCount: progress.totalPages,
            lastPageRead: progress.lastPageRead
        )
    }
    
    private func relativeDateString(from date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
            if days > 1 && days < 7 {
                return "\(days) days ago"
            } else {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                return formatter.localizedString(for: date, relativeTo: Date())
            }
        }
    }
    
    private func relativeTimeString(from date: Date) -> String {
        relativeDateString(from: date)
    }
    
    // MARK: - Empty State
    
    private var emptyHistoryView: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("(¯\\_(ツ)_/¯)")
                .font(.system(size: 38, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
            Text("No Reading History")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text("Titles you read will appear here with reading time and progress.")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}
