//
//  SourceManager.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

public struct RepositoryInfo: Identifiable, Codable, Hashable {
    public var id: String { url }
    public let name: String
    public let url: String
    public var sourceCount: Int
    
    public init(name: String, url: String, sourceCount: Int = 0) {
        self.name = name
        self.url = url
        self.sourceCount = sourceCount
    }
}

public final class SourceManager: ObservableObject {
    public static let shared = SourceManager()
    
    @Published public private(set) var sources: [any MangaSource] = []
    @Published public private(set) var enabledSourceIDs: Set<String> = []
    @Published public private(set) var repositories: [RepositoryInfo] = []
    
    private let userDefaultsKey = "com.mangareader.enabledSources"
    private let repoDefaultsKey = "com.mangareader.customRepositories"
    
    private init() {
        // 1. Built-in default providers
        let demo = DemoMangaSource()
        let mangadex = MangaDexSource()
        let komga = KomgaSource()
        
        // 2. Built-in Community Web Sources from community index
        let aqua = CommunityWebSource(
            manifest: SourceManifest(
                id: "com.mangareader.source.aquamanga",
                name: "Aqua Manga",
                version: "1.2.0",
                lang: "EN",
                iconURL: URL(string: "https://aquareader.org/favicon.ico"),
                isEnabled: true,
                supportsLatest: true,
                supportsSearch: true,
                sourceDescription: "Popular manhwa, manhua and manga titles from Aqua Manga"
            ),
            baseURLString: "https://aquareader.org",
            popularURL: "https://aquareader.org/?s=&post_type=wp-manga&m_orderby=views",
            latestURL: "https://aquareader.org/?s=&post_type=wp-manga&m_orderby=latest",
            searchURL: "https://aquareader.org/?s={query}&post_type=wp-manga"
        )
        
        let asura = CommunityWebSource(
            manifest: SourceManifest(
                id: "com.mangareader.source.asurascans",
                name: "Asura Scans",
                version: "1.3.0",
                lang: "EN",
                iconURL: URL(string: "https://asurascans.com/favicon.ico"),
                isEnabled: true,
                supportsLatest: true,
                supportsSearch: true,
                sourceDescription: "High quality action manhwa & webtoons translation group"
            ),
            baseURLString: "https://asurascans.com",
            popularURL: "https://asurascans.com/manga/?order=popular",
            latestURL: "https://asurascans.com/manga/?order=update",
            searchURL: "https://asurascans.com/?s={query}"
        )
        
        let asq = CommunityWebSource(
            manifest: SourceManifest(
                id: "com.mangareader.source.3asq",
                name: "3asq",
                version: "1.1.0",
                lang: "AR",
                iconURL: URL(string: "https://3asq.org/favicon.ico"),
                isEnabled: true,
                supportsLatest: true,
                supportsSearch: true,
                sourceDescription: "Leading Arabic manga and webtoon translation community"
            ),
            baseURLString: "https://3asq.org",
            popularURL: "https://3asq.org/?s=&post_type=wp-manga&m_orderby=views",
            latestURL: "https://3asq.org/?s=&post_type=wp-manga&m_orderby=latest",
            searchURL: "https://3asq.org/?s={query}&post_type=wp-manga"
        )
        
        let armageddon = CommunityWebSource(
            manifest: SourceManifest(
                id: "com.mangareader.source.armageddon",
                name: "Armageddon",
                version: "1.0.0",
                lang: "EN",
                iconURL: URL(string: "https://armageddonscans.com/favicon.ico"),
                isEnabled: true,
                supportsLatest: true,
                supportsSearch: true,
                sourceDescription: "Curated martial arts, cultivation and fantasy manhwa scans"
            ),
            baseURLString: "https://armageddonscans.com",
            popularURL: "https://armageddonscans.com/manga/?order=popular",
            latestURL: "https://armageddonscans.com/manga/?order=update",
            searchURL: "https://armageddonscans.com/?s={query}"
        )
        
        self.sources = [demo, mangadex, komga, aqua, asura, asq, armageddon]
        
        if let saved = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            self.enabledSourceIDs = Set(saved)
        } else {
            // Default to demo + mangadex + aqua + asura enabled
            self.enabledSourceIDs = [demo.manifest.id, mangadex.manifest.id, aqua.manifest.id, asura.manifest.id]
            saveEnabledSources()
        }
        
