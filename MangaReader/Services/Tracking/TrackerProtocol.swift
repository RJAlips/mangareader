//
//  TrackerProtocol.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public enum TrackStatus: String, CaseIterable, Codable {
    case current = "Reading"
    case completed = "Completed"
    case onHold = "On Hold"
    case dropped = "Dropped"
    case planToRead = "Plan to Read"
}

public struct TrackSearchResult: Identifiable, Codable {
    public let id: String
    public let title: String
    public let coverURL: URL?
    public let totalChapters: Int?
    public let synopsis: String?
}

public protocol MangaTracker: AnyObject, Sendable {
    var trackerID: String { get }
    var trackerName: String { get }
    var isLoggedIn: Bool { get }
    
    func login(token: String) async throws
    func logout()
    func search(query: String) async throws -> [TrackSearchResult]
    func updateProgress(remoteID: String, chapterNumber: Int, status: TrackStatus, score: Double?) async throws
}
