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
    
    private let columns = [
        GridItem(.adaptive(minimum: 105, maximum: 140), spacing: Theme.Spacing.md, alignment: .top)
    ]
    
    private var sourceBaseURL: URL? {
        if let community = source as? CommunityWebSource {
            return URL(string: community.baseURLString)
        }
        return URL(string: "https://api.mangadex.org")
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
                    Task { await performSearch() }
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
                Task {
                    await loadData()
                }
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
                VStack(spacing: 14) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 44))
                        .foregroundColor(.textTertiary)
                    Text("No Titles Available")
                        .font(.sectionTitle)
                        .foregroundColor(.textPrimary)
                    Text("Check your connection or try another source.")
                        .font(.captionMedium)
                        .foregroundColor(.textSecondary)
                    Button {
                        Task { await loadData() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.bodyMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.mangaAccent)
                        .cornerRadius(Theme.CornerRadius.small)
                    }
                }
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
        .task {
            if items.isEmpty {
                await loadData()
            }
        }
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        do {
            let result: [MangaItem]
            if selectedTab == 0 {
                result = try await source.fetchPopular(page: currentPage)
            } else {
                result = try await source.fetchLatest(page: currentPage)
            }
            self.items = result
        } catch {
            // Keep existing items if reload fails
        }
        self.isLoading = false
    }
    
    @MainActor
    private func performSearch() async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await loadData()
            return
        }
        isLoading = true
        do {
            let results = try await source.search(query: trimmed, page: 1)
            self.items = results
        } catch {
            // Error handling
        }
        self.isLoading = false
    }
}