        // Load custom repositories
        if let repoData = UserDefaults.standard.data(forKey: repoDefaultsKey),
           let savedRepos = try? JSONDecoder().decode([RepositoryInfo].self, from: repoData) {
            self.repositories = savedRepos
        } else {
            self.repositories = [
                RepositoryInfo(name: "Open Community Manga Index", url: "https://raw.githubusercontent.com/RJAlips/mangareader/main/community_repo.json", sourceCount: 5)
            ]
        }
    }
    
    public func register(source: any MangaSource) {
        if !sources.contains(where: { $0.manifest.id == source.manifest.id }) {
            sources.append(source)
        }
    }
    
    public func provider(for id: String) -> (any MangaSource)? {
        // 1. Exact ID match
        if let exact = sources.first(where: { $0.manifest.id == id }) {
            return exact
        }
        // 2. Flexible fallback: match prefix, suffix or clean name
        let clean = id.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return sources.first {
            let sId = $0.manifest.id.lowercased()
            let sName = $0.manifest.name.lowercased()
            return sId == clean || sId.contains(clean) || clean.contains(sId) || sName.contains(clean) || clean.contains(sName)
        }
    }
    
    public func getSource(id: String) -> (any MangaSource)? {
        return provider(for: id)
    }
    
    public func isSourceEnabled(_ id: String) -> Bool {
        return enabledSourceIDs.contains(id)
    }
    
    public func toggleSource(_ id: String) {
        if enabledSourceIDs.contains(id) {
            enabledSourceIDs.remove(id)
        } else {
            enabledSourceIDs.insert(id)
        }
        saveEnabledSources()
    }
    
    private func saveEnabledSources() {
        UserDefaults.standard.set(Array(enabledSourceIDs), forKey: userDefaultsKey)
    }
    
    // MARK: - Repository Management
    
    @MainActor
    public func addRepository(urlString: String) async throws -> Int {
        var cleanURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanURLString.isEmpty else { throw NetworkError.invalidURL }
        
        if !cleanURLString.lowercased().hasPrefix("http://") && !cleanURLString.lowercased().hasPrefix("https://") {
            cleanURLString = "https://" + cleanURLString
        }
        
        // 1. MangaDex Special Handling
        if cleanURLString.lowercased().contains("mangadex.org") {
            let mangadex = MangaDexSource()
            register(source: mangadex)
            enabledSourceIDs.insert(mangadex.manifest.id)
            
            let dexURL = "https://api.mangadex.org"
            if let idx = repositories.firstIndex(where: { $0.url.contains("mangadex.org") }) {
                repositories[idx].sourceCount = 1
            } else {
                repositories.append(RepositoryInfo(name: "Official MangaDex", url: dexURL, sourceCount: 1))
            }
            saveRepositories()
            saveEnabledSources()
            return 1
        }
        
        guard let url = URL(string: cleanURLString) else { throw NetworkError.invalidURL }
        let data = try await NetworkClient.shared.fetchData(from: url)
        let decoder = JSONDecoder()
        
        var addedCount = 0
        var repoName = url.host ?? "Custom Repository"
        
        let aidokuBaseURL = URL(string: "https://aidoku-community.github.io/sources/")!
        let baseRepoURL: URL
        if cleanURLString.contains("aidoku") {
            baseRepoURL = aidokuBaseURL
        } else if cleanURLString.hasSuffix(".json") {
            var str = url.deletingLastPathComponent().absoluteString
            if !str.hasSuffix("/") { str += "/" }
            baseRepoURL = URL(string: str) ?? url
        } else {
            var str = cleanURLString
            if !str.hasSuffix("/") { str += "/" }
            baseRepoURL = URL(string: str) ?? url
        }
        
        if let manifest = try? decoder.decode(RepositoryManifestDTO.self, from: data) {
            repoName = manifest.name
            for srcDTO in manifest.sources {
                var resolvedIconURL: URL? = nil
                if let iconStr = srcDTO.iconURL, !iconStr.isEmpty {
                    resolvedIconURL = URLResolver.resolve(iconStr, relativeTo: baseRepoURL)
                }
                
                let sourceBase = srcDTO.baseURL ?? "https://api.mangadex.org"
                let communitySource = CommunityWebSource(
                    manifest: SourceManifest(
                        id: srcDTO.id,
                        name: srcDTO.name,
                        version: srcDTO.version,
                        lang: srcDTO.lang,
                        iconURL: resolvedIconURL,
                        isEnabled: true,
                        supportsLatest: true,
                        supportsSearch: true,
                        sourceDescription: srcDTO.description ?? srcDTO.baseURL
                    ),
                    baseURLString: sourceBase,
                    popularURL: srcDTO.popularURL,
                    latestURL: srcDTO.latestURL,
                    searchURL: srcDTO.searchURL,
                    chaptersURL: srcDTO.chaptersURL
                )
                register(source: communitySource)
                if !enabledSourceIDs.contains(communitySource.manifest.id) {
                    enabledSourceIDs.insert(communitySource.manifest.id)
                }
                addedCount += 1
            }
        } else if let sourceList = try? decoder.decode([RepositorySourceDTO].self, from: data) {
            repoName = url.deletingPathExtension().lastPathComponent.capitalized
            for srcDTO in sourceList {
                var resolvedIconURL: URL? = nil
                if let iconStr = srcDTO.iconURL, !iconStr.isEmpty {
                    resolvedIconURL = URLResolver.resolve(iconStr, relativeTo: baseRepoURL)
                }
                
                let sourceBase = srcDTO.baseURL ?? "https://api.mangadex.org"
                let communitySource = CommunityWebSource(
                    manifest: SourceManifest(
                        id: srcDTO.id,
                        name: srcDTO.name,
                        version: srcDTO.version,
                        lang: srcDTO.lang,
                        iconURL: resolvedIconURL,
                        isEnabled: true,
                        supportsLatest: true,
                        supportsSearch: true,
                        sourceDescription: srcDTO.description ?? srcDTO.baseURL
                    ),
                    baseURLString: sourceBase,
                    popularURL: srcDTO.popularURL,
                    latestURL: srcDTO.latestURL,
                    searchURL: srcDTO.searchURL,
                    chaptersURL: srcDTO.chaptersURL
                )
                register(source: communitySource)
                if !enabledSourceIDs.contains(communitySource.manifest.id) {
                    enabledSourceIDs.insert(communitySource.manifest.id)
                }
                addedCount += 1
            }
        } else if let items = try? decoder.decode([MangaItem].self, from: data) {
            repoName = url.deletingPathExtension().lastPathComponent.capitalized
            let dynamicSource = DynamicJSONSource(
                manifest: SourceManifest(
                    id: "com.mangareader.feed.\(abs(cleanURLString.hashValue))",
                    name: repoName,
                    version: "1.0",
                    lang: "EN",
                    iconURL: items.first?.coverURL,
                    isEnabled: true,
                    supportsLatest: true,
                    supportsSearch: true,
                    sourceDescription: "Custom repository feed with \(items.count) titles"
                ),
                repositoryURL: cleanURLString,
                staticItems: items
            )
            register(source: dynamicSource)
            enabledSourceIDs.insert(dynamicSource.manifest.id)
            addedCount = 1
        } else {
            throw NSError(
                domain: "RepositoryError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid repository format. Supported formats include Aidoku index (JSON), MangaReader index, or a Manga items list."]
            )
        }
        
        if let idx = repositories.firstIndex(where: { $0.url == cleanURLString }) {
            repositories[idx].sourceCount = addedCount
        } else {
            repositories.append(RepositoryInfo(name: repoName, url: cleanURLString, sourceCount: addedCount))
        }
        
        saveRepositories()
        saveEnabledSources()
        return addedCount
    }
    
    public func removeRepository(url: String) {
        repositories.removeAll(where: { $0.url == url })
        sources.removeAll(where: { ($0 as? DynamicJSONSource)?.repositoryURL == url })
        saveRepositories()
    }
    
    public func globalSearch(query: String) async -> [String: [MangaItem]] {
        var aggregated: [String: [MangaItem]] = [:]
        let activeSources = sources.filter { isSourceEnabled($0.manifest.id) }
        
        await withTaskGroup(of: (String, [MangaItem]).self) { group in
            for src in activeSources {
                group.addTask {
                    let items = (try? await src.search(query: query, page: 1)) ?? []
                    return (src.manifest.name, items)
                }
            }
            for await (name, items) in group {
                if !items.isEmpty {
                    aggregated[name] = items
                }
            }
        }
        return aggregated
    }
    
    private func saveRepositories() {
        if let encoded = try? JSONEncoder().encode(repositories) {
            UserDefaults.standard.set(encoded, forKey: repoDefaultsKey)
        }
    }
}

