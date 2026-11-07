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
                
                // Active Tasks
                if !viewModel.activeTasks.isEmpty {
                    Section("Active Downloads") {
                        ForEach(viewModel.activeTasks) { task in
                            downloadTaskRow(task: task)
                        }
                    }
                }
                
                // Queued Tasks
                if !viewModel.queuedTasks.isEmpty {
                    Section("Queued (\(viewModel.queuedTasks.count))") {
                        ForEach(viewModel.queuedTasks) { task in
                            downloadTaskRow(task: task)
                        }
                    }
                }
                
                // Completed Tasks
                if !viewModel.completedTasks.isEmpty {
                    Section {
                        ForEach(viewModel.completedTasks) { task in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.manga.title)
                                        .font(.bodyMedium)
                                        .foregroundColor(.textPrimary)
                                    Text(task.chapter.displayTitle)
                                        .font(.captionMedium)
                                        .foregroundColor(.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.mangaGreen)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Completed (\(viewModel.completedTasks.count))")
                            Spacer()
                            Button("Clear All") {
                                viewModel.clearCompleted()
                            }
                            .font(.captionMedium)
                            .foregroundColor(.mangaAccent)
                        }
                    }
                }
                
                // Empty state
                if viewModel.activeTasks.isEmpty && viewModel.queuedTasks.isEmpty && viewModel.completedTasks.isEmpty {
                    Section {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.textTertiary)
                            Text("No Download Tasks")
                                .font(.sectionTitle)
                                .foregroundColor(.textPrimary)
                            Text("Downloaded chapters will be available here for completely offline reading.")
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
    
    private func downloadTaskRow(task: DownloadTaskItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.manga.title)
                        .font(.bodyEmphasized)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text(task.chapter.displayTitle)
                        .font(.captionMedium)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Text(task.status.displayText)
                    .font(.captionMedium)
                    .foregroundColor(.mangaAccent)
                
                Button {
                    viewModel.cancel(task: task)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textTertiary)
                }
            }
            
            ProgressView(value: task.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .mangaAccent))
        }
        .padding(.vertical, 4)
    }
}
