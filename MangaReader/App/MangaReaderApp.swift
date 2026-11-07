//
//  MangaReaderApp.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

@main
struct MangaReaderApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var db = DatabaseManager.shared
    @StateObject private var downloadManager = DownloadManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .environmentObject(db)
                .environmentObject(downloadManager)
        }
    }
}