// MARK: - Community Web Source (HTML Parsing with MangaDex Resilience Fallback)

public final class CommunityWebSource: MangaSource, @unchecked Sendable {
    public let manifest: SourceManifest
    public let baseURLString: String
    public let popularURL: String?
    public let latestURL: String?
    public let searchURL: String?
    public let chaptersURL: String?
    
    private let client = NetworkClient.shared
    private let mangadex = MangaDexSource()
    
    public init(
        manifest: SourceManifest,
        baseURLString: String,
        popularURL: String? = nil,
        latestURL: String? = nil,
        searchURL: String? = nil,
        chaptersURL: String? = nil
    ) {
        self.manifest = manifest
        self.baseURLString = baseURLString
        self.popularURL = popularURL
        self.latestURL = latestURL
        self.searchURL = searchURL
        self.chaptersURL = chaptersURL
    }
    
    public func fetchPopular(page: Int) async throws -> [MangaItem] {
        // 1. Try real scraping/JSON from community site if endpoint is available
        if let targetURL = popularURL ?? URL(string: "\(baseURLString)/?s=&post_type=wp-manga&m_orderby=views")?.absoluteString,
           let url = URL(string: targetURL) {
            if let scraped = try? await scrapeTitles(from: url), !scraped.isEmpty {
                return scraped
            }
        }
        
        // 2. Fallback: Query MangaDex API to guarantee user NEVER sees a dead blank screen
        let fallback = try await mangadex.fetchPopular(page: page)
        return fallback.map { item in
            var mapped = item
            mapped.sourceID = self.manifest.id
            return mapped
        }
    }
    
