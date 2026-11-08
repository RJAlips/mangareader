//
//  LibraryViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

public enum LibraryDisplayMode: String, CaseIterable {
    case compactGrid = "Grid"
    case comfortableGrid = "Large Grid"
    case list = "List"
    
    public var iconName: String {
        switch self {
        case .compactGrid: return "square.grid.3x3.fill"
        case .comfortableGrid: return "square.grid.2x2.fill"
        case .list: return "list.bullet"
        }
    }
}

@MainActor
public final class LibraryViewModel: ObservableObject {
    @Published public var selectedCategory: String = "All"
    @Published public var searchQuery: String = ""
    @Published public var sortOption: LibrarySortOption = .lastRead
    @Published public var sortAscending: Bool = false
    @Published public var unreadOnly: Bool = false
    @Published public var downloadedOnly: Bool = false
    @Published public var displayMode: LibraryDisplayMode = .compactGrid
    
    // Batch Selection Mode
    @Published public var isSelectionMode: Bool = false
    @Published public var selectedMangaIDs: Set<UUID> = []
    
    // Categories
    @Published public private(set) var categories: [CategoryItem] = []
    
    // Continue Reading Shelf
    @Published public private(set) var currentlyReadingItems: [ContinueReadingItem] = []
    
    private let repo = LibraryRepository.shared
    private let db = DatabaseManager.shared
    private let historyRepo = HistoryRepository.shared
    private var cancellables = Set<AnyCancellable>()

    /// Incremented every time the library data changes so SwiftUI re-evaluates
    /// `filteredManga` without storing a redundant copy of the array.
    @Published private var libraryVersion: Int = 0
    
    public init() {
        db.$categoriesList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cats in
                self?.categories = cats
            }
            .store(in: &cancellables)

        // Observe Continue Reading Items from History
        historyRepo.$continueReadingItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.currentlyReadingItems = items
            }
            .store(in: &cancellables)

        // Whenever the underlying library list changes, bump the version counter.
        repo.$libraryItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.libraryVersion &+= 1
            }
            .store(in: &cancellables)

        // Also observe filter/sort knobs so the computed property stays fresh.
        let filterPublishers: [AnyPublisher<Void, Never>] = [
            $selectedCategory.map { _ in () }.eraseToAnyPublisher(),
            $searchQuery.map { _ in () }.eraseToAnyPublisher(),
            $sortOption.map { _ in () }.eraseToAnyPublisher(),
            $sortAscending.map { _ in () }.eraseToAnyPublisher(),
            $unreadOnly.map { _ in () }.eraseToAnyPublisher(),
            $downloadedOnly.map { _ in () }.eraseToAnyPublisher()
        ]
        for pub in filterPublishers {
            pub
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.libraryVersion &+= 1 }
                .store(in: &cancellables)
        }
    }
    
    /// Re-computed every time `libraryVersion` changes (via `objectWillChange`).
    public var filteredManga: [MangaItem] {
        _ = libraryVersion // create dependency on the published counter
        return repo.filteredAndSorted(
            category: selectedCategory,
            searchQuery: searchQuery,
            sortOption: sortOption,
            ascending: sortAscending,
            unreadOnly: unreadOnly,
            downloadedOnly: downloadedOnly
        )
    }
    
    public func refresh() {
        db.reloadFromDisk()
        libraryVersion &+= 1
    }
    
    public func toggleSelection(for id: UUID) {
        if selectedMangaIDs.contains(id) {
            selectedMangaIDs.remove(id)
        } else {
            selectedMangaIDs.insert(id)
        }
    }
    
    public func selectAll() {
        selectedMangaIDs = Set(filteredManga.map { $0.id })
    }
    
    public func deselectAll() {
        selectedMangaIDs.removeAll()
    }
    
    public func exitSelectionMode() {
        isSelectionMode = false
        selectedMangaIDs.removeAll()
    }
    
    // MARK: - Batch Actions
    
    public func batchMarkSelectedRead(isRead: Bool) {
        repo.batchMarkRead(mangaIDs: Array(selectedMangaIDs), isRead: isRead)
        exitSelectionMode()
    }
    
    public func batchRemoveSelected() {
        repo.batchRemoveFromLibrary(mangaIDs: Array(selectedMangaIDs))
        exitSelectionMode()
    }
    
    public func batchAddSelectedToCategory(name: String) {
        repo.batchSetCategory(mangaIDs: Array(selectedMangaIDs), category: name, add: true)
        exitSelectionMode()
    }
}
