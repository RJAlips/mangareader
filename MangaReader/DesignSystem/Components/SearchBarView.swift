//
//  SearchBarView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct SearchBarView: View {
    @Binding public var text: String
    public var placeholder: String = "Search manga, manhwa, author..."
    public var onFilterTapped: (() -> Void)? = nil
    
    public init(text: Binding<String>, placeholder: String = "Search manga, manhwa, author...", onFilterTapped: (() -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.onFilterTapped = onFilterTapped
    }
    
    public var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textTertiary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField(placeholder, text: $text)
                    .font(.bodyRegular)
                    .foregroundColor(.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textTertiary)
                            .font(.system(size: 15))
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
            .background(Color.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
            
            if let onFilterTapped = onFilterTapped {
                Button(action: onFilterTapped) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.mangaAccent)
                }
            }
        }
    }
}
