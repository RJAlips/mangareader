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
