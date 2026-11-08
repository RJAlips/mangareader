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
    @StateObject private var downloadManager = DownloadManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                // DatabaseManager is a singleton; inject via environment so views
                // can use @EnvironmentObject, but do NOT wrap it in a second
                // @StateObject (that would create a second instance and shadow
                // the real singleton, breaking reactivity).
                .environmentObject(DatabaseManager.shared)
                .environmentObject(downloadManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .inactive, .background:
                // Flush all JSON to disk synchronously before the OS suspends
                // the process. Using saveAllSync() ensures the queue.sync
                // blocks complete before this handler returns.
                DatabaseManager.shared.saveAllSync()
            case .active:
                // Refresh in-memory state from disk in case another process
                // (e.g. an extension) modified the store while backgrounded.
                DatabaseManager.shared.reloadFromDisk()
            default:
                break
            }
        }
        .onExitNotifications(perform: {
            // Final safety net: persist on app termination (force-quit path
            // where .background may not fire).
            DatabaseManager.shared.saveAllSync()
        })
    }
}
