//
//  AppState.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import Combine

public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var activeReadingManga: MangaItem? = nil
    @Published public var activeReadingChapter: ChapterItem? = nil
    @Published public var pendingExtensionUpdatesCount: Int = 2
    
    // Appearance & Customization Settings
    @AppStorage("pureBlackDarkMode") public var pureBlackDarkMode: Bool = false
    @AppStorage("liquidGlassEnabled") public var liquidGlassEnabled: Bool = true
    @AppStorage("themePalette") public var themePalette: String = "periwinkle"
    @AppStorage("itemsPerRow") public var itemsPerRow: Int = 3
    @AppStorage("colorBlendLevel") public var colorBlendLevel: Double = 0.5
    
    // Security & Privacy Settings
    @AppStorage("requireUnlock") public var requireUnlock: Bool = false
    @AppStorage("incognitoMode") public var incognitoMode: Bool = false
    @AppStorage("secureScreen") public var secureScreen: Bool = false
    @AppStorage("disableContentSharing") public var disableContentSharing: Bool = false
    
    public var currentBackground: Color {
        pureBlackDarkMode ? Color.black : Color.appBackground
    }
    
    private init() {
        bootstrapSampleDataIfNeeded()
    }
    
    private func bootstrapSampleDataIfNeeded() {
        let db = DatabaseManager.shared
        if db.mangaList.isEmpty {
            let demo = DemoMangaSource()
            Task { @MainActor in
                if let popular = try? await demo.fetchPopular(page: 1) {
                    for manga in popular {
                        db.upsertManga(manga)
                        if let chapters = try? await demo.fetchChapters(for: manga.urlOrSlug) {
                            db.upsertChapters(chapters)
                        }
                    }
                }
            }
        }
    }
}
