//
//  MangaReaderApp.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

@main
@MainActor
struct MangaReaderApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var db = DatabaseManager.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .environmentObject(db)
                .environmentObject(downloadManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                // Flush all JSON to disk synchronously before the OS suspends
                // the process. Using saveAllSync() ensures the queue.sync
                // blocks complete before this handler returns.
                DatabaseManager.shared.saveAllSync()
            }
        }
    }
}