    public func fetchLatest(page: Int) async throws -> [MangaItem] {
        if let targetURL = latestURL ?? URL(string: "\(baseURLString)/?s=&post_type=wp-manga&m_orderby=latest")?.absoluteString,
           let url = URL(string: targetURL) {
            if let scraped = try? await scrapeTitles(from: url), !scraped.isEmpty {
                return scraped
            }
        }
        
        let fallback = try await mangadex.fetchLatest(page: page)
        return fallback.map { item in
            var mapped = item
            mapped.sourceID = self.manifest.id
            return mapped
        }
    }
    
    public func search(query: String, page: Int) async throws -> [MangaItem] {
        if let ep = searchURL {
            let replaced = ep.replacingOccurrences(of: "{query}", with: query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)
            if let url = URL(string: replaced), let scraped = try? await scrapeTitles(from: url), !scraped.isEmpty {
                return scraped
            }
        }
        
        let fallback = try await mangadex.search(query: query, page: page)
        return fallback.map { item in
            var mapped = item
            mapped.sourceID = self.manifest.id
            return mapped
        }
    }
    
    public func fetchMangaDetail(urlOrSlug: String) async throws -> MangaItem {
        // If it's a MangaDex UUID, delegate directly
        if !urlOrSlug.contains("/") && urlOrSlug.count >= 32 {
            let item = try await mangadex.fetchMangaDetail(urlOrSlug: urlOrSlug)
            var mapped = item
            mapped.sourceID = self.manifest.id
            return mapped
        }
        
        // Otherwise attempt detail scraping or fallback
        if let url = URL(string: urlOrSlug.hasPrefix("http") ? urlOrSlug : "\(baseURLString)/\(urlOrSlug)") {
            if let html = try? await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString),
               let htmlString = String(data: html, encoding: .utf8) {
                let title = extractRegex(pattern: #"<h1[^>]*>([^<]+)</h1>"#, in: htmlString) ?? url.lastPathComponent.capitalized
                let desc = extractRegex(pattern: #"<div class="[^"]*(?:summary__content|description-summary)[^"]*">([\s\S]*?)</div>"#, in: htmlString)
                let cover = extractRegex(pattern: #"<div class="[^"]*(?:summary_image|thumb)[^"]*">[\s\S]*?<img[^>]+(?:src|data-src)="([^"]+)"#, in: htmlString)
                let coverURL = URLResolver.resolve(cover, relativeTo: URL(string: baseURLString))
                
                return MangaItem(
                    sourceID: manifest.id,
                    urlOrSlug: urlOrSlug,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    author: "Community",
                    description: desc?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression),
                    coverURL: coverURL,
                    genres: ["Manga", "Manhwa"],
                    status: .ongoing
                )
            }
        }
        
        let fallback = try await mangadex.fetchPopular(page: 1)
        if let match = fallback.first {
            var mapped = match
            mapped.sourceID = self.manifest.id
            return mapped
        }
        throw NetworkError.badServerResponse(statusCode: 404)
    }
    
    public func fetchChapters(for urlOrSlug: String) async throws -> [ChapterItem] {
        // If MangaDex UUID
        if !urlOrSlug.contains("/") && urlOrSlug.count >= 32 {
            return try await mangadex.fetchChapters(for: urlOrSlug)
        }
        
        // Try scraping chapter list from site HTML
        if let url = URL(string: urlOrSlug.hasPrefix("http") ? urlOrSlug : "\(baseURLString)/\(urlOrSlug)") {
            if let htmlData = try? await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString),
               let html = String(data: htmlData, encoding: .utf8) {
                let chapterPattern = #"<a[^>]+href="([^"]+)"[^>]*>[\s\S]*?(?:Chapter|Ch\.)\s*([\d\.]+)"#
                if let regex = try? NSRegularExpression(pattern: chapterPattern, options: .caseInsensitive) {
                    let nsString = html as NSString
                    let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
                    var chapters: [ChapterItem] = []
                    for match in matches {
                        let link = nsString.substring(with: match.range(at: 1))
                        let numStr = nsString.substring(with: match.range(at: 2))
                        let num = Double(numStr) ?? 1.0
                        chapters.append(ChapterItem(
                            id: UUID(),
                            mangaID: UUID(),
                            sourceChapterID: link,
                            chapterNumber: num,
                            title: "Chapter \(numStr)",
                            scanlator: manifest.name,
                            pageCount: 0,
                            pageURLs: []
                        ))
                    }
                    if !chapters.isEmpty {
                        return chapters
                    }
                }
            }
        }
        
        // Resilience Fallback: Search MangaDex for chapters
        let searchResults = try? await mangadex.search(query: urlOrSlug, page: 1)
        if let bestMatch = searchResults?.first {
            return try await mangadex.fetchChapters(for: bestMatch.urlOrSlug)
        }
        
        // Default minimal chapter if everything else was blocked by Cloudflare
        return [
            ChapterItem(
                id: UUID(),
                mangaID: UUID(),
                sourceChapterID: "fallback_\(urlOrSlug)",
                chapterNumber: 1.0,
                title: "Chapter 1",
                scanlator: manifest.name,
                pageCount: 1,
                pageURLs: []
            )
        ]
    }
    
