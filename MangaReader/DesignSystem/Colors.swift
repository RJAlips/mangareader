//
//  Colors.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public extension Color {
    // MARK: - Hex Initializer
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }

    // MARK: - Tachimanga Liquid Glass & Periwinkle Palette
    /// Primary Accent: Periwinkle Lavender-Blue (#9BB1FF)
    static let mangaAccent = Color(hex: 0x9BB1FF)
    /// Dark ink contrast text for periwinkle buttons and badges (#0E1528)
    static let mangaAccentInk = Color(hex: 0x0E1528)
    /// Soft secondary periwinkle
    static let mangaAccentSecondary = Color(hex: 0xB5C4FF)
    
    // Status & Variety Accents
    static let mangaGreen = Color(hex: 0x34D399)
    static let mangaAmber = Color(hex: 0xFBBF24)
    static let mangaRed = Color(hex: 0xF87171)
    static let mangaPurple = Color(hex: 0xC084FC)
    static let mangaBlue = Color(hex: 0x60A5FA)

    // MARK: - Dark-Mode Surfaces
    /// Primary App Background: #0E0E10 (or pure #000000 when pure black dark mode is active)
    static let appBackground = Color(hex: 0x0E0E10)
    static let appPureBlack = Color.black
    
    /// Elevated Surface / Card / List Row: #18181C
    static let surfacePrimary = Color(hex: 0x18181C)
    static let surfaceSecondary = Color(hex: 0x222228)
    static let surfaceTertiary = Color(hex: 0x2C2C34)
    static let surfaceOverlay = Color.black.opacity(0.75)
    
    // MARK: - Glass Tokens
    static let glassOverlay = Color.white.opacity(0.06)
    static let glassBorder = Color.white.opacity(0.14)
    static let glassHighlight = Color.white.opacity(0.10)

    // MARK: - Text & Content
    static let textPrimary = Color(hex: 0xF4F4F6)
    static let textSecondary = Color(hex: 0x8E8E98)
    static let textTertiary = Color(hex: 0x5A5A64) // Muted / read chapter text
    static let textMuted = Color(hex: 0x5A5A64)
    static let borderSubtle = Color.white.opacity(0.08)

    // MARK: - Reader Themes
    static let readerPureBlack = Color.black
    static let readerDarkGray = Color(hex: 0x141416)
    static let readerSepia = Color(hex: 0xF7F1E3)
    static let readerSepiaText = Color(hex: 0x3C3228)
    static let readerWhite = Color.white
    static let readerWhiteText = Color.black
}

public extension LinearGradient {
    static let mangaAccentGradient = LinearGradient(
        colors: [Color.mangaAccent, Color.mangaAccentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardCoverOverlay = LinearGradient(
        colors: [
            Color.clear,
            Color.black.opacity(0.1),
            Color.black.opacity(0.85)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let detailHeroOverlay = LinearGradient(
        colors: [
            Color.clear,
            Color(hex: 0x0E0E10).opacity(0.7),
            Color(hex: 0x0E0E10)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
