//
//  DownloadManager.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine
import Network
import UIKit

// MARK: - Sandboxed Offline Storage Manager

public final class LocalStorageManager: @unchecked Sendable {
    public static let shared = LocalStorageManager()
    
    private let fileManager = FileManager.default
    
    public var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    public func resolveURL(for relativePath: String) -> URL {
        let clean = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return documentsDirectory.appendingPathComponent(clean)
    }
    
    public func getRelativePath(sourceID: String, mangaID: UUID, chapterID: UUID) -> String {
        return "Downloads/\(mangaID.uuidString)/\(chapterID.uuidString)/"
    }
    
    public func getLocalChapterPageURLs(mangaId: String, chapterId: String) -> [String]? {
        let cleanM = mangaId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanC = chapterId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let rootDownloads = documentsDirectory.appendingPathComponent("Downloads")
        
        // 1. Primary path: Documents/Downloads/{mangaId}/{chapterId}
        let directDir = rootDownloads.appendingPathComponent(cleanM).appendingPathComponent(cleanC)
        if let files = scanImages(in: directDir), !files.isEmpty {
            return files.map { $0.absoluteString }
        }
        
        // 2. Secondary path: check nested source directories Documents/Downloads/*/{mangaId}/{chapterId}
        if let sourceDirs = try? fileManager.contentsOfDirectory(at: rootDownloads, includingPropertiesForKeys: nil) {
            for sDir in sourceDirs {
                let candidate = sDir.appendingPathComponent(cleanM).appendingPathComponent(cleanC)
                if let files = scanImages(in: candidate), !files.isEmpty {
                    return files.map { $0.absoluteString }
                }
            }
        }
        return nil
    }
    
