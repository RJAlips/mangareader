//
//  Typography.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public extension Font {
    static let heroTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let largeTitleBold = Font.system(size: 24, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let cardTitle = Font.system(size: 13, weight: .semibold, design: .default)
    static let cardSubtitle = Font.system(size: 12, weight: .regular, design: .default)
    static let bodyRegular = Font.system(size: 15, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .medium, design: .default)
    static let bodyEmphasized = Font.system(size: 15, weight: .semibold, design: .default)
    static let captionMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let badgeFont = Font.system(size: 11, weight: .bold, design: .rounded)
    static let readerCounter = Font.system(size: 13, weight: .semibold, design: .monospaced)
    static let kaomoji = Font.system(size: 38, weight: .medium, design: .rounded)
}
