//
//  BrowseViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

public enum GlobalSourceSearchState: Equatable {
    case loading
    case loaded([MangaItem])
    case empty
    case failed(String)
}

public struct GlobalSearchSection: Identifiable, Equatable {
    public let id: String // source.manifest.id
    public let sourceName: String
    public let sourceLang: String
    public let baseURL: String
    public var state: GlobalSourceSearchState
    
    public init(id: String, sourceName: String, sourceLang: String, baseURL: String, state: GlobalSourceSearchState) {
        self.id = id
        self.sourceName = sourceName
        self.sourceLang = sourceLang
        self.baseURL = baseURL
        self.state = state
    }
}

@MainActor
public final class BrowseViewModel: ObservableObject {
    @Published public private(set) var sources: [any MangaSource] = []
    @Published public private(set) var repositories: [RepositoryInfo] = []
    @Published public private(set) var installedManifests: [SourceManifest] = []
    @Published public private(set) var pendingUpdates: [SourceManifest] = []
    @Published public private(set) var availableManifests: [SourceManifest] = []
    @Published public private(set) var isRefreshing: Bool = false
    
    // Legacy simple search bindings
    @Published public var globalQuery: String = ""
    @Published public private(set) var isSearching: Bool = false
    @Published public private(set) var globalSearchResults: [String: [MangaItem]] = [:]
    
    // Mihon / Tachimanga Global Search Streaming Engine
    @Published public var globalSearchQuery: String = ""
    @Published public private(set) var isGlobalSearching: Bool = false
    @Published public private(set) var globalSearchSections: [GlobalSearchSection] = []
    
    private let sourceManager = SourceManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var globalSearchTask: Task<Void, Never>? = nil
    
    public init() {
        sourceManager.$sources
            .sink { [weak self] sources in
                self?.sources = sources
            }
            .store(in: &cancellables)
        
        sourceManager.$repositories
            .sink { [weak self] repos in
                self?.repositories = repos
            }
            .store(in: &cancellables)
            
        sourceManager.$installedManifests
            .sink { [weak self] manifests in
                self?.installedManifests = manifests
            }
            .store(in: &cancellables)
            
        sourceManager.$pendingUpdates
            .sink { [weak self] updates in
                self?.pendingUpdates = updates
            }
            .store(in: &cancellables)
            
        sourceManager.$availableManifests
            .sink { [weak self] available in
                self?.availableManifests = available
            }
            .store(in: &cancellables)
            
        sourceManager.$isRefreshingRepos
            .sink { [weak self] refreshing in
                self?.isRefreshing = refreshing
            }
            .store(in: &cancellables)
    }
    
    public func isSourceEnabled(_ id: String) -> Bool {
        sourceManager.isSourceEnabled(id)
    }
    
    public func toggleSource(_ id: String) {
        sourceManager.toggleSource(id)
    }
    
    public func refreshSourcesFromRepos(force: Bool = true) async {
        await sourceManager.refreshRepositories(force: force)
    }
    
    public func updateSource(_ manifest: SourceManifest) {
        sourceManager.updateSource(manifest)
    }
    
    public func updateAllSources() async {
        await sourceManager.updateAllSources()
    }
    
    public func installSource(_ manifest: SourceManifest) {
        sourceManager.installSource(manifest)
    }
    
    // MARK: - Global Search (Concurrent Streaming)
    
    public func performGlobalSearch(query: String? = nil) {
        if let query = query {
            self.globalSearchQuery = query
            self.globalQuery = query
        }
        
        let q = globalSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            clearSearch()
            return
        }
        
        globalSearchTask?.cancel()
        
        // Active or enabled sources
        let activeSources = sourceManager.sources.filter { sourceManager.isSourceEnabled($0.manifest.id) }
        let targetSources = activeSources.isEmpty ? sourceManager.sources : activeSources
        
        // Initialize all sections into .loading state
        self.globalSearchSections = targetSources.map { src in
            GlobalSearchSection(
                id: src.manifest.id,
                sourceName: src.manifest.name,
                sourceLang: src.manifest.lang,
                baseURL: src.manifest.baseURL,
                state: .loading
            )
        }
        
        self.isGlobalSearching = true
        self.isSearching = true
        
        globalSearchTask = Task { @MainActor in
            await withTaskGroup(of: (String, Result<[MangaItem], Error>).self) { group in
                for src in targetSources {
                    let sourceID = src.manifest.id
                    group.addTask {
                        do {
                            let items = try await src.search(query: q, page: 1)
                            return (sourceID, .success(items))
                        } catch {
                            return (sourceID, .failure(error))
                        }
                    }
                }
                
                for await (sourceID, result) in group {
                    if Task.isCancelled { break }
                    
                    if let index = self.globalSearchSections.firstIndex(where: { $0.id == sourceID }) {
                        switch result {
                        case .success(let items):
                            self.globalSearchSections[index].state = items.isEmpty ? .empty : .loaded(items)
                            if !items.isEmpty {
                                self.globalSearchResults[self.globalSearchSections[index].sourceName] = items
                            }
                        case .failure(let error):
                            self.globalSearchSections[index].state = .failed(error.localizedDescription)
                        }
                    }
                }
            }
            
            if !Task.isCancelled {
                self.isGlobalSearching = false
                self.isSearching = false
            }
        }
    }
    
    public func retryGlobalSearch(for sourceID: String) {
        let q = globalSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let src = sourceManager.provider(for: sourceID) else { return }
        
        if let index = globalSearchSections.firstIndex(where: { $0.id == sourceID }) {
            globalSearchSections[index].state = .loading
        }
        
        Task { @MainActor in
            do {
                let items = try await src.search(query: q, page: 1)
                if let index = self.globalSearchSections.firstIndex(where: { $0.id == sourceID }) {
                    self.globalSearchSections[index].state = items.isEmpty ? .empty : .loaded(items)
                    if !items.isEmpty {
                        self.globalSearchResults[self.globalSearchSections[index].sourceName] = items
                    }
                }
            } catch {
                if let index = self.globalSearchSections.firstIndex(where: { $0.id == sourceID }) {
                    self.globalSearchSections[index].state = .failed(error.localizedDescription)
                }
            }
        }
    }
    
    public func clearSearch() {
        globalSearchTask?.cancel()
        globalQuery = ""
        globalSearchQuery = ""
        globalSearchResults = [:]
        globalSearchSections = []
        isSearching = false
        isGlobalSearching = false
    }
    
    public func addRepository(url: String) async throws -> Int {
        try await sourceManager.addRepository(urlString: url)
    }
    
    public func removeRepository(url: String) {
        sourceManager.removeRepository(url: url)
    }
}
