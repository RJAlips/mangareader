//
//  DownloadsViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

@MainActor
public final class DownloadsViewModel: ObservableObject {
    @Published public private(set) var activeTasks: [DownloadTaskItem] = []
    @Published public private(set) var queuedTasks: [DownloadTaskItem] = []
    @Published public private(set) var completedTasks: [DownloadTaskItem] = []
    @Published public private(set) var failedTasks: [DownloadTaskItem] = []
    @Published public var wifiOnly: Bool = false
    @Published public private(set) var storageUsage: String = "0 MB"
    
    private let downloadManager = DownloadManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        self.wifiOnly = downloadManager.wifiOnly
        
        downloadManager.$tasks
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
                self.updateStorageUsage()
            }
            .store(in: &cancellables)
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
    
    public func clearCompleted() {
        downloadManager.clearCompleted()
    }
    
    public func updateStorageUsage() {
        self.storageUsage = downloadManager.calculateTotalDownloadsSize()
    }
}
