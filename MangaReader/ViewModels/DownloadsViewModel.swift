//
//  DownloadsViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

public struct MangaDownloadGroup: Identifiable {
    public var id: UUID { manga.id }
    public let manga: MangaItem
    public var downloadedCount: Int
    public var queueCount: Int
    public var activeTask: DownloadTaskItem?
    public var activeProgress: Double?
}

@MainActor
public final class DownloadsViewModel: ObservableObject {
    @Published public private(set) var mangaGroups: [MangaDownloadGroup] = []
    @Published public private(set) var activeTasks: [DownloadTaskItem] = []
    @Published public private(set) var queuedTasks: [DownloadTaskItem] = []
    @Published public private(set) var completedTasks: [DownloadTaskItem] = []
    @Published public private(set) var failedTasks: [DownloadTaskItem] = []
    @Published public var wifiOnly: Bool = false
    @Published public private(set) var storageUsage: String = "0 MB"
    
    private let downloadManager = DownloadManager.shared
    private let db = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        self.wifiOnly = downloadManager.wifiOnly
        
        // Listen to download tasks
        downloadManager.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                guard let self = self else { return }
                self.activeTasks = tasks.filter {
                    if case .downloading = $0.status { return true }
                    return false
                }
                self.queuedTasks = tasks.filter {
                    if case .queued = $0.status { return true }
                    if case .paused = $0.status { return true }
                    return false
                }
                self.completedTasks = tasks.filter {
                    if case .completed = $0.status { return true }
                    return false
                }
                self.failedTasks = tasks.filter {
                    if case .failed = $0.status { return true }
                    return false
                }
                self.refreshGroups()
            }
            .store(in: &cancellables)
        
        // Listen to chapters changes (e.g. downloads completed or deleted)
        db.$chaptersList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshGroups()
            }
            .store(in: &cancellables)
        
        refreshGroups()
    }
    
    public func refreshGroups() {
        let tasks = downloadManager.tasks
        let chapters = db.chaptersList
        let allManga = db.mangaList
        
        var relevantMangaIDs = Set<UUID>()
        for t in tasks {
            relevantMangaIDs.insert(t.manga.id)
        }
        for ch in chapters where ch.isDownloaded {
            relevantMangaIDs.insert(ch.mangaID)
        }
        
        var groups: [MangaDownloadGroup] = []
        for id in relevantMangaIDs {
            guard let manga = allManga.first(where: { $0.id == id }) ?? tasks.first(where: { $0.manga.id == id })?.manga else {
                continue
            }
            
            let mangaChapters = chapters.filter { $0.mangaID == id }
            let downloadedChapters = mangaChapters.filter { $0.isDownloaded }
            let mangaTasks = tasks.filter { $0.manga.id == id }
            
            let active = mangaTasks.first(where: {
                if case .downloading = $0.status { return true }
                return false
            })
            
            var currentProgress: Double? = nil
            if let a = active, case .downloading(let p) = a.status {
                currentProgress = p
            }
            
            let queuedCount = mangaTasks.filter {
                if case .queued = $0.status { return true }
                if case .downloading = $0.status { return true }
                if case .paused = $0.status { return true }
                return false
            }.count
            
            let group = MangaDownloadGroup(
                manga: manga,
                downloadedCount: downloadedChapters.count,
                queueCount: queuedCount,
                activeTask: active,
                activeProgress: currentProgress
            )
            groups.append(group)
        }
        
        self.mangaGroups = groups.sorted {
            if ($0.activeProgress != nil) != ($1.activeProgress != nil) {
                return ($0.activeProgress != nil)
            }
            if $0.queueCount != $1.queueCount {
                return $0.queueCount > $1.queueCount
            }
            return $0.manga.title.localizedCompare($1.manga.title) == .orderedAscending
        }
        
        self.storageUsage = downloadManager.calculateTotalDownloadsSize()
    }
    
    public func inProgressTasks(for mangaID: UUID) -> [DownloadTaskItem] {
        return downloadManager.tasks.filter { task in
            guard task.manga.id == mangaID else { return false }
            switch task.status {
            case .downloading, .queued, .paused:
                return true
            default:
                return false
            }
        }
    }
    
    public func downloadedChapters(for mangaID: UUID) -> [ChapterItem] {
        return db.chapters(for: mangaID)
            .filter { $0.isDownloaded }
            .sorted { $0.chapterNumber > $1.chapterNumber }
    }
    
    public func notDownloadedChapters(for mangaID: UUID) -> [ChapterItem] {
        let queuedIDs = Set(downloadManager.tasks.map { $0.chapter.id })
        return db.chapters(for: mangaID)
            .filter { !$0.isDownloaded && !queuedIDs.contains($0.id) }
            .sorted { $0.chapterNumber > $1.chapterNumber }
    }
    
    public func chapterFileSize(_ chapter: ChapterItem, sourceID: String) -> String {
        return LocalStorageManager.shared.chapterFileSizeFormatted(chapter: chapter, sourceID: sourceID)
    }
    
    public func toggleWifiOnly() {
        downloadManager.wifiOnly.toggle()
        self.wifiOnly = downloadManager.wifiOnly
    }
    
    public func pause(task: DownloadTaskItem) {
        downloadManager.pauseTask(chapterID: task.chapter.id)
    }
    
    public func resume(task: DownloadTaskItem) {
        downloadManager.resumeTask(chapterID: task.chapter.id)
    }
    
    public func cancel(task: DownloadTaskItem) {
        downloadManager.cancelTask(chapterID: task.chapter.id)
    }
    
    public func deleteChapter(_ chapter: ChapterItem) {
        downloadManager.deleteDownloadedChapter(chapter)
    }
    
    public func downloadChapter(_ chapter: ChapterItem, for manga: MangaItem) {
        downloadManager.downloadChapter(chapter, for: manga)
    }
    
    public func clearCompleted() {
        downloadManager.clearCompleted()
    }
    
    public func updateStorageUsage() {
        self.storageUsage = downloadManager.calculateTotalDownloadsSize()
    }
}
