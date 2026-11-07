//
//  DiskCache.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import CryptoKit

public actor DiskCache {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxDiskBytes: Int64
    
    public init(name: String = "MangaReaderImageDiskCache", maxDiskBytes: Int64 = 500 * 1024 * 1024) { // 500MB
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        self.cacheDirectory = paths[0].appendingPathComponent(name, isDirectory: true)
        self.maxDiskBytes = maxDiskBytes
        createDirectoryIfNeeded()
    }
    
    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func keyToFilename(_ key: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    public func store(data: Data, for key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(keyToFilename(key))
        try? data.write(to: fileURL, options: .atomic)
        trimIfNeeded()
    }
    
    public func retrieve(for key: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(keyToFilename(key))
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        // Touch file modification date for LRU tracking
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
        return try? Data(contentsOf: fileURL)
    }
    
    public func remove(for key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(keyToFilename(key))
        try? fileManager.removeItem(at: fileURL)
    }
    
    public func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        createDirectoryIfNeeded()
    }
    
    public func calculateSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for file in files {
            if let resources = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = resources.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
    
    private func trimIfNeeded() {
        let currentSize = calculateSize()
        guard currentSize > maxDiskBytes else { return }
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }
        
        // Sort files by oldest access date
        let sorted = files.sorted { f1, f2 in
            let d1 = (try? f1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let d2 = (try? f2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return d1 < d2
        }
        
        var bytesToRemove = currentSize - (maxDiskBytes * 7 / 10) // Evict down to 70%
        for file in sorted {
            if bytesToRemove <= 0 { break }
            if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                try? fileManager.removeItem(at: file)
                bytesToRemove -= Int64(size)
            }
        }
    }
}
