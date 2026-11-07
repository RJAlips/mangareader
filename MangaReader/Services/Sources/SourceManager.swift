//
//  SourceManager.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

public final class SourceManager: ObservableObject {
    public static let shared = SourceManager()
    
    @Published public private(set) var sources: [any MangaSource] = []
    @Published public private(set) var enabledSourceIDs: Set<String> = []
    
    private let userDefaultsKey = "com.mangareader.enabledSources"
    
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
