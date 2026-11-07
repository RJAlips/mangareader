//
//  SettingsView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                // Reader Settings Section
                Section("Reader Defaults") {
                    Picker("Default Reading Mode", selection: $viewModel.readerSettings.defaultReadingMode) {
                        ForEach(ReadingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: viewModel.readerSettings.defaultReadingMode) {
                        viewModel.updateSettings()
                    }
                    
                    Picker("Default Background", selection: $viewModel.readerSettings.backgroundColor) {
                        ForEach(ReaderBackgroundColor.allCases) { bg in
                            Text(bg.rawValue).tag(bg)
                        }
                    }
                    .onChange(of: viewModel.readerSettings.backgroundColor) {
                        viewModel.updateSettings()
                    }
                    
                    Toggle("Keep Screen Awake While Reading", isOn: $viewModel.readerSettings.keepScreenAwake)
                        .tint(.mangaAccent)
                        .onChange(of: viewModel.readerSettings.keepScreenAwake) {
                            viewModel.updateSettings()
                        }
                }
                
                // Integrations Section
                Section("Integrations") {
                    NavigationLink(destination: KomgaConfigView()) {
                        Label("Komga Media Server", systemImage: "server.rack")
                    }
                    
                    NavigationLink(destination: TrackingSettingsView()) {
                        Label("Tracking Services (AniList, MAL)", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                
                // Data & Storage Section
                Section("Data & Storage") {
                    NavigationLink(destination: BackupRestoreView(viewModel: viewModel)) {
                        Label("Backup and Restore", systemImage: "externaldrive.badge.icloud")
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Image Disk Cache")
                            Text(viewModel.cacheSizeFormatted)
                                .font(.captionMedium)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button("Clear Cache") {
                            viewModel.clearImageCache()
                        }
                        .foregroundColor(.mangaAccent)
                        .disabled(viewModel.isClearingCache)
                    }
                }
                
                // About Section
                Section("About MangaReader") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 2026.11)")
                            .foregroundColor(.textSecondary)
                    }
                    
                    HStack {
                        Text("Engine")
                        Spacer()
                        Text("SwiftUI + SwiftData Architecture")
                            .foregroundColor(.textSecondary)
                    }
                    
                    Text("Designed with Apple Human Interface Guidelines for iPhone and iPad. Supports continuous Webtoon reading, traditional Manga R-to-L, Komga, and local CBZ/EPUB archives.")
                        .font(.footnote)
                        .foregroundColor(.textTertiary)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
        }
    }
}
