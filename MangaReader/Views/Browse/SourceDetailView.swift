//
//  SourceDetailView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct SourceDetailView: View {
    public let source: any MangaSource
    @State private var items: [MangaItem] = []
    @State private var searchQuery: String = ""
    @State private var selectedTab: Int = 0 // 0 = Popular, 1 = Latest
    @State private var isLoading: Bool = false
    @State private var currentPage: Int = 1
    @State private var currentFetchTask: Task<Void, Never>? = nil
    
    private let columns = [
        GridItem(.adaptive(minimum: 105, maximum: 140), spacing: Theme.Spacing.md, alignment: .top)
    ]
    
    private var sourceBaseURL: URL? {
        if let community = source as? CommunityWebSource {
            return URL(string: community.baseURLString)
        }
        return URL(string: "https://api.mangadex.org")
    }
    
    private var sourceWebURL: URL? {
        if let community = source as? CommunityWebSource, let url = URL(string: community.baseURLString) {
            return url
        }
        if !source.manifest.baseURL.isEmpty, let url = URL(string: source.manifest.baseURL) {
            return url
        }
        return URL(string: "https://mangadex.org")
    }
    
    public init(source: any MangaSource) {
        self.source = source
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Input
            SearchBarView(text: $searchQuery, placeholder: "Search \(source.manifest.name)...")
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
                .onSubmit {
                    performSearch()
                }
            
            // Tab Picker
            Picker("Mode", selection: $selectedTab) {
                Text("Popular").tag(0)
                Text("Latest").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .onChange(of: selectedTab) {
                currentPage = 1
                loadData()
            }
            
            // Content
            if isLoading && items.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .mangaAccent))
                        .scaleEffect(1.3)
                    Text("Loading \(source.manifest.name)...")
                        .font(.captionMedium)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            } else if !isLoading && items.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 44))
                        .foregroundColor(.textTertiary)
                    
                    VStack(spacing: 4) {
                        Text("No Titles Available")
                            .font(.sectionTitle)
                            .foregroundColor(.textPrimary)
                        Text("Check your connection or open in browser.")
                            .font(.captionMedium)
                            .foregroundColor(.textSecondary)
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            loadData()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry")
                            }
                            .font(.bodyMedium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.mangaAccent)
                            .cornerRadius(Theme.CornerRadius.small)
                        }
                        
                        if let webURL = sourceWebURL {
                            Link(destination: webURL) {
                                HStack(spacing: 6) {
                                    Image(systemName: "safari")
                                    Text("Open in Web Browser")
                                }
                                .font(.bodyMedium)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Color.surfaceSecondary)
                                .cornerRadius(Theme.CornerRadius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                        ForEach(items) { manga in
                            NavigationLink(destination: MangaDetailView(manga: manga)) {
                                MangaCardView(
                                    manga: manga,
                                    baseURL: sourceBaseURL,
                                    showUnreadBadge: false
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(source.manifest.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let webURL = sourceWebURL {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: webURL) {
                        Image(systemName: "safari")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.mangaAccent)
                    }
                }
            }
        }
        .task {
            if items.isEmpty {
                loadData()
            }
        }
        .onDisappear {
            currentFetchTask?.cancel()
        }
    }
    
    @MainActor
    private func loadData() {
        currentFetchTask?.cancel()
        currentFetchTask = Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            
            do {
                let result: [MangaItem]
                if selectedTab == 0 {
                    result = try await source.fetchPopular(page: currentPage)
                } else {
                    result = try await source.fetchLatest(page: currentPage)
                }
                if !Task.isCancelled {
                    self.items = result
                }
            } catch {
                // Keep existing items if reload fails
            }
        }
    }
    
    @MainActor
    private func performSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            loadData()
            return
        }
        
        currentFetchTask?.cancel()
        currentFetchTask = Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            
            do {
                let results = try await source.search(query: trimmed, page: 1)
                if !Task.isCancelled {
                    self.items = results
                }
            } catch {
                // Keep existing or empty
            }
        }
    }
}
