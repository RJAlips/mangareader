//
//  DownloadManager.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine
import Network

@MainActor
public final class DownloadManager: ObservableObject {
    public static let shared = DownloadManager()
    
    @Published public private(set) var tasks: [DownloadTaskItem] = []
    @Published public var wifiOnly: Bool = false
    @Published public var isConnectedToWifi: Bool = true
    
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mangareader.networkmonitor")
    private let fileManager = FileManager.default
    private var isProcessingQueue: Bool = false
    private let downloadsDirectory: URL
    
    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.downloadsDirectory = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        
        startNetworkMonitoring()
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
    
    public func downloadChapters(_ chapters: [ChapterItem], for manga: MangaItem) {
        for ch in chapters where !ch.isDownloaded {
            downloadChapter(ch, for: manga)
        }
    }
    
    public func pauseTask(chapterID: UUID) {
        if let idx = tasks.firstIndex(where: { $0.chapter.id == chapterID }) {
            tasks[idx].status = .paused
        }
    }
    
    public func resumeTask(chapterID: UUID) {
        if let idx = tasks.firstIndex(where: { $0.chapter.id == chapterID }) {
            tasks[idx].status = .queued
            resumeProcessingQueue()
        }
    }
    
    public func cancelTask(chapterID: UUID) {
        tasks.removeAll(where: { $0.chapter.id == chapterID })
    }
    
    public func clearCompleted() {
        tasks.removeAll(where: {
            if case .completed = $0.status { return true }
            return false
        })
    }
    
    public func deleteDownloadedChapter(_ chapter: ChapterItem) {
        let chapterDir = downloadsDirectory
            .appendingPathComponent(chapter.mangaID.uuidString)
            .appendingPathComponent(chapter.id.uuidString)
        try? fileManager.removeItem(at: chapterDir)
        
        // Update database
        if let index = DatabaseManager.shared.chaptersList.firstIndex(where: { $0.id == chapter.id }) {
            var updated = DatabaseManager.shared.chaptersList[index]
            updated.isDownloaded = false
            updated.downloadProgress = 0.0
            updated.localDirectoryPath = nil
            DatabaseManager.shared.upsertChapters([updated])
        }
        
        tasks.removeAll(where: { $0.chapter.id == chapter.id })
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
        
        Task {
            await executeDownload(for: task)
            self.isProcessingQueue = false
            self.resumeProcessingQueue()
        }
    }
    
    private func executeDownload(for task: DownloadTaskItem) async {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[taskIndex].status = .downloading(progress: 0.0)
        
        let mangaDir = downloadsDirectory.appendingPathComponent(task.manga.id.uuidString)
        let chapterDir = mangaDir.appendingPathComponent(task.chapter.id.uuidString)
        try? fileManager.createDirectory(at: chapterDir, withIntermediateDirectories: true)
        
        // If page URLs are empty, try fetching them from source provider
        var pageURLs = task.chapter.pageURLs
        if pageURLs.isEmpty {
            if let provider = SourceManager.shared.provider(for: task.manga.sourceID) {
                do {
                    pageURLs = try await provider.fetchPageURLs(for: task.chapter.sourceChapterID)
                    var updatedChapter = task.chapter
                    updatedChapter.pageURLs = pageURLs
                    updatedChapter.pageCount = pageURLs.count
                    DatabaseManager.shared.upsertChapters([updatedChapter])
                } catch {
                    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                        tasks[idx].status = .failed(message: error.localizedDescription)
                    }
                    return
                }
            }
        }
        
        guard !pageURLs.isEmpty else {
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].status = .failed(message: "No pages found")
            }
            return
        }
        
        var downloadedCount = 0
        let total = pageURLs.count
        
        for (pageIdx, url) in pageURLs.enumerated() {
            // Check cancellation / paused
            guard let currentTask = tasks.first(where: { $0.id == task.id }),
                  case .downloading = currentTask.status else {
                return
            }
            
            let filename = String(format: "%04d.jpg", pageIdx + 1)
            let destinationURL = chapterDir.appendingPathComponent(filename)
            
            if !fileManager.fileExists(atPath: destinationURL.path) {
                do {
                    let data = try await NetworkClient.shared.fetchData(from: url)
                    try data.write(to: destinationURL)
                } catch {
                    // Try caching through image manager as fallback
                    if let cached = await ImageCacheManager.shared.image(for: url),
                       let data = cached.jpegData(compressionQuality: 0.85) {
                        try? data.write(to: destinationURL)
                    } else {
                        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                            tasks[idx].status = .failed(message: "Failed page \(pageIdx + 1)")
                        }
                        return
                    }
                }
            }
            
            downloadedCount += 1
            let progress = Double(downloadedCount) / Double(total)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].downloadedPages = downloadedCount
                tasks[idx].totalPages = total
                tasks[idx].status = .downloading(progress: progress)
            }
        }
        
        // Success
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].status = .completed
            
            var updatedChapter = task.chapter
            updatedChapter.isDownloaded = true
            updatedChapter.downloadProgress = 1.0
            updatedChapter.localDirectoryPath = chapterDir.path
            DatabaseManager.shared.upsertChapters([updatedChapter])
        }
    }
    
    public func localPagesForChapter(_ chapter: ChapterItem) -> [URL]? {
        let chapterDir = downloadsDirectory
            .appendingPathComponent(chapter.mangaID.uuidString)
            .appendingPathComponent(chapter.id.uuidString)
        
        guard fileManager.fileExists(atPath: chapterDir.path),
              let files = try? fileManager.contentsOfDirectory(at: chapterDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        
        let imageFiles = files
            .filter { ["jpg", "jpeg", "png", "webp"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        
        return imageFiles.isEmpty ? nil : imageFiles
    }
    
    public func calculateTotalDownloadsSize() -> String {
        guard let files = fileManager.enumerator(at: downloadsDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 MB"
        }
        var totalBytes: Int64 = 0
        for case let fileURL as URL in files {
            if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                totalBytes += Int64(size)
            }
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
}
