//
//  SettingsViewModel.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import SwiftUI
import Combine

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var readerSettings: ReaderSettings
    @Published public private(set) var cacheSizeFormatted: String = "Calculating..."
    @Published public var isClearingCache: Bool = false
    @Published public var showBackupShare: Bool = false
    @Published public var backupFileURL: URL? = nil
    @Published public var restoreMessage: String? = nil
    
    private let db = DatabaseManager.shared
    private let imageCache = ImageCacheManager.shared
    private let backupService = BackupService.shared
    
    public init() {
        self.readerSettings = db.readerSettings
        calculateCacheSize()
    }
    
    public func updateSettings() {
        db.readerSettings = readerSettings
        db.saveSettingsToDisk()
    }
    
    public func calculateCacheSize() {
        Task {
            let size = await imageCache.diskUsageFormatted()
            self.cacheSizeFormatted = size
        }
    }
    
    public func clearImageCache() {
        isClearingCache = true
        Task {
            await imageCache.clearAll()
            await calculateCacheSize()
            self.isClearingCache = false
        }
    }
    
    public func exportBackup() {
        do {
            let url = try backupService.createBackup()
            self.backupFileURL = url
            self.showBackupShare = true
        } catch {
            self.restoreMessage = "Backup failed: \(error.localizedDescription)"
        }
    }
    
    public func importBackup(from url: URL) {
        do {
            try backupService.restoreBackup(from: url)
            self.restoreMessage = "Backup restored successfully!"
            self.readerSettings = db.readerSettings
        } catch {
            self.restoreMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
}
