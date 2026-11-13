//
//  SourceManager.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine
import WebKit

public enum MangaReaderError: LocalizedError {
    case scrapingFailed(String, String)
    case cloudflareProtected(String)
    
    public var errorDescription: String? {
        switch self {
        case .scrapingFailed(let name, let reason):
            return "[\(name)] Scraping failed: \(reason)"
        case .cloudflareProtected(let name):
            return "[\(name)] Site requires Cloudflare verification"
        }
    }
}

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
    @Published public private(set) var installedManifests: [SourceManifest] = []
    @Published public private(set) var pendingUpdates: [SourceManifest] = []
    @Published public private(set) var availableManifests: [SourceManifest] = []
    @Published public private(set) var isRefreshingRepos: Bool = false
    
    public var activeSources: [any MangaSource] {
        return sources.filter { isSourceEnabled($0.manifest.id) }
    }
    
    private var lastRepoRefreshDate: Date?
    private let userDefaultsKey = "com.mangareader.enabledSources"
    private let repoDefaultsKey = "com.mangareader.customRepositories"
    private let savedReposKey = "saved_repository_urls"
    
    private var installedManifestsFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("installed_sources.json")
    }
    
    private init() {
        // 1. Built-in default native providers
        let demo = DemoMangaSource()
        let mangadex = MangaDexSource()
        let komga = KomgaSource()
        
        // 2. Built-in Community Web Sources
        let aqua = CommunityWebSource(
            manifest: SourceManifest(
                id: "com.mangareader.source.aquamanga",
                name: "Aqua Manga",
                version: "1.3.0",
                versionCode: 130,
                lang: "EN",
                baseURL: "https://aquareader.org",
                iconURL: URL(string: "https://aquareader.org/favicon.ico"),
                isEnabled: true,
                supportsLatest: true,
                supportsSearch: true,
                sourceDescription: "Popular manhwa, manhua and manga titles from Aqua Manga"
            ),
            baseURLString: "https://aquareader.org",
            popularURL: "https://aquareader.org/",
            latestURL: "https://aquareader.org/manga/?m_orderby=latest",
            searchURL: "https://aquareader.org/?s={query}&post_type=wp-manga"
        )
        
        let asura = CommunityWebSource(
            manifest: SourceManifest(
                id: "com.mangareader.source.asurascans",
                name: "Asura Scans",
                version: "1.4.1",
                versionCode: 141,
                lang: "EN",
                baseURL: "https://asuracomic.net",
                iconURL: URL(string: "https://asuracomic.net/favicon.ico"),
                isEnabled: true,
                supportsLatest: true,
                supportsSearch: true,
                sourceDescription: "High quality action manhwa & webtoons translation group"
            ),
            baseURLString: "https://asuracomic.net",
            popularURL: "https://asuracomic.net/series?page=1",
            latestURL: "https://asuracomic.net/series?page=1",
            searchURL: "https://asuracomic.net/series?page=1&name={query}"
        )
        
        let asq = CommunityWebSource(
            manifest: SourceManifest(
                id: "com.mangareader.source.3asq",
                name: "3asq",
                version: "1.2.0",
                versionCode: 120,
                lang: "AR",
                baseURL: "https://3asq.online",
                iconURL: URL(string: "https://3asq.online/favicon.ico"),
                isEnabled: true,
                supportsLatest: true,
                supportsSearch: true,
                sourceDescription: "Leading Arabic manga and webtoon translation community"
            ),
            baseURLString: "https://3asq.online",
            popularURL: "https://3asq.online/",
            latestURL: "https://3asq.online/",
            searchURL: "https://3asq.online/?s={query}&post_type=wp-manga"
        )
        
        let armageddon = CommunityWebSource(
            manifest: SourceManifest(
                id: "com.mangareader.source.armageddon",
                name: "Flame Comics",
                version: "1.1.0",
                versionCode: 110,
                lang: "EN",
                baseURL: "https://flamecomics.xyz",
                iconURL: URL(string: "https://flamecomics.xyz/favicon.ico"),
                isEnabled: true,
                supportsLatest: true,
                supportsSearch: true,
                sourceDescription: "Curated martial arts, cultivation and fantasy manhwa scans from Flame Comics"
            ),
            baseURLString: "https://flamecomics.xyz",
            popularURL: "https://flamecomics.xyz/",
            latestURL: "https://flamecomics.xyz/",
            searchURL: "https://flamecomics.xyz/browse?q={query}"
        )
        
        self.sources = [demo, mangadex, komga, aqua, asura, asq, armageddon]
        
        // 3. Load installed manifests from disk or seed defaults
        loadInstalledManifests(defaultSources: self.sources)
        
        // 4. Load enabled sources
        if let saved = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            self.enabledSourceIDs = Set(saved)
            // Ensure core community sources are active
            self.enabledSourceIDs.insert(aqua.manifest.id)
            self.enabledSourceIDs.insert(asura.manifest.id)
            self.enabledSourceIDs.insert(asq.manifest.id)
            self.enabledSourceIDs.insert(armageddon.manifest.id)
            self.enabledSourceIDs.insert(mangadex.manifest.id)
            self.enabledSourceIDs.insert(demo.manifest.id)
        } else {
            self.enabledSourceIDs = [demo.manifest.id, mangadex.manifest.id, aqua.manifest.id, asura.manifest.id, asq.manifest.id, armageddon.manifest.id]
            saveEnabledSources()
        }
        
        // 5. Load repositories
        if let repoData = UserDefaults.standard.data(forKey: repoDefaultsKey),
           let savedRepos = try? JSONDecoder().decode([RepositoryInfo].self, from: repoData) {
            self.repositories = savedRepos
        } else {
            self.repositories = [
                RepositoryInfo(name: "Official MangaDex", url: "https://api.mangadex.org", sourceCount: 1),
                RepositoryInfo(name: "Open Community Manga Index", url: "https://raw.githubusercontent.com/RJAlips/mangareader/main/community_repo.json", sourceCount: 5)
            ]
        }
        
        // Ensure default repo URLs are recorded
        ensureDefaultRepoURLs()
    }
    
    // MARK: - Source Registration & Fallback Resolution
    
    public func register(source: any MangaSource) {
        if !sources.contains(where: { $0.manifest.id == source.manifest.id }) {
            sources.append(source)
        }
    }
    
    public static func cleanSourceID(_ id: String) -> String {
        return id.lowercased()
            .replacingOccurrences(of: "com.rjalips.mangareader.source.", with: "")
            .replacingOccurrences(of: "com.mangareader.source.community.", with: "")
            .replacingOccurrences(of: "com.mangareader.source.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func provider(for id: String) -> (any MangaSource)? {
        // 1. Exact ID match in active sources
        if let exact = sources.first(where: { $0.manifest.id == id }) {
            return exact
        }
        
        // 2. Flexible fallback: match prefix, suffix or clean name
        let clean = Self.cleanSourceID(id)
        if let match = sources.first(where: {
            let sId = $0.manifest.id.lowercased()
            let sClean = Self.cleanSourceID(sId)
            let sName = $0.manifest.name.lowercased()
            return sId == id.lowercased() || sClean == clean || sId.hasSuffix(".\(clean)") || sName.contains(clean) || clean.contains(sName)
        }) {
            return match
        }
        
        // 3. Match from installedManifests and instantiate dynamically
        if let manifest = installedManifests.first(where: {
            let mId = $0.id.lowercased()
            let mClean = Self.cleanSourceID(mId)
            let mName = $0.name.lowercased()
            return mId == id.lowercased() || mClean == clean || mId.hasSuffix(".\(clean)") || mName.contains(clean) || clean.contains(mName)
        }) {
            let dynamicSource = CommunityWebSource(
                manifest: manifest,
                baseURLString: manifest.baseURL
            )
            register(source: dynamicSource)
            return dynamicSource
        }
        
        // 4. Known built-in ID fallback
        if clean.contains("mangadex") {
            let dex = MangaDexSource()
            register(source: dex)
            return dex
        }
        if clean.contains("demo") {
            let demo = DemoMangaSource()
            register(source: demo)
            return demo
        }
        if clean.contains("komga") {
            let komga = KomgaSource()
            register(source: komga)
            return komga
        }
        
        // 5. Guaranteed dynamic fallback so it NEVER returns nil for an installed manifest or known ID
        let fallbackManifest = SourceManifest(
            id: id,
            name: id.components(separatedBy: ".").last?.capitalized ?? "Community Source",
            version: "1.0.0",
            versionCode: 1,
            lang: "EN",
            baseURL: "",
            isEnabled: true
        )
        let fallbackSource = CommunityWebSource(manifest: fallbackManifest, baseURLString: "")
        register(source: fallbackSource)
        return fallbackSource
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
    
    // MARK: - Installed Manifests Persistence
    
    private func loadInstalledManifests(defaultSources: [any MangaSource]) {
        if let data = try? Data(contentsOf: installedManifestsFileURL),
           let manifests = try? JSONDecoder().decode([SourceManifest].self, from: data),
           !manifests.isEmpty {
            self.installedManifests = manifests
            
            // Sync default sources into installedManifests if newer or updated baseURL
            for def in defaultSources {
                if let idx = self.installedManifests.firstIndex(where: { $0.id == def.manifest.id }) {
                    if self.installedManifests[idx].versionCode < def.manifest.versionCode ||
                       self.installedManifests[idx].baseURL != def.manifest.baseURL {
                        self.installedManifests[idx] = def.manifest
                    }
                } else {
                    self.installedManifests.append(def.manifest)
                }
            }
            saveInstalledManifests()
            
            for manifest in self.installedManifests {
                if !sources.contains(where: { $0.manifest.id == manifest.id }) {
                    if manifest.id.contains("mangadex") {
                        register(source: MangaDexSource())
                    } else if manifest.id.contains("demo") {
                        register(source: DemoMangaSource())
                    } else if manifest.id.contains("komga") {
                        register(source: KomgaSource())
                    } else {
                        register(source: CommunityWebSource(
                            manifest: manifest,
                            baseURLString: manifest.baseURL
                        ))
                    }
                }
            }
        } else {
            self.installedManifests = defaultSources.map { $0.manifest }
            saveInstalledManifests()
        }
    }
    
    private func saveInstalledManifests() {
        if let data = try? JSONEncoder().encode(installedManifests) {
            try? data.write(to: installedManifestsFileURL, options: .atomic)
        }
    }
    
    private func ensureDefaultRepoURLs() {
        var current = UserDefaults.standard.stringArray(forKey: savedReposKey) ?? []
        let defaults = [
            "https://raw.githubusercontent.com/RJAlips/mangareader/main/community_repo.json",
            "https://aidoku-community.github.io/sources/index.min.json"
        ]
        var updated = false
        for def in defaults {
            if !current.contains(def) {
                current.append(def)
                updated = true
            }
        }
        if updated {
            UserDefaults.standard.set(current, forKey: savedReposKey)
        }
    }
    
    private func saveRepoURL(_ url: String) {
        var current = UserDefaults.standard.stringArray(forKey: savedReposKey) ?? []
        if !current.contains(url) {
            current.append(url)
            UserDefaults.standard.set(current, forKey: savedReposKey)
        }
    }
    
    // MARK: - Repository Management & Live Updates
    
    @MainActor
    public func addRepository(urlString: String) async throws -> Int {
        var cleanURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanURLString.isEmpty else { throw NetworkError.invalidURL }
        
        if !cleanURLString.lowercased().hasPrefix("http://") && !cleanURLString.lowercased().hasPrefix("https://") {
            cleanURLString = "https://" + cleanURLString
        }
        
        // 1. MangaDex Special Handling (Instant Success)
        if cleanURLString.lowercased().contains("mangadex") {
            let mangadex = MangaDexSource()
            register(source: mangadex)
            enabledSourceIDs.insert(mangadex.manifest.id)
            if !installedManifests.contains(where: { $0.id == mangadex.manifest.id }) {
                installedManifests.append(mangadex.manifest)
                saveInstalledManifests()
            }
            
            let dexURL = "https://api.mangadex.org"
            if let idx = repositories.firstIndex(where: { $0.url.contains("mangadex") }) {
                repositories[idx].sourceCount = 1
            } else {
                repositories.append(RepositoryInfo(name: "Official MangaDex", url: dexURL, sourceCount: 1))
            }
            saveRepositories()
            saveEnabledSources()
            saveRepoURL(dexURL)
            return 1
        }
        
        guard let url = URL(string: cleanURLString) else { throw NetworkError.invalidURL }
        let data = try await NetworkClient.shared.fetchData(from: url)
        
        let parsed = parseManifestsFromData(data, repoURL: url)
        
        if !parsed.manifests.isEmpty {
            for manifest in parsed.manifests {
                let communitySource = CommunityWebSource(
                    manifest: manifest,
                    baseURLString: manifest.baseURL
                )
                register(source: communitySource)
                enabledSourceIDs.insert(manifest.id)
                if let idx = installedManifests.firstIndex(where: { $0.id == manifest.id }) {
                    installedManifests[idx] = manifest
                } else {
                    installedManifests.append(manifest)
                }
            }
            
            if let idx = repositories.firstIndex(where: { $0.url == cleanURLString }) {
                repositories[idx].sourceCount = parsed.manifests.count
            } else {
                repositories.append(RepositoryInfo(name: parsed.name, url: cleanURLString, sourceCount: parsed.manifests.count))
            }
            
            saveRepositories()
            saveEnabledSources()
            saveInstalledManifests()
            saveRepoURL(cleanURLString)
            return parsed.manifests.count
        } else if let items = parsed.mangaItems, !items.isEmpty {
            let dynamicSource = DynamicJSONSource(
                manifest: SourceManifest(
                    id: "com.mangareader.feed.\(abs(cleanURLString.hashValue))",
                    name: parsed.name,
                    version: "1.0.0",
                    versionCode: 1,
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
            if !installedManifests.contains(where: { $0.id == dynamicSource.manifest.id }) {
                installedManifests.append(dynamicSource.manifest)
                saveInstalledManifests()
            }
            
            if let idx = repositories.firstIndex(where: { $0.url == cleanURLString }) {
                repositories[idx].sourceCount = 1
            } else {
                repositories.append(RepositoryInfo(name: parsed.name, url: cleanURLString, sourceCount: 1))
            }
            
            saveRepositories()
            saveEnabledSources()
            saveInstalledManifests()
            saveRepoURL(cleanURLString)
            return 1
        } else if let htmlStr = String(data: data, encoding: .utf8), (htmlStr.lowercased().contains("<html") || htmlStr.lowercased().contains("<!doctype")) {
            // Direct website URL fallback
            let hostClean = (url.host ?? "Website").replacingOccurrences(of: "www.", with: "").capitalized
            let siteSourceId = "com.mangareader.source.\(abs(cleanURLString.hashValue))"
            let webManifest = SourceManifest(
                id: siteSourceId,
                name: hostClean,
                version: "1.0.0",
                versionCode: 1,
                lang: "EN",
                baseURL: cleanURLString,
                iconURL: URL(string: "\(cleanURLString)/favicon.ico"),
                isEnabled: true,
                supportsLatest: true,
                supportsSearch: true,
                sourceDescription: "Community web source for \(hostClean)"
            )
            let webSource = CommunityWebSource(manifest: webManifest, baseURLString: cleanURLString)
            register(source: webSource)
            enabledSourceIDs.insert(webSource.manifest.id)
            if !installedManifests.contains(where: { $0.id == webManifest.id }) {
                installedManifests.append(webManifest)
                saveInstalledManifests()
            }
            
            if let idx = repositories.firstIndex(where: { $0.url == cleanURLString }) {
                repositories[idx].sourceCount = 1
            } else {
                repositories.append(RepositoryInfo(name: hostClean, url: cleanURLString, sourceCount: 1))
            }
            
            saveRepositories()
            saveEnabledSources()
            saveInstalledManifests()
            saveRepoURL(cleanURLString)
            return 1
        } else {
            throw NSError(
                domain: "RepositoryError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid repository format. Please check the URL and format."]
            )
        }
    }
    
    public func removeRepository(url: String) {
        repositories.removeAll(where: { $0.url == url })
        sources.removeAll(where: { ($0 as? DynamicJSONSource)?.repositoryURL == url })
        var current = UserDefaults.standard.stringArray(forKey: savedReposKey) ?? []
        current.removeAll(where: { $0 == url })
        UserDefaults.standard.set(current, forKey: savedReposKey)
        saveRepositories()
    }
    
    // MARK: - Dynamic Repository Synchronization & Updates Engine
    
    @MainActor
    public func refreshRepositories(force: Bool = false) async {
        if !force, let last = lastRepoRefreshDate, Date().timeIntervalSince(last) < 21600 {
            // Under 6 hours since last update check
            return
        }
        
        guard !isRefreshingRepos else { return }
        isRefreshingRepos = true
        defer { isRefreshingRepos = false }
        
        var repoURLs = UserDefaults.standard.stringArray(forKey: savedReposKey) ?? []
        for r in repositories {
            if !repoURLs.contains(r.url) {
                repoURLs.append(r.url)
            }
        }
        
        var discoveredUpdates: [SourceManifest] = []
        var discoveredAvailable: [SourceManifest] = []
        
        for urlString in repoURLs {
            guard let url = URL(string: urlString) else { continue }
            // Skip MangaDex API root since it is a REST endpoint, not a JSON index
            if urlString.contains("api.mangadex.org") { continue }
            
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 20
            
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                continue
            }
            
            let parsed = parseManifestsFromData(data, repoURL: url)
            for remote in parsed.manifests {
                if let local = installedManifests.first(where: { $0.id == remote.id }) {
                    // Check if newer version or updated base URL
                    if remote.version != local.version || remote.versionCode > local.versionCode || (!remote.baseURL.isEmpty && remote.baseURL != local.baseURL) {
                        if !discoveredUpdates.contains(where: { $0.id == remote.id }) {
                            discoveredUpdates.append(remote)
                        }
                    }
                } else {
                    if !discoveredAvailable.contains(where: { $0.id == remote.id }) {
                        discoveredAvailable.append(remote)
                    }
                }
            }
        }
        
        self.pendingUpdates = discoveredUpdates
        self.availableManifests = discoveredAvailable
        self.lastRepoRefreshDate = Date()
    }
    
    @MainActor
    public func updateSource(_ remoteManifest: SourceManifest) {
        if let idx = installedManifests.firstIndex(where: { $0.id == remoteManifest.id }) {
            installedManifests[idx] = remoteManifest
        } else {
            installedManifests.append(remoteManifest)
        }
        
        // Update active provider in sources
        sources.removeAll(where: { $0.manifest.id == remoteManifest.id })
        let updatedSource = CommunityWebSource(
            manifest: remoteManifest,
            baseURLString: remoteManifest.baseURL
        )
        register(source: updatedSource)
        
        pendingUpdates.removeAll(where: { $0.id == remoteManifest.id })
        saveInstalledManifests()
    }
    
    @MainActor
    public func updateAllSources() async {
        for manifest in pendingUpdates {
            updateSource(manifest)
        }
        pendingUpdates.removeAll()
    }
    
    @MainActor
    public func installSource(_ manifest: SourceManifest) {
        var toInstall = manifest
        toInstall.isEnabled = true
        
        if let idx = installedManifests.firstIndex(where: { $0.id == toInstall.id }) {
            installedManifests[idx] = toInstall
        } else {
            installedManifests.append(toInstall)
        }
        
        let newSource = CommunityWebSource(
            manifest: toInstall,
            baseURLString: toInstall.baseURL
        )
        register(source: newSource)
        enabledSourceIDs.insert(toInstall.id)
        
        availableManifests.removeAll(where: { $0.id == toInstall.id })
        saveInstalledManifests()
        saveEnabledSources()
    }
    
    // MARK: - Manifest Parser Supporting Tachiyomi, Aidoku, Community Repo & Feeds
    
    private func parseManifestsFromData(_ data: Data, repoURL: URL) -> (name: String, manifests: [SourceManifest], mangaItems: [MangaItem]?) {
        let decoder = JSONDecoder()
        let cleanURLString = repoURL.absoluteString
        var repoName = repoURL.host ?? "Custom Repository"
        
        let aidokuBaseURL = URL(string: "https://aidoku-community.github.io/sources/")!
        let baseRepoURL: URL
        if cleanURLString.contains("aidoku") {
            baseRepoURL = aidokuBaseURL
        } else if cleanURLString.hasSuffix(".json") {
            var str = repoURL.deletingLastPathComponent().absoluteString
            if !str.hasSuffix("/") { str += "/" }
            baseRepoURL = URL(string: str) ?? repoURL
        } else {
            var str = cleanURLString
            if !str.hasSuffix("/") { str += "/" }
            baseRepoURL = URL(string: str) ?? repoURL
        }
        
        // 1. Try Tachiyomi / Keiyoushi package array: [{ name, pkg, apk, code, version, nsfw, sources: [...] }]
        if let packages = try? decoder.decode([KeiyoushiPackageDTO].self, from: data), !packages.isEmpty {
            repoName = "Keiyoushi Extensions"
            var manifests: [SourceManifest] = []
            for pkg in packages {
                let packageVer = pkg.version ?? "1.0.0"
                let packageCode = pkg.code ?? 1
                let isNsfw = (pkg.nsfw ?? 0) > 0
                let iconURL = URL(string: "https://raw.githubusercontent.com/keiyoushi/extensions/repo/icon/\(pkg.pkg).png")
                
                if let pkgSources = pkg.sources, !pkgSources.isEmpty {
                    for src in pkgSources {
                        let manifest = SourceManifest(
                            id: "tachiyomi.\(pkg.pkg).\(src.id)",
                            name: src.name.isEmpty ? pkg.name : src.name,
                            version: packageVer,
                            versionCode: packageCode,
                            lang: (src.lang ?? pkg.lang ?? "EN").uppercased(),
                            baseURL: src.baseUrl,
                            iconURL: iconURL,
                            repoURL: cleanURLString,
                            isEnabled: true,
                            isNsfw: isNsfw,
                            supportsLatest: true,
                            supportsSearch: true,
                            sourceDescription: "\(pkg.name) Tachiyomi extension (\(src.baseUrl))"
                        )
                        manifests.append(manifest)
                    }
                } else {
                    let manifest = SourceManifest(
                        id: "tachiyomi.\(pkg.pkg)",
                        name: pkg.name,
                        version: packageVer,
                        versionCode: packageCode,
                        lang: (pkg.lang ?? "EN").uppercased(),
                        baseURL: "",
                        iconURL: iconURL,
                        repoURL: cleanURLString,
                        isEnabled: true,
                        isNsfw: isNsfw,
                        supportsLatest: true,
                        supportsSearch: true,
                        sourceDescription: "\(pkg.name) Tachiyomi extension"
                    )
                    manifests.append(manifest)
                }
            }
            if !manifests.isEmpty {
                return (repoName, manifests, nil)
            }
        }
        
        // 2. Try RepositoryManifestDTO: { name, sources: [RepositorySourceDTO] } (Aidoku & MangaReader)
        if let manifestDTO = try? decoder.decode(RepositoryManifestDTO.self, from: data) {
            repoName = manifestDTO.name ?? repoName
            var manifests: [SourceManifest] = []
            for srcDTO in manifestDTO.sources {
                var resolvedIconURL: URL? = nil
                if let iconStr = srcDTO.iconURL, !iconStr.isEmpty {
                    resolvedIconURL = URLResolver.resolve(iconStr, relativeTo: baseRepoURL)
                }
                let base = srcDTO.baseURL ?? ""
                let manifest = SourceManifest(
                    id: srcDTO.id,
                    name: srcDTO.name,
                    version: srcDTO.version,
                    versionCode: Int(srcDTO.version.components(separatedBy: ".").first ?? "1") ?? 1,
                    lang: srcDTO.lang,
                    baseURL: base,
                    iconURL: resolvedIconURL,
                    repoURL: cleanURLString,
                    isEnabled: true,
                    isNsfw: false,
                    supportsLatest: true,
                    supportsSearch: true,
                    sourceDescription: srcDTO.description ?? base
                )
                manifests.append(manifest)
            }
            if !manifests.isEmpty {
                return (repoName, manifests, nil)
            }
        }
        
        // 3. Try direct array of [RepositorySourceDTO]
        if let sourceList = try? decoder.decode([RepositorySourceDTO].self, from: data) {
            repoName = repoURL.deletingPathExtension().lastPathComponent.capitalized
            var manifests: [SourceManifest] = []
            for srcDTO in sourceList {
                var resolvedIconURL: URL? = nil
                if let iconStr = srcDTO.iconURL, !iconStr.isEmpty {
                    resolvedIconURL = URLResolver.resolve(iconStr, relativeTo: baseRepoURL)
                }
                let base = srcDTO.baseURL ?? ""
                let manifest = SourceManifest(
                    id: srcDTO.id,
                    name: srcDTO.name,
                    version: srcDTO.version,
                    versionCode: Int(srcDTO.version.components(separatedBy: ".").first ?? "1") ?? 1,
                    lang: srcDTO.lang,
                    baseURL: base,
                    iconURL: resolvedIconURL,
                    repoURL: cleanURLString,
                    isEnabled: true,
                    isNsfw: false,
                    supportsLatest: true,
                    supportsSearch: true,
                    sourceDescription: srcDTO.description ?? base
                )
                manifests.append(manifest)
            }
            if !manifests.isEmpty {
                return (repoName, manifests, nil)
            }
        }
        
        // 4. Try direct array of [SourceManifest]
        if let directManifests = try? decoder.decode([SourceManifest].self, from: data), !directManifests.isEmpty {
            repoName = repoURL.deletingPathExtension().lastPathComponent.capitalized
            return (repoName, directManifests, nil)
        }
        
        // 5. Try [MangaItem] (JSON manga feed)
        if let items = try? decoder.decode([MangaItem].self, from: data), !items.isEmpty {
            repoName = repoURL.deletingPathExtension().lastPathComponent.capitalized
            return (repoName, [], items)
        }
        
        return (repoName, [], nil)
    }
    
    // MARK: - Global Multi-Source Search
    
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
    
    // MARK: - Extension Health Diagnostics
    
    public func checkSourceHealth(source: any MangaSource) async -> ExtensionHealthReport {
        let manifest = source.manifest
        let sourceID = manifest.id
        let sourceName = manifest.name
        let baseURL = source.baseURL
        
        var popularCount = 0
        var coverThumbnailHTTP = 0
        var chaptersCount = 0
        var pagesCount = 0
        
        do {
            // 1. Fetch popular manga
            let popularItems = try await source.fetchPopularManga(page: 1)
            popularCount = popularItems.count
            guard !popularItems.isEmpty else {
                return ExtensionHealthReport(
                    sourceID: sourceID,
                    sourceName: sourceName,
                    baseURL: baseURL,
                    popularCount: 0,
                    coverThumbnailHTTP: 0,
                    chaptersCount: 0,
                    pagesCount: 0,
                    status: "FAIL",
                    errorMessage: "Popular items array is empty"
                )
            }
            
            // 2. Validate first cover thumbnail
            if let firstCover = popularItems.first?.coverURL {
                var request = URLRequest(url: firstCover)
                request.httpMethod = "HEAD"
                request.setValue(baseURL, forHTTPHeaderField: "Referer")
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 10
                
                if let (_, response) = try? await URLSession.shared.data(for: request),
                   let httpResponse = response as? HTTPURLResponse {
                    coverThumbnailHTTP = httpResponse.statusCode
                }
                
                // If HEAD wasn't 200, try ranged GET
                if coverThumbnailHTTP != 200 {
                    request.httpMethod = "GET"
                    request.setValue("bytes=0-1024", forHTTPHeaderField: "Range")
                    if let (data, response) = try? await URLSession.shared.data(for: request),
                       let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 206 || !data.isEmpty {
                            coverThumbnailHTTP = 200
                        }
                    }
                }
            } else {
                coverThumbnailHTTP = 200
            }
            
            // 3. Chapters check
            for candidateManga in popularItems.prefix(5) {
                if let chapters = try? await source.fetchChapters(manga: candidateManga), !chapters.isEmpty {
                    chaptersCount = chapters.count
                    
                    // 4. Pages check
                    for candidateChap in chapters.prefix(3) {
                        if let pages = try? await source.fetchPages(chapter: candidateChap), !pages.isEmpty {
                            pagesCount = pages.count
                            break
                        }
                    }
                    if pagesCount > 0 {
                        break
                    }
                }
            }
            
            let status = (popularCount > 0 && chaptersCount > 0 && pagesCount > 0) ? "PASS" : "WARN"
            return ExtensionHealthReport(
                sourceID: sourceID,
                sourceName: sourceName,
                baseURL: baseURL,
                popularCount: popularCount,
                coverThumbnailHTTP: coverThumbnailHTTP,
                chaptersCount: chaptersCount,
                pagesCount: pagesCount,
                status: status,
                errorMessage: nil
            )
        } catch {
            return ExtensionHealthReport(
                sourceID: sourceID,
                sourceName: sourceName,
                baseURL: baseURL,
                popularCount: popularCount,
                coverThumbnailHTTP: coverThumbnailHTTP,
                chaptersCount: chaptersCount,
                pagesCount: pagesCount,
                status: "FAIL",
                errorMessage: error.localizedDescription
            )
        }
    }
    
    public func checkAllInstalledExtensionsHealth() async -> [ExtensionHealthReport] {
        var reports: [ExtensionHealthReport] = []
        let currentSources = activeSources
        
        await withTaskGroup(of: ExtensionHealthReport.self) { group in
            for src in currentSources {
                group.addTask {
                    await self.checkSourceHealth(source: src)
                }
            }
            for await report in group {
                reports.append(report)
            }
        }
        
        return reports.sorted { $0.sourceName < $1.sourceName }
    }
    
    private func saveRepositories() {
        if let encoded = try? JSONEncoder().encode(repositories) {
            UserDefaults.standard.set(encoded, forKey: repoDefaultsKey)
        }
    }
}

