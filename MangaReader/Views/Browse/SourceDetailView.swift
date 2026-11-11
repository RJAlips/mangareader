//
//  SourceDetailView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import WebKit

public struct SourceDetailView: View {
    public let source: any MangaSource
    @State private var items: [MangaItem] = []
    @State private var searchQuery: String = ""
    @State private var selectedTab: Int = 0 // 0 = Popular, 1 = Latest
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var currentPage: Int = 1
    @State private var hasMorePages: Bool = true
    @State private var showCloudflareBanner: Bool = false
    @State private var showCloudflareSheet: Bool = false
    @State private var currentFetchTask: Task<Void, Never>? = nil
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    
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
                    searchDebounceTask?.cancel()
                    performSearch(reset: true)
                }
                .onChange(of: searchQuery) { _, newValue in
                    scheduleDebouncedSearch(newValue)
                }
            
            // Tab Picker (hidden or disabled if actively searching)
            if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Picker("Mode", selection: $selectedTab) {
                    Text("Popular").tag(0)
                    Text("Latest").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .onChange(of: selectedTab) { _, _ in
                    currentFetchTask?.cancel()
                    items = []
                    currentPage = 1
                    hasMorePages = true
                    loadData()
                }
            }
            
            // Cloudflare Verification Warning Banner
            if showCloudflareBanner {
                HStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(.mangaAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Site requires Cloudflare verification")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Complete verification once in Web View to load titles.")
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Button {
                        showCloudflareSheet = true
                    } label: {
                        Text("Open Web View")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.mangaAccent)
                            .cornerRadius(6)
                    }
                }
                .padding(12)
                .background(Color.surfacePrimary)
                .cornerRadius(8)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.xs)
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
                            currentPage = 1
                            hasMorePages = true
                            if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                loadData()
                            } else {
                                performSearch(reset: true)
                            }
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
                            .onAppear {
                                if manga.id == items.suffix(4).first?.id || manga.id == items.last?.id {
                                    loadNextPage()
                                }
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    
                    if isLoadingMore {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .mangaAccent))
                            .padding(.vertical, 16)
                    }
                }
                .refreshable {
                    currentPage = 1
                    hasMorePages = true
                    if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        loadData()
                    } else {
                        performSearch(reset: true)
                    }
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
        .sheet(isPresented: $showCloudflareSheet) {
            if let webURL = sourceWebURL {
                CloudflareWebViewSheet(url: webURL) {
                    showCloudflareBanner = false
                    loadData()
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
            searchDebounceTask?.cancel()
        }
    }
    
    private func scheduleDebouncedSearch(_ query: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                currentPage = 1
                hasMorePages = true
                loadData()
            } else {
                performSearch(reset: true)
            }
        }
    }
    
    @MainActor
    private func loadData() {
        currentFetchTask?.cancel()
        currentFetchTask = Task { @MainActor in
            isLoading = true
            currentPage = 1
            hasMorePages = true
            showCloudflareBanner = false
            defer { isLoading = false }
            
            do {
                let result: [MangaItem] = try await withThrowingTaskGroup(of: [MangaItem].self) { group in
                    group.addTask {
                        if selectedTab == 0 {
                            return try await source.fetchPopular(page: 1)
                        } else {
                            return try await source.fetchLatest(page: 1)
                        }
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 12_000_000_000)
                        throw MangaReaderError.cloudflareProtected(source.manifest.name)
                    }
                    
                    if let first = try await group.next() {
                        group.cancelAll()
                        return first
                    }
                    return []
                }
                
                if !Task.isCancelled {
                    self.items = result
                    if result.count < 10 {
                        self.hasMorePages = false
                    }
                }
            } catch {
                let errStr = "\(error)".lowercased()
                if errStr.contains("cloudflare") || errStr.contains("408") || errStr.contains("timeout") || errStr.contains("403") {
                    showCloudflareBanner = true
                }
            }
        }
    }
    
    @MainActor
    private func performSearch(reset: Bool) {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            loadData()
            return
        }
        
        currentFetchTask?.cancel()
        currentFetchTask = Task { @MainActor in
            if reset {
                isLoading = true
                currentPage = 1
                hasMorePages = true
                showCloudflareBanner = false
            }
            defer { isLoading = false }
            
            do {
                let results: [MangaItem] = try await withThrowingTaskGroup(of: [MangaItem].self) { group in
                    group.addTask {
                        return try await source.search(query: trimmed, page: 1)
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 12_000_000_000)
                        throw MangaReaderError.cloudflareProtected(source.manifest.name)
                    }
                    
                    if let first = try await group.next() {
                        group.cancelAll()
                        return first
                    }
                    return []
                }
                
                if !Task.isCancelled {
                    self.items = results
                    if results.count < 10 {
                        self.hasMorePages = false
                    }
                }
            } catch {
                let errStr = "\(error)".lowercased()
                if errStr.contains("cloudflare") || errStr.contains("408") || errStr.contains("timeout") || errStr.contains("403") {
                    showCloudflareBanner = true
                }
            }
        }
    }
    
    @MainActor
    private func loadNextPage() {
        guard !isLoading && !isLoadingMore && hasMorePages else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        Task { @MainActor in
            defer { isLoadingMore = false }
            do {
                let results: [MangaItem]
                let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    results = try await source.search(query: trimmed, page: nextPage)
                } else if selectedTab == 0 {
                    results = try await source.fetchPopular(page: nextPage)
                } else {
                    results = try await source.fetchLatest(page: nextPage)
                }
                
                if !Task.isCancelled {
                    if results.isEmpty {
                        self.hasMorePages = false
                    } else {
                        let existingIDs = Set(self.items.map { $0.id })
                        let existingSlugs = Set(self.items.map { $0.urlOrSlug })
                        let newItems = results.filter { !existingIDs.contains($0.id) && !existingSlugs.contains($0.urlOrSlug) }
                        
                        if newItems.isEmpty {
                            self.hasMorePages = false
                        } else {
                            self.items.append(contentsOf: newItems)
                            self.currentPage = nextPage
                            if results.count < 10 {
                                self.hasMorePages = false
                            }
                        }
                    }
                }
            } catch {
                self.hasMorePages = false
            }
        }
    }
}

// MARK: - Cloudflare Web View Sheet

public struct CloudflareWebViewSheet: View {
    public let url: URL
    public let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    public init(url: URL, onDismiss: @escaping () -> Void) {
        self.url = url
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            CloudflareWKView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Cloudflare Verification")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                            onDismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.mangaAccent)
                    }
                }
        }
    }
}

public struct CloudflareWKView: UIViewRepresentable {
    public let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
        webView.navigationDelegate = context.coordinator
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        webView.load(req)
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public final class Coordinator: NSObject, WKNavigationDelegate {
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                for cookie in cookies {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
            }
        }
    }
}
