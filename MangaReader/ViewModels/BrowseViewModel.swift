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
    }
    
    public func isSourceEnabled(_ id: String) -> Bool {
        sourceManager.isSourceEnabled(id)
    }
    
    public func toggleSource(_ id: String) {
        sourceManager.toggleSource(id)
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
