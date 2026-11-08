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
    @Published public var wifiOnly: Bool = false
    @Published public var isConnectedToWifi: Bool = true
    @Published public private(set) var totalDownloadedSize: Int64 = 0
    
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mangareader.networkmonitor")
    private let fileManager = FileManager.default
    private var isProcessingQueue: Bool = false
    private var activeDownloadTask: Task<Void, Never>? = nil
    
    private init() {
        // Ensure root Downloads directory exists
        let downloadsDir = LocalStorageManager.shared.resolveURL(for: "Downloads")
        try? fileManager.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        
        startNetworkMonitoring()
        updateTotalStorageUsage()
    }
    
    public func getLocalChapterPageURLs(mangaId: String, chapterId: String) -> [String]? {
        return LocalStorageManager.shared.getLocalChapterPageURLs(mangaId: mangaId, chapterId: chapterId)
    }
    
    public func getLocalChapterPageURLs(mangaId: UUID, chapterId: UUID) -> [String]? {
        return getLocalChapterPageURLs(mangaId: mangaId.uuidString, chapterId: chapterId.uuidString)
    }
    
    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let isWifi = path.usesInterfaceType(.wifi)
            Task { @MainActor in
                self?.isConnectedToWifi = isWifi
                if isWifi {
                    self?.resumeProcessingQueue()
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    public func downloadChapter(_ chapter: ChapterItem, for manga: MangaItem) {
        guard !tasks.contains(where: { $0.chapter.id == chapter.id }) else { return }
        
        let newTask = DownloadTaskItem(
            manga: manga,
            chapter: chapter,
            status: .queued,
            downloadedPages: 0,
            totalPages: chapter.pageURLs.count
        )
        tasks.append(newTask)
        resumeProcessingQueue()
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
            let wasDownloading: Bool = {
                if case .downloading = tasks[idx].status { return true }
                return false
            }()
            tasks[idx].status = .paused
            if wasDownloading {
                activeDownloadTask?.cancel()
                activeDownloadTask = nil
                isProcessingQueue = false
                resumeProcessingQueue()
            }
        }
    }
    
    public func resumeTask(chapterID: UUID) {
        if let idx = tasks.firstIndex(where: { $0.chapter.id == chapterID }) {
            tasks[idx].status = .queued
            resumeProcessingQueue()
        }
    }
    
    public func cancelTask(chapterID: UUID) {
        if let idx = tasks.firstIndex(where: { $0.chapter.id == chapterID }) {
            let wasDownloading: Bool = {
                if case .downloading = tasks[idx].status { return true }
                return false
            }()
            tasks.remove(at: idx)
            if wasDownloading {
                activeDownloadTask?.cancel()
                activeDownloadTask = nil
                isProcessingQueue = false
                resumeProcessingQueue()
            }
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
    }
    
    public func deleteDownloadedChapter(_ chapter: ChapterItem) {
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
        updateTotalStorageUsage()
    }
    
    public func deleteDownloadedChapters(for mangaID: UUID) {
        let downloaded = DatabaseManager.shared.chapters(for: mangaID).filter { $0.isDownloaded }
        for ch in downloaded {
            deleteDownloadedChapter(ch)
        }
    }
    
    private func resumeProcessingQueue() {
        guard !isProcessingQueue else { return }
        if wifiOnly && !isConnectedToWifi { return }
        
        guard let nextIndex = tasks.firstIndex(where: {
            if case .queued = $0.status { return true }
            return false
        }) else { return }
        
        isProcessingQueue = true
        let task = tasks[nextIndex]
        
        activeDownloadTask = Task {
            await executeDownload(for: task)
            self.isProcessingQueue = false
            self.activeDownloadTask = nil
            self.resumeProcessingQueue()
        }
    }
    
    private func executeDownload(for task: DownloadTaskItem) async {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[taskIndex].status = .downloading(progress: 0.0)
        
        // Sandboxed relative path: Documents/Downloads/{mangaId}/{chapterId}/
        let relativePath = "Downloads/\(task.manga.id.uuidString)/\(task.chapter.id.uuidString)/"
        let chapterDir = LocalStorageManager.shared.resolveURL(for: relativePath)
        try? fileManager.createDirectory(at: chapterDir, withIntermediateDirectories: true)
        
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
                    }
                    return
                }
            }
        }
        
        guard !pageURLs.isEmpty else {
            // Mark failed and return immediately so the worker loop advances to the next chapter
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].status = .failed(message: "No pages found")
            }
            return
        }
        
        var completedPages = 0
        var totalBytes: Int64 = 0
        let total = pageURLs.count
        
        for (pageIdx, url) in pageURLs.enumerated() {
            // Check cancellation or pause
            if Task.isCancelled { return }
            guard let currentTask = tasks.first(where: { $0.id == task.id }),
                  case .downloading = currentTask.status else {
                return
            }
            
            let filename = String(format: "%03d.jpg", pageIdx + 1)
            let destinationURL = chapterDir.appendingPathComponent(filename)
            
            if !fileManager.fileExists(atPath: destinationURL.path) {
                do {
                    let data = try await NetworkClient.shared.fetchDataWithCDNHeaders(from: url)
                    try data.write(to: destinationURL, options: .atomic)
                    totalBytes += Int64(data.count)
                } catch {
                    // Try caching through image cache manager as fallback
                    if let cached = await ImageCacheManager.shared.image(for: url),
                       let data = cached.jpegData(compressionQuality: 0.85) {
                        try? data.write(to: destinationURL, options: .atomic)
                        totalBytes += Int64(data.count)
                    } else {
                        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                            tasks[idx].status = .failed(message: "Failed page \(pageIdx + 1)")
                        }
                        return
                    }
                }
            } else {
                if let attrs = try? fileManager.attributesOfItem(atPath: destinationURL.path),
                   let size = attrs[.size] as? Int64 {
                    totalBytes += size
                }
            }
            
            completedPages += 1
            let progress = Double(completedPages) / Double(total)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].downloadedPages = completedPages
                tasks[idx].totalPages = total
                tasks[idx].bytesDownloaded = totalBytes
                tasks[idx].status = .downloading(progress: progress)
            }
        }
        
        // Success: Store strictly relative path in entities and mark completed
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].status = .completed
            tasks[idx].downloadedPages = total
            tasks[idx].totalPages = total
            tasks[idx].bytesDownloaded = totalBytes
            
            var updatedChapter = task.chapter
            updatedChapter.isDownloaded = true
            updatedChapter.downloadProgress = 1.0
            updatedChapter.localDirectoryPath = relativePath
            DatabaseManager.shared.upsertChapters([updatedChapter])
        }
        
        updateTotalStorageUsage()
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
