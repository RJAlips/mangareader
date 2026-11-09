//
//  BrowseView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import UIKit

public enum BrowseSegment: String, CaseIterable, Identifiable {
    case sources = "Sources"
    case extensions = "Extensions"
    case migrate = "Migrate"
    
    public var id: String { rawValue }
}

public struct BrowseView: View {
    @StateObject private var viewModel = BrowseViewModel()
    @ObservedObject private var appState = AppState.shared
    @State private var selectedSegment: BrowseSegment = .sources
    @State private var showRepositorySheet = false
    @State private var showSearchField = false
    @State private var pinnedSourceIDs: Set<String> = ["com.mangareader.source.asurascans"]
    @State private var updatingExtensionIDs: Set<String> = []
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Collapsible Search Bar
                if showSearchField || !viewModel.globalQuery.isEmpty {
                    SearchBarView(
                        text: $viewModel.globalQuery,
                        placeholder: "Search across enabled sources..."
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .onSubmit {
                        viewModel.performGlobalSearch()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 3-Segment Capsule Picker
                segmentPickerBar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                
                // Segment Body
                Group {
                    if !viewModel.globalQuery.isEmpty {
                        globalSearchResultsView
                    } else {
                        switch selectedSegment {
                        case .sources:
                            sourcesSegmentView
                        case .extensions:
                            extensionsSegmentView
                        case .migrate:
                            migrateSegmentView
                        }
                    }
                }
            }
            .background(appState.currentBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Left Title + Cloud Sync Icon
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Text("Browse")
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
                        
                        Button {
                            showRepositorySheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.textPrimary)
                        }
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 0.5, height: 14)
                        
                        Menu {
                            Button("Filter: All Languages") {}
                            Button("Filter: English Only") {}
                            Button("Filter: Arabic Only") {}
                        } label: {
                            Image(systemName: "globe")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.textPrimary)
                        }
                    }
                    .glassCapsule(height: 34, cornerRadius: 17, horizontalPadding: 11)
                }
            }
            .sheet(isPresented: $showRepositorySheet) {
                RepositoryManagementSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.refreshSourcesFromRepos(force: false)
            }
        }
    }
    
    // MARK: - 3-Segment Capsule Picker
    
    private var segmentPickerBar: some View {
        HStack(spacing: 0) {
            ForEach(BrowseSegment.allCases) { seg in
                let isSelected = selectedSegment == seg
                Button {
                    withAnimation(Theme.Animation.quick) {
                        selectedSegment = seg
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(seg.rawValue)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .textPrimary : .textSecondary)
                        
                        if seg == .extensions && !viewModel.pendingUpdates.isEmpty {
                            Text("\(viewModel.pendingUpdates.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.mangaRed)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        isSelected ? Color.white.opacity(0.12) : Color.clear
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .padding(3)
        .background(Color.surfacePrimary)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    // MARK: - Sources Segment
    
    private var sourcesSegmentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Pinned Sources
                let pinned = viewModel.sources.filter { pinnedSourceIDs.contains($0.manifest.id) }
                if !pinned.isEmpty {
                    sourceSection(title: "Pinned", sources: pinned)
                }
                
                // Last Used Sources
                let lastUsed = viewModel.sources.filter { !pinnedSourceIDs.contains($0.manifest.id) }.prefix(2)
                if !lastUsed.isEmpty {
                    sourceSection(title: "Last used", sources: Array(lastUsed))
                }
                
                // English Sources
                let english = viewModel.sources.filter { $0.manifest.lang.uppercased().contains("EN") }
                if !english.isEmpty {
                    sourceSection(title: "English", sources: english)
                }
                
                // Other / Multi Sources
                let others = viewModel.sources.filter { !$0.manifest.lang.uppercased().contains("EN") }
                if !others.isEmpty {
                    sourceSection(title: "Other Languages", sources: others)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 80)
        }
        .refreshable {
            await viewModel.refreshSourcesFromRepos(force: true)
        }
    }
    
    private func sourceSection(title: String, sources: [any MangaSource]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(sources.enumerated()), id: \.element.manifest.id) { index, src in
                    sourceRow(source: src)
                    if index < sources.count - 1 {
                        Divider().background(Color.white.opacity(0.06))
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color.surfacePrimary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }
    
    private func sourceRow(source: any MangaSource) -> some View {
        NavigationLink(destination: SourceDetailView(source: source)) {
            HStack(spacing: 12) {
                // Source Icon
                AsyncMangaImage(
                    url: source.manifest.iconURL,
                    contentMode: .fit,
                    cornerRadius: 8
                )
                .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.manifest.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Text(source.manifest.lang.uppercased())
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                // Action Buttons: Pin, Chevron
                HStack(spacing: 14) {
                    Button {
                        if pinnedSourceIDs.contains(source.manifest.id) {
                            pinnedSourceIDs.remove(source.manifest.id)
                        } else {
                            pinnedSourceIDs.insert(source.manifest.id)
                        }
                    } label: {
                        Image(systemName: pinnedSourceIDs.contains(source.manifest.id) ? "pin.fill" : "pin")
                            .font(.system(size: 13))
                            .foregroundColor(pinnedSourceIDs.contains(source.manifest.id) ? .mangaAccent : .textTertiary)
                    }
                    .buttonStyle(.borderless)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Extensions Segment
    
    private var extensionsSegmentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Updates Pending Section
                if !viewModel.pendingUpdates.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Updates pending (\(viewModel.pendingUpdates.count))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.textSecondary)
                            Spacer()
                            Button("Update All") {
                                Task {
                                    await viewModel.updateAllSources()
                                }
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.mangaAccent)
                        }
                        .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.pendingUpdates.enumerated()), id: \.element.id) { index, manifest in
                                pendingExtensionRow(manifest: manifest)
                                if index < viewModel.pendingUpdates.count - 1 {
                                    Divider().background(Color.white.opacity(0.06))
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .background(Color.surfacePrimary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                }
                
                // Installed Extensions Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Installed (\(viewModel.sources.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.sources.enumerated()), id: \.element.manifest.id) { index, src in
                            installedExtensionRow(source: src)
                            if index < viewModel.sources.count - 1 {
                                Divider().background(Color.white.opacity(0.06))
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color.surfacePrimary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                }
                
                // Available Extensions Section (From External Repos)
                if !viewModel.availableManifests.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available (\(viewModel.availableManifests.count))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.availableManifests.prefix(40).enumerated()), id: \.element.id) { index, manifest in
                                availableExtensionRow(manifest: manifest)
                                if index < min(40, viewModel.availableManifests.count) - 1 {
                                    Divider().background(Color.white.opacity(0.06))
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .background(Color.surfacePrimary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 80)
        }
        .refreshable {
            await viewModel.refreshSourcesFromRepos(force: true)
        }
    }
    
    private func pendingExtensionRow(manifest: SourceManifest) -> some View {
        HStack(spacing: 12) {
            AsyncMangaImage(url: manifest.iconURL, contentMode: .fit, cornerRadius: 8)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(manifest.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("\(manifest.lang.uppercased()) • v\(manifest.version)")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            if updatingExtensionIDs.contains(manifest.id) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .mangaAccent))
                    .scaleEffect(0.8)
            } else {
                Button {
                    updatingExtensionIDs.insert(manifest.id)
                    viewModel.updateSource(manifest)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        updatingExtensionIDs.remove(manifest.id)
                    }
                } label: {
                    Text("Update")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.mangaAccentInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.mangaAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func installedExtensionRow(source: any MangaSource) -> some View {
        HStack(spacing: 12) {
            AsyncMangaImage(url: source.manifest.iconURL, contentMode: .fit, cornerRadius: 8)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(source.manifest.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("\(source.manifest.lang.uppercased()) • v\(source.manifest.version)")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            NavigationLink(destination: SourceDetailView(source: source)) {
                Text("Browse")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func availableExtensionRow(manifest: SourceManifest) -> some View {
        HStack(spacing: 12) {
            AsyncMangaImage(url: manifest.iconURL, contentMode: .fit, cornerRadius: 8)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(manifest.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("\(manifest.lang.uppercased()) • v\(manifest.version)")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            Button {
                viewModel.installSource(manifest)
            } label: {
                Text("+ Install")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.mangaAccentInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.mangaAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Migrate Segment
    
    private var migrateSegmentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Select a source to migrate titles from:")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 4)
                
                VStack(spacing: 0) {
                    ForEach(viewModel.sources, id: \.manifest.id) { src in
                        NavigationLink(destination: SourceDetailView(source: src)) {
                            HStack(spacing: 12) {
                                AsyncMangaImage(url: src.manifest.iconURL, contentMode: .fit, cornerRadius: 8)
                                    .frame(width: 36, height: 36)
                                
                                Text(src.manifest.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.textPrimary)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.mangaAccent)
                                    .font(.system(size: 16))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.surfacePrimary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 80)
        }
    }
    
    // MARK: - Global Search Results
    
    private var globalSearchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ForEach(Array(viewModel.globalSearchResults.keys.sorted()), id: \.self) { sourceName in
                    if let results = viewModel.globalSearchResults[sourceName], !results.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(sourceName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 12)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(results) { manga in
                                        NavigationLink(destination: MangaDetailView(manga: manga)) {
                                            MangaCardView(manga: manga, showUnreadBadge: false)
                                                .frame(width: 120)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.bottom, 80)
        }
    }
}

// MARK: - Extension Repository Management Sheet

public struct RepositoryManagementSheet: View {
    @ObservedObject public var viewModel: BrowseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var repoURLInput: String = ""
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isSuccess: Bool = false
    
    public init(viewModel: BrowseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Custom URL Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add Custom Repository")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text("Enter an extension index JSON, repository URL, or MangaDex endpoint.")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                        
                        TextField("https://example.com/index.min.json", text: $repoURLInput)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                        
                        Button {
                            addRepository()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .mangaAccentInk))
                                        .scaleEffect(0.8)
                                }
                                Text("Add Repository")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.mangaAccentInk)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.mangaAccent)
                            .clipShape(Capsule())
                        }
                        .disabled(repoURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        
                        if let msg = statusMessage {
                            Text(msg)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isSuccess ? .mangaGreen : .mangaRed)
                        }
                    }
                    .padding(14)
                    .background(Color.surfacePrimary)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                    
                    // Popular Community Presets
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Popular Curated Repositories")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary)
                        
                        presetCard(
                            name: "Official MangaDex Mirror",
                            url: "https://api.mangadex.org",
                            desc: "Official MangaDex REST API v5 endpoint",
                            chips: ["MangaDex", "Official", "Multi-lang"]
                        )
                        
                        presetCard(
                            name: "Open Community Manga Index",
                            url: "https://raw.githubusercontent.com/RJAlips/mangareader/main/community_repo.json",
                            desc: "Curated manhwa & webtoons (Asura, Aqua, Armageddon)",
                            chips: ["Community", "Curated"]
                        )
                        
                        presetCard(
                            name: "Aidoku Community Sources",
                            url: "https://aidoku-community.github.io/sources/index.min.json",
                            desc: "Fast, sandboxed community sources with icons",
                            chips: ["Aidoku", "Multi", "Fast"]
                        )
                        
                        presetCard(
                            name: "Keiyoushi Tachiyomi Extensions",
                            url: "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json",
                            desc: "Largest community repository with 1,000+ sources",
                            chips: ["Keiyoushi", "Discord", "Tachiyomi"]
                        )
                    }
                    
                    // Installed Repositories List
                    if !viewModel.repositories.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Installed Repositories (\(viewModel.repositories.count))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textSecondary)
                            
                            VStack(spacing: 0) {
                                ForEach(viewModel.repositories) { repo in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(repo.name)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.textPrimary)
                                            Text(repo.url)
                                                .font(.system(size: 10))
                                                .foregroundColor(.textSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text("\(repo.sourceCount) src")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.textTertiary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.06))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                            }
                            .background(Color.surfacePrimary)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Extension Repositories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.mangaAccent)
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func presetCard(name: String, url: String, desc: String, chips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Button {
                    repoURLInput = url
                    addRepository()
                } label: {
                    Text("+ Add")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.mangaAccentInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.mangaAccent)
                        .clipShape(Capsule())
                }
                .disabled(isLoading)
            }
            
            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
            
            HStack(spacing: 6) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = url
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.mangaAccent)
                }
            }
        }
        .padding(12)
        .background(Color.surfacePrimary)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
    
    private func addRepository() {
        let target = repoURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        
        isLoading = true
        statusMessage = "Connecting to repository..."
        isSuccess = false
        
        Task {
            do {
                let count = try await viewModel.addRepository(url: target)
                await viewModel.refreshSourcesFromRepos(force: true)
                self.isLoading = false
                self.isSuccess = true
                self.statusMessage = "Successfully added \(count) source(s)!"
                self.repoURLInput = ""
            } catch {
                self.isLoading = false
                self.isSuccess = false
                self.statusMessage = "Failed: \(error.localizedDescription)"
            }
        }
    }
}
