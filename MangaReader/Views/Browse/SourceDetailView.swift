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
            
            // Grid Content
            if isLoading && items.isEmpty {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .mangaAccent))
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                        ForEach(items) { manga in
                            NavigationLink(destination: MangaDetailView(manga: manga)) {
                                MangaCardView(manga: manga, showUnreadBadge: false)
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
        .onAppear {
            if items.isEmpty {
                loadData()
            }
        }
    }
    
    private func loadData() {
        isLoading = true
        Task {
            do {
                let result: [MangaItem]
                if selectedTab == 0 {
                    result = try await source.fetchPopular(page: currentPage)
                } else {
                    result = try await source.fetchLatest(page: currentPage)
                }
                self.items = result
                self.isLoading = false
            } catch {
                self.isLoading = false
            }
        }
    }
    
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            loadData()
            return
        }
        isLoading = true
        Task {
            do {
                let results = try await source.search(query: searchQuery, page: 1)
                self.items = results
                self.isLoading = false
            } catch {
                self.isLoading = false
            }
        }
    }
}
