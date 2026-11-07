//
//  HomeViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var continueReading: [ContinueReadingItem] = []
    @Published public private(set) var recentlyAdded: [MangaItem] = []
    @Published public private(set) var popularManga: [MangaItem] = []
    @Published public private(set) var latestUpdates: [MangaItem] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String? = nil
    
    // Quick statistics
    @Published public private(set) var totalLibraryCount: Int = 0
    @Published public private(set) var totalUnreadChapters: Int = 0
    
    private let db = DatabaseManager.shared
    private let historyRepo = HistoryRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupSubscriptions()
        loadHomeData()
    }
    
    private func setupSubscriptions() {
        historyRepo.$continueReadingItems
            .assign(to: \.continueReading, on: self)
            .store(in: &cancellables)
        
        db.$mangaList
            .sink { [weak self] list in
                guard let self = self else { return }
                self.totalLibraryCount = list.filter { $0.inLibrary }.count
                self.totalUnreadChapters = list.filter { $0.inLibrary }.reduce(0) { $0 + $1.unreadCount }
                self.recentlyAdded = Array(list.sorted { $0.lastUpdated > $1.lastUpdated }.prefix(10))
            }
            .store(in: &cancellables)
    }
    
    public func loadHomeData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            // Fetch popular and latest from the primary enabled source
            if let primarySource = SourceManager.shared.sources.first(where: { SourceManager.shared.isSourceEnabled($0.manifest.id) }) {
                do {
                    async let pop = primarySource.fetchPopular(page: 1)
                    async let lat = primarySource.fetchLatest(page: 1)
                    
                    let (popular, latest) = try await (pop, lat)
                    self.popularManga = popular
                    self.latestUpdates = latest
                    self.isLoading = false
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            } else {
                self.isLoading = false
            }
        }
    }
}
