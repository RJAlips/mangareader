//
//  HistoryRepository.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

public struct ContinueReadingItem: Identifiable {
    public var id: UUID { manga.id }
    public let manga: MangaItem
    public let chapter: ChapterItem
    public let progress: ReadingProgress
}

public final class HistoryRepository: ObservableObject {
    public static let shared = HistoryRepository()
    
    private let db = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published public private(set) var continueReadingItems: [ContinueReadingItem] = []
    
    private init() {
        Publishers.CombineLatest3(db.$mangaList, db.$chaptersList, db.$historyList)
            .map { mangas, chapters, history in
                var results: [ContinueReadingItem] = []
                let sortedHistory = history.sorted { $0.updatedAt > $1.updatedAt }
                
                var seenMangaIDs = Set<UUID>()
                for entry in sortedHistory {
                    guard !seenMangaIDs.contains(entry.mangaID) else { continue }
                    if let manga = mangas.first(where: { $0.id == entry.mangaID }),
                       let chapter = chapters.first(where: { $0.id == entry.chapterID }) {
                        seenMangaIDs.insert(entry.mangaID)
                        results.append(ContinueReadingItem(manga: manga, chapter: chapter, progress: entry))
                    }
                }
                return results
            }
            .assign(to: \.continueReadingItems, on: self)
            .store(in: &cancellables)
    }
    
    public func clearHistory() {
        for item in db.historyList {
            db.updateProgress(chapterID: item.chapterID, mangaID: item.mangaID, pageIndex: 0, totalPages: 0)
        }
    }
}
