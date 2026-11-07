//
//  ReadingMode.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public enum ReadingMode: String, CaseIterable, Codable, Identifiable {
    case webtoon = "Webtoon (Continuous)"
    case horizontalRTL = "Right to Left (Manga)"
    case horizontalLTR = "Left to Right (Comic)"
    case verticalPaged = "Vertical Paged"
    case doublePage = "Double Page (iPad/Landscape)"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .webtoon: return "arrow.up.and.down.square.fill"
        case .horizontalRTL: return "arrow.left.square.fill"
        case .horizontalLTR: return "arrow.right.square.fill"
        case .verticalPaged: return "doc.plaintext.fill"
        case .doublePage: return "book.pages.fill"
        }
    }
    
    public var shortDescription: String {
        switch self {
        case .webtoon: return "Infinite vertical strip for manhwa & webtoons"
        case .horizontalRTL: return "Standard right-to-left paging for traditional manga"
        case .horizontalLTR: return "Standard left-to-right paging for Western comics"
        case .verticalPaged: return "Vertical single-page snapping"
        case .doublePage: return "Two-page spread side by side"
        }
    }
}
