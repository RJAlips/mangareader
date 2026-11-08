//
//  DownloadsView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @ObservedObject private var appState = AppState.shared
    @State private var showInfoBanner: Bool = true
    @State private var concurrentDownloads: Int = 2
    @State private var isPaused: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // 1. Dismissible Info Banner
                    if showInfoBanner {
                        infoBanner
                    }
                    
                    // 2. Control Pills: Pause/Resume & Concurrency
                    controlPillsRow
                    
                    // 3. Recently Downloaded Navigation Card
                    NavigationLink(destination: DownloadedSeriesListView(viewModel: viewModel)) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.mangaGreen.opacity(0.18))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.mangaGreen)
                                    .font(.system(size: 16))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recently Downloaded")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                Text("Offline series & files (\(viewModel.storageUsage))")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.textTertiary)
                        }
                        .padding(12)
                        .background(Color.surfacePrimary)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 4. Active Queues or Kaomoji Empty State
                    if viewModel.mangaGroups.isEmpty {
                        kaomojiEmptyState
                            .padding(.top, 40)
                    } else {
                        queueSection
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 60)
            }
            .background(appState.currentBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Text("Downloads")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        Image(systemName: "icloud")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle("Wi-Fi Only", isOn: Binding(
                        get: { viewModel.wifiOnly },
                        set: { _ in viewModel.toggleWifiOnly() }
                    ))
                    .tint(.mangaAccent)
                    .labelsHidden()
                }
            }
        }
    }
    
    // MARK: - Info Banner
    
    private var infoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundColor(.mangaAccent)
                .font(.system(size: 16))
            
            Text("Downloads will pause when you leave the app or lock your device.")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .lineLimit(2)
            
            Spacer()
            
            Button {
                withAnimation(Theme.Animation.quick) {
                    showInfoBanner = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textTertiary)
                    .padding(4)
            }
        }
        .padding(10)
        .background(Color.surfacePrimary)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }
    
    // MARK: - Control Pills
    
    private var controlPillsRow: some View {
        HStack(spacing: 10) {
            // Resume / Pause Pill
            Button {
                isPaused.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    Text(isPaused ? "Resume" : "Pause")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.mangaAccentInk)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color.mangaAccent)
                .clipShape(Capsule())
            }
            
            // Concurrency Pill
            Menu {
                Button("1 Concurrent Download") { concurrentDownloads = 1 }
                Button("2 Concurrent Downloads") { concurrentDownloads = 2 }
                Button("3 Concurrent Downloads") { concurrentDownloads = 3 }
                Button("5 Concurrent Downloads") { concurrentDownloads = 5 }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                    Text("Concurrent: \(concurrentDownloads)")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            }
        }
    }
    
    // MARK: - Kaomoji Empty State
    
    private var kaomojiEmptyState: some View {
        VStack(spacing: 14) {
            Text("Σ(ಠ_ಠ)")
                .font(.system(size: 38, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
            Text("No Downloads")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text("Downloaded chapters and active queues will appear here grouped by title.")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Active Queues Section
    
    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Queued Series (\(viewModel.mangaGroups.count))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(viewModel.mangaGroups.enumerated()), id: \.element.id) { index, group in
                    NavigationLink(destination: MangaDownloadDetailView(manga: group.manga, viewModel: viewModel)) {
                        mangaTitleRow(group: group)
                    }
                    if index < viewModel.mangaGroups.count - 1 {
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 64)
                    }
                }
            }
            .background(Color.surfacePrimary)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        }
    }
    
    private func mangaTitleRow(group: MangaDownloadGroup) -> some View {
        HStack(spacing: 12) {
            AsyncMangaImage(
                url: group.manga.coverURL,
                contentMode: .fill,
                cornerRadius: 6
            )
            .frame(width: 44, height: 62)
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.manga.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text("\(group.downloadedCount) downloaded")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                    
                    if group.queueCount > 0 {
                        Text("\(group.queueCount) queued")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.mangaAccentInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.mangaAccent)
                            .clipShape(Capsule())
                    }
                }
                
                if let progress = group.activeProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .mangaAccent))
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Downloaded Series List View

