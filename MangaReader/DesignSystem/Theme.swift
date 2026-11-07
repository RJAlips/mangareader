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
        public static let card: CGFloat = 14
        public static let large: CGFloat = 20
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
    }
}
