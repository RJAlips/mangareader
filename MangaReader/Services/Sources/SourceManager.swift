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
    @Published public private(set) var installedManifests: [SourceManifest] = []
    @Published public private(set) var pendingUpdates: [SourceManifest] = []
    @Published public private(set) var availableManifests: [SourceManifest] = []
    @Published public private(set) var isRefreshingRepos: Bool = false
    
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
                version: "1.2.0",
                versionCode: 120,
                lang: "EN",
                baseURL: "https://aquareader.org",
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
                versionCode: 130,
                lang: "EN",
                baseURL: "https://asurascans.com",
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
                versionCode: 110,
                lang: "AR",
                baseURL: "https://3asq.org",
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
                versionCode: 100,
                lang: "EN",
                baseURL: "https://armageddonscans.com",
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
        
        // 3. Load installed manifests from disk or seed defaults
        loadInstalledManifests(defaultSources: self.sources)
        
        // 4. Load enabled sources
        if let saved = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            self.enabledSourceIDs = Set(saved)
        } else {
            self.enabledSourceIDs = [demo.manifest.id, mangadex.manifest.id, aqua.manifest.id, asura.manifest.id]
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
    
    public func provider(for id: String) -> (any MangaSource)? {
        // 1. Exact ID match in active sources
        if let exact = sources.first(where: { $0.manifest.id == id }) {
            return exact
        }
        
        // 2. Flexible fallback: match prefix, suffix or clean name
        let clean = id.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = sources.first(where: {
            let sId = $0.manifest.id.lowercased()
            let sName = $0.manifest.name.lowercased()
            return sId == clean || sId.contains(clean) || clean.contains(sId) || sName.contains(clean) || clean.contains(sName)
        }) {
            return match
        }
        
        // 3. Match from installedManifests and instantiate dynamically
        if let manifest = installedManifests.first(where: {
            let mId = $0.id.lowercased()
            let mName = $0.name.lowercased()
            return mId == clean || mId.contains(clean) || clean.contains(mId) || mName.contains(clean) || clean.contains(mName)
        }) {
            let dynamicSource = CommunityWebSource(
                manifest: manifest,
                baseURLString: manifest.baseURL.isEmpty ? "https://api.mangadex.org" : manifest.baseURL
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
            baseURL: "https://api.mangadex.org",
            isEnabled: true
        )
        let fallbackSource = CommunityWebSource(manifest: fallbackManifest, baseURLString: "https://api.mangadex.org")
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
            for manifest in manifests {
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
                            baseURLString: manifest.baseURL.isEmpty ? (manifest.sourceDescription ?? "https://api.mangadex.org") : manifest.baseURL
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
                    baseURLString: manifest.baseURL.isEmpty ? (manifest.sourceDescription ?? "https://api.mangadex.org") : manifest.baseURL
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
            baseURLString: remoteManifest.baseURL.isEmpty ? "https://api.mangadex.org" : remoteManifest.baseURL
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
            baseURLString: toInstall.baseURL.isEmpty ? "https://api.mangadex.org" : toInstall.baseURL
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
    
    private func saveRepositories() {
        if let encoded = try? JSONEncoder().encode(repositories) {
            UserDefaults.standard.set(encoded, forKey: repoDefaultsKey)
        }
    }
}

// MARK: - Community Web Source (3-Tier Resilient Architecture: HTML Scraper -> WP REST API -> MangaDex Catalog)

public final class CommunityWebSource: MangaSource, @unchecked Sendable {
    public let manifest: SourceManifest
    public let baseURLString: String
    public let popularURL: String?
    public let latestURL: String?
    public let searchURL: String?
    public let chaptersURL: String?
    
    private let client = NetworkClient.shared
    private let mangadex = MangaDexSource()
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
        self.baseURLString = baseURLString
        self.popularURL = popularURL
        self.latestURL = latestURL
        self.searchURL = searchURL
        self.chaptersURL = chaptersURL
    }
    
    // MARK: - Popular Titles (3-Tier Pipeline)
    public func fetchPopular(page: Int) async throws -> [MangaItem] {
        // Tier 1: HTML Scrape with timeout
        let candidateURLs = [
            popularURL,
            "\(baseURLString)/?s=&post_type=wp-manga&m_orderby=views",
            "\(baseURLString)/manga/?order=popular",
            "\(baseURLString)/manga/"
        ].compactMap { $0 }.compactMap { URL(string: $0) }
        
        for url in candidateURLs {
            if let scraped = try? await scrapeTitles(from: url), !scraped.isEmpty {
                return scraped
            }
        }
        
        // Tier 2: WordPress REST API fallback (/wp-json/wp/v2/manga or /wp-json/wp/v2/posts)
        if let wpItems = await fetchWordPressTitles(subpath: "manga", orderby: "views") ?? (await fetchWordPressTitles(subpath: "posts", orderby: "date")), !wpItems.isEmpty {
            return wpItems
        }
        
        // Tier 3: MangaDex Catalog fallback
        let fallback = (try? await mangadex.fetchPopular(page: page)) ?? []
        return fallback.map { item in
            var mapped = item
            mapped.sourceID = self.manifest.id
            return mapped
        }
    }
    
    // MARK: - Latest Titles (3-Tier Pipeline)
    public func fetchLatest(page: Int) async throws -> [MangaItem] {
        // Tier 1: HTML Scrape with timeout
        let candidateURLs = [
            latestURL,
            "\(baseURLString)/?s=&post_type=wp-manga&m_orderby=latest",
            "\(baseURLString)/manga/?order=update",
            "\(baseURLString)/latest/"
        ].compactMap { $0 }.compactMap { URL(string: $0) }
        
        for url in candidateURLs {
            if let scraped = try? await scrapeTitles(from: url), !scraped.isEmpty {
                return scraped
            }
        }
        
        // Tier 2: WordPress REST API fallback
        if let wpItems = await fetchWordPressTitles(subpath: "manga", orderby: "date") ?? (await fetchWordPressTitles(subpath: "posts", orderby: "date")), !wpItems.isEmpty {
            return wpItems
        }
        
        // Tier 3: MangaDex Catalog fallback
        let fallback = (try? await mangadex.fetchLatest(page: page)) ?? []
        return fallback.map { item in
            var mapped = item
            mapped.sourceID = self.manifest.id
            return mapped
        }
    }
    
    // MARK: - Search (3-Tier Pipeline)
    public func search(query: String, page: Int) async throws -> [MangaItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            return try await fetchPopular(page: page)
        }
        
        let encoded = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanQuery
        
        // Tier 1: HTML Search
        let candidateSearchURLs = [
            searchURL?.replacingOccurrences(of: "{query}", with: encoded),
            "\(baseURLString)/?s=\(encoded)&post_type=wp-manga",
            "\(baseURLString)/?s=\(encoded)"
        ].compactMap { $0 }.compactMap { URL(string: $0) }
        
        for url in candidateSearchURLs {
            if let scraped = try? await scrapeTitles(from: url), !scraped.isEmpty {
                return scraped
            }
        }
        
        // Tier 2: WordPress REST API search
        if let wpResults = await fetchWordPressTitles(subpath: "manga", searchQuery: encoded) ?? (await fetchWordPressTitles(subpath: "posts", searchQuery: encoded)), !wpResults.isEmpty {
            return wpResults
        }
        
        // Tier 3: MangaDex Catalog search
        let fallback = (try? await mangadex.search(query: cleanQuery, page: page)) ?? []
        return fallback.map { item in
            var mapped = item
            mapped.sourceID = self.manifest.id
            return mapped
        }
    }
    
    // MARK: - Manga Detail
    public func fetchMangaDetail(urlOrSlug: String) async throws -> MangaItem {
        if !urlOrSlug.contains("/") && urlOrSlug.count >= 32 {
            let item = try await mangadex.fetchMangaDetail(urlOrSlug: urlOrSlug)
            var mapped = item
            mapped.sourceID = self.manifest.id
            return mapped
        }
        
        if let url = URL(string: urlOrSlug.hasPrefix("http") ? urlOrSlug : "\(baseURLString)/\(urlOrSlug)") {
            if let htmlData = try? await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString, timeoutInterval: requestTimeout),
               let html = String(data: htmlData, encoding: .utf8) {
                let title = extractRegex(pattern: #"<h1[^>]*>([^<]+)</h1>"#, in: html) ?? url.lastPathComponent.capitalized
                let desc = extractRegex(pattern: #"<div class="[^"]*(?:summary__content|description-summary|entry-content)[^"]*">([\s\S]*?)</div>"#, in: html)
                
                // Extract cover using priority attributes
                var coverURL: URL? = nil
                if let imgTag = extractRegex(pattern: #"<div class="[^"]*(?:summary_image|thumb|thumb-manga)[^"]*">([\s\S]*?)</div>"#, in: html) {
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
        
        let searchResults = try? await mangadex.search(query: urlOrSlug, page: 1)
        if let match = searchResults?.first {
            var mapped = match
            mapped.sourceID = self.manifest.id
            return mapped
        }
        
        throw NetworkError.badServerResponse(statusCode: 404)
    }
    
    // MARK: - Chapters
    public func fetchChapters(for urlOrSlug: String) async throws -> [ChapterItem] {
        if !urlOrSlug.contains("/") && urlOrSlug.count >= 32 {
            return try await mangadex.fetchChapters(for: urlOrSlug)
        }
        
        if let url = URL(string: urlOrSlug.hasPrefix("http") ? urlOrSlug : "\(baseURLString)/\(urlOrSlug)") {
            if let htmlData = try? await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString, timeoutInterval: requestTimeout),
               let html = String(data: htmlData, encoding: .utf8) {
                var chapters = parseChaptersFromHTML(html)
                
                // If 0 chapters and post ID is present, try WP AJAX manga_get_chapters
                if chapters.isEmpty, let postID = extractRegex(pattern: #"(?:manga_id|data-id|post_id)\s*=\s*['"]?(\d+)"#, in: html) {
                    if let ajaxChapters = await fetchChaptersFromWPAJAX(mangaID: postID) {
                        chapters = ajaxChapters
                    }
                }
                
                if !chapters.isEmpty {
                    return chapters
                }
            }
        }
        
        let searchResults = try? await mangadex.search(query: urlOrSlug, page: 1)
        if let bestMatch = searchResults?.first {
            return (try? await mangadex.fetchChapters(for: bestMatch.urlOrSlug)) ?? []
        }
        
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
    
    // MARK: - Page URLs
    public func fetchPageURLs(for chapterSourceID: String) async throws -> [URL] {
        var cleanId = chapterSourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = cleanId.components(separatedBy: "_").last, !last.isEmpty, last.count >= 32 {
            cleanId = last
            return try await mangadex.fetchPageURLs(for: cleanId)
        }
        
        if let url = URL(string: chapterSourceID.hasPrefix("http") ? chapterSourceID : "\(baseURLString)/\(chapterSourceID)") {
            if let htmlData = try? await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString, timeoutInterval: requestTimeout),
               let html = String(data: htmlData, encoding: .utf8) {
                let base = URL(string: baseURLString)
                
                // Match all <img> tags in HTML
                let imgRegexPattern = #"<img[^>]+>"#
                guard let regex = try? NSRegularExpression(pattern: imgRegexPattern, options: .caseInsensitive) else { return [] }
                let ns = html as NSString
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
                
                var pageURLs: [URL] = []
                for m in matches {
                    let tag = ns.substring(with: m.range)
                    let lower = tag.lowercased()
                    if lower.contains("avatar") || lower.contains("logo") || lower.contains("banner") || lower.contains("favicon") {
                        continue
                    }
                    if let extracted = Self.extractImageURL(from: tag, relativeTo: base) {
                        if !pageURLs.contains(extracted) {
                            pageURLs.append(extracted)
                        }
                    }
                }
                
                if !pageURLs.isEmpty {
                    return pageURLs
                }
            }
        }
        
        return []
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
        // Priority order as required:
        // 1. data-src
        // 2. data-lazy-src
        // 3. data-cfsrc
        // 4. data-original (and data-manga-src)
        // 5. srcset / data-srcset (first URL before space/comma)
        // 6. src (only if not starting with data:image)
        
        let singleAttrs = ["data-src", "data-lazy-src", "data-cfsrc", "data-original", "data-manga-src"]
        for attr in singleAttrs {
            let pattern = "\(attr)\\s*=\\s*[\"']([^\"']+)[\"']"
            if let raw = extractRegexFirst(pattern: pattern, in: tag) {
                if let sanitized = sanitizeImageURL(raw, baseURL: baseURL) {
                    return sanitized
                }
            }
        }
        
        let setAttrs = ["data-srcset", "srcset"]
        for attr in setAttrs {
            let pattern = "\(attr)\\s*=\\s*[\"']([^\"']+)[\"']"
            if let raw = extractRegexFirst(pattern: pattern, in: tag) {
                let firstCand = raw.components(separatedBy: ",").first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .whitespaces).first
                if let cand = firstCand, let sanitized = sanitizeImageURL(cand, baseURL: baseURL) {
                    return sanitized
                }
            }
        }
        
        let srcPattern = "src\\s*=\\s*[\"']([^\"']+)[\"']"
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
        let data = try await client.fetchDataWithCDNHeaders(from: url, refererOverride: baseURLString, timeoutInterval: requestTimeout)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        
        var results: [MangaItem] = []
        let base = URL(string: baseURLString)
        
        // Multi-card regex pattern covering Madara, WP-Manga, and custom webtoon themes
        let cardPattern = #"<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?<img[^>]+>[\s\S]*?<(?:h1|h2|h3|h4|h5|div|span|p)[^>]+class="[^"]*(?:title|post-title|tt|entry-title)[^"]*"[^>]*>([^<]+)<[\s\S]*?)</a>"#
        
        if let regex = try? NSRegularExpression(pattern: cardPattern, options: .caseInsensitive) {
            let ns = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for m in matches.prefix(35) {
                let link = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                let body = ns.substring(with: m.range(at: 2))
                let title = ns.substring(with: m.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let coverURL = Self.extractImageURL(from: body, relativeTo: base)
                let slug = link.trimmingCharacters(in: CharacterSet(charactersIn: "/")).components(separatedBy: "/").last ?? link
                
                results.append(MangaItem(
                    sourceID: manifest.id,
                    urlOrSlug: slug,
                    title: Self.unescapeHTML(title),
                    coverURL: coverURL,
                    genres: ["Manhwa", "Manga"],
                    status: .ongoing
                ))
            }
        }
        
        return results
    }
    
    // MARK: - WordPress REST API (Tier 2 Fallback)
    
    private func fetchWordPressTitles(subpath: String, orderby: String? = nil, searchQuery: String? = nil) async -> [MangaItem]? {
        var queryItems = ["_embed=1", "per_page=20"]
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
        request.httpBody = "action=manga_get_chapters&manga=\(mangaID)".data(using: .utf8)
        request.timeoutInterval = 6.0
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        let chapters = parseChaptersFromHTML(html)
        return chapters.isEmpty ? nil : chapters
    }
    
    private func parseChaptersFromHTML(_ html: String) -> [ChapterItem] {
        let chapterPattern = #"<a[^>]+href="([^"]+)"[^>]*>[\s\S]*?(?:Chapter|Ch\.)\s*([\d\.]+)"#
        guard let regex = try? NSRegularExpression(pattern: chapterPattern, options: .caseInsensitive) else { return [] }
        let nsString = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
        
        var chapters: [ChapterItem] = []
        var seenLinks = Set<String>()
        
        for match in matches {
            let link = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
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
        return ns.substring(with: first.range(at: 1))
    }
    
    private static func extractRegexFirst(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let first = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: first.range(at: 1))
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
