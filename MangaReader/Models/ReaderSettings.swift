//
//  ReaderSettings.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public enum ReaderBackgroundColor: String, CaseIterable, Codable, Identifiable {
    case pureBlack = "AMOLED Black"
    case darkGray = "Dark Charcoal"
    case sepia = "Sepia"
    case white = "White"
    
    public var id: String { rawValue }
    
    public var color: Color {
        switch self {
        case .pureBlack: return .readerPureBlack
        case .darkGray: return .readerDarkGray
        case .sepia: return .readerSepia
        case .white: return .readerWhite
        }
    }
    
    public var textColor: Color {
        switch self {
        case .pureBlack, .darkGray: return .white
        case .sepia: return .readerSepiaText
        case .white: return .readerWhiteText
        }
    }
}

public enum ImageScaleType: String, CaseIterable, Codable, Identifiable {
    case fitWidth = "Fit Width"
    case fitHeight = "Fit Height"
    case stretch = "Stretch to Fill"
    case original = "Original Size"
    
    public var id: String { rawValue }
}

public struct ReaderSettings: Codable, Equatable {
    public var defaultReadingMode: ReadingMode = .webtoon
    public var backgroundColor: ReaderBackgroundColor = .pureBlack
    public var imageScale: ImageScaleType = .fitWidth
    public var keepScreenAwake: Bool = true
    public var showPageNumber: Bool = true
    public var showBatteryAndClock: Bool = true
    public var volumeButtonsNavigation: Bool = false
    public var pageSpacing: CGFloat = 0
    public var sidePadding: CGFloat = 0
    public var cropBorders: Bool = false
    public var autoScrollSpeed: Double = 1.0
    public var preloadPagesAhead: Int = 4
    
    public init() {}
}