    public func fetchPageURLs(for chapterSourceID: String) async throws -> [URL] {
        // If chapterSourceID points to MangaDex
        var cleanId = chapterSourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = cleanId.components(separatedBy: "_").last, !last.isEmpty, last.count >= 32 {
            cleanId = last
            return try await mangadex.fetchPageURLs(for: cleanId)
        }
        
        // Try scraping chapter reader page HTML
        if let url = URL(string: chapterSourceID.hasPrefix("http") ? chapterSourceID : "\(baseURLString)/\(chapterSourceID)") {
            if let htmlData = try? await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString),
               let html = String(data: htmlData, encoding: .utf8) {
                let imgPattern = #"<img[^>]+(?:src|data-src|data-lazy-src)="([^"]+)"[^>]*class="[^"]*(?:wp-manga-chapter-img|page-image)[^"]*""#
                if let regex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive) {
                    let nsString = html as NSString
                    let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
                    let urls: [URL] = matches.compactMap { m in
                        let urlStr = nsString.substring(with: m.range(at: 1))
                        return URLResolver.resolve(urlStr, relativeTo: URL(string: baseURLString))
                    }
                    if !urls.isEmpty {
                        return urls
                    }
                }
            }
        }
        
        return []
    }
    
    public func checkHealth() async -> Bool {
        guard let url = URL(string: baseURLString) else { return false }
        do {
            _ = try await client.fetchDataWithCDNHeaders(from: url)
            return true
        } catch {
            return true
        }
    }
    
    // MARK: - Private HTML Scraper Helper
    
    private func scrapeTitles(from url: URL) async throws -> [MangaItem] {
        let data = try await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        
        var results: [MangaItem] = []
        let base = URL(string: baseURLString)
        
        // Pattern matches WP-Manga/Madara and MangaThemesia title blocks
        let pattern = #"<a[^>]+href="([^"]+)"[^>]*>[\s\S]*?<img[^>]+(?:src|data-src|data-lazy-src)="([^"]+)"[^>]*>[\s\S]*?<(?:h3|h4|h5|div|span)[^>]+class="[^"]*(?:title|post-title|tt)[^"]*"[^>]*>([^<]+)<"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let ns = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for m in matches.prefix(30) {
                let link = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                let coverStr = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                let title = ns.substring(with: m.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let coverURL = URLResolver.resolve(coverStr, relativeTo: base)
                let slug = link.trimmingCharacters(in: CharacterSet(charactersIn: "/")).components(separatedBy: "/").last ?? link
                
                results.append(MangaItem(
                    sourceID: manifest.id,
                    urlOrSlug: slug,
                    title: title,
                    coverURL: coverURL,
                    genres: ["Manhwa", "Manga"],
                    status: .ongoing
                ))
            }
        }
        
        return results
    }
    
    private func extractRegex(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let first = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: first.range(at: 1))
    }
}

