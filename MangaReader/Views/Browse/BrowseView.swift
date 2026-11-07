//
//  BrowseView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct BrowseView: View {
    @StateObject private var viewModel = BrowseViewModel()
    
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
