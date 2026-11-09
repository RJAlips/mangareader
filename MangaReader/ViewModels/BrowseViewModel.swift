//
//  BrowseViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

@MainActor
public final class BrowseViewModel: ObservableObject {
    @Published public private(set) var sources: [any MangaSource] = []
    @Published public private(set) var repositories: [RepositoryInfo] = []
    @Published public private(set) var installedManifests: [SourceManifest] = []
    @Published public private(set) var pendingUpdates: [SourceManifest] = []
    @Published public private(set) var availableManifests: [SourceManifest] = []
    @Published public private(set) var isRefreshing: Bool = false
    
    @Published public var globalQuery: String = ""
    @Published public private(set) var isSearching: Bool = false
    @Published public private(set) var globalSearchResults: [String: [MangaItem]] = [:]
    
    private let sourceManager = SourceManager.shared
    private var cancellables = Set<AnyCancellable>()
    
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
    
    public func performGlobalSearch() {
        let q = globalQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            globalSearchResults = [:]
            return
        }
        
        isSearching = true
        Task {
            let results = await sourceManager.globalSearch(query: q)
            self.globalSearchResults = results
            self.isSearching = false
        }
    }
    
    public func clearSearch() {
        globalQuery = ""
        globalSearchResults = [:]
        isSearching = false
    }
    
    public func addRepository(url: String) async throws -> Int {
        try await sourceManager.addRepository(urlString: url)
    }
    
    public func removeRepository(url: String) {
        sourceManager.removeRepository(url: url)
    }
}
