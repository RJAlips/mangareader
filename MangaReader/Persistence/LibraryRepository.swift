//
//  LibraryRepository.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

public enum LibrarySortOption: String, CaseIterable, Identifiable {
    case title = "Title"
    case lastRead = "Last Read"
    case latestUpdate = "Latest Update"
    case unreadCount = "Unread Chapters"
    case totalChapters = "Total Chapters"
    
    public var id: String { rawValue }
}

public final class LibraryRepository: ObservableObject {
    public static let shared = LibraryRepository()
    
    private let db = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published public private(set) var libraryItems: [MangaItem] = []
    
    private init() {
        db.$mangaList
            .map { list in list.filter { $0.inLibrary } }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.libraryItems = items
            }
            .store(in: &cancellables)
    }
    
    public func filteredAndSorted(
        category: String?,
        searchQuery: String = "",
        sortOption: LibrarySortOption = .lastRead,
        ascending: Bool = false,
        unreadOnly: Bool = false,
        downloadedOnly: Bool = false
    ) -> [MangaItem] {
        var items = libraryItems
        
        // 1. Category Filter
        if let category = category, category != "All" {
            items = items.filter { $0.categories.contains(category) }
        }
        
        // 2. Search Query
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchQuery.lowercased()
            items = items.filter {
                $0.title.lowercased().contains(q) ||
                ($0.author?.lowercased().contains(q) ?? false) ||
                $0.genres.contains(where: { $0.lowercased().contains(q) })
            }
        }
        
        // 3. Unread Only
        if unreadOnly {
            items = items.filter { $0.unreadCount > 0 }
        }
        
        // 4. Downloaded Only
        if downloadedOnly {
            let downloadedMangaIDs = Set(db.chaptersList.filter { $0.isDownloaded }.map { $0.mangaID })
            items = items.filter { downloadedMangaIDs.contains($0.id) }
        }
        
        // 5. Sorting
        return items.sorted { m1, m2 in
            switch sortOption {
            case .title:
                return ascending ? m1.title.localizedCompare(m2.title) == .orderedAscending : m1.title.localizedCompare(m2.title) == .orderedDescending
            case .lastRead:
                let d1 = m1.lastReadAt ?? Date.distantPast
                let d2 = m2.lastReadAt ?? Date.distantPast
                return ascending ? d1 < d2 : d1 > d2
            case .latestUpdate:
                return ascending ? m1.lastUpdated < m2.lastUpdated : m1.lastUpdated > m2.lastUpdated
            case .unreadCount:
                return ascending ? m1.unreadCount < m2.unreadCount : m1.unreadCount > m2.unreadCount
            case .totalChapters:
                return ascending ? m1.totalChapters < m2.totalChapters : m1.totalChapters > m2.totalChapters
            }
        }
    }
    
    // MARK: - Batch Actions
    
    public func batchMarkRead(mangaIDs: [UUID], isRead: Bool) {
        for id in mangaIDs {
            db.markAllChaptersRead(mangaID: id, isRead: isRead)
        }
    }
    
    public func batchRemoveFromLibrary(mangaIDs: [UUID]) {
        for id in mangaIDs {
            db.toggleLibrary(mangaID: id)
        }
    }
    
    public func batchSetCategory(mangaIDs: [UUID], category: String, add: Bool) {
        for id in mangaIDs {
            if let index = db.mangaList.firstIndex(where: { $0.id == id }) {
                var m = db.mangaList[index]
                if add {
                    if !m.categories.contains(category) {
                        m.categories.append(category)
                    }
                } else {
                    m.categories.removeAll(where: { $0 == category })
                }
                db.upsertManga(m)
            }
        }
    }
    
    public func getManga(by id: UUID) -> MangaItem? {
        return db.mangaList.first(where: { $0.id == id })
    }
    
    public func getManga(by idString: String) -> MangaItem? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return getManga(by: uuid)
    }
}
