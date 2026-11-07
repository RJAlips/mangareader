//
//  EmptyStateView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct EmptyStateView: View {
    public let icon: String
    public let title: String
    public let subtitle: String
    public var actionTitle: String? = nil
    public var action: (() -> Void)? = nil
    
    public init(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.surfaceSecondary)
                    .frame(width: 88, height: 88)
                
                Image(systemName: icon)
                    .font(.system(size: 38))
                    .foregroundColor(.mangaAccent)
            }
            
            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.sectionTitle)
                    .foregroundColor(.textPrimary)
                
                Text(subtitle)
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxl)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.bodyEmphasized)
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(LinearGradient.mangaAccentGradient)
                        .clipShape(Capsule())
                        .shadow(color: Color.mangaAccent.opacity(0.4), radius: 6, x: 0, y: 3)
                }
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .padding()
    }
}