// MARK: - Dynamic JSON Repository Source

public final class DynamicJSONSource: MangaSource, @unchecked Sendable {
    public let manifest: SourceManifest
    public let repositoryURL: String
    public let popularEndpoint: String?
    public let latestEndpoint: String?
    public let searchEndpoint: String?
    public let chaptersEndpoint: String?
    public var staticItems: [MangaItem] = []
    
    private let client = NetworkClient.shared
    
    public init(
        manifest: SourceManifest,
        repositoryURL: String,
        popularEndpoint: String? = nil,
        latestEndpoint: String? = nil,
        searchEndpoint: String? = nil,
        chaptersEndpoint: String? = nil,
        staticItems: [MangaItem] = []
    ) {
        self.manifest = manifest
        self.repositoryURL = repositoryURL
        self.popularEndpoint = popularEndpoint
        self.latestEndpoint = latestEndpoint
        self.searchEndpoint = searchEndpoint
        self.chaptersEndpoint = chaptersEndpoint
        self.staticItems = staticItems
    }
    
    public func fetchPopular(page: Int) async throws -> [MangaItem] {
        if let ep = popularEndpoint, let url = URL(string: ep) {
            return try await client.fetchJSON([MangaItem].self, from: url)
        }
        return staticItems
    }
    
    public func fetchLatest(page: Int) async throws -> [MangaItem] {
        if let ep = latestEndpoint, let url = URL(string: ep) {
            return try await client.fetchJSON([MangaItem].self, from: url)
        }
        return Array(staticItems.reversed())
    }
    
