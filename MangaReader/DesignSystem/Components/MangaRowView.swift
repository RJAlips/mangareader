//
//  MangaRowView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct MangaRowView: View {
    public let manga: MangaItem
    public let baseURL: URL?
    public var isSelected: Bool = false
    public var isSelectionMode: Bool = false

    public init(
        manga: MangaItem,
        baseURL: URL? = nil,
        isSelected: Bool = false,
        isSelectionMode: Bool = false
    ) {
        self.manga = manga
        self.baseURL = baseURL
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .mangaAccent : .textTertiary)
                    .font(.system(size: 22))
            }

            // Thumbnail
            AsyncMangaImage(
                url: manga.coverURL,
                baseURL: baseURL,
                contentMode: .fill,
                cornerRadius: Theme.CornerRadius.small
            )
            .frame(width: 56, height: 80)
            .shadow(color: Theme.Shadow.card, radius: 2, x: 0, y: 1)
            
            // Details
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack {
                    Text(manga.title)
                        .font(.bodyEmphasized)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    if manga.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.mangaAccent)
                    }
                }
                
                if let author = manga.author {
                    Text(author)
                        .font(.cardSubtitle)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: Theme.Spacing.xs) {
                    BadgeView(text: manga.status.rawValue, backgroundColor: .surfaceSecondary)
                    
                    if let firstGenre = manga.genres.first {
                        BadgeView(text: firstGenre, backgroundColor: .surfaceSecondary)
                    }
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            // Unread count & arrow
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                if manga.unreadCount > 0 {
                    UnreadCountBadge(count: manga.unreadCount)
                }
                
                if !isSelectionMode {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(Rectangle())
    }
}
