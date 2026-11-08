//
//  Theme.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public enum Theme {
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 28
        public static let hero: CGFloat = 36
    }
    
    public enum CornerRadius {
        public static let small: CGFloat = 6
        public static let medium: CGFloat = 10
        public static let card: CGFloat = 10 // Tachimanga style cover radius
        public static let large: CGFloat = 18
        public static let capsule: CGFloat = 32
        public static let pill: CGFloat = 999
    }
    
    public enum Animation {
        public static let standard = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
        public static let quick = SwiftUI.Animation.easeOut(duration: 0.2)
        public static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
    }
    
    public enum Shadow {
        public static let subtle = Color.black.opacity(0.15)
        public static let card = Color.black.opacity(0.3)
        public static let deep = Color.black.opacity(0.6)
        public static let glass = Color.black.opacity(0.25)
    }
}

// MARK: - Reusable Liquid Glass Modifiers

public struct GlassCapsuleModifier: ViewModifier {
    public var height: CGFloat = 36
    public var cornerRadius: CGFloat = 18
    public var horizontalPadding: CGFloat = 12

    public init(height: CGFloat = 36, cornerRadius: CGFloat = 18, horizontalPadding: CGFloat = 12) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
    }

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
            )
            .shadow(color: Theme.Shadow.glass, radius: 4, x: 0, y: 2)
    }
}

public struct GlassCircleModifier: ViewModifier {
    public var size: CGFloat = 36

    public init(size: CGFloat = 36) {
        self.size = size
    }

    public func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.06))
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.white.opacity(0.14), lineWidth: 0.5)
            )
            .shadow(color: Theme.Shadow.glass, radius: 4, x: 0, y: 2)
    }
}

public extension View {
    func glassCapsule(height: CGFloat = 36, cornerRadius: CGFloat = 18, horizontalPadding: CGFloat = 12) -> some View {
        modifier(GlassCapsuleModifier(height: height, cornerRadius: cornerRadius, horizontalPadding: horizontalPadding))
    }
    
    func glassCircle(size: CGFloat = 36) -> some View {
        modifier(GlassCircleModifier(size: size))
    }
}
