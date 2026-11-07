//
//  TrackerManager.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Combine

public final class TrackerManager: ObservableObject {
    public static let shared = TrackerManager()
    
    @Published public private(set) var trackers: [any MangaTracker] = []
    
    public let anilist = AniListTracker()
    public let myanimelist = MyAnimeListTracker()
    
    private init() {
        self.trackers = [anilist, myanimelist]
    }
    
    public func linkManga(_ mangaID: UUID, remoteID: String, trackerID: String) {
        let key = "\(mangaID.uuidString):\(trackerID)"
        DatabaseManager.shared.trackingLinks[key] = remoteID
        DatabaseManager.shared.saveTrackingToDisk()
    }
    
    public func linkedRemoteID(for mangaID: UUID, trackerID: String) -> String? {
        let key = "\(mangaID.uuidString):\(trackerID)"
        return DatabaseManager.shared.trackingLinks[key]
    }
    
    public func unlinkManga(_ mangaID: UUID, trackerID: String) {
        let key = "\(mangaID.uuidString):\(trackerID)"
        DatabaseManager.shared.trackingLinks.removeValue(forKey: key)
        DatabaseManager.shared.saveTrackingToDisk()
    }
    
    public func syncProgress(mangaID: UUID, chapterNumber: Int, isCompleted: Bool) async {
        for tracker in trackers where tracker.isLoggedIn {
            if let remoteID = linkedRemoteID(for: mangaID, trackerID: tracker.trackerID) {
                let status: TrackStatus = isCompleted ? .completed : .current
                try? await tracker.updateProgress(
                    remoteID: remoteID,
                    chapterNumber: chapterNumber,
                    status: status,
                    score: nil
                )
            }
        }
    }
}
