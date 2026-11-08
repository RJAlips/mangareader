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
        HStack(spacing: 12) {
            // Chapter Title & Metadata on the left
            VStack(alignment: .leading, spacing: 3) {
                Text(chapter.displayTitle)
                    .font(.system(size: 14, weight: chapter.isRead ? .regular : .semibold))
                    .foregroundColor(chapter.isRead ? .textTertiary : .textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let date = chapter.releaseDate {
                        Text(date, style: .date)
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)
                    }
                    
                    if let scan = chapter.scanlator, !scan.isEmpty {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)
                        Text(scan)
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)
                            .lineLimit(1)
                    }
                    
                    if chapter.lastPageRead > 0 && !chapter.isRead {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)
                        Text("Page \(chapter.lastPageRead + 1)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.mangaAccent)
                    }
                }
            }
            
            Spacer()
            
            // Right-side Status / Action
            HStack(spacing: 10) {
                if chapter.isRead {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.textTertiary)
                }
                
                if chapter.isDownloaded {
                    Menu {
                        Button(role: .destructive, action: onDeleteDownload) {
                            Label("Delete Download", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.mangaGreen)
                    }
                } else if chapter.downloadProgress > 0 && chapter.downloadProgress < 1.0 {
                    ProgressView(value: chapter.downloadProgress)
                        .progressViewStyle(CircularProgressViewStyle(tint: .mangaAccent))
                        .scaleEffect(0.7)
                        .frame(width: 20, height: 20)
                } else {
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading) {
            Button {
                onToggleRead()
            } label: {
                Label(chapter.isRead ? "Mark Unread" : "Mark Read", systemImage: chapter.isRead ? "envelope.badge" : "envelope.open")
            }
            .tint(.mangaAccent)
        }
    }
}
