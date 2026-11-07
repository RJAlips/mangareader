//
//  DownloadTaskItem.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public enum DownloadStatus: Equatable {
    case queued
    case downloading(progress: Double)
    case paused
    case completed
    case failed(message: String)
    
    public var displayText: String {
        switch self {
        case .queued: return "Queued"
        case .downloading(let p): return "\(Int(p * 100))%"
        case .paused: return "Paused"
        case .completed: return "Downloaded"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }
}

public struct DownloadTaskItem: Identifiable {
    public var id: UUID { chapter.id }
    public let manga: MangaItem
    public let chapter: ChapterItem
    public var status: DownloadStatus
    public var downloadedPages: Int
    public var totalPages: Int
    public var bytesDownloaded: Int64
    
    public init(
        manga: MangaItem,
        chapter: ChapterItem,
        status: DownloadStatus = .queued,
        downloadedPages: Int = 0,
        totalPages: Int = 0,
        bytesDownloaded: Int64 = 0
    ) {
        self.manga = manga
        self.chapter = chapter
        self.status = status
        self.downloadedPages = downloadedPages
        self.totalPages = totalPages
        self.bytesDownloaded = bytesDownloaded
    }
    
    public var progress: Double {
        guard totalPages > 0 else { return 0.0 }
        return Double(downloadedPages) / Double(totalPages)
    }
}