public struct DownloadedSeriesListView: View {
    @ObservedObject public var viewModel: DownloadsViewModel
    @ObservedObject private var appState = AppState.shared
    
    public init(viewModel: DownloadsViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        List {
            ForEach(viewModel.mangaGroups) { group in
                NavigationLink(destination: MangaDownloadDetailView(manga: group.manga, viewModel: viewModel)) {
                    HStack(spacing: 12) {
                        AsyncMangaImage(url: group.manga.coverURL, contentMode: .fill, cornerRadius: 6)
                            .frame(width: 44, height: 62)
                            .clipped()
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.manga.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                            
                            if let author = group.manga.author {
                                Text(author)
                                    .font(.system(size: 11))
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Text("\(group.downloadedCount) chapters • \(group.manga.status.rawValue)")
                                .font(.system(size: 11))
                                .foregroundColor(.textTertiary)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .background(appState.currentBackground.ignoresSafeArea())
        .navigationTitle("Downloaded Series")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Level 2: Manga Download Detail

public struct MangaDownloadDetailView: View {
    public let manga: MangaItem
    @ObservedObject public var viewModel: DownloadsViewModel
    @State private var readingChapter: ChapterItem? = nil
    
    public init(manga: MangaItem, viewModel: DownloadsViewModel) {
        self.manga = manga
        self.viewModel = viewModel
    }
    
    public var body: some View {
        List {
            inProgressSection
            downloadedSection
            notDownloadedSection
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(manga.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $readingChapter) { ch in
            ReaderContainerView(manga: manga, chapter: ch, initialPage: ch.lastPageRead)
        }
    }
    
    // In Progress / Queued
    @ViewBuilder
    private var inProgressSection: some View {
        let inProgress = viewModel.inProgressTasks(for: manga.id)
        if !inProgress.isEmpty {
            Section("In Progress / Queued (\(inProgress.count))") {
                ForEach(inProgress) { task in
                    inProgressTaskRow(task: task)
                }
            }
        }
    }
    
    // Downloaded Chapters
    @ViewBuilder
    private var downloadedSection: some View {
        let downloaded = viewModel.downloadedChapters(for: manga.id)
        Section("Downloaded (\(downloaded.count))") {
            if downloaded.isEmpty {
                Text("No chapters downloaded for this title yet.")
                    .font(.captionMedium)
                    .foregroundColor(.textTertiary)
            } else {
                ForEach(downloaded) { chapter in
                    Button {
                        readingChapter = chapter
                    } label: {
                        downloadedChapterRow(chapter: chapter)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteChapter(chapter)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    // Not Downloaded
    @ViewBuilder
    private var notDownloadedSection: some View {
        let notDownloaded = viewModel.notDownloadedChapters(for: manga.id)
        if !notDownloaded.isEmpty {
            Section("Not Downloaded (\(notDownloaded.count))") {
                ForEach(notDownloaded) { chapter in
                    notDownloadedChapterRow(chapter: chapter)
                }
            }
        }
    }
    
    private func inProgressTaskRow(task: DownloadTaskItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.chapter.displayTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Button {
                    viewModel.cancel(task: task)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            ProgressView(value: task.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .mangaAccent))
        }
        .padding(.vertical, 4)
    }
    
    private func downloadedChapterRow(chapter: ChapterItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(chapter.displayTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                    Image(systemName: "book.circle.fill")
                        .font(.caption)
                        .foregroundColor(.mangaAccent)
                }
                
                Text(viewModel.chapterFileSize(chapter, sourceID: manga.sourceID))
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.mangaGreen)
                .font(.system(size: 16))
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
    
    private func notDownloadedChapterRow(chapter: ChapterItem) -> some View {
        HStack {
            Text(chapter.displayTitle)
                .font(.system(size: 14))
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Button {
                viewModel.downloadChapter(chapter, for: manga)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.mangaAccent)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