    private func scanImages(in directory: URL) -> [URL]? {
        guard fileManager.fileExists(atPath: directory.path) else { return nil }
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return nil }
        let imageFiles = files
            .filter { ["jpg", "jpeg", "png", "webp", "gif"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        return imageFiles.isEmpty ? nil : imageFiles
    }
    
    public func getLocalPages(for chapter: ChapterItem, sourceID: String? = nil) -> [URL]? {
        var candidateDirs: [URL] = []
        
        // 1. Strictly relative stored path
        if let rel = chapter.localDirectoryPath, !rel.isEmpty {
            candidateDirs.append(resolveURL(for: rel))
        }
        
        // 2. Standard pattern: Downloads/{mangaId}/{chapterId}/
        candidateDirs.append(
            documentsDirectory
                .appendingPathComponent("Downloads")
                .appendingPathComponent(chapter.mangaID.uuidString)
                .appendingPathComponent(chapter.id.uuidString)
        )
        
        // 3. Computed standard relative pattern with sourceID: Downloads/{sourceId}/{mangaId}/{chapterId}/
        if let sID = sourceID {
            candidateDirs.append(
                documentsDirectory
                    .appendingPathComponent("Downloads")
                    .appendingPathComponent(sID)
                    .appendingPathComponent(chapter.mangaID.uuidString)
                    .appendingPathComponent(chapter.id.uuidString)
            )
        }
        
        for dir in candidateDirs {
            if let files = scanImages(in: dir), !files.isEmpty {
                return files
            }
        }
        return nil
    }
    
    public static func getLocalPages(for chapter: ChapterItem, sourceID: String? = nil) -> [URL]? {
        return shared.getLocalPages(for: chapter, sourceID: sourceID)
    }
    
    public func getLocalImage(for url: URL) -> UIImage? {
        guard url.isFileURL || url.scheme == "file" else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    
    public static func getLocalImage(for url: URL) -> UIImage? {
        return shared.getLocalImage(for: url)
    }
    
    public func chapterFileSizeFormatted(chapter: ChapterItem, sourceID: String? = nil) -> String {
        guard let pages = getLocalPages(for: chapter, sourceID: sourceID) else { return "0 KB" }
        var totalBytes: Int64 = 0
        for page in pages {
            if let attrs = try? fileManager.attributesOfItem(atPath: page.path),
               let size = attrs[.size] as? Int64 {
                totalBytes += size
            }
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
}

// MARK: - Download Manager

@MainActor
public final class DownloadManager: ObservableObject {
    public static let shared = DownloadManager()
    
    @Published public private(set) var tasks: [DownloadTaskItem] = []
    @Published public private(set) var activeQueueTasks: [DownloadTaskItem] = []
    @Published public private(set) var completedTasks: [DownloadTaskItem] = []
    
    @Published public var maxConcurrentDownloads: Int {
        didSet {
            UserDefaults.standard.set(maxConcurrentDownloads, forKey: "maxConcurrentDownloads")
            scheduleWorkers()
        }
    }
    @Published public var isPaused: Bool = false
    @Published public var wifiOnly: Bool = false
    @Published public var isConnectedToWifi: Bool = true
    @Published public private(set) var totalDownloadedSize: Int64 = 0
    
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mangareader.networkmonitor")
    private let fileManager = FileManager.default
    private var activeDownloadTasks: [UUID: Task<Void, Never>] = [:]
    
    private var downloadStoreURL: URL {
        LocalStorageManager.shared.resolveURL(for: "Downloads/download_store.json")
    }
    
    private init() {
        let storedConcurrency = UserDefaults.standard.integer(forKey: "maxConcurrentDownloads")
        self.maxConcurrentDownloads = (1...4).contains(storedConcurrency) ? storedConcurrency : 2
        
        // Ensure root Downloads directory exists
        let downloadsDir = LocalStorageManager.shared.resolveURL(for: "Downloads")
        try? fileManager.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        
        // 1. Reconstruct persisted queue from disk
        loadQueueFromDisk()
        
        // 2. Scan disk for any downloaded chapters not in queue (Mihon DownloadCache pattern)
        rebuildIndexFromDisk()
        
        startNetworkMonitoring()
        updateTotalStorageUsage()
        updateFilteredTaskLists()
        
        // Start processing any remaining queued tasks
        scheduleWorkers()
    }
    
    nonisolated public func getLocalChapterPageURLs(mangaId: String, chapterId: String) -> [String]? {
        return LocalStorageManager.shared.getLocalChapterPageURLs(mangaId: mangaId, chapterId: chapterId)
    }
    
    nonisolated public func getLocalChapterPageURLs(mangaId: UUID, chapterId: UUID) -> [String]? {
        return getLocalChapterPageURLs(mangaId: mangaId.uuidString, chapterId: chapterId.uuidString)
    }
    
    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let isWifi = path.usesInterfaceType(.wifi)
            Task { @MainActor in
                self?.isConnectedToWifi = isWifi
                if isWifi {
                    self?.scheduleWorkers()
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Queue & Worker Coordinator (Mihon Multi-Worker Pool)
    
    public func scheduleWorkers() {
        guard !isPaused else { return }
        if wifiOnly && !isConnectedToWifi { return }
        
        while activeDownloadTasks.count < maxConcurrentDownloads {
            guard let nextIndex = tasks.firstIndex(where: {
                if case .queued = $0.status, activeDownloadTasks[$0.id] == nil {
                    return true
                }
                return false
            }) else {
                break
            }
            
            let task = tasks[nextIndex]
            tasks[nextIndex].status = .downloading(progress: tasks[nextIndex].progress)
            updateFilteredTaskLists()
            saveQueueToDisk()
            
            let taskID = task.id
            let worker = Task { [weak self] in
                await self?.executeDownload(for: task)
                await MainActor.run {
                    self?.activeDownloadTasks.removeValue(forKey: taskID)
                    self?.scheduleWorkers()
                }
            }
            activeDownloadTasks[taskID] = worker
        }
    }
    
    public func cycleConcurrency() {
        maxConcurrentDownloads = (maxConcurrentDownloads % 4) + 1
    }
    
    public func togglePauseAll() {
        isPaused.toggle()
        if isPaused {
            for (_, task) in activeDownloadTasks {
                task.cancel()
            }
            activeDownloadTasks.removeAll()
            
            for i in 0..<tasks.count {
                if case .downloading = tasks[i].status {
                    tasks[i].status = .paused
                }
            }
            updateFilteredTaskLists()
            saveQueueToDisk()
        } else {
            for i in 0..<tasks.count {
                if case .paused = tasks[i].status {
                    tasks[i].status = .queued
                }
            }
            updateFilteredTaskLists()
            saveQueueToDisk()
            scheduleWorkers()
        }
    }
    
    // MARK: - Task Enqueue & Operations
    
    public func downloadChapter(_ chapter: ChapterItem, for manga: MangaItem) {
        guard !tasks.contains(where: { $0.chapter.id == chapter.id }) else { return }
        
        let newTask = DownloadTaskItem(
            manga: manga,
            chapter: chapter,
            status: .queued,
            downloadedPages: 0,
            totalPages: chapter.pageURLs.count,
            localFolderPath: "Downloads/\(manga.id.uuidString)/\(chapter.id.uuidString)/"
        )
        tasks.append(newTask)
        updateFilteredTaskLists()
        saveQueueToDisk()
        scheduleWorkers()
    }
    
    public func enqueue(_ chapter: ChapterItem, for manga: MangaItem) {
        downloadChapter(chapter, for: manga)
    }
    
    public func downloadChapters(_ chapters: [ChapterItem], for manga: MangaItem) {
        for ch in chapters where !ch.isDownloaded {
            downloadChapter(ch, for: manga)
        }
    }
    
    public func enqueue(chapters: [ChapterItem], for manga: MangaItem) {
        downloadChapters(chapters, for: manga)
    }
    
    public func pauseTask(chapterID: UUID) {
        if let idx = tasks.firstIndex(where: { $0.chapter.id == chapterID }) {
            let taskID = tasks[idx].id
            tasks[idx].status = .paused
            if let worker = activeDownloadTasks.removeValue(forKey: taskID) {
                worker.cancel()
            }
            updateFilteredTaskLists()
            saveQueueToDisk()
            scheduleWorkers()
        }
    }
    
    public func resumeTask(chapterID: UUID) {
        if let idx = tasks.firstIndex(where: { $0.chapter.id == chapterID }) {
            tasks[idx].status = .queued
            updateFilteredTaskLists()
            saveQueueToDisk()
            scheduleWorkers()
        }
    }
    
    public func cancelTask(chapterID: UUID) {
        if let idx = tasks.firstIndex(where: { $0.chapter.id == chapterID }) {
            let taskID = tasks[idx].id
            if let worker = activeDownloadTasks.removeValue(forKey: taskID) {
                worker.cancel()
            }
            tasks.remove(at: idx)
            updateFilteredTaskLists()
            saveQueueToDisk()
            scheduleWorkers()
        }
    }
    
    public func cancelDownloads(for mangaID: UUID) {
        let matches = tasks.filter { $0.manga.id == mangaID }
        for match in matches {
            cancelTask(chapterID: match.chapter.id)
        }
    }
    
    public func clearCompleted() {
        tasks.removeAll(where: {
            if case .completed = $0.status { return true }
            return false
        })
        updateFilteredTaskLists()
        saveQueueToDisk()
    }
    
    public func deleteDownloadedChapter(_ chapter: ChapterItem) {
        cancelTask(chapterID: chapter.id)
        
        // Remove from disk
        let directDir = LocalStorageManager.shared.resolveURL(for: "Downloads/\(chapter.mangaID.uuidString)/\(chapter.id.uuidString)")
        try? fileManager.removeItem(at: directDir)
        
        if let rel = chapter.localDirectoryPath, !rel.isEmpty {
            let relDir = LocalStorageManager.shared.resolveURL(for: rel)
            try? fileManager.removeItem(at: relDir)
        }
        
        // Update database
        if let index = DatabaseManager.shared.chaptersList.firstIndex(where: { $0.id == chapter.id }) {
            var updated = DatabaseManager.shared.chaptersList[index]
            updated.isDownloaded = false
            updated.downloadProgress = 0.0
            updated.localDirectoryPath = nil
            DatabaseManager.shared.upsertChapters([updated])
        }
        
        tasks.removeAll(where: { $0.chapter.id == chapter.id })
        updateFilteredTaskLists()
        saveQueueToDisk()
        updateTotalStorageUsage()
    }
    
    public func deleteDownloadedChapters(for mangaID: UUID) {
        let downloaded = DatabaseManager.shared.chapters(for: mangaID).filter { $0.isDownloaded }
        for ch in downloaded {
            deleteDownloadedChapter(ch)
        }
    }
    
    // MARK: - Download Execution with Bounded Parallel Page Fetching
    
    private func executeDownload(for task: DownloadTaskItem) async {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[taskIndex].status = .downloading(progress: task.progress)
        updateFilteredTaskLists()
        
        let relativePath = "Downloads/\(task.manga.id.uuidString)/\(task.chapter.id.uuidString)/"
        let chapterDir = LocalStorageManager.shared.resolveURL(for: relativePath)
        try? fileManager.createDirectory(at: chapterDir, withIntermediateDirectories: true)
        
        // Save initial metadata
        saveChapterMetadata(task, at: chapterDir)
        
        // 1. Resolve source provider & fetch page URLs if needed
        var pageURLs = task.chapter.pageURLs
        if pageURLs.isEmpty {
            let provider = SourceManager.shared.getSource(id: task.manga.sourceID) ?? SourceManager.shared.provider(for: task.manga.sourceID)
            if let provider = provider {
                do {
                    var cleanChapterId = task.chapter.sourceChapterID.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let lastPart = cleanChapterId.components(separatedBy: "_").last, !lastPart.isEmpty {
                        cleanChapterId = lastPart
                    }
                    if cleanChapterId.lowercased().hasPrefix("ch_") {
                        cleanChapterId = String(cleanChapterId.dropFirst(3))
                    } else if cleanChapterId.lowercased().hasPrefix("chapter_") {
                        cleanChapterId = String(cleanChapterId.dropFirst(8))
                    }
                    
                    pageURLs = try await provider.fetchPageURLs(for: cleanChapterId)
                    if !pageURLs.isEmpty {
                        var updatedChapter = task.chapter
                        updatedChapter.pageURLs = pageURLs
                        updatedChapter.pageCount = pageURLs.count
                        DatabaseManager.shared.upsertChapters([updatedChapter])
                    }
                } catch {
                    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                        tasks[idx].status = .failed(message: error.localizedDescription)
                        updateFilteredTaskLists()
                        saveQueueToDisk()
                    }
                    return
                }
            }
        }
        
        guard !pageURLs.isEmpty else {
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].status = .failed(message: "No pages found")
                updateFilteredTaskLists()
                saveQueueToDisk()
            }
            return
        }
        
        // 2. Bounded sliding window of up to 3 concurrent page downloads
        let total = pageURLs.count
        var completedPages = 0
        var totalBytes: Int64 = 0
        let maxConcurrentPages = 3
        var inFlight = 0
        
        do {
            try await withThrowingTaskGroup(of: (Int, Int64).self) { group in
                var iterator = pageURLs.enumerated().makeIterator()
                
                while inFlight < maxConcurrentPages, let (pageIdx, url) = iterator.next() {
                    inFlight += 1
                    let dest = chapterDir.appendingPathComponent(String(format: "%03d.jpg", pageIdx + 1))
                    group.addTask {
                        return try await self.downloadPageWithRetry(
                            pageIndex: pageIdx,
                            url: url,
                            destinationURL: dest
                        )
                    }
                }
                
                while let (pageIdx, bytes) = try await group.next() {
                    _ = pageIdx
                    inFlight -= 1
                    completedPages += 1
                    totalBytes += bytes
                    
                    if let idx = self.tasks.firstIndex(where: { $0.id == task.id }) {
                        self.tasks[idx].downloadedPages = completedPages
                        self.tasks[idx].totalPages = total
                        self.tasks[idx].bytesDownloaded = totalBytes
                        let progress = Double(completedPages) / Double(total)
                        self.tasks[idx].status = .downloading(progress: progress)
                        self.updateFilteredTaskLists()
                    }
                    
                    if let (nextIdx, nextURL) = iterator.next() {
                        inFlight += 1
                        let dest = chapterDir.appendingPathComponent(String(format: "%03d.jpg", nextIdx + 1))
                        group.addTask {
                            return try await self.downloadPageWithRetry(
                                pageIndex: nextIdx,
                                url: nextURL,
                                destinationURL: dest
                            )
                        }
                    }
                }
            }
        } catch {
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].status = .failed(message: error.localizedDescription)
                updateFilteredTaskLists()
                saveQueueToDisk()
            }
            return
        }
        
        // Success: Mark completed and update persistence
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].status = .completed
            tasks[idx].downloadedPages = total
            tasks[idx].totalPages = total
            tasks[idx].bytesDownloaded = totalBytes
            tasks[idx].completedAt = Date()
            
            var updatedChapter = task.chapter
            updatedChapter.isDownloaded = true
            updatedChapter.downloadProgress = 1.0
            updatedChapter.localDirectoryPath = relativePath
            DatabaseManager.shared.upsertChapters([updatedChapter])
            
            saveChapterMetadata(tasks[idx], at: chapterDir)
            updateFilteredTaskLists()
            saveQueueToDisk()
        }
        
