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
    
    public init(manga: MangaItem, chapter: ChapterItem, progress: ReadingProgress) {
        self.manga = manga
        self.chapter = chapter
        self.progress = progress
    }
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
            .sink { [weak self] items in
                self?.continueReadingItems = items
            }
            .store(in: &cancellables)
    }
    
    public func readingProgress(for mangaID: UUID) -> ReadingProgress? {
        return db.historyList.first(where: { $0.mangaID == mangaID })
    }
    
    public func readingProgress(forMangaIdString idString: String) -> ReadingProgress? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return readingProgress(for: uuid)
    }
    
    public func readingDuration(for mangaID: UUID) -> String {
        let entries = db.historyList.filter { $0.mangaID == mangaID }
        let totalSeconds = entries.reduce(0.0) { $0 + $1.readingTimeSeconds }
        let totalMinutes = max(1, Int(totalSeconds) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours) h \(minutes) m"
        } else {
            return "\(minutes) m"
        }
    }
    
    public func removeHistory(for mangaID: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let filtered = self.db.historyList.filter { $0.mangaID != mangaID }
            // Save updated history
            for entry in self.db.historyList where entry.mangaID == mangaID {
                self.db.updateProgress(chapterID: entry.chapterID, mangaID: entry.mangaID, pageIndex: 0, totalPages: 0)
            }
            self.continueReadingItems.removeAll(where: { $0.manga.id == mangaID })
            self.db.saveHistoryToDiskSync()
        }
    }
    
    public func clearHistory() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for item in self.db.historyList {
                self.db.updateProgress(chapterID: item.chapterID, mangaID: item.mangaID, pageIndex: 0, totalPages: 0)
            }
            self.continueReadingItems.removeAll()
            self.db.saveHistoryToDiskSync()
        }
    }
}