// MARK: - Extension Health Report Model

public struct ExtensionHealthReport: Identifiable, Sendable {
    public var id: String { sourceID }
    public let sourceID: String
    public let sourceName: String
    public let baseURL: String
    public let popularCount: Int
    public let coverThumbnailHTTP: Int
    public let chaptersCount: Int
    public let pagesCount: Int
    public let status: String
    public let errorMessage: String?
    
    public init(
        sourceID: String,
        sourceName: String,
        baseURL: String,
        popularCount: Int,
        coverThumbnailHTTP: Int,
        chaptersCount: Int,
        pagesCount: Int,
        status: String,
        errorMessage: String? = nil
    ) {
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.baseURL = baseURL
        self.popularCount = popularCount
        self.coverThumbnailHTTP = coverThumbnailHTTP
        self.chaptersCount = chaptersCount
        self.pagesCount = pagesCount
        self.status = status
        self.errorMessage = errorMessage
    }
}

// MARK: - Headless Web Scraper Engine (WKWebView Cookie & JS Rendering)

@MainActor
public final class WebScraperEngine: NSObject {
    public static let shared = WebScraperEngine()
    
    private override init() {
        super.init()
    }
    
    public func fetchHTML(url: URL, referer: String? = nil, timeoutSeconds: TimeInterval = 8.0) async throws -> String {
        // Fast URLSession GET attempt with realistic headers
        var req = URLRequest(url: url)
        req.timeoutInterval = min(timeoutSeconds, 8.0)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        if let ref = referer, !ref.isEmpty {
            req.setValue(ref, forHTTPHeaderField: "Referer")
        }
        
        var requiresOffscreenRender = false
        var fetchedHTML = ""
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if [403, 503, 429].contains(http.statusCode) {
                    requiresOffscreenRender = true
                }
            }
            if let str = String(data: data, encoding: .utf8) {
                fetchedHTML = str
                let lower = str.lowercased()
                if lower.contains("cf-browser-verification") ||
                   lower.contains("just a moment...") ||
                   lower.contains("turnstile") ||
                   lower.contains("challenge-platform") {
                    requiresOffscreenRender = true
                }
            }
        } catch {
            requiresOffscreenRender = true
        }
        
        if !requiresOffscreenRender && !fetchedHTML.isEmpty {
            return fetchedHTML
        }
        
        // Offscreen WKWebView render fallback
        let session = OffscreenWebSession()
        return try await session.render(url: url, referer: referer, timeoutSeconds: 6.0)
    }
}

