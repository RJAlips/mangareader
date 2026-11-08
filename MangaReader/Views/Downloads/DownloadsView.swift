//
//  DownloadsView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Storage & Network Settings Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Offline Storage")
                                .font(.captionMedium)
                                .foregroundColor(.textSecondary)
                            Text(viewModel.storageUsage)
                                .font(.title3.bold())
                                .foregroundColor(.textPrimary)
                        }
                        
                        Spacer()
                        
                        Toggle("Wi-Fi Only", isOn: Binding(
                            get: { viewModel.wifiOnly },
                            set: { _ in viewModel.toggleWifiOnly() }
                        ))
                        .tint(.mangaAccent)
                    }
                    .padding(.vertical, 4)
                }
                
                // Level 1: Manga Title Rows
                if !viewModel.mangaGroups.isEmpty {
                    Section("Downloaded Series (\(viewModel.mangaGroups.count))") {
                        ForEach(viewModel.mangaGroups) { group in
                            NavigationLink(destination: MangaDownloadDetailView(manga: group.manga, viewModel: viewModel)) {
                                mangaTitleRow(group: group)
                            }
                        }
                    }
                } else {
                    Section {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 42))
                                .foregroundColor(.textTertiary)
                            Text("No Downloaded Series")
                                .font(.sectionTitle)
                                .foregroundColor(.textPrimary)
                            Text("Downloaded chapters and active queues will appear here grouped by title.")
                                .font(.bodyRegular)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xl)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Downloads")
        }
    }
    
    // Level 1: Manga Title Row
    private func mangaTitleRow(group: MangaDownloadGroup) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            AsyncMangaImage(
                url: group.manga.coverURL,
                contentMode: .fill,
                cornerRadius: Theme.CornerRadius.small
            )
            .frame(width: 48, height: 68)
            .clipped()
            
            VStack(alignment: .leading, spacing: 5) {
                Text(group.manga.title)
                    .font(.bodyEmphasized)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(group.downloadedCount) downloaded")
                        .font(.captionMedium)
                        .foregroundColor(.textSecondary)
                    
                    if group.queueCount > 0 {
                        BadgeView(
                            text: "\(group.queueCount) in queue",
                            backgroundColor: Color.mangaAccent.opacity(0.18)
                        )
                    }
                }
                
                if let progress = group.activeProgress {
                    VStack(alignment: .leading, spacing: 2) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .mangaAccent))
                        Text(String(format: "Downloading %.0f%%", progress * 100))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.mangaAccent)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
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
            ReaderContainerView(manga: manga, chapter: ch)
        }
    }
    
    // MARK: - Section 1: In Progress / Queued
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
    
    // MARK: - Section 2: Downloaded Chapters
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
    
    // MARK: - Section 3: Not Downloaded
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
    
    // In Progress / Queued Row
    private func inProgressTaskRow(task: DownloadTaskItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.chapter.displayTitle)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                // Pause / Resume
                if case .downloading = task.status {
                    Button {
                        viewModel.pause(task: task)
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.mangaAccent)
                    }
                    .buttonStyle(.plain)
                } else if case .paused = task.status {
                    Button {
                        viewModel.resume(task: task)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.mangaGreen)
                    }
                    .buttonStyle(.plain)
                }
                
                // Cancel
                Button {
                    viewModel.cancel(task: task)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
            
            HStack(spacing: 8) {
                ProgressView(value: task.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .mangaAccent))
                
                Text(task.status.displayText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // Downloaded Row
    private func downloadedChapterRow(chapter: ChapterItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(chapter.displayTitle)
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                    Image(systemName: "book.circle.fill")
                        .font(.caption)
                        .foregroundColor(.mangaAccent)
                }
                
                Text(viewModel.chapterFileSize(chapter, sourceID: manga.sourceID))
                    .font(.captionMedium)
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
    
    // Not Downloaded Row
    private func notDownloadedChapterRow(chapter: ChapterItem) -> some View {
        HStack {
            Text(chapter.displayTitle)
                .font(.bodyMedium)
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
