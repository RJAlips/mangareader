//
//  BackupService.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation

public enum BackupError: LocalizedError {
    case invalidBackupFormat
    case fileWriteFailed
    case decodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidBackupFormat: return "The selected file is not a valid MangaReader backup."
        case .fileWriteFailed: return "Could not write backup to destination."
        case .decodingFailed: return "Failed to parse backup content."
        }
    }
}

public final class BackupService {
    public static let shared = BackupService()
    
    private let db = DatabaseManager.shared
    private let fileManager = FileManager.default
    
    public init() {}
    
    public func createBackup() throws -> URL {
        let backup = BackupData(
            libraryManga: db.mangaList,
            chapters: db.chaptersList,
            categories: db.categoriesList,
            history: db.historyList,
            readerSettings: db.readerSettings,
            trackingLinks: db.trackingLinks
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(backup)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = "MangaReader_Backup_\(timestamp).json"
        
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }
    
    public func restoreBackup(from fileURL: URL) throws {
        let isSecurityScoped = fileURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let backup = try? decoder.decode(BackupData.self, from: data) else {
            throw BackupError.invalidBackupFormat
        }
        
        db.restoreFromBackup(backup)
    }
}
