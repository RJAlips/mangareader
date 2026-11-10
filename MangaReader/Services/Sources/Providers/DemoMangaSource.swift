//
//  DemoMangaSource.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public final class DemoMangaSource: MangaSource, @unchecked Sendable {
    public let manifest = SourceManifest(
        id: "com.mangareader.source.demo",
        name: "MangaReader Curated",
        version: "1.2.0",
        lang: "EN",
        baseURL: "https://demo.mangareader.app",
        iconURL: URL(string: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=100&q=80"),
        isEnabled: true,
        isNsfw: false,
        supportsLatest: true,
        supportsSearch: true,
        sourceDescription: "Curated high-quality open manga & manhwa demo catalog"
    )
    
    private let sampleTitles: [MangaItem] = [
        MangaItem(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "shadow-monarch-rebirth",
            title: "Shadow Monarch: Rebirth of the Sovereign",
            alternativeTitles: ["나 혼자만 그림자 군주", "The Dark Monarch"],
            author: "Chugong",
            artist: "DUBU (REDICE STUDIO)",
            description: "In a world where hunters with supernatural powers battle deadly monsters, the weakest hunter Jin-Woo finds himself trapped in a brutal double dungeon. Facing certain death, a mysterious quest window appears before him, bestowing the rare ability to level up infinitely.",
            coverURL: URL(string: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&q=80"),
            genres: ["Action", "Manhwa", "Supernatural", "Fantasy", "System"],
            status: .ongoing,
            contentRating: .safe,
            totalChapters: 25,
            unreadCount: 25,
            inLibrary: true,
            isFavorite: true,
            categories: ["Reading", "Favorites"],
            lastReadAt: Date().addingTimeInterval(-3600),
            lastUpdated: Date(),
            preferredReadingMode: .webtoon
        ),
        MangaItem(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "tower-of-ascension",
            title: "Tower of Ascension: The 100th Floor",
            alternativeTitles: ["신의 탑 이야기", "Ascension Tower"],
            author: "SIU Studio",
            artist: "SIU",
            description: "Reach the top of the mysterious Tower, and whatever you desire shall be granted. A young boy enters the perilous structure searching for his dearest friend, only to discover ancient conspiracies and trials at every level.",
            coverURL: URL(string: "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&q=80"),
            genres: ["Adventure", "Fantasy", "Webtoon", "Mystery"],
            status: .ongoing,
            contentRating: .safe,
            totalChapters: 40,
            unreadCount: 40,
            inLibrary: true,
            isFavorite: false,
            categories: ["Plan to Read"],
            lastReadAt: nil,
            lastUpdated: Date().addingTimeInterval(-86400 * 2),
            preferredReadingMode: .webtoon
        ),
        MangaItem(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "blades-of-eternity",
            title: "Blades of Eternity: Ronin's Odyssey",
            alternativeTitles: ["無限の剣客", "The Lone Blade"],
            author: "Hiroshi Takahashi",
            artist: "Kenji Sato",
            description: "Set in feudal Japan during the bloody Sengoku era, an exiled samurai carrying a cursed katana must defend an innocent shrine maiden while confronting his dark lineage.",
            coverURL: URL(string: "https://images.unsplash.com/photo-1563089145-599997674d42?w=600&q=80"),
            genres: ["Action", "Historical", "Manga", "Martial Arts", "Seinen"],
            status: .completed,
            contentRating: .suggestive,
            totalChapters: 18,
            unreadCount: 0,
            inLibrary: false,
            isFavorite: false,
            categories: ["Completed"],
            lastReadAt: nil,
            lastUpdated: Date().addingTimeInterval(-86400 * 5),
            preferredReadingMode: .horizontalRTL
        ),
        MangaItem(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "celestial-academy-chronicles",
            title: "Celestial Academy: Starlight Enchanter",
            alternativeTitles: ["별빛의 마법 아카데미", "Starlight Mage"],
            author: "Elena Rostova",
            artist: "Miyako Art",
            description: "Born without a speck of elemental affinity in an empire that exalts magic, Aaron stumbles upon forbidden celestial runes beneath the ancient academy archives.",
            coverURL: URL(string: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80"),
            genres: ["Fantasy", "School Life", "Romance", "Manhwa"],
            status: .ongoing,
            contentRating: .safe,
            totalChapters: 30,
            unreadCount: 12,
            inLibrary: true,
            isFavorite: true,
            categories: ["Reading"],
            lastReadAt: Date().addingTimeInterval(-86400),
            lastUpdated: Date().addingTimeInterval(-3600 * 12),
            preferredReadingMode: .webtoon
        ),
        MangaItem(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            sourceID: "com.mangareader.source.demo",
            urlOrSlug: "cyber-tokyo-2088",
            title: "Cyber Tokyo 2088: Ghost Protocols",
            alternativeTitles: ["サイバー東京2088", "Neon Syndicate"],
            author: "K. R. Sterling",
            artist: "NeoWorks",
            description: "Rain-slicked neon skyscrapers, corporate megastructures, and rogue cyborg mercenaries. When a memory chip containing state secrets is grafted into an underground courier, every faction in the city initiates a manhunt.",
            coverURL: URL(string: "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&q=80"),
            genres: ["Sci-Fi", "Cyberpunk", "Action", "Comics"],
            status: .ongoing,
            contentRating: .safe,
            totalChapters: 12,
            unreadCount: 5,
            inLibrary: false,
            isFavorite: false,
            categories: ["Plan to Read"],
            lastReadAt: nil,
            lastUpdated: Date().addingTimeInterval(-86400 * 3),
            preferredReadingMode: .horizontalLTR
        )
    ]
    
    public init() {}
    
    public func fetchPopular(page: Int) async throws -> [MangaItem] {
        return sampleTitles
    }
    
    public func fetchLatest(page: Int) async throws -> [MangaItem] {
        return sampleTitles.sorted { $0.lastUpdated > $1.lastUpdated }
    }
    
    public func search(query: String, page: Int) async throws -> [MangaItem] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return sampleTitles }
        return sampleTitles.filter {
            $0.title.lowercased().contains(q) ||
            $0.genres.contains(where: { $0.lowercased().contains(q) }) ||
            ($0.author?.lowercased().contains(q) ?? false)
        }
    }
    
    public func fetchMangaDetail(urlOrSlug: String) async throws -> MangaItem {
        if let found = sampleTitles.first(where: { $0.urlOrSlug == urlOrSlug }) {
            return found
        }
        throw NetworkError.badServerResponse(statusCode: 404)
    }
    
    public func fetchChapters(for urlOrSlug: String) async throws -> [ChapterItem] {
        let manga = sampleTitles.first(where: { $0.urlOrSlug == urlOrSlug }) ?? sampleTitles[0]
        
        var chapters: [ChapterItem] = []
        for chNum in (1...10).reversed() {
            let chapterID = UUID()
            let dummyPages = generateSamplePageURLs(chapterNum: chNum)
            let item = ChapterItem(
                id: chapterID,
                mangaID: manga.id,
                sourceChapterID: "\(urlOrSlug)-chapter-\(chNum)",
                chapterNumber: Double(chNum),
                volumeNumber: nil,
                title: chNum == 1 ? "Prologue: The Awakening" : "Awakening Part \(chNum)",
                scanlator: "MangaReader Scans",
                releaseDate: Date().addingTimeInterval(-Double(11 - chNum) * 86400 * 3),
                pageCount: dummyPages.count,
                pageURLs: dummyPages,
                isRead: chNum < 3,
                lastPageRead: chNum < 3 ? dummyPages.count : 0,
                isDownloaded: false,
                downloadProgress: 0.0
            )
            chapters.append(item)
        }
        return chapters
    }
    
    public func fetchPageURLs(for chapterSourceID: String) async throws -> [URL] {
        let chapterNum = Int(chapterSourceID.components(separatedBy: "-").last ?? "1") ?? 1
        return generateSamplePageURLs(chapterNum: chapterNum)
    }
    
    public func checkHealth() async -> Bool {
        return true
    }
    
    private func generateSamplePageURLs(chapterNum: Int) -> [URL] {
        // High quality webtoon and comic panels
        let sampleImagePool = [
            "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=1080&q=85",
            "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1080&q=85",
            "https://images.unsplash.com/photo-1563089145-599997674d42?w=1080&q=85",
            "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1080&q=85",
            "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=1080&q=85",
            "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=1080&q=85",
            "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1080&q=85",
            "https://images.unsplash.com/photo-1550684848-fac1c5b4e853?w=1080&q=85"
        ]
        
        return (0..<8).compactMap { i in
            URL(string: sampleImagePool[(i + chapterNum) % sampleImagePool.count])
        }
    }
}
