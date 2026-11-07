//
//  DatabaseManager.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

public final class DatabaseManager: ObservableObject {
    public static let shared = DatabaseManager()
    
    @Published public private(set) var mangaList: [MangaItem] = []
    @Published public private(set) var chaptersList: [ChapterItem] = []
    @Published public private(set) var categoriesList: [CategoryItem] = []
    @Published public private(set) var historyList: [ReadingProgress] = []
    @Published public var readerSettings: ReaderSettings = ReaderSettings()
    @Published public var trackingLinks: [String: String] = [:] // mangaID -> tracking ID
    
    private let queue = DispatchQueue(label: "com.mangareader.databasemanager", qos: .userInitiated)
    private let fileManager = FileManager.default
    private let storageDirectory: URL
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.storageDirectory = appSupport.appendingPathComponent("MangaReaderStore", isDirectory: true)
        
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        loadFromDisk()
        
        if categoriesList.isEmpty {
            categoriesList = CategoryItem.defaultCategories
            saveCategoriesToDisk()
        }
    }
    
    // MARK: - Disk Persistence
    
    private var mangaFileURL: URL { storageDirectory.appendingPathComponent("manga.json") }
    private var chaptersFileURL: URL { storageDirectory.appendingPathComponent("chapters.json") }
    private var categoriesFileURL: URL { storageDirectory.appendingPathComponent("categories.json") }
    private var historyFileURL: URL { storageDirectory.appendingPathComponent("history.json") }
    private var settingsFileURL: URL { storageDirectory.appendingPathComponent("settings.json") }
    private var trackingFileURL: URL { storageDirectory.appendingPathComponent("tracking.json") }
    
    private func loadFromDisk() {
        queue.sync {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            if let data = try? Data(contentsOf: mangaFileURL),
               let list = try? decoder.decode([MangaItem].self, from: data) {
                DispatchQueue.main.async { self.mangaList = list }
            }
            
            if let data = try? Data(contentsOf: chaptersFileURL),
               let list = try? decoder.decode([ChapterItem].self, from: data) {
                DispatchQueue.main.async { self.chaptersList = list }
            }
            
            if let data = try? Data(contentsOf: categoriesFileURL),
               let list = try? decoder.decode([CategoryItem].self, from: data) {
                DispatchQueue.main.async { self.categoriesList = list }
            }
            
            if let data = try? Data(contentsOf: historyFileURL),
               let list = try? decoder.decode([ReadingProgress].self, from: data) {
                DispatchQueue.main.async { self.historyList = list }
            }
            
            if let data = try? Data(contentsOf: settingsFileURL),
               let settings = try? decoder.decode(ReaderSettings.self, from: data) {
                DispatchQueue.main.async { self.readerSettings = settings }
            }
            
            if let data = try? Data(contentsOf: trackingFileURL),
               let links = try? decoder.decode([String: String].self, from: data) {
                DispatchQueue.main.async { self.trackingLinks = links }
            }
        }
    }
    
    public func saveAll() {
        saveMangaToDisk()
        saveChaptersToDisk()
        saveCategoriesToDisk()
        saveHistoryToDisk()
        saveSettingsToDisk()
        saveTrackingToDisk()
    }
    
    public func saveMangaToDisk() {
        queue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(self.mangaList) {
                try? data.write(to: self.mangaFileURL, options: .atomic)
            }
        }
    }
    
    public func saveChaptersToDisk() {
        queue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(self.chaptersList) {
                try? data.write(to: self.chaptersFileURL, options: .atomic)
            }
        }
    }
    
    public func saveCategoriesToDisk() {
        queue.async {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(self.categoriesList) {
                try? data.write(to: self.categoriesFileURL, options: .atomic)
            }
        }
    }
    
    public func saveHistoryToDisk() {
        queue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(self.historyList) {
                try? data.write(to: self.historyFileURL, options: .atomic)
            }
        }
    }
    
    public func saveSettingsToDisk() {
        queue.async {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(self.readerSettings) {
                try? data.write(to: self.settingsFileURL, options: .atomic)
            }
        }
    }
    
    public func saveTrackingToDisk() {
        queue.async {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(self.trackingLinks) {
                try? data.write(to: self.trackingFileURL, options: .atomic)
            }
        }
    }
    
    // MARK: - Manga Operations
    
    public func upsertManga(_ manga: MangaItem) {
        if let index = mangaList.firstIndex(where: { $0.id == manga.id }) {
            mangaList[index] = manga
        } else {
            mangaList.append(manga)
        }
        saveMangaToDisk()
    }
    
    public func toggleFavorite(mangaID: UUID) {
        if let index = mangaList.firstIndex(where: { $0.id == mangaID }) {
            mangaList[index].isFavorite.toggle()
            if mangaList[index].isFavorite {
                mangaList[index].inLibrary = true
            }
            saveMangaToDisk()
        }
    }
    
    public func toggleLibrary(mangaID: UUID) {
        if let index = mangaList.firstIndex(where: { $0.id == mangaID }) {
            mangaList[index].inLibrary.toggle()
            saveMangaToDisk()
        }
    }
    
    public func removeManga(mangaID: UUID) {
        mangaList.removeAll(where: { $0.id == mangaID })
        chaptersList.removeAll(where: { $0.mangaID == mangaID })
        historyList.removeAll(where: { $0.mangaID == mangaID })
        trackingLinks.removeValue(forKey: mangaID.uuidString)
        saveAll()
    }
    
    // MARK: - Chapter Operations
    
    public func upsertChapters(_ chapters: [ChapterItem]) {
        for chapter in chapters {
            if let index = chaptersList.firstIndex(where: { $0.id == chapter.id }) {
                chaptersList[index] = chapter
            } else {
                chaptersList.append(chapter)
            }
        }
        recalculateUnreadCounts()
        saveChaptersToDisk()
    }
    
    public func setChapterReadStatus(chapterID: UUID, isRead: Bool) {
        if let index = chaptersList.firstIndex(where: { $0.id == chapterID }) {
            chaptersList[index].isRead = isRead
            if isRead {
                chaptersList[index].lastPageRead = chaptersList[index].pageCount
            }
            recalculateUnreadCounts(for: chaptersList[index].mangaID)
            saveChaptersToDisk()
        }
    }
    
    public func markAllChaptersRead(mangaID: UUID, isRead: Bool) {
        for i in 0..<chaptersList.count {
            if chaptersList[i].mangaID == mangaID {
                chaptersList[i].isRead = isRead
                if isRead {
                    chaptersList[i].lastPageRead = chaptersList[i].pageCount
                }
            }
        }
        recalculateUnreadCounts(for: mangaID)
        saveChaptersToDisk()
    }
    
    public func chapters(for mangaID: UUID) -> [ChapterItem] {
        return chaptersList.filter { $0.mangaID == mangaID }
            .sorted { $0.chapterNumber < $1.chapterNumber }
    }
    
    private func recalculateUnreadCounts(for mangaID: UUID? = nil) {
        let targets = mangaID != nil ? [mangaID!] : mangaList.map { $0.id }
        for target in targets {
            let unread = chaptersList.filter { $0.mangaID == target && !$0.isRead }.count
            if let index = mangaList.firstIndex(where: { $0.id == target }) {
                mangaList[index].unreadCount = unread
            }
        }
        saveMangaToDisk()
    }
    
    // MARK: - Reading Progress
    
    @MainActor
    public func recordReadingProgress(
        chapter: ChapterItem,
        manga: MangaItem,
        pageIndex: Int,
        isComplete: Bool = false
    ) {
        let isFinished = isComplete || (chapter.pageCount > 0 && pageIndex >= chapter.pageCount - 1)
        
        // 1. Update Chapter in memory
        if let chIdx = chaptersList.firstIndex(where: { $0.id == chapter.id }) {
            chaptersList[chIdx].lastPageRead = pageIndex
            chaptersList[chIdx].lastReadPage = pageIndex
            if isFinished {
                chaptersList[chIdx].isRead = true
            }
        }
        
        // 2. Update Manga in memory with reactive timestamp and chapter link
        if let mIdx = mangaList.firstIndex(where: { $0.id == manga.id }) {
            let now = Date()
            mangaList[mIdx].lastReadAt = now
            mangaList[mIdx].lastReadDate = now
            mangaList[mIdx].lastReadChapterID = chapter.id
            mangaList[mIdx].lastReadChapterNumber = chapter.chapterNumber
            mangaList[mIdx].lastReadChapterTitle = chapter.displayTitle
        }
        
        // 3. Update Progress History
        let progress = ReadingProgress(
            chapterID: chapter.id,
            mangaID: manga.id,
            pageIndex: pageIndex,
            totalPages: max(chapter.pageCount, 1)
        )
        if let idx = historyList.firstIndex(where: { $0.chapterID == chapter.id }) {
            historyList[idx] = progress
        } else {
            historyList.append(progress)
        }
        
        recalculateUnreadCounts(for: manga.id)
        
        // Synchronous main thread save to disk
        saveHistoryToDisk()
        saveChaptersToDisk()
        saveMangaToDisk()
    }
    
    public func updateProgress(chapterID: UUID, mangaID: UUID, pageIndex: Int, totalPages: Int) {
        let progress = ReadingProgress(chapterID: chapterID, mangaID: mangaID, pageIndex: pageIndex, totalPages: totalPages)
        if let index = historyList.firstIndex(where: { $0.chapterID == chapterID }) {
            historyList[index] = progress
        } else {
            historyList.append(progress)
        }
        
        // Update chapter lastPageRead
        if let chIdx = chaptersList.firstIndex(where: { $0.id == chapterID }) {
            chaptersList[chIdx].lastPageRead = pageIndex
            chaptersList[chIdx].lastReadPage = pageIndex
            if pageIndex >= max(0, totalPages - 1) {
                chaptersList[chIdx].isRead = true
            }
        }
        
        // Update manga lastReadAt and lastReadDate
        if let mIdx = mangaList.firstIndex(where: { $0.id == mangaID }) {
            let now = Date()
            mangaList[mIdx].lastReadAt = now
            mangaList[mIdx].lastReadDate = now
            mangaList[mIdx].lastReadChapterID = chapterID
        }
        
        recalculateUnreadCounts(for: mangaID)
        saveHistoryToDisk()
        saveChaptersToDisk()
        saveMangaToDisk()
    }
    
    public func progress(for chapterID: UUID) -> ReadingProgress? {
        return historyList.first(where: { $0.chapterID == chapterID })
    }
    
    // MARK: - Categories
    
    public func addCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !categoriesList.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else { return }
        let newCat = CategoryItem(name: trimmed, sortOrder: categoriesList.count, isSystem: false)
        categoriesList.append(newCat)
        saveCategoriesToDisk()
    }
    
    public func removeCategory(id: UUID) {
        guard let cat = categoriesList.first(where: { $0.id == id }), !cat.isSystem else { return }
        categoriesList.removeAll(where: { $0.id == id })
        // Remove from manga items
        for i in 0..<mangaList.count {
            mangaList[i].categories.removeAll(where: { $0 == cat.name })
        }
        saveCategoriesToDisk()
        saveMangaToDisk()
    }
    
    // MARK: - Import / Restore
    
    public func restoreFromBackup(_ backup: BackupData) {
        self.mangaList = backup.libraryManga
        self.chaptersList = backup.chapters
        self.categoriesList = backup.categories
        self.historyList = backup.history
        self.readerSettings = backup.readerSettings
        self.trackingLinks = backup.trackingLinks
        saveAll()
    }
}
