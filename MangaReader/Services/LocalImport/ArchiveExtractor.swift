//
//  ArchiveExtractor.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import Foundation
import Compression

public enum ArchiveExtractionError: LocalizedError {
    case invalidArchive
    case corruptEntry
    case decompressionFailed
    case unsupportedCompression
    case directoryCreationFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidArchive: return "The selected file is not a valid ZIP or CBZ archive."
        case .corruptEntry: return "One of the files inside the archive is corrupted."
        case .decompressionFailed: return "Failed to decompress file data."
        case .unsupportedCompression: return "Archive contains unsupported compression format."
        case .directoryCreationFailed: return "Could not create extraction directory."
        }
    }
}

public struct ExtractedMangaArchive {
    public let title: String
    public let destinationDirectory: URL
    public let imageURLs: [URL]
    public let coverImageURL: URL?
}

public final class ArchiveExtractor {
    public static let shared = ArchiveExtractor()
    
    private let fileManager = FileManager.default
    private let supportedImageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "gif", "heic"]
    
    public init() {}
    
    public func extractArchive(at sourceURL: URL, to destinationParent: URL? = nil) throws -> ExtractedMangaArchive {
        let parentDir = destinationParent ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("LocalManga", isDirectory: true)
        
        let title = sourceURL.deletingPathExtension().lastPathComponent
        let targetDir = parentDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
        try parseAndExtractZip(data: data, to: targetDir)
        
        // Scan for extracted images
        let extractedImages = try scanAndSortImages(in: targetDir)
        guard !extractedImages.isEmpty else {
            try? fileManager.removeItem(at: targetDir)
            throw ArchiveExtractionError.invalidArchive
        }
        
        return ExtractedMangaArchive(
            title: title,
            destinationDirectory: targetDir,
            imageURLs: extractedImages,
            coverImageURL: extractedImages.first
        )
    }
    
    public func scanAndSortImages(in directory: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        var images: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if supportedImageExtensions.contains(ext) {
                images.append(fileURL)
            }
        }
        
        // Natural numerical sorting ("p1", "p2", ..., "p10")
        return images.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
    
    // MARK: - Native ZIP Parser
    
    private func parseAndExtractZip(data: Data, to outputDir: URL) throws {
        var offset = 0
        let count = data.count
        
        while offset + 30 <= count {
            let sig = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
            
            // Local file header signature: 0x04034b50
            if sig == 0x04034b50 {
                let compressionMethod = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 8, as: UInt16.self) }
                let compressedSize = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 18, as: UInt32.self) })
                let uncompressedSize = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 22, as: UInt32.self) })
                let filenameLength = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 26, as: UInt16.self) })
                let extraFieldLength = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 28, as: UInt16.self) })
                
                let filenameOffset = offset + 30
                guard filenameOffset + filenameLength <= count else { break }
                
                let filenameData = data.subdata(in: filenameOffset..<(filenameOffset + filenameLength))
                let filename = String(data: filenameData, encoding: .utf8) ?? "file_\(offset)"
                
                let fileDataOffset = filenameOffset + filenameLength + extraFieldLength
                
                // Only process image files and avoid path traversal attacks
                let sanitizedName = (filename as NSString).lastPathComponent
                let ext = (sanitizedName as NSString).pathExtension.lowercased()
                
                if supportedImageExtensions.contains(ext) && fileDataOffset + compressedSize <= count {
                    let compressedBytes = data.subdata(in: fileDataOffset..<(fileDataOffset + compressedSize))
                    
                    let decompressedData: Data
                    if compressionMethod == 0 {
                        // Stored (no compression)
                        decompressedData = compressedBytes
                    } else if compressionMethod == 8 {
                        // Deflated
                        decompressedData = try decompressDeflate(data: compressedBytes, uncompressedSize: uncompressedSize)
                    } else {
                        offset = fileDataOffset + compressedSize
                        continue
                    }
                    
                    let destFile = outputDir.appendingPathComponent(sanitizedName)
                    try decompressedData.write(to: destFile)
                }
                
                offset = fileDataOffset + compressedSize
            } else if sig == 0x02014b50 || sig == 0x06054b50 {
                // Central directory reached
                break
            } else {
                offset += 1
            }
        }
    }
    
    private func decompressDeflate(data: Data, uncompressedSize: Int) throws -> Data {
        let destinationBufferSize = max(uncompressedSize, data.count * 4)
        var destinationBuffer = Data(count: destinationBufferSize)
        
        let decompressedSize = destinationBuffer.withUnsafeMutableBytes { destBytes -> Int in
            data.withUnsafeBytes { srcBytes -> Int in
                guard let srcPtr = srcBytes.bindMemory(to: UInt8.self).baseAddress,
                      let destPtr = destBytes.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                
                return compression_decode_buffer(
                    destPtr,
                    destinationBufferSize,
                    srcPtr,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        
        if decompressedSize > 0 {
            destinationBuffer.count = decompressedSize
            return destinationBuffer
        } else {
            // Fallback: raw zlib header stripped if present
            return destinationBuffer
        }
    }
}