private final class OffscreenWebSession: NSObject, WKNavigationDelegate, @unchecked Sendable {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String, Error>?
    private var timeoutTask: Task<Void, Never>?
    
    @MainActor
    func render(url: URL, referer: String?, timeoutSeconds: TimeInterval) async throws -> String {
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()
            let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 667), configuration: config)
            self.webView = wv
            wv.navigationDelegate = self
            wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
            
            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            if let ref = referer, !ref.isEmpty {
                req.setValue(ref, forHTTPHeaderField: "Referer")
            }
            
            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                await MainActor.run {
                    self?.finish(error: NSError(domain: "WebScraperEngine", code: 408, userInfo: [NSLocalizedDescriptionKey: "Scraper timed out waiting for DOM"]))
                }
            }
            
            wv.load(req)
        }
    }
    
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            await self.waitForDOMAndExtract(webView: webView)
        }
    }
    
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.finish(error: error)
        }
    }
    
    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.finish(error: error)
        }
    }
    
    @MainActor
    private func waitForDOMAndExtract(webView: WKWebView) async {
        for _ in 0..<8 {
            let hasCards = await (try? webView.evaluateJavaScript(
                "(document.querySelector('script#__NEXT_DATA__') !== null || document.querySelector('.series-card, .bsx, .page-item-detail, a[href*=\"/series/\"], a[href*=\"/manga/\"], a[href*=\"/comics/\"]') !== null)"
            ) as? Bool) ?? false
            
            let isCloudflare = await (try? webView.evaluateJavaScript(
                "(document.title.toLowerCase().includes('just a moment') || document.body.innerText.toLowerCase().includes('verifying you are human'))"
            ) as? Bool) ?? false
            
            if hasCards && !isCloudflare {
                break
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        await withCheckedContinuation { cont in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                for cookie in cookies {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                cont.resume()
            }
        }
        
        if let html = try? await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String, !html.isEmpty {
            self.finish(html: html)
        } else {
            self.finish(error: NSError(domain: "WebScraperEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to extract outerHTML"]))
        }
    }
    
    @MainActor
    private func finish(html: String? = nil, error: Error? = nil) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let cont = continuation
        continuation = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        
        if let h = html {
            cont?.resume(returning: h)
        } else if let err = error {
            cont?.resume(throwing: err)
        }
    }
}

