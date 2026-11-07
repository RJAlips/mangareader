//
//  ChapterRowView.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI

public struct ChapterRowView: View {
    public let chapter: ChapterItem
    public let onDownload: () -> Void
    public let onDeleteDownload: () -> Void
    public let onToggleRead: () -> Void
    
    public init(
        chapter: ChapterItem,
        onDownload: @escaping () -> Void,
        onDeleteDownload: @escaping () -> Void,
        onToggleRead: @escaping () -> Void
    ) {
        self.chapter = chapter
        self.onDownload = onDownload
        self.onDeleteDownload = onDeleteDownload
        self.onToggleRead = onToggleRead
    }
    
    public var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Read indicator dot
            Circle()
                .fill(chapter.isRead ? Color.clear : Color.mangaAccent)
                .frame(width: 6, height: 6)
            
            // Chapter Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(chapter.displayTitle)
                    .font(.bodyMedium)
                    .foregroundColor(chapter.isRead ? .textTertiary : .textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: Theme.Spacing.xs) {
                    if let scan = chapter.scanlator {
                        Text(scan)
                            .font(.captionMedium)
                            .foregroundColor(.textTertiary)
                    }
                    
                    if let date = chapter.releaseDate {
                        Text("•")
                            .font(.captionMedium)
                            .foregroundColor(.textTertiary)
                        Text(date, style: .date)
                            .font(.captionMedium)
                            .foregroundColor(.textTertiary)
                    }
                    
                    if chapter.lastPageRead > 0 && !chapter.isRead {
                        Text("•")
                            .font(.captionMedium)
                            .foregroundColor(.textTertiary)
                        Text("Page \(chapter.lastPageRead + 1)")
                            .font(.captionMedium)
                            .foregroundColor(.mangaAccent)
                    }
                }
            }
            
            Spacer()
            
            // Download Action / Status
            if chapter.isDownloaded {
                Menu {
                    Button(role: .destructive, action: onDeleteDownload) {
                        Label("Delete Download", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.mangaGreen)
                }
            } else if chapter.downloadProgress > 0 && chapter.downloadProgress < 1.0 {
                ProgressView(value: chapter.downloadProgress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .mangaAccent))
                    .scaleEffect(0.7)
                    .frame(width: 24, height: 24)
            } else {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading) {
            Button {
                onToggleRead()
            } label: {
                Label(chapter.isRead ? "Mark Unread" : "Mark Read", systemImage: chapter.isRead ? "eye.slash" : "eye")
            }
            .tint(.mangaBlue)
        }
    }
}
