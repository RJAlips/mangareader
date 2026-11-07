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
                    if iconStr.lowercased().hasPrefix("http://") || iconStr.lowercased().hasPrefix("https://") {
                        resolvedIconURL = URL(string: iconStr)
                    } else {
                        resolvedIconURL = URL(string: iconStr, relativeTo: baseRepoURL)?.absoluteURL
                    }
                }
                
                let dynamicSource = DynamicJSONSource(
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
                    repositoryURL: cleanURLString,
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
        } else if let sourceList = try? decoder.decode([RepositorySourceDTO].self, from: data) {
            repoName = url.deletingPathExtension().lastPathComponent.capitalized
            for srcDTO in sourceList {
                var resolvedIconURL: URL? = nil
                if let iconStr = srcDTO.iconURL, !iconStr.isEmpty {
                    if iconStr.lowercased().hasPrefix("http://") || iconStr.lowercased().hasPrefix("https://") {
                        resolvedIconURL = URL(string: iconStr)
                    } else {
                        resolvedIconURL = URL(string: iconStr, relativeTo: baseRepoURL)?.absoluteURL
                    }
                }
                
                let dynamicSource = DynamicJSONSource(
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
                    repositoryURL: cleanURLString,
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
            repoName = url.deletingPathExtension().lastPathComponent.capitalized
            let dynamicSource = DynamicJSONSource(
                manifest: SourceManifest(
                    id: "com.mangareader.feed.\(abs(cleanURLString.hashValue))",
                    name: repoName,
                    version: "1.0.0",
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
            throw NetworkError.decodingError(NSError(
                domain: "RepositoryError",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid repository format. Supported formats include Aidoku index (JSON), MangaReader index, or a Manga items list."]
            ))
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
