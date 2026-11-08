//
//  SettingsView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var appState = AppState.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // Section 1: Core Preferences
                Section {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        moreRow(icon: "paintbrush.fill", color: .mangaAccent, title: "Appearance", subtitle: "\(appState.themePalette.capitalized) • \(appState.itemsPerRow) per row")
                    }
                    
                    NavigationLink(destination: ReaderSettingsView(viewModel: viewModel)) {
                        moreRow(icon: "book.fill", color: .mangaBlue, title: "Reader", subtitle: viewModel.readerSettings.defaultReadingMode.rawValue)
                    }
                    
                    NavigationLink(destination: SecuritySettingsView()) {
                        moreRow(icon: "lock.shield.fill", color: .mangaGreen, title: "Security", subtitle: appState.incognitoMode ? "Incognito Active" : "Protected")
                    }
                    
                    NavigationLink(destination: DownloadsView()) {
                        moreRow(icon: "arrow.down.circle.fill", color: .mangaAmber, title: "Downloads", subtitle: viewModel.cacheSizeFormatted)
                    }
                }
                
                // Section 2: Integrations & Sync
                Section("Sync & Integrations") {
                    NavigationLink(destination: TrackingSettingsView()) {
                        moreRow(icon: "arrow.triangle.2.circlepath", color: .mangaPurple, title: "Tracking", subtitle: "AniList, MyAnimeList")
                    }
                    
                    NavigationLink(destination: KomgaConfigView()) {
                        moreRow(icon: "server.rack", color: .mangaBlue, title: "Komga Server", subtitle: "Self-hosted library")
                    }
                    
                    NavigationLink(destination: BackupRestoreView(viewModel: viewModel)) {
                        moreRow(icon: "externaldrive.badge.icloud", color: .mangaAccent, title: "Backup & Restore", subtitle: "JSON data archives")
                    }
                    
                    NavigationLink(destination: ReadingInsightsView()) {
                        moreRow(icon: "chart.bar.fill", color: .mangaGreen, title: "Reading Insights", subtitle: "History & Statistics")
                    }
                }
                
                // Section 3: Information & Support
                Section("Information") {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.textSecondary)
                            .font(.system(size: 18))
                            .frame(width: 26)
                        
                        Text("Version")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text("1.0.0 (Build 2026.11)")
                            .font(.system(size: 13))
                            .foregroundColor(.textTertiary)
                    }
                    
                    Button {
                        if let url = URL(string: "https://github.com/RJAlips/mangareader") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        moreRow(icon: "link", color: .textSecondary, title: "GitHub Repository", subtitle: "Open source project")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .background(appState.currentBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Text("More")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        Image(systemName: "icloud")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
    }
    
    private func moreRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Appearance Settings Sub-Screen

public struct AppearanceSettingsView: View {
    @ObservedObject private var appState = AppState.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            // Theme Cards
            Section("Color Palette") {
                HStack(spacing: 12) {
                    themeCard(title: "Default", color: Color(hex: 0x9BB1FF), key: "periwinkle")
                    themeCard(title: "Green Apple", color: Color(hex: 0x34D399), key: "greenApple")
                    themeCard(title: "Lavender", color: Color(hex: 0xC084FC), key: "lavender")
                }
                .padding(.vertical, 4)
            }
            
            // Display Tweaks
            Section("Interface & Dark Mode") {
                Toggle("Liquid Glass Material", isOn: $appState.liquidGlassEnabled)
                    .tint(.mangaAccent)
                
                Toggle("Pure Black Dark Mode", isOn: $appState.pureBlackDarkMode)
                    .tint(.mangaAccent)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Color Blend Level")
                        Spacer()
                        Text(String(format: "%.0f%%", appState.colorBlendLevel * 100))
                            .foregroundColor(.textSecondary)
                    }
                    Slider(value: $appState.colorBlendLevel, in: 0...1.0)
                        .tint(.mangaAccent)
                }
            }
            
            // Grid Columns Stepper
            Section("Library Grid Layout") {
                Stepper(value: $appState.itemsPerRow, in: 2...5) {
                    HStack {
                        Text("Items Per Row")
                        Spacer()
                        Text("\(appState.itemsPerRow)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.mangaAccent)
                    }
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func themeCard(title: String, color: Color, key: String) -> some View {
        let isSelected = appState.themePalette == key
        return Button {
            appState.themePalette = key
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: isSelected ? 2.5 : 0)
                    )
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .textPrimary : .textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Security Settings Sub-Screen

public struct SecuritySettingsView: View {
    @ObservedObject private var appState = AppState.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section("Authentication") {
                Toggle("Require Face ID / Passcode", isOn: $appState.requireUnlock)
                    .tint(.mangaAccent)
            }
            
            Section("Privacy & Reading") {
                Toggle("Incognito Mode", isOn: $appState.incognitoMode)
                    .tint(.mangaAccent)
                
                Text("When active, newly read chapters will not be added to your reading history.")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
            
            Section("System Protection") {
                Toggle("Secure Screen (Hide App Preview)", isOn: $appState.secureScreen)
                    .tint(.mangaAccent)
                
                Toggle("Disable Content Sharing", isOn: $appState.disableContentSharing)
                    .tint(.mangaAccent)
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reader Settings Sub-Screen

public struct ReaderSettingsView: View {
    @ObservedObject public var viewModel: SettingsViewModel
    
    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Form {
            Section("Reading Experience") {
                Picker("Default Reading Mode", selection: $viewModel.readerSettings.defaultReadingMode) {
                    ForEach(ReadingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .onChange(of: viewModel.readerSettings.defaultReadingMode) {
                    viewModel.updateSettings()
                }
                
                Picker("Background Tone", selection: $viewModel.readerSettings.backgroundColor) {
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
            
            Section("Preloading") {
                Stepper(value: $viewModel.readerSettings.preloadPagesAhead, in: 1...10) {
                    HStack {
                        Text("Preload Pages Ahead")
                        Spacer()
                        Text("\(viewModel.readerSettings.preloadPagesAhead)")
                            .foregroundColor(.mangaAccent)
                    }
                }
                .onChange(of: viewModel.readerSettings.preloadPagesAhead) {
                    viewModel.updateSettings()
                }
            }
        }
        .navigationTitle("Reader Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reading Insights Sub-Screen

public struct ReadingInsightsView: View {
    @ObservedObject private var historyRepo = HistoryRepository.shared
    @ObservedObject private var db = DatabaseManager.shared
    
    public init() {}
    
    public var body: some View {
        List {
            Section("Overview") {
                HStack {
                    Text("Total Titles in History")
                    Spacer()
                    Text("\(historyRepo.continueReadingItems.count)")
                        .foregroundColor(.mangaAccent)
                        .fontWeight(.bold)
                }
                HStack {
                    Text("Total Library Titles")
                    Spacer()
                    Text("\(db.mangaList.filter { $0.inLibrary }.count)")
                        .foregroundColor(.textSecondary)
                }
                HStack {
                    Text("Read Chapters")
                    Spacer()
                    Text("\(db.chaptersList.filter { $0.isRead }.count)")
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .navigationTitle("Reading Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}