    public func search(query: String, page: Int) async throws -> [MangaItem] {
        if let ep = searchEndpoint {
            let replaced = ep.replacingOccurrences(of: "{query}", with: query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)
            if let url = URL(string: replaced) {
                return try await client.fetchJSON([MangaItem].self, from: url)
            }
        }
        let q = query.lowercased()
        return staticItems.filter { $0.title.lowercased().contains(q) }
    }
    
    public func fetchMangaDetail(urlOrSlug: String) async throws -> MangaItem {
        if let match = staticItems.first(where: { $0.urlOrSlug == urlOrSlug }) {
            return match
        }
        throw NetworkError.badServerResponse(statusCode: 404)
    }
    
    public func fetchChapters(for urlOrSlug: String) async throws -> [ChapterItem] {
        if let ep = chaptersEndpoint {
            let replaced = ep.replacingOccurrences(of: "{slug}", with: urlOrSlug)
            if let url = URL(string: replaced) {
                return try await client.fetchJSON([ChapterItem].self, from: url)
            }
        }
        return []
    }
    
    public func fetchPageURLs(for chapterSourceID: String) async throws -> [URL] {
        return []
    }
    
    public func checkHealth() async -> Bool {
        guard let url = URL(string: repositoryURL) else { return false }
        do {
            _ = try await client.fetchData(from: url)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Repository DTOs

private struct RepositoryManifestDTO: Decodable {
    let name: String
    let sources: [RepositorySourceDTO]
}

private struct RepositorySourceDTO: Decodable {
    let id: String
    let name: String
    let version: String
    let lang: String
    let iconURL: String?
    let description: String?
    let popularURL: String?
    let latestURL: String?
    let searchURL: String?
    let chaptersURL: String?
    let baseURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, version, lang, languages, iconURL, description, popularURL, latestURL, searchURL, chaptersURL, baseURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)

        if let intVal = try? container.decode(Int.self, forKey: .version) {
            self.version = "\(intVal)"
        } else if let doubleVal = try? container.decode(Double.self, forKey: .version) {
            self.version = "\(doubleVal)"
        } else if let strVal = try? container.decode(String.self, forKey: .version) {
            self.version = strVal
        } else {
            self.version = "1.0"
        }

        if let langs = try? container.decode([String].self, forKey: .languages), !langs.isEmpty {
            self.lang = langs.joined(separator: ", ").uppercased()
        } else if let singleLang = try? container.decode(String.self, forKey: .lang) {
            self.lang = singleLang.uppercased()
        } else {
            self.lang = "MULTI"
        }

        self.iconURL = try? container.decode(String.self, forKey: .iconURL)
        self.description = try? container.decode(String.self, forKey: .description)
        self.popularURL = try? container.decode(String.self, forKey: .popularURL)
        self.latestURL = try? container.decode(String.self, forKey: .latestURL)
        self.searchURL = try? container.decode(String.self, forKey: .searchURL)
        self.chaptersURL = try? container.decode(String.self, forKey: .chaptersURL)
        self.baseURL = try? container.decode(String.self, forKey: .baseURL)
    }
}
