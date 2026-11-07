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
    
    private let repo = LibraryRepository.shared
    private let db = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        db.$categoriesList
            .assign(to: \.categories, on: self)
            .store(in: &cancellables)
    }
    
    public var filteredManga: [MangaItem] {
        repo.filteredAndSorted(
            category: selectedCategory,
            searchQuery: searchQuery,
            sortOption: sortOption,
            ascending: sortAscending,
            unreadOnly: unreadOnly,
            downloadedOnly: downloadedOnly
        )
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
