//
//  ImageCacheManager.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import UIKit

public final class ImageCacheManager: @unchecked Sendable {
    public static let shared = ImageCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCache = DiskCache()
    
    private init() {
        // Memory Cache limits (~150MB or 200 items)
        memoryCache.countLimit = 250
        memoryCache.totalCostLimit = 150 * 1024 * 1024
        
        // Listen to memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.memoryCache.removeAllObjects()
        }
    }
    
    public func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        
        // 1. In-memory check
        if let memoryHit = memoryCache.object(forKey: key) {
            return memoryHit
        }
        
        // 2. Disk check
        if let diskData = await diskCache.retrieve(for: url.absoluteString),
           let diskImage = UIImage(data: diskData) {
            // Restore to memory cache
            let cost = diskData.count
            memoryCache.setObject(diskImage, forKey: key, cost: cost)
            return diskImage
        }
        
        return nil
    }
    
    public func insert(_ image: UIImage, for url: URL, data: Data? = nil) async {
        let key = url.absoluteString as NSString
        let imageData = data ?? image.jpegData(compressionQuality: 0.85)
        let cost = imageData?.count ?? (Int(image.size.width * image.size.height) * 4)
        
        memoryCache.setObject(image, forKey: key, cost: cost)
        
        if let data = imageData {
            await diskCache.store(data: data, for: url.absoluteString)
        }
    }
    
    public func remove(for url: URL) async {
        let key = url.absoluteString as NSString
        memoryCache.removeObject(forKey: key)
        await diskCache.remove(for: url.absoluteString)
    }
    
    public func clearAll() async {
        memoryCache.removeAllObjects()
        await diskCache.clearAll()
    }
    
    public func diskUsageFormatted() async -> String {
        let bytes = await diskCache.calculateSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
