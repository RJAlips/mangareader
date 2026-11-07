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
        // Register default built-in providers
        let demo = DemoMangaSource()
        let mangadex = MangaDexSource()
        let komga = KomgaSource()
        
        self.sources = [demo, mangadex, komga]
        
        if let saved = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            self.enabledSourceIDs = Set(saved)
        } else {
            // Default to demo + mangadex enabled
            self.enabledSourceIDs = [demo.manifest.id, mangadex.manifest.id]
            saveEnabledSources()
        }
        
        // Load custom repositories
        if let repoData = UserDefaults.standard.data(forKey: repoDefaultsKey),
           let savedRepos = try? JSONDecoder().decode([RepositoryInfo].self, from: repoData) {
            self.repositories = savedRepos
        } else {
            self.repositories = [
                RepositoryInfo(name: "Official MangaDex Repository", url: "https://api.mangadex.org", sourceCount: 1),
                RepositoryInfo(name: "MangaReader Curated Catalog", url: "https://mangareader.local/demo", sourceCount: 1)
            ]
        }
    }
    
    public func register(source: any MangaSource) {
        if !sources.contains(where: { $0.manifest.id == source.manifest.id }) {
            sources.append(source)
        }
    }
    
    public func provider(for id: String) -> (any MangaSource)? {
        return sources.first(where: { $0.manifest.id == id })
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
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { throw NetworkError.invalidURL }
        
        let data = try await NetworkClient.shared.fetchData(from: url)
        let decoder = JSONDecoder()
        
        var addedCount = 0
        var repoName = url.host ?? "Custom Repository"
        
        if let manifest = try? decoder.decode(RepositoryManifestDTO.self, from: data) {
            repoName = manifest.name
            for srcDTO in manifest.sources {
                let dynamicSource = DynamicJSONSource(
                    manifest: SourceManifest(
                        id: srcDTO.id,
                        name: srcDTO.name,
                        version: srcDTO.version ?? "1.0.0",
                        lang: srcDTO.lang ?? "EN",
                        iconURL: srcDTO.iconURL != nil ? URL(string: srcDTO.iconURL!) : nil,
                        isEnabled: true,
                        supportsLatest: true,
                        supportsSearch: true,
                        sourceDescription: srcDTO.description
                    ),
                    repositoryURL: trimmed,
                    popularEndpoint: srcDTO.popularURL,
                    latestEndpoint: srcDTO.latestURL,
                    searchEndpoint: srcDTO.searchURL,
                    chaptersEndpoint: srcDTO.chaptersURL
                )
                register(source: dynamicSource)
                if !enabledSourceIDs.contains(dynamicSource.manifest.id) {
                    enabledSourceIDs.insert(dynamicSource.manifest.id)
                }
                addedCount += 1
            }
        } else if let items = try? decoder.decode([MangaItem].self, from: data) {
            repoName = url.deletingPathExtension().lastPathComponent
            let dynamicSource = DynamicJSONSource(
                manifest: SourceManifest(
                    id: "com.mangareader.feed.\(abs(trimmed.hashValue))",
                    name: repoName.capitalized,
                    version: "1.0.0",
                    lang: "EN",
                    iconURL: items.first?.coverURL,
                    isEnabled: true,
                    supportsLatest: true,
                    supportsSearch: true,
                    sourceDescription: "Custom repository feed with \(items.count) titles"
                ),
                repositoryURL: trimmed,
                staticItems: items
            )
            register(source: dynamicSource)
            enabledSourceIDs.insert(dynamicSource.manifest.id)
            addedCount = 1
        } else {
            throw NetworkError.decodingError(NSError(
                domain: "RepositoryError",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid repository format. Please check the URL and format."]
            ))
        }
        
        if let idx = repositories.firstIndex(where: { $0.url == trimmed }) {
            repositories[idx].sourceCount = addedCount
        } else {
            repositories.append(RepositoryInfo(name: repoName, url: trimmed, sourceCount: addedCount))
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
    
    private func saveRepositories() {
        if let encoded = try? JSONEncoder().encode(repositories) {
            UserDefaults.standard.set(encoded, forKey: repoDefaultsKey)
        }
    }
    
    // MARK: - Global Multi-Source Search
    
    public func globalSearch(query: String) async -> [String: [MangaItem]] {
        let activeSources = sources.filter { enabledSourceIDs.contains($0.manifest.id) && $0.manifest.supportsSearch }
        
        return await withTaskGroup(of: (String, [MangaItem]).self) { group in
            for src in activeSources {
                group.addTask {
                    do {
                        let results = try await src.search(query: query, page: 1)
                        return (src.manifest.name, results)
                    } catch {
                        return (src.manifest.name, [])
                    }
                }
            }
            
            var aggregated: [String: [MangaItem]] = [:]
            for await (sourceName, results) in group {
                if !results.isEmpty {
                    aggregated[sourceName] = results
                }
            }
            return aggregated
        }
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
    let version: String?
    let lang: String?
    let iconURL: String?
    let description: String?
    let popularURL: String?
    let latestURL: String?
    let searchURL: String?
    let chaptersURL: String?
}
