//
//  BadgeView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct BadgeView: View {
    public let text: String
    public var icon: String? = nil
    public var foregroundColor: Color = .white
    public var backgroundColor: Color = .surfaceTertiary
    public var isEmphasized: Bool = false
    
    public init(
        text: String,
        icon: String? = nil,
        foregroundColor: Color = .white,
        backgroundColor: Color = .surfaceTertiary,
        isEmphasized: Bool = false
    ) {
        self.text = text
        self.icon = icon
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.isEmphasized = isEmphasized
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.badgeFont)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(foregroundColor)
        .background(
            Capsule()
                .fill(isEmphasized ? AnyShapeStyle(LinearGradient.mangaAccentGradient) : AnyShapeStyle(backgroundColor))
        )
    }
}

public struct UnreadCountBadge: View {
    public let count: Int
    
    public init(count: Int) {
        self.count = count
    }
    
    public var body: some View {
        if count > 0 {
            Text(count > 999 ? "999+" : "\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.mangaAccent)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 2)
        }
    }
}