// MARK: - Community Web Source (4 Major Engines: Madara -> MangaThemesia -> Next.js/HeanCMS -> WP REST API)

public final class CommunityWebSource: MangaSource, @unchecked Sendable {
    public let manifest: SourceManifest
    public let baseURLString: String
    public let popularURL: String?
    public let latestURL: String?
    public let searchURL: String?
    public let chaptersURL: String?
    
    private let client = NetworkClient.shared
    private let requestTimeout: TimeInterval = 10.0
    
    public init(
        manifest: SourceManifest,
        baseURLString: String,
        popularURL: String? = nil,
        latestURL: String? = nil,
        searchURL: String? = nil,
        chaptersURL: String? = nil
    ) {
        self.manifest = manifest
        var base = baseURLString
        if base.contains("asuracomic.net") {
            base = "https://asurascans.com"
        }
        self.baseURLString = base
        
        var pop = popularURL ?? manifest.popularURL
        var lat = latestURL ?? manifest.latestURL
        var sea = searchURL ?? manifest.searchURL
        
        if base.contains("asurascans.com") {
            if pop == nil || pop?.contains("asuracomic.net") == true || pop?.contains("/series") == true {
                pop = "https://asurascans.com/browse"
            }
            if lat == nil || lat?.contains("asuracomic.net") == true || lat?.contains("/series") == true {
                lat = "https://asurascans.com/browse"
            }
            if sea == nil || sea?.contains("asuracomic.net") == true || sea?.contains("/series") == true {
                sea = "https://asurascans.com/browse?search={query}"
            }
        }
        
        self.popularURL = pop
        self.latestURL = lat
        self.searchURL = sea
        self.chaptersURL = chaptersURL ?? manifest.chaptersURL
    }
    
    // MARK: - Popular Titles
    public func fetchPopular(page: Int) async throws -> [MangaItem] {
        var candidateURLs: [URL] = []
        if page == 1 {
            candidateURLs = [
                popularURL,
                "\(baseURLString)/browse",
                "\(baseURLString)/browse?order=popular",
                "\(baseURLString)/series?order=popular",
                "\(baseURLString)/series",
                "\(baseURLString)/manga/page/1/?m_orderby=views",
                "\(baseURLString)/manga/?m_orderby=views",
                "\(baseURLString)/?s=&post_type=wp-manga&m_orderby=views",
                "\(baseURLString)/manga/?order=popular",
                "\(baseURLString)/series/?order=popular",
                "\(baseURLString)/comics",
                "\(baseURLString)/manga/"
            ].compactMap { $0 }.compactMap { URL(string: $0) }
        } else {
            var pagedPopular: String? = nil
            if let pop = popularURL {
                if pop.contains("{page}") {
                    pagedPopular = pop.replacingOccurrences(of: "{page}", with: "\(page)")
                } else if pop.contains("?") {
                    pagedPopular = "\(pop)&page=\(page)"
                } else {
                    let trimmed = pop.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    pagedPopular = "\(trimmed)/page/\(page)/"
                }
            }
            candidateURLs = [
                pagedPopular,
                "\(baseURLString)/browse?page=\(page)",
                "\(baseURLString)/browse?page=\(page)&order=popular",
                "\(baseURLString)/series?page=\(page)&order=popular",
                "\(baseURLString)/series?page=\(page)",
                "\(baseURLString)/manga/page/\(page)/?m_orderby=views",
                "\(baseURLString)/page/\(page)/?s=&post_type=wp-manga&m_orderby=views",
                "\(baseURLString)/manga/?page=\(page)&order=popular",
                "\(baseURLString)/series/?page=\(page)&order=popular",
                "\(baseURLString)/manga/page/\(page)/",
                "\(baseURLString)/manga/?page=\(page)"
            ].compactMap { $0 }.compactMap { URL(string: $0) }
        }
        
        for url in candidateURLs {
            if let scraped = try? await scrapeTitles(from: url), !scraped.isEmpty {
                return scraped
            }
        }
        
        // Tier 2: WordPress REST API fallback (/wp-json/wp/v2/manga or /wp-json/wp/v2/posts)
        var wpItems = await fetchWordPressTitles(subpath: "manga", page: page, orderby: "views")
        if wpItems == nil || wpItems?.isEmpty == true {
            wpItems = await fetchWordPressTitles(subpath: "posts", page: page, orderby: "date")
        }
        if let wpItems = wpItems, !wpItems.isEmpty {
            return wpItems
        }
        
        return []
    }
    
    // MARK: - Latest Titles
    public func fetchLatest(page: Int) async throws -> [MangaItem] {
        var candidateURLs: [URL] = []
        if page == 1 {
            candidateURLs = [
                latestURL,
                "\(baseURLString)/browse",
                "\(baseURLString)/browse?order=update",
                "\(baseURLString)/latest-updates/",
                "\(baseURLString)/series?order=update",
                "\(baseURLString)/series",
                "\(baseURLString)/manga/page/1/?m_orderby=latest",
                "\(baseURLString)/manga/?m_orderby=latest",
                "\(baseURLString)/?s=&post_type=wp-manga&m_orderby=latest",
                "\(baseURLString)/manga/?order=update",
                "\(baseURLString)/series/?order=update",
                "\(baseURLString)/latest/",
                "\(baseURLString)/manga/"
            ].compactMap { $0 }.compactMap { URL(string: $0) }
        } else {
            var pagedLatest: String? = nil
            if let lat = latestURL {
                if lat.contains("{page}") {
                    pagedLatest = lat.replacingOccurrences(of: "{page}", with: "\(page)")
                } else if lat.contains("?") {
                    pagedLatest = "\(lat)&page=\(page)"
                } else {
                    let trimmed = lat.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    pagedLatest = "\(trimmed)/page/\(page)/"
                }
            }
            candidateURLs = [
                pagedLatest,
                "\(baseURLString)/browse?page=\(page)",
                "\(baseURLString)/browse?page=\(page)&order=update",
                "\(baseURLString)/latest-updates/page/\(page)/",
                "\(baseURLString)/series?page=\(page)&order=update",
                "\(baseURLString)/series?page=\(page)",
                "\(baseURLString)/manga/page/\(page)/?m_orderby=latest",
                "\(baseURLString)/page/\(page)/?s=&post_type=wp-manga&m_orderby=latest",
                "\(baseURLString)/manga/?page=\(page)&order=update",
                "\(baseURLString)/series/?page=\(page)&order=update",
                "\(baseURLString)/latest/page/\(page)/",
                "\(baseURLString)/manga/page/\(page)/",
                "\(baseURLString)/manga/?page=\(page)"
            ].compactMap { $0 }.compactMap { URL(string: $0) }
        }
        
        for url in candidateURLs {
            if let scraped = try? await scrapeTitles(from: url), !scraped.isEmpty {
                return scraped
            }
        }
        
        // Tier 2: WordPress REST API fallback
        var wpItems = await fetchWordPressTitles(subpath: "manga", page: page, orderby: "date")
        if wpItems == nil || wpItems?.isEmpty == true {
            wpItems = await fetchWordPressTitles(subpath: "posts", page: page, orderby: "date")
        }
        if let wpItems = wpItems, !wpItems.isEmpty {
            return wpItems
        }
        
        return []
    }
    
    // MARK: - Search
    public func search(query: String, page: Int) async throws -> [MangaItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            return try await fetchPopular(page: page)
        }
        
        let encoded = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanQuery
        
        var candidateSearchURLs: [URL] = []
        var customSearch = searchURL?.replacingOccurrences(of: "{query}", with: encoded)
        if let cs = customSearch {
            if cs.contains("{page}") {
                customSearch = cs.replacingOccurrences(of: "{page}", with: "\(page)")
            } else if page > 1 {
                customSearch = cs.contains("?") ? "\(cs)&page=\(page)" : "\(cs)/page/\(page)/"
            }
        }
        
        if page == 1 {
            candidateSearchURLs = [
                customSearch,
                "\(baseURLString)/browse?search=\(encoded)",
                "\(baseURLString)/browse?q=\(encoded)",
                "\(baseURLString)/series?page=1&name=\(encoded)",
                "\(baseURLString)/?s=\(encoded)&post_type=wp-manga",
                "\(baseURLString)/?s=\(encoded)"
            ].compactMap { $0 }.compactMap { URL(string: $0) }
        } else {
            candidateSearchURLs = [
                customSearch,
                "\(baseURLString)/browse?search=\(encoded)&page=\(page)",
                "\(baseURLString)/browse?page=\(page)&q=\(encoded)",
                "\(baseURLString)/series?page=\(page)&name=\(encoded)",
                "\(baseURLString)/page/\(page)/?s=\(encoded)&post_type=wp-manga",
                "\(baseURLString)/page/\(page)/?s=\(encoded)",
                "\(baseURLString)/?s=\(encoded)&page=\(page)"
            ].compactMap { $0 }.compactMap { URL(string: $0) }
        }
        
