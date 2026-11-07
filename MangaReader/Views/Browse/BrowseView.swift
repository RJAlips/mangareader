//
//  BrowseView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct BrowseView: View {
    @StateObject private var viewModel = BrowseViewModel()
    @State private var showRepositorySheet = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Input across all sources
                SearchBarView(
                    text: $viewModel.globalQuery,
                    placeholder: "Search across all sources..."
                )
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.sm)
                .onSubmit {
                    viewModel.performGlobalSearch()
                }
                
                if viewModel.isSearching {
                    Spacer()
                    ProgressView("Searching enabled sources...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .mangaAccent))
                        .foregroundColor(.textSecondary)
                    Spacer()
                } else if !viewModel.globalSearchResults.isEmpty {
                    globalSearchResultsView
                } else {
                    sourcesListView
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Browse Sources")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRepositorySheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Repositories")
                                .font(.captionMedium)
                        }
                        .foregroundColor(.mangaAccent)
                    }
                }
            }
            .sheet(isPresented: $showRepositorySheet) {
                RepositoryManagementSheet(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Sources List
    
    private var sourcesListView: some View {
        List {
            Section("Available Sources") {
                ForEach(viewModel.sources, id: \.manifest.id) { source in
                    sourceRow(source: source)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func sourceRow(source: any MangaSource) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            AsyncMangaImage(
                url: source.manifest.iconURL,
                contentMode: .fit,
                cornerRadius: Theme.CornerRadius.small
            )
            .frame(width: 42, height: 42)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(source.manifest.name)
                        .font(.bodyEmphasized)
                        .foregroundColor(.textPrimary)
                    
                    BadgeView(text: source.manifest.lang, backgroundColor: .surfaceSecondary)
                }
                
                if let desc = source.manifest.sourceDescription {
                    Text(desc)
                        .font(.cardSubtitle)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { viewModel.isSourceEnabled(source.manifest.id) },
                set: { _ in viewModel.toggleSource(source.manifest.id) }
            ))
            .labelsHidden()
            .tint(.mangaAccent)
            
            NavigationLink(destination: SourceDetailView(source: source)) {
                EmptyView()
            }
            .frame(width: 0)
            .opacity(0)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Global Search Results
    
    private var globalSearchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ForEach(Array(viewModel.globalSearchResults.keys.sorted()), id: \.self) { sourceName in
                    if let results = viewModel.globalSearchResults[sourceName], !results.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(sourceName)
                                .font(.sectionTitle)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, Theme.Spacing.lg)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.md) {
                                    ForEach(results) { manga in
                                        NavigationLink(destination: MangaDetailView(manga: manga)) {
                                            MangaCardView(manga: manga, showUnreadBadge: false)
                                                .frame(width: 130)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.lg)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.md)
        }
    }
}

// MARK: - Repository Management Sheet

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
            Form {
                // Add Custom Repository
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter a JSON extension repository or manga feed URL to dynamically add online sources to MangaReader.")
                            .font(.captionMedium)
                            .foregroundColor(.textSecondary)
                        
                        TextField("https://example.com/repo.json", text: $repoURLInput)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        
                        Button {
                            addRepository()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                }
                                Text("Add Repository")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mangaAccent)
                        .disabled(repoURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        
                        if let msg = statusMessage {
                            Text(msg)
                                .font(.captionMedium)
                                .foregroundColor(isSuccess ? .mangaGreen : .mangaAccent)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Add Custom Repository")
                }
                
                // Community Presets (1-Tap Add)
                Section("Popular Community Presets") {
                    presetRow(
                        name: "Official MangaDex",
                        url: "https://api.mangadex.org",
                        desc: "Enable official MangaDex REST API v5 provider"
                    )
                    presetRow(
                        name: "Aidoku Community Sources",
                        url: "https://aidoku-community.github.io/sources/index.min.json",
                        desc: "Standard community index with 100+ sources"
                    )
                    presetRow(
                        name: "Open Community Manga Index",
                        url: "https://raw.githubusercontent.com/RJAlips/mangareader/main/community_repo.json",
                        desc: "Curated community manga feeds"
                    )
                }
                
                // Active Repositories
                Section("Installed Repositories (\(viewModel.repositories.count))") {
                    if viewModel.repositories.isEmpty {
                        Text("No repositories added yet.")
                            .foregroundColor(.textTertiary)
                    } else {
                        ForEach(viewModel.repositories) { repo in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(repo.name)
                                        .font(.bodyEmphasized)
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                    BadgeView(text: "\(repo.sourceCount) sources", backgroundColor: .surfaceSecondary)
                                }
                                Text(repo.url)
                                    .font(.captionMedium)
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let repo = viewModel.repositories[index]
                                viewModel.removeRepository(url: repo.url)
                            }
                        }
                    }
                }
            }
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
    
    private func presetRow(name: String, url: String, desc: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)
                Text(desc)
                    .font(.captionMedium)
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Button("Add") {
                repoURLInput = url
                addRepository()
            }
            .buttonStyle(.bordered)
            .tint(.mangaAccent)
            .font(.captionMedium)
            .disabled(isLoading)
        }
        .padding(.vertical, 2)
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
                self.isLoading = false
                self.isSuccess = true
                self.statusMessage = "Successfully added! \(count) source(s) available in Browse."
                self.repoURLInput = ""
            } catch {
                self.isLoading = false
                self.isSuccess = false
                self.statusMessage = "Failed: \(error.localizedDescription)"
            }
        }
    }
}
