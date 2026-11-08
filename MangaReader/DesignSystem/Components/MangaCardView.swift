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
        ZStack(alignment: .bottomLeading) {
            // Full-bleed Cover Image
            AsyncMangaImage(
                url: manga.coverURL,
                baseURL: baseURL,
                contentMode: .fill,
                cornerRadius: 10
            )
            .aspectRatio(0.68, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            
            // Bottom 40% Gradient for Title Legibility
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.4), Color.black.opacity(0.88)],
                startPoint: .center,
                endPoint: .bottom
            )
            
            // Overlaid Title at Bottom-Left
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text(manga.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    
                    Spacer(minLength: 0)
                    
                    // Bottom-Right Reading Progress Badge
                    if let chNum = manga.lastReadChapterNumber {
                        Text("Ch. \(Int(chNum.rounded()))")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 7)
                .padding(.bottom, 7)
            }
            
            // Top Badges Overlay
            VStack {
                HStack(alignment: .top) {
                    // Top-Left: Periwinkle Unread Count Pill (#9BB1FF background, #0E1528 bold text)
                    if showUnreadBadge && manga.unreadCount > 0 {
                        Text("\(manga.unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.mangaAccentInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.mangaAccent)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    
                    Spacer()
                    
                    if isSelectionMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? .mangaAccent : .white)
                            .shadow(radius: 2)
                    } else if manga.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.mangaAccent)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(6)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.mangaAccent : Color.white.opacity(0.12), lineWidth: isSelected ? 2.5 : 0.6)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
    }
}
