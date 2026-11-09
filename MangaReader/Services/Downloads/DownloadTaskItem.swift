//
//  DownloadTaskItem.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public enum DownloadStatus: Codable, Equatable, Hashable {
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
    
    private enum CodingKeys: String, CodingKey {
        case type
        case progress
        case message
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "queued":
            self = .queued
        case "downloading":
            let progress = try container.decodeIfPresent(Double.self, forKey: .progress) ?? 0.0
            self = .downloading(progress: progress)
        case "paused":
            self = .paused
        case "completed":
            self = .completed
        case "failed":
            let message = try container.decodeIfPresent(String.self, forKey: .message) ?? "Unknown error"
            self = .failed(message: message)
        default:
            self = .queued
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .queued:
            try container.encode("queued", forKey: .type)
        case .downloading(let progress):
            try container.encode("downloading", forKey: .type)
            try container.encode(progress, forKey: .progress)
        case .paused:
            try container.encode("paused", forKey: .type)
        case .completed:
            try container.encode("completed", forKey: .type)
        case .failed(let message):
            try container.encode("failed", forKey: .type)
            try container.encode(message, forKey: .message)
        }
    }
}

public struct DownloadTaskItem: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID { chapter.id }
    public let manga: MangaItem
    public let chapter: ChapterItem
    public var status: DownloadStatus
    public var downloadedPages: Int
    public var totalPages: Int
    public var bytesDownloaded: Int64
    public var localFolderPath: String?
    public var completedAt: Date?
    
    // Convenience accessors for offline display
    public var mangaId: UUID { manga.id }
    public var mangaTitle: String { manga.title }
    public var mangaCoverURL: URL? { manga.coverURL }
    public var author: String? { manga.author }
    public var sourceId: String { manga.sourceID }
    public var chapterId: UUID { chapter.id }
    public var chapterTitle: String { chapter.title ?? "Chapter \(chapter.chapterNumber)" }
    public var chapterNumber: Double { chapter.chapterNumber }
    
    public init(
        manga: MangaItem,
        chapter: ChapterItem,
        status: DownloadStatus = .queued,
        downloadedPages: Int = 0,
        totalPages: Int = 0,
        bytesDownloaded: Int64 = 0,
        localFolderPath: String? = nil,
        completedAt: Date? = nil
    ) {
        self.manga = manga
        self.chapter = chapter
        self.status = status
        self.downloadedPages = downloadedPages
        self.totalPages = totalPages
        self.bytesDownloaded = bytesDownloaded
        self.localFolderPath = localFolderPath ?? "Downloads/\(manga.id.uuidString)/\(chapter.id.uuidString)/"
        self.completedAt = completedAt
    }
    
    public var progress: Double {
        guard totalPages > 0 else { return 0.0 }
        return Double(downloadedPages) / Double(totalPages)
    }
}