        updateTotalStorageUsage()
    }
    
    private func downloadPageWithRetry(
        pageIndex: Int,
        url: URL,
        destinationURL: URL
    ) async throws -> (Int, Int64) {
        if fileManager.fileExists(atPath: destinationURL.path),
           let attrs = try? fileManager.attributesOfItem(atPath: destinationURL.path),
           let size = attrs[.size] as? Int64, size > 0 {
            return (pageIndex, size)
        }
        
        var lastError: Error?
        for attempt in 1...3 {
            try Task.checkCancellation()
            do {
                let data = try await NetworkClient.shared.fetchDataWithCDNHeaders(from: url)
                guard !data.isEmpty, UIImage(data: data) != nil else {
                    throw NetworkError.noData
                }
                try data.write(to: destinationURL, options: .atomic)
                return (pageIndex, Int64(data.count))
            } catch {
                lastError = error
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s backoff
                }
            }
        }
        throw lastError ?? NetworkError.unknown(message: "Failed page \(pageIndex + 1)")
    }
    
    // MARK: - Disk Persistence & Recovery (Mihon DownloadStore + DownloadCache)
    
    public func saveQueueToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self.tasks)
            try data.write(to: downloadStoreURL, options: .atomic)
        } catch {
            print("[DownloadManager] Error saving download_store.json: \(error)")
        }
    }
    
    private func loadQueueFromDisk() {
        guard fileManager.fileExists(atPath: downloadStoreURL.path) else { return }
        do {
            let data = try Data(contentsOf: downloadStoreURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var loaded = try decoder.decode([DownloadTaskItem].self, from: data)
            
            // Set any zombie .downloading tasks to .paused
            for i in 0..<loaded.count {
                if case .downloading = loaded[i].status {
                    loaded[i].status = .paused
                }
            }
            self.tasks = loaded
        } catch {
            print("[DownloadManager] Error reading download_store.json: \(error)")
        }
    }
    
    private func saveChapterMetadata(_ task: DownloadTaskItem, at folder: URL) {
        let metadataURL = folder.appendingPathComponent("metadata.json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(task)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            print("[DownloadManager] Failed writing metadata.json: \(error)")
        }
    }
    
    public func loadSavedDownloads() {
        loadQueueFromDisk()
        rebuildIndexFromDisk()
        updateTotalStorageUsage()
        updateFilteredTaskLists()
    }
    
    public func resetInMemoryQueueForTesting() {
        activeDownloadTasks.values.forEach { $0.cancel() }
        activeDownloadTasks.removeAll()
        tasks = []
        activeQueueTasks = []
        completedTasks = []
    }
    
    public func rebuildIndexFromDisk() {
        let downloadsDir = LocalStorageManager.shared.resolveURL(for: "Downloads")
        guard let mangaDirs = try? fileManager.contentsOfDirectory(at: downloadsDir, includingPropertiesForKeys: nil) else {
            return
        }
        
        var existingIDs = Set(tasks.map { $0.chapter.id })
        var restored: [DownloadTaskItem] = []
        
        for mDir in mangaDirs where mDir.hasDirectoryPath {
            guard let chapterDirs = try? fileManager.contentsOfDirectory(at: mDir, includingPropertiesForKeys: nil) else {
                continue
            }
            
            for cDir in chapterDirs where cDir.hasDirectoryPath {
                let files = (try? fileManager.contentsOfDirectory(at: cDir, includingPropertiesForKeys: nil)) ?? []
                let imageFiles = files.filter { ["jpg", "jpeg", "png", "webp"].contains($0.pathExtension.lowercased()) }
                guard !imageFiles.isEmpty else { continue }
                
                let metadataFile = cDir.appendingPathComponent("metadata.json")
                if fileManager.fileExists(atPath: metadataFile.path),
                   let data = try? Data(contentsOf: metadataFile),
                   let decoded = try? JSONDecoder().decode(DownloadTaskItem.self, from: data) {
                    if !existingIDs.contains(decoded.chapter.id) {
                        var task = decoded
                        task.status = .completed
                        task.downloadedPages = imageFiles.count
                        task.totalPages = max(task.totalPages, imageFiles.count)
                        existingIDs.insert(task.chapter.id)
                        restored.append(task)
                    }
                } else {
                    let mangaIdStr = mDir.lastPathComponent
                    let chapterIdStr = cDir.lastPathComponent
                    let chapterUUID = UUID(uuidString: chapterIdStr) ?? UUID()
                    let mangaUUID = UUID(uuidString: mangaIdStr) ?? UUID()
                    
                    if !existingIDs.contains(chapterUUID) {
                        let dbManga = DatabaseManager.shared.mangaList.first(where: { $0.id == mangaUUID })
                        let dbChapter = DatabaseManager.shared.chaptersList.first(where: { $0.id == chapterUUID })
                        
                        let mangaItem = dbManga ?? MangaItem(
                            id: mangaUUID,
                            sourceID: "offline",
                            urlOrSlug: mangaIdStr,
                            title: dbManga?.title ?? "Downloaded Series",
                            genres: ["Offline"]
                        )
                        
                        let chapterItem = dbChapter ?? ChapterItem(
                            id: chapterUUID,
                            mangaID: mangaUUID,
                            sourceChapterID: chapterIdStr,
                            chapterNumber: dbChapter?.chapterNumber ?? 1.0,
                            title: dbChapter?.title ?? "Chapter \(chapterIdStr)",
                            pageCount: imageFiles.count,
                            isDownloaded: true,
                            localDirectoryPath: "Downloads/\(mangaIdStr)/\(chapterIdStr)/"
                        )
                        
                        let totalBytes = imageFiles.reduce(Int64(0)) { sum, file in
                            let sz = (try? fileManager.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                            return sum + sz
                        }
                        
                        let synthTask = DownloadTaskItem(
                            manga: mangaItem,
                            chapter: chapterItem,
                            status: .completed,
                            downloadedPages: imageFiles.count,
                            totalPages: imageFiles.count,
                            bytesDownloaded: totalBytes,
                            localFolderPath: "Downloads/\(mangaIdStr)/\(chapterIdStr)/",
                            completedAt: Date()
                        )
                        existingIDs.insert(synthTask.chapter.id)
                        restored.append(synthTask)
                        saveChapterMetadata(synthTask, at: cDir)
                    }
                }
            }
        }
        
        if !restored.isEmpty {
            self.tasks.append(contentsOf: restored)
            saveQueueToDisk()
        }
    }
    
    private func updateFilteredTaskLists() {
        self.activeQueueTasks = self.tasks.filter {
            switch $0.status {
            case .queued, .downloading, .paused, .failed: return true
            case .completed: return false
            }
        }
        self.completedTasks = self.tasks.filter {
            if case .completed = $0.status { return true }
            return false
        }
    }
    
    public func localPagesForChapter(_ chapter: ChapterItem, sourceID: String? = nil) -> [URL]? {
        return LocalStorageManager.shared.getLocalPages(for: chapter, sourceID: sourceID)
    }
    
    public func updateTotalStorageUsage() {
        let downloadsDir = LocalStorageManager.shared.resolveURL(for: "Downloads")
        guard let files = fileManager.enumerator(at: downloadsDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            self.totalDownloadedSize = 0
            return
        }
        var totalBytes: Int64 = 0
        for case let fileURL as URL in files {
            if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                totalBytes += Int64(size)
            }
        }
        self.totalDownloadedSize = totalBytes
    }
    
    public func calculateTotalDownloadsSize() -> String {
        updateTotalStorageUsage()
        guard totalDownloadedSize > 0 else { return "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalDownloadedSize)
    }
}