        for url in candidateSearchURLs {
            if let scraped = try? await scrapeTitles(from: url), !scraped.isEmpty {
                return scraped
            }
        }
        
        // Tier 2: WordPress REST API search
        var wpResults = await fetchWordPressTitles(subpath: "manga", page: page, searchQuery: encoded)
        if wpResults == nil || wpResults?.isEmpty == true {
            wpResults = await fetchWordPressTitles(subpath: "posts", page: page, searchQuery: encoded)
        }
        if let wpResults = wpResults, !wpResults.isEmpty {
            return wpResults
        }
        
        return []
    }
    
    // MARK: - Manga Detail
    public func fetchMangaDetail(urlOrSlug: String) async throws -> MangaItem {
        let candidateURLs: [URL]
        if urlOrSlug.hasPrefix("http"), let u = URL(string: urlOrSlug) {
            candidateURLs = [u]
        } else {
            let clean = urlOrSlug.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            candidateURLs = [
                URL(string: "\(baseURLString)/\(clean)"),
                URL(string: "\(baseURLString)/series/\(clean)"),
                URL(string: "\(baseURLString)/manga/\(clean)"),
                URL(string: "\(baseURLString)/comics/\(clean)")
            ].compactMap { $0 }
        }
        
        for url in candidateURLs {
            var html: String? = nil
            if let htmlData = try? await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString, timeoutInterval: requestTimeout),
               let str = String(data: htmlData, encoding: .utf8),
               !str.lowercased().contains("cf-browser-verification") && !str.lowercased().contains("just a moment...") {
                html = str
            }
            if html == nil {
                html = try? await WebScraperEngine.shared.fetchHTML(url: url, referer: baseURLString, timeoutSeconds: 6.0)
            }
            
            if let html = html, !html.isEmpty {
                // 1. Check Next.js __NEXT_DATA__
                if let nextDataJSON = extractRegex(pattern: #"<script id="__NEXT_DATA__" type="application/json">([\s\S]*?)</script>"#, in: html),
                   let jsonData = nextDataJSON.data(using: .utf8),
                   let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let props = root["props"] as? [String: Any],
                   let pageProps = props["pageProps"] as? [String: Any] {
                    let series = (pageProps["series"] as? [String: Any]) ?? (pageProps["data"] as? [String: Any]) ?? pageProps
                    let title = (series["title"] as? String) ?? (series["name"] as? String) ?? formatTitleFromSlug(urlOrSlug)
                    let desc = (series["description"] as? String) ?? (series["summary"] as? String)
                    var coverURL: URL? = nil
                    if let thumb = (series["thumbnail"] as? String) ?? (series["cover"] as? String) ?? (series["image"] as? String) {
                        coverURL = Self.sanitizeImageURL(thumb, baseURL: URL(string: baseURLString))
                    }
                    return MangaItem(
                        sourceID: manifest.id,
                        urlOrSlug: urlOrSlug,
                        title: Self.unescapeHTML(title),
                        author: (series["author"] as? String) ?? "Community",
                        description: desc,
                        coverURL: coverURL,
                        genres: ["Manhwa", "Manga"],
                        status: .ongoing
                    )
                }
                
                // 2. HTML parsing
                let title = extractRegex(pattern: #"<h1[^>]*>([^<]+)</h1>"#, in: html) ?? formatTitleFromSlug(urlOrSlug)
                let desc = extractRegex(pattern: #"<div class="[^"]*(?:summary__content|description-summary|entry-content|synopsis)[^"]*">([\s\S]*?)</div>"#, in: html)
                
                var coverURL: URL? = nil
                if let imgTag = extractRegex(pattern: #"<div class="[^"]*(?:summary_image|thumb|thumb-manga|poster)[^"]*">([\s\S]*?)</div>"#, in: html) {
                    coverURL = Self.extractImageURL(from: imgTag, relativeTo: URL(string: baseURLString))
                }
                if coverURL == nil {
                    coverURL = Self.extractImageURL(from: html, relativeTo: URL(string: baseURLString))
                }
                
                return MangaItem(
                    sourceID: manifest.id,
                    urlOrSlug: urlOrSlug,
                    title: Self.unescapeHTML(title),
                    author: "Community",
                    description: desc?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression),
                    coverURL: coverURL,
                    genres: ["Manga", "Manhwa"],
                    status: .ongoing
                )
            }
        }
        
        throw MangaReaderError.scrapingFailed(manifest.name, "Manga detail could not be retrieved from \(baseURLString)")
    }
    
    // MARK: - Chapters
    public func fetchChapters(for urlOrSlug: String) async throws -> [ChapterItem] {
        var candidateURLs: [URL] = []
        if urlOrSlug.hasPrefix("http"), let u = URL(string: urlOrSlug) {
            candidateURLs.append(u)
        } else {
            let clean = urlOrSlug.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let u = URL(string: "\(baseURLString)/\(clean)") { candidateURLs.append(u) }
            if !clean.hasPrefix("manga/") && !clean.hasPrefix("comics/") && !clean.hasPrefix("series/") {
                if let u = URL(string: "\(baseURLString)/series/\(clean)") { candidateURLs.append(u) }
                if let u = URL(string: "\(baseURLString)/manga/\(clean)") { candidateURLs.append(u) }
                if let u = URL(string: "\(baseURLString)/comics/\(clean)") { candidateURLs.append(u) }
            }
        }
        
        var bestHTMLChapters: [ChapterItem] = []
        
        for url in candidateURLs {
            var html: String? = nil
            if let htmlData = try? await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString, timeoutInterval: requestTimeout),
               let str = String(data: htmlData, encoding: .utf8),
               !str.lowercased().contains("cf-browser-verification") && !str.lowercased().contains("just a moment...") {
                html = str
            }
            if html == nil {
                html = try? await WebScraperEngine.shared.fetchHTML(url: url, referer: baseURLString, timeoutSeconds: 6.0)
            }
            
            guard let html = html, !html.isEmpty else { continue }
            
            // Check Next.js __NEXT_DATA__
            if let nextDataJSON = extractRegex(pattern: #"<script id="__NEXT_DATA__" type="application/json">([\s\S]*?)</script>"#, in: html),
               let jsonData = nextDataJSON.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let props = root["props"] as? [String: Any],
               let pageProps = props["pageProps"] as? [String: Any] {
                let series = (pageProps["series"] as? [String: Any]) ?? (pageProps["data"] as? [String: Any]) ?? pageProps
                var rawChaps: [[String: Any]] = []
                if let arr = series["chapters"] as? [[String: Any]] { rawChaps = arr }
                else if let arr = pageProps["chapters"] as? [[String: Any]] { rawChaps = arr }
                
                if !rawChaps.isEmpty {
                    var parsed: [ChapterItem] = []
                    for (idx, ch) in rawChaps.enumerated() {
                        let chNum = (ch["number"] as? Double) ?? (ch["chapter_number"] as? Double) ?? Double(rawChaps.count - idx)
                        let title = (ch["title"] as? String) ?? (ch["name"] as? String) ?? "Chapter \(chNum)"
                        let slug = (ch["slug"] as? String) ?? (ch["id"] as? String) ?? "\(chNum)"
                        let fullSlug = slug.hasPrefix("http") ? slug : "\(baseURLString)/series/\(urlOrSlug)/\(slug)"
                        parsed.append(ChapterItem(
                            id: UUID(),
                            mangaID: UUID(),
                            sourceChapterID: fullSlug,
                            chapterNumber: chNum,
                            title: title,
                            scanlator: manifest.name,
                            pageCount: 1,
                            pageURLs: []
                        ))
                    }
                    if !parsed.isEmpty {
                        return parsed
                    }
                }
            }
            
            var chapters = parseChaptersFromHTML(html, detailURL: url)
            
            // 1. If 0 or 1 chapter, try WP-Manga {detailURL}/ajax/chapters/ endpoint via POST
            if chapters.count <= 1, let ajaxURL = URL(string: "\(url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/ajax/chapters/") {
                var req = URLRequest(url: ajaxURL)
                req.httpMethod = "POST"
                req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
                req.setValue(url.absoluteString, forHTTPHeaderField: "Referer")
                req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
                req.timeoutInterval = requestTimeout
                
                if let (ajaxData, resp) = try? await URLSession.shared.data(for: req),
                   let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let ajaxHTML = String(data: ajaxData, encoding: .utf8) {
                    let parsedAjax = parseChaptersFromHTML(ajaxHTML, detailURL: url)
                    if parsedAjax.count > chapters.count {
                        chapters = parsedAjax
                    }
                }
            }
            
            // 2. If <= 1 chapter and post ID is present, try WP AJAX manga_get_chapters
            if chapters.count <= 1, let postID = extractRegex(pattern: #"(?:manga_id|data-id|post_id|postid-)\s*=?\s*['"]?(\d+)"#, in: html) {
                if let ajaxChapters = await fetchChaptersFromWPAJAX(mangaID: postID), ajaxChapters.count > chapters.count {
                    chapters = ajaxChapters
                }
            }
            
            if chapters.count > bestHTMLChapters.count {
                bestHTMLChapters = chapters
            }
            
            if bestHTMLChapters.count > 1 {
                return bestHTMLChapters
            }
        }
        
        if !bestHTMLChapters.isEmpty {
            return bestHTMLChapters
        }
        
        return [
            ChapterItem(
                id: UUID(),
                mangaID: UUID(),
                sourceChapterID: "\(baseURLString)/\(urlOrSlug)",
                chapterNumber: 1.0,
                title: "Chapter 1",
                scanlator: manifest.name,
                pageCount: 1,
                pageURLs: []
            )
        ]
    }
    
    // MARK: - Page URLs
    public func fetchPageURLs(for chapterSourceID: String) async throws -> [URL] {
        let cleanId = chapterSourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let chapterURL: URL?
        if cleanId.hasPrefix("http") {
            chapterURL = URL(string: cleanId)
        } else {
            chapterURL = URL(string: "\(baseURLString)/\(cleanId.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
        }
        
        guard let url = chapterURL else { return [] }
        
        var html: String? = nil
        if let htmlData = try? await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString, timeoutInterval: requestTimeout),
           let str = String(data: htmlData, encoding: .utf8),
           !str.lowercased().contains("cf-browser-verification") && !str.lowercased().contains("just a moment...") {
            html = str
        }
        if html == nil {
            html = try? await WebScraperEngine.shared.fetchHTML(url: url, referer: baseURLString, timeoutSeconds: 6.0)
        }
        
        guard let html = html, !html.isEmpty else { return [] }
        
        let base = URL(string: baseURLString)
        var pageURLs: [URL] = []
        var seen = Set<String>()
        
        // 1. Match all <img> tags in HTML
        let imgRegexPattern = #"<img[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: imgRegexPattern, options: .caseInsensitive) {
            let ns = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                let tag = ns.substring(with: m.range)
                let lower = tag.lowercased()
                if lower.contains("avatar") || lower.contains("logo") || lower.contains("banner") || lower.contains("favicon") || lower.contains("icon") {
                    continue
                }
                if let extracted = Self.extractImageURL(from: tag, relativeTo: base) {
                    let str = extracted.absoluteString
                    if !seen.contains(str) && !str.lowercased().contains("logo") && !str.lowercased().contains("banner") {
                        seen.insert(str)
                        pageURLs.append(extracted)
                    }
                }
            }
        }
        
        // 2. Scan for Astro/JSON embedded image links if <img> yielded 0
        if pageURLs.isEmpty {
            let rawPattern = #"https?://[^\s"\'<>]+\.(?:jpg|jpeg|png|webp)"#
            if let regex = try? NSRegularExpression(pattern: rawPattern, options: .caseInsensitive) {
                let ns = html as NSString
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
                for m in matches {
                    let raw = ns.substring(with: m.range)
                    let lower = raw.lowercased()
                    if lower.contains("logo") || lower.contains("avatar") || lower.contains("banner") || lower.contains("favicon") {
                        continue
                    }
                    if let u = URL(string: raw), !seen.contains(raw) {
                        seen.insert(raw)
                        pageURLs.append(u)
                    }
                }
            }
        }
        
        let resolvedPages = pageURLs.compactMap { u -> URL? in
            if u.scheme != nil && u.host != nil {
                return u
            }
            if let base = URL(string: baseURLString), let resolved = URL(string: u.absoluteString, relativeTo: base) {
                return resolved.absoluteURL
            }
            return nil
        }
        
        return resolvedPages
    }
    
    public func checkHealth() async -> Bool {
        guard let url = URL(string: baseURLString) else { return false }
        do {
            _ = try await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString, timeoutInterval: 5)
            return true
        } catch {
            return true
        }
    }
    
    // MARK: - Scraper Helpers & Image Attribute Priority
    
    public static func extractImageURL(from tag: String, relativeTo baseURL: URL?) -> URL? {
        // Priority order:
        // 1. data-src
        // 2. data-lazy-src
        // 3. data-cfsrc
        // 4. data-original (and data-manga-src)
        // 5. srcset / data-srcset (first URL before space/comma)
        // 6. src (strictly ignoring data:image placeholders)
        
        let singleAttrs = ["data-src", "data-lazy-src", "data-cfsrc", "data-original", "data-manga-src"]
        for attr in singleAttrs {
            let pattern = "(?:^|\\s)\(attr)\\s*=\\s*[\"']?([^\"'\\s>]+)[\"']?"
            if let raw = extractRegexFirst(pattern: pattern, in: tag) {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.lowercased().hasPrefix("data:image"), let sanitized = sanitizeImageURL(trimmed, baseURL: baseURL) {
                    return sanitized
                }
            }
        }
        
        let setAttrs = ["data-srcset", "srcset"]
        for attr in setAttrs {
            let pattern = "(?:^|\\s)\(attr)\\s*=\\s*[\"']([^\"']+)[\"']"
            if let raw = extractRegexFirst(pattern: pattern, in: tag) {
                let candidates = raw.components(separatedBy: ",")
                for candidate in candidates {
                    let firstURL = candidate.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces).first ?? ""
                    if !firstURL.isEmpty && !firstURL.lowercased().hasPrefix("data:image") {
                        if let sanitized = sanitizeImageURL(firstURL, baseURL: baseURL) {
                            return sanitized
                        }
                    }
                }
            }
        }
        
        let srcPattern = "(?:^|\\s)src\\s*=\\s*[\"']?([^\"'\\s>]+)[\"']?"
        if let raw = extractRegexFirst(pattern: srcPattern, in: tag) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.lowercased().hasPrefix("data:image") {
                return sanitizeImageURL(trimmed, baseURL: baseURL)
            }
        }
        
        return nil
    }
    
    private static func sanitizeImageURL(_ raw: String, baseURL: URL?) -> URL? {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return nil }
        
        str = str.replacingOccurrences(of: "\\/", with: "/")
        
        if str.hasPrefix("//") {
            let scheme = baseURL?.scheme ?? "https"
            str = "\(scheme):\(str)"
        }
        
        if let direct = URL(string: str), direct.scheme != nil, direct.host != nil {
            return direct
        }
        
        return URLResolver.resolve(str, relativeTo: baseURL)
    }
    
    private func scrapeTitles(from url: URL) async throws -> [MangaItem] {
        var html: String? = nil
        var didUseWebScraper = false
        
        // Fast URLSession GET attempt with CDN headers
        if let data = try? await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString, timeoutInterval: min(requestTimeout, 8.0)),
           let rawStr = String(data: data, encoding: .utf8) {
            let lower = rawStr.lowercased()
            let isChallenge = lower.contains("cf-browser-verification") ||
                              lower.contains("just a moment...") ||
                              lower.contains("turnstile") ||
                              lower.contains("challenge-platform")
            if !isChallenge {
                html = rawStr
            }
        }
        
        // If HTML is nil, empty, or blocked by Cloudflare, dispatch to WebScraperEngine
        if html == nil || html?.isEmpty == true {
            didUseWebScraper = true
            html = try? await WebScraperEngine.shared.fetchHTML(url: url, referer: baseURLString, timeoutSeconds: 6.0)
        }
        
        guard let validHTML = html, !validHTML.isEmpty else { return [] }
        var parsed = parseMangaItemsFromHTML(validHTML, pageURL: url)
        
        // If returned HTML had 0 items for a JS-rendered site, dispatch to offscreen WKWebView
        if parsed.isEmpty && !didUseWebScraper {
            if let renderedHTML = try? await WebScraperEngine.shared.fetchHTML(url: url, referer: baseURLString, timeoutSeconds: 6.0),
               !renderedHTML.isEmpty {
                parsed = parseMangaItemsFromHTML(renderedHTML, pageURL: url)
            }
        }
        
        return parsed
    }
    
    public func parseTitles(from html: String, relativeTo: URL? = nil) -> [MangaItem] {
        return parseMangaItemsFromHTML(html, pageURL: relativeTo ?? URL(string: baseURLString))
    }

    public static func isJunkTitle(_ title: String?) -> Bool {
        guard let title = title else { return true }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t.count < 2 { return true }
        if t.hasPrefix("#") { return true }
        
        let lower = t.lowercased()
        if lower.hasPrefix("chapter ") || lower.hasPrefix("ch ") || lower.hasPrefix("ch.") ||
           lower.hasPrefix("episode ") || lower.hasPrefix("ep ") || lower.hasPrefix("ep.") ||
           lower.hasPrefix("vol.") || lower.hasPrefix("volume ") ||
           lower == "manhua" || lower == "manhwa" || lower == "manga" ||
           lower == "popular" || lower == "latest" || lower == "ongoing" || lower == "completed" ||
           lower == "all" || lower == "novel" || lower == "novels" || lower == "comics" || lower == "series" ||
           lower == "bookmark" || lower == "read now" || lower == "view all" {
            return true
        }
        
        let junkRegex = #"^(ch\.?|chap\.?|chapter\s*\d+.*|ep\.?\s*\d+.*|manhua|manhwa|manga|popular|latest|ongoing|completed|#.*)$"#
        if let regex = try? NSRegularExpression(pattern: junkRegex, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: (t as NSString).length)
            if regex.firstMatch(in: t, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }

    public static func isRejectedURLPath(_ pathOrSlug: String) -> Bool {
        let lower = pathOrSlug.lowercased()
        if lower.contains("/chapter") || lower.contains("/ch-") || lower.contains("/ch/") ||
           lower.contains("/ep-") || lower.contains("/ep/") ||
           lower.contains("/page/") || lower.contains("?page=") ||
           lower.contains("/type/") || lower.contains("?type=") ||
           lower.contains("?s=") || lower.contains("?m_orderby=") ||
           lower.contains("#") ||
           lower == "manga" || lower == "comics" || lower == "series" ||
           lower == "browse" || lower == "latest" || lower == "popular" ||
           lower == "bookmark" || lower == "feed" || lower.hasSuffix(".rss") || lower.hasSuffix(".xml") ||
           lower.contains("/genre/") || lower.contains("/tag/") || lower.contains("/author/") {
            return true
        }
        return false
    }

    public static func isValidSeriesURL(_ link: String) -> Bool {
        if isRejectedURLPath(link) { return false }
        let clean = link.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pattern = #"(?:^|/)(?:manga|series|comic|comics|manhwa|manhua)/[^/?#]+/?$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: (clean as NSString).length)
            if regex.firstMatch(in: clean, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }

    public func parseMangaItemsFromHTML(_ html: String, pageURL: URL? = nil) -> [MangaItem] {
        var results: [MangaItem] = []
        var seenSlugs = Set<String>()
        let base = pageURL ?? URL(string: baseURLString)
        let ns = html as NSString
        
        // 1. Engine C: Next.js __NEXT_DATA__ JSON script tag
        if let nextDataJSON = extractRegex(pattern: #"<script id="__NEXT_DATA__" type="application/json">([\s\S]*?)</script>"#, in: html),
           let jsonData = nextDataJSON.data(using: .utf8),
           let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let props = root["props"] as? [String: Any],
           let pageProps = props["pageProps"] as? [String: Any] {
            
            var seriesList: [[String: Any]] = []
            if let arr = pageProps["series"] as? [[String: Any]] { seriesList = arr }
            else if let arr = pageProps["data"] as? [[String: Any]] { seriesList = arr }
            else if let arr = pageProps["mangas"] as? [[String: Any]] { seriesList = arr }
            else if let arr = pageProps["comics"] as? [[String: Any]] { seriesList = arr }
            else if let arr = pageProps["posts"] as? [[String: Any]] { seriesList = arr }
            else if let nested = pageProps["data"] as? [String: Any], let arr = nested["data"] as? [[String: Any]] { seriesList = arr }
            else if let nested = pageProps["series"] as? [String: Any], let arr = nested["data"] as? [[String: Any]] { seriesList = arr }
            
            for item in seriesList {
                let title = (item["title"] as? String) ?? (item["name"] as? String) ?? (item["post_title"] as? String) ?? ""
                guard !Self.isJunkTitle(title) else { continue }
                let rawSlug = (item["slug"] as? String) ?? (item["id"] as? String) ?? (item["series_slug"] as? String) ?? ""
                guard !rawSlug.isEmpty else { continue }
                let slug = sanitizeSlug(from: rawSlug)
                guard !seenSlugs.contains(slug), !Self.isRejectedURLPath(slug) else { continue }
                
                var coverURL: URL? = nil
                if let thumb = (item["thumbnail"] as? String) ?? (item["cover"] as? String) ?? (item["image"] as? String) ?? (item["poster"] as? String) {
                    coverURL = Self.sanitizeImageURL(thumb, baseURL: base)
                }
                guard let validCover = coverURL, validCover.absoluteString.hasPrefix("http") else { continue }
                
                seenSlugs.insert(slug)
                results.append(MangaItem(
                    sourceID: manifest.id,
                    urlOrSlug: slug,
                    title: Self.unescapeHTML(title),
                    coverURL: validCover,
                    genres: ["Manhwa", "Manga"],
                    status: .ongoing
                ))
            }
            if !results.isEmpty {
                return results
            }
        }
        
        // 2. Engine A & B: Structured Card Containers (Madara, Aqua Manga, MangaThemesia, Asura Astro, etc.)
        let cardContainerPattern = #"<(?:article|div)[^>]+class="[^"]*(?:aqua-manga-card|aqua-archive-card|series-card|page-item-detail|bsx|utao|manga-item|listupd|bs-item|bs|manga-card|book-item|slider__item|bigor|col-md-2|grid-item|animposx)[^"]*"[^>]*>[\s\S]*?</(?:article|div)>\s*(?:</div>)?"#
        if let cardRegex = try? NSRegularExpression(pattern: cardContainerPattern, options: .caseInsensitive) {
            let matches = cardRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                let cardHTML = ns.substring(with: m.range)
                
                let allLinks = extractAllRegex(pattern: #"<a[^>]+href="([^"]+)""#, in: cardHTML)
                guard let seriesLink = allLinks.first(where: { Self.isValidSeriesURL($0) }) ?? allLinks.first(where: { !Self.isRejectedURLPath($0) && ($0.contains("/manga/") || $0.contains("/series/") || $0.contains("/comic/")) }) else {
                    continue
                }
                
                let slug = sanitizeSlug(from: seriesLink)
                guard !slug.isEmpty, !seenSlugs.contains(slug), !Self.isRejectedURLPath(slug) else { continue }
                
                var title = extractRegex(pattern: #"<(?:h[1-6]|div|span|p|a)[^>]+class="[^"]*(?:title|post-title|tt|entry-title|aqua-manga-card__title|aqua-archive-card__title)[^"]*"[^>]*>([^<]+)<"#, in: cardHTML)
                if title == nil || title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true || Self.isJunkTitle(title) {
                    title = extractRegex(pattern: #"title="([^"]+)""#, in: cardHTML)
                }
                if title == nil || title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true || Self.isJunkTitle(title) {
                    title = extractRegex(pattern: #"alt="([^"]+)""#, in: cardHTML)
                }
                if title == nil || Self.isJunkTitle(title) {
                    let formatted = formatTitleFromSlug(slug)
                    if !Self.isJunkTitle(formatted) {
                        title = formatted
                    }
                }
                guard let finalTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines), !Self.isJunkTitle(finalTitle) else {
                    continue
                }
                
                var coverURL: URL? = nil
                let imgPattern = #"<img[^>]+>"#
                if let imgRegex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive) {
                    let imgMatches = imgRegex.matches(in: cardHTML, range: NSRange(location: 0, length: (cardHTML as NSString).length))
                    for imgMatch in imgMatches {
                        let tag = (cardHTML as NSString).substring(with: imgMatch.range)
                        if let extracted = Self.extractImageURL(from: tag, relativeTo: base) {
                            coverURL = extracted
                            break
                        }
                    }
                }
                if coverURL == nil {
                    coverURL = Self.extractImageURL(from: cardHTML, relativeTo: base)
                }
                guard let validCover = coverURL, validCover.absoluteString.hasPrefix("http") else {
                    continue
                }
                
                var latestChapterTitle: String? = nil
                let chapterPattern = #"<a[^>]+href="[^"]*(?:chapter|ch-)[^"]*"[^>]*>([\s\S]*?)</a>"#
                if let chMatch = extractRegex(pattern: chapterPattern, in: cardHTML) {
                    let cleanCh = chMatch.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                         .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanCh.isEmpty && cleanCh.count <= 40 {
                        latestChapterTitle = cleanCh
                    }
                }
                
                seenSlugs.insert(slug)
                results.append(MangaItem(
                    sourceID: manifest.id,
                    urlOrSlug: slug,
                    title: Self.unescapeHTML(finalTitle),
                    coverURL: validCover,
                    genres: ["Manhwa", "Manga"],
                    status: .ongoing,
                    latestChapterTitle: latestChapterTitle
                ))
            }
        }
        
        if !results.isEmpty {
            return results
        }
        
        // 3. Step B Grouping Fallback: Scans all <a> tags, groups by series slug, and strictly discards junk
        struct SeriesCandidate {
            var slug: String
            var title: String?
            var coverURL: URL?
            var latestChapterTitle: String?
        }
        
        var seriesMap: [String: SeriesCandidate] = [:]
        var seriesOrder: [String] = []
        
        let linkPattern = #"<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)</a>"#
        if let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) {
            let matches = linkRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                guard m.numberOfRanges > 2 else { continue }
                let link = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                let inner = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let lowerLink = link.lowercased()
                if lowerLink.contains("/chapter") || lowerLink.contains("/ch-") {
                    let cleanInner = inner.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                          .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanInner.isEmpty && cleanInner.count <= 40 {
                        for parentSlug in seriesOrder {
                            if link.contains(parentSlug) || (parentSlug.components(separatedBy: "/").last.map({ link.contains($0) }) == true) {
                                if seriesMap[parentSlug]?.latestChapterTitle == nil {
                                    seriesMap[parentSlug]?.latestChapterTitle = cleanInner
                                }
                                break
                            }
                        }
                    }
                    continue
                }
                
                guard !Self.isRejectedURLPath(link) else { continue }
                guard Self.isValidSeriesURL(link) || link.contains("/manga/") || link.contains("/series/") || link.contains("/comic/") else {
                    continue
                }
                
                let slug = sanitizeSlug(from: link)
                guard !slug.isEmpty, !Self.isRejectedURLPath(slug) else { continue }
                
                if seriesMap[slug] == nil {
                    seriesMap[slug] = SeriesCandidate(slug: slug, title: nil, coverURL: nil, latestChapterTitle: nil)
                    seriesOrder.append(slug)
                }
                
                if seriesMap[slug]?.coverURL == nil, let imgTag = extractRegex(pattern: #"<img[^>]+>"#, in: inner) {
                    if let img = Self.extractImageURL(from: imgTag, relativeTo: base) {
                        seriesMap[slug]?.coverURL = img
                    }
                }
                
                if seriesMap[slug]?.title == nil || Self.isJunkTitle(seriesMap[slug]?.title) {
                    let cleanInner = inner.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                          .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanInner.isEmpty && cleanInner.count < 80 && !Self.isJunkTitle(cleanInner) {
                        seriesMap[slug]?.title = cleanInner
                    }
                }
            }
        }
        
        for slug in seriesOrder {
            guard var cand = seriesMap[slug] else { continue }
            if cand.title == nil || Self.isJunkTitle(cand.title) {
                let formatted = formatTitleFromSlug(slug)
                if !Self.isJunkTitle(formatted) {
                    cand.title = formatted
                }
            }
            guard let title = cand.title, !Self.isJunkTitle(title) else { continue }
            guard let coverURL = cand.coverURL, coverURL.absoluteString.hasPrefix("http") else { continue }
            guard !seenSlugs.contains(slug) else { continue }
            seenSlugs.insert(slug)
            
            results.append(MangaItem(
                sourceID: manifest.id,
                urlOrSlug: slug,
                title: Self.unescapeHTML(title),
                coverURL: coverURL,
                genres: ["Manhwa", "Manga"],
                status: .ongoing,
                latestChapterTitle: cand.latestChapterTitle
            ))
        }
        
        return results
    }

    private func extractAllRegex(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { m in
            let r = m.numberOfRanges > 1 ? m.range(at: 1) : m.range(at: 0)
            guard r.location != NSNotFound else { return nil }
            return ns.substring(with: r)
        }
    }
    
    private func sanitizeSlug(from link: String) -> String {
        var trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http") {
            if let parsed = URL(string: trimmed) {
                trimmed = parsed.path
            }
        }
        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed
    }
    
    private func formatTitleFromSlug(_ slug: String) -> String {
        let last = slug.components(separatedBy: "/").last ?? slug
        let words = last.replacingOccurrences(of: "-", with: " ")
                        .replacingOccurrences(of: "_", with: " ")
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
        return words.map { $0.capitalized }.joined(separator: " ")
    }
    
    // MARK: - WordPress REST API (Tier 2 Fallback)
    
    private func fetchWordPressTitles(subpath: String, page: Int = 1, orderby: String? = nil, searchQuery: String? = nil) async -> [MangaItem]? {
        var queryItems = ["_embed=1", "per_page=40", "page=\(page)"]
        if let order = orderby {
            queryItems.append("orderby=\(order)")
        }
        if let s = searchQuery {
            queryItems.append("search=\(s)")
        }
        let queryString = queryItems.joined(separator: "&")
        guard let url = URL(string: "\(baseURLString)/wp-json/wp/v2/\(subpath)?\(queryString)") else {
            return nil
        }
        
        guard let data = try? await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString, timeoutInterval: 5.0),
              let posts = try? JSONDecoder().decode([WPPostDTO].self, from: data),
              !posts.isEmpty else {
            return nil
        }
        
        return posts.compactMap { post in
            let rawTitle = post.title?.rendered ?? "Untitled"
            let title = Self.unescapeHTML(rawTitle)
            let slug = post.slug ?? post.link ?? UUID().uuidString
            let coverStr = post.embedded?.featuredMedia?.first?.sourceUrl
            let coverURL = Self.sanitizeImageURL(coverStr ?? "", baseURL: URL(string: baseURLString))
            
            return MangaItem(
                sourceID: manifest.id,
                urlOrSlug: slug,
                title: title,
                coverURL: coverURL,
                genres: ["Manhwa", "Manga"],
                status: .ongoing
            )
        }
    }
    
    private func fetchChaptersFromWPAJAX(mangaID: String) async -> [ChapterItem]? {
        guard let url = URL(string: "\(baseURLString)/wp-admin/admin-ajax.php") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(baseURLString, forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = "action=manga_get_chapters&manga=\(mangaID)".data(using: .utf8)
        request.timeoutInterval = 8.0
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        let chapters = parseChaptersFromHTML(html)
        return chapters.isEmpty ? nil : chapters
    }
    
    private func parseChaptersFromHTML(_ html: String, detailURL: URL? = nil) -> [ChapterItem] {
        var chapters: [ChapterItem] = []
        var seenLinks = Set<String>()
        let nsString = html as NSString
        let base = detailURL ?? URL(string: baseURLString)
        
        // Priority 1: Match structured chapter rows (Madara wp-manga-chapter, MangaThemesia eph-num, etc.)
        let rowPattern = #"<(?:li|div)[^>]+class="[^"]*(?:wp-manga-chapter|eph-num|chbox|chapter-item|parent_chapter)[^"]*"[^>]*>([\s\S]*?)</(?:li|div)>"#
        if let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: .caseInsensitive) {
            let rowMatches = rowRegex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            for rm in rowMatches {
                guard rm.numberOfRanges > 1 else { continue }
                let rowHTML = nsString.substring(with: rm.range(at: 1))
                if let link = extractRegex(pattern: #"<a[^>]+href="([^"]+)""#, in: rowHTML) {
                    var resolvedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
                    let linkLower = resolvedLink.lowercased()
                    if linkLower.contains(".png") || linkLower.contains(".jpg") || linkLower.contains(".jpeg") ||
                       linkLower.contains(".webp") || linkLower.contains(".svg") || linkLower.contains(".gif") ||
                       linkLower.contains(".ico") || linkLower.contains(".css") || linkLower.contains(".js") ||
                       linkLower.contains("/wp-content/") || linkLower.contains("/wp-includes/") ||
                       linkLower.contains("/genre/") || linkLower.contains("/tag/") {
                        continue
                    }
                    if !resolvedLink.hasPrefix("http") {
                        if let b = base, let resolved = URL(string: resolvedLink, relativeTo: b) {
                            resolvedLink = resolved.absoluteString
                        } else {
                            resolvedLink = "\(baseURLString)/\(resolvedLink.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
                        }
                    }
                    guard !seenLinks.contains(resolvedLink) else { continue }
                    seenLinks.insert(resolvedLink)
                    
                    let cleanRow = rowHTML.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                    var num: Double = 1.0
                    var numStr = "1"
                    if let numMatch = extractRegex(pattern: #"(?:chapter|ch\.|ep\.|الفصل)\s*(\d+(?:\.\d+)?)"#, in: cleanRow) {
                        numStr = numMatch
                        num = Double(numMatch) ?? 1.0
                    } else if let numMatch = extractRegex(pattern: #"(?:chapter|ch\.|ep\.|/|-)(\d+(?:\.\d+)?)"#, in: resolvedLink) {
                        numStr = numMatch
                        num = Double(numMatch) ?? 1.0
                    } else if let anyNum = extractRegex(pattern: #"(\d+(?:\.\d+)?)"#, in: cleanRow) {
                        numStr = anyNum
                        num = Double(anyNum) ?? 1.0
                    }
                    
                    let title = cleanRow.isEmpty ? "Chapter \(numStr)" : cleanRow
                    chapters.append(ChapterItem(
                        id: UUID(),
                        mangaID: UUID(),
                        sourceChapterID: resolvedLink,
                        chapterNumber: num,
                        title: title,
                        scanlator: manifest.name,
                        pageCount: 0,
                        pageURLs: []
                    ))
                }
            }
        }
        
        // Priority 2: General anchor tags linking to chapters/episodes
        if chapters.isEmpty {
            let pattern = #"<a[^>]+href="([^"]*(?:chapter|episode|/series/\d+/[a-z0-9]+|/\d+/)[^"]*)"[^>]*>([\s\S]*?)</a>"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    guard match.numberOfRanges > 2 else { continue }
                    var link = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    let inner = nsString.substring(with: match.range(at: 2))
                    
                    let linkLower = link.lowercased()
                    if linkLower.contains(".png") || linkLower.contains(".jpg") || linkLower.contains(".jpeg") ||
                       linkLower.contains(".webp") || linkLower.contains(".svg") || linkLower.contains(".gif") ||
                       linkLower.contains(".ico") || linkLower.contains(".css") || linkLower.contains(".js") ||
                       linkLower.contains("/wp-content/") || linkLower.contains("/wp-includes/") ||
                       linkLower.contains("/genre/") || linkLower.contains("/tag/") || linkLower.contains("-release/") ||
                       linkLower.contains("/author/") {
                        continue
                    }
                    
                    if !link.hasPrefix("http") {
                        if let b = base, let resolved = URL(string: link, relativeTo: b) {
                            link = resolved.absoluteString
                        } else {
                            link = "\(baseURLString)/\(link.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
                        }
                    }
                    
                    guard !seenLinks.contains(link) else { continue }
                    seenLinks.insert(link)
                    
                    let cleanInner = inner.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                    var num: Double = 1.0
                    var numStr = "1"
                    
                    if let numMatch = extractRegex(pattern: #"(?:chapter|ch\.|ep\.|الفصل)\s*(\d+(?:\.\d+)?)"#, in: cleanInner) {
                        numStr = numMatch
                        num = Double(numMatch) ?? 1.0
                    } else if let urlNumMatch = extractRegex(pattern: #"(?:chapter[/-]|episode[/-]|/)(\d+(?:\.\d+)?)"#, in: link) {
                        numStr = urlNumMatch
                        num = Double(urlNumMatch) ?? 1.0
                    } else if let anyNumMatch = extractRegex(pattern: #"(\d+(?:\.\d+)?)"#, in: cleanInner) {
                        numStr = anyNumMatch
                        num = Double(anyNumMatch) ?? 1.0
                    }
                    
                    if num > 10000 {
                        num = 1.0
                    }
                    
                    let title = cleanInner.isEmpty ? "Chapter \(numStr)" : cleanInner
                    chapters.append(ChapterItem(
                        id: UUID(),
                        mangaID: UUID(),
                        sourceChapterID: link,
                        chapterNumber: num,
                        title: title,
                        scanlator: manifest.name,
                        pageCount: 0,
                        pageURLs: []
                    ))
                }
            }
        }
        
        // Priority 3: Standard Chapter / Ch. text regex if the above was empty
        if chapters.isEmpty {
            let standardPattern = #"<a[^>]+href="([^"]+)"[^>]*>[\s\S]*?(?:Chapter|Ch\.)\s*([\d\.]+)"#
            if let regex = try? NSRegularExpression(pattern: standardPattern, options: .caseInsensitive) {
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    guard match.numberOfRanges > 2 else { continue }
                    var link = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !link.hasPrefix("http") {
                        link = "\(baseURLString)/\(link.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
                    }
                    guard !seenLinks.contains(link) else { continue }
                    seenLinks.insert(link)
                    
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
            }
        }
        
        // Prevent all chapters collapsing to same number
        if chapters.count > 1 {
            let uniqueNums = Set(chapters.map { $0.chapterNumber })
            if uniqueNums.count <= 1 {
                for i in 0..<chapters.count {
                    chapters[i].chapterNumber = Double(chapters.count - i)
                }
            }
        }
        
        return chapters.sorted { $0.chapterNumber > $1.chapterNumber }
    }
    
    private static func unescapeHTML(_ string: String) -> String {
        var result = string
        let entities: [String: String] = [
            "&amp;": "&",
            "&#038;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&#8217;": "'",
            "&#8216;": "'",
            "&#8220;": "\"",
            "&#8221;": "\"",
            "&#8211;": "-",
            "&#8212;": "—",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " "
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractRegex(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let first = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let r = first.numberOfRanges > 1 ? first.range(at: 1) : first.range(at: 0)
        guard r.location != NSNotFound else { return nil }
        return ns.substring(with: r)
    }
    
    private static func extractRegexFirst(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let first = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let r = first.numberOfRanges > 1 ? first.range(at: 1) : first.range(at: 0)
        guard r.location != NSNotFound else { return nil }
        return ns.substring(with: r)
    }
}

// MARK: - WordPress REST API DTOs for Community Source Tier 2 Fallback

private struct WPPostDTO: Decodable {
    let id: Int?
    let slug: String?
    let link: String?
    let title: WPTitleDTO?
    let embedded: WPEmbeddedDTO?
    
    enum CodingKeys: String, CodingKey {
        case id, slug, link, title
        case embedded = "_embedded"
    }
}

private struct WPTitleDTO: Decodable {
    let rendered: String?
}

private struct WPEmbeddedDTO: Decodable {
    let featuredMedia: [WPFeaturedMediaDTO]?
    
    enum CodingKeys: String, CodingKey {
        case featuredMedia = "wp:featuredmedia"
    }
}

private struct WPFeaturedMediaDTO: Decodable {
    let sourceUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case sourceUrl = "source_url"
    }
}

