//
//  MangaCardView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct MangaCardView: View {
    public let manga: MangaItem
    public let baseURL: URL?
    public var showUnreadBadge: Bool = true
    public var isSelected: Bool = false
    public var isSelectionMode: Bool = false

    public init(
        manga: MangaItem,
        baseURL: URL? = nil,
        showUnreadBadge: Bool = true,
        isSelected: Bool = false,
        isSelectionMode: Bool = false
    ) {
        self.manga = manga
        self.baseURL = baseURL
        self.showUnreadBadge = showUnreadBadge
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ZStack(alignment: .bottomLeading) {
                // Cover Image
                AsyncMangaImage(
                    url: manga.coverURL,
                    baseURL: baseURL,
                    contentMode: .fill,
                    cornerRadius: Theme.CornerRadius.card
                )
                .aspectRatio(0.70, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.card, style: .continuous)
                        .stroke(isSelected ? Color.mangaAccent : Color.borderSubtle, lineWidth: isSelected ? 3 : 0.8)
                )
                
                // Bottom Gradient
                LinearGradient.cardCoverOverlay
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.card, style: .continuous))
                
                // Badges overlay
                VStack {
                    HStack {
                        if isSelectionMode {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? .mangaAccent : .white)
                                .shadow(radius: 2)
                        } else if manga.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.mangaAccent)
                                .padding(5)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        if showUnreadBadge && manga.unreadCount > 0 {
                            UnreadCountBadge(count: manga.unreadCount)
                        }
                    }
                    .padding(Theme.Spacing.xs)
                    
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.card, style: .continuous))
            .shadow(color: Theme.Shadow.card, radius: 4, x: 0, y: 3)
            
            // Title
            Text(manga.title)
                .font(.cardTitle)
                .foregroundColor(.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Subtitle / Genres
            if let firstGenre = manga.genres.first {
                Text(firstGenre)
                    .font(.cardSubtitle)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            } else {
                Text(manga.status.rawValue)
                    .font(.cardSubtitle)
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}
