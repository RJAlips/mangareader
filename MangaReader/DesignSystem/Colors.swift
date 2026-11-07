//
//  Colors.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public extension Color {
    // Brand & Accents
    static let mangaAccent = Color(red: 255/255, green: 82/255, blue: 82/255) // Vibrant Coral/Red
    static let mangaAccentSecondary = Color(red: 255/255, green: 138/255, blue: 101/255)
    static let mangaPurple = Color(red: 168/255, green: 85/255, blue: 247/255)
    static let mangaBlue = Color(red: 59/255, green: 130/255, blue: 246/255)
    static let mangaGreen = Color(red: 34/255, green: 197/255, blue: 94/255)
    static let mangaAmber = Color(red: 245/255, green: 158/255, blue: 11/255)

    // Dark-Mode First Surfaces
    static let appBackground = Color(red: 10/255, green: 10/255, blue: 12/255) // Rich AMOLED Black
    static let surfacePrimary = Color(red: 22/255, green: 22/255, blue: 26/255)
    static let surfaceSecondary = Color(red: 32/255, green: 32/255, blue: 38/255)
    static let surfaceTertiary = Color(red: 45/255, green: 45/255, blue: 54/255)
    static let surfaceOverlay = Color.black.opacity(0.7)

    // Text & Content
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)
    static let textTertiary = Color(white: 0.45)
    static let borderSubtle = Color(white: 0.2, opacity: 0.5)

    // Reader Themes
    static let readerPureBlack = Color.black
    static let readerDarkGray = Color(red: 20/255, green: 20/255, blue: 22/255)
    static let readerSepia = Color(red: 247/255, green: 241/255, blue: 227/255)
    static let readerSepiaText = Color(red: 60/255, green: 50/255, blue: 40/255)
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
            Color.appBackground.opacity(0.6),
            Color.appBackground
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
