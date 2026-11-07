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
    @Published public var globalQuery: String = ""
    @Published public private(set) var isSearching: Bool = false
    @Published public private(set) var globalSearchResults: [String: [MangaItem]] = [:]
    
    private let sourceManager = SourceManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        sourceManager.$sources
            .assign(to: \.sources, on: self)
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
}