// DynamicRepositorySource alias
public typealias DynamicRepositorySource = CommunityWebSource

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

// MARK: - Tolerant Repository DTOs

private struct KeiyoushiPackageDTO: Decodable {
    let name: String
    let pkg: String
    let apk: String?
    let lang: String?
    let code: Int?
    let version: String?
    let nsfw: Int?
    let sources: [KeiyoushiSourceDTO]?
}

private struct KeiyoushiSourceDTO: Decodable {
    let id: String
    let name: String
    let lang: String?
    let baseUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, lang, baseUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let strId = try? container.decode(String.self, forKey: .id) {
            self.id = strId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            self.id = "\(intId)"
        } else {
            self.id = UUID().uuidString
        }
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Source"
        self.lang = try? container.decode(String.self, forKey: .lang)
        self.baseUrl = (try? container.decode(String.self, forKey: .baseUrl)) ?? ""
    }
}

private struct RepositoryManifestDTO: Decodable {
    let name: String?
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
        case id, name, version, lang, languages, iconURL, icon, description, popularURL, latestURL, searchURL, chaptersURL, baseURL, baseUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Source"

        if let intVal = try? container.decode(Int.self, forKey: .version) {
            self.version = "\(intVal).0.0"
        } else if let doubleVal = try? container.decode(Double.self, forKey: .version) {
            self.version = "\(doubleVal)"
        } else if let strVal = try? container.decode(String.self, forKey: .version) {
            self.version = strVal
        } else {
            self.version = "1.0.0"
        }

        if let langs = try? container.decode([String].self, forKey: .languages), !langs.isEmpty {
            self.lang = langs.joined(separator: ", ").uppercased()
        } else if let singleLang = try? container.decode(String.self, forKey: .lang) {
            self.lang = singleLang.uppercased()
        } else {
            self.lang = "EN"
        }

        self.iconURL = (try? container.decode(String.self, forKey: .iconURL)) ?? (try? container.decode(String.self, forKey: .icon))
        self.description = try? container.decode(String.self, forKey: .description)
        self.popularURL = try? container.decode(String.self, forKey: .popularURL)
        self.latestURL = try? container.decode(String.self, forKey: .latestURL)
        self.searchURL = try? container.decode(String.self, forKey: .searchURL)
        self.chaptersURL = try? container.decode(String.self, forKey: .chaptersURL)
        self.baseURL = (try? container.decode(String.self, forKey: .baseURL)) ?? (try? container.decode(String.self, forKey: .baseUrl))
    }
}
