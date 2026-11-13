//
//  ImageCacheManager.swift
//  MangaReader
//
//  Created for MangaReader iOS.
//

import UIKit

/// Concurrency limiter that throttles parallel image downloads (max 3-4 concurrent)
/// so MangaDex@Home and third-party CDNs do not throttle, rate-limit, or drop connections.
public actor ImageDownloadLimiter {
    public static let shared = ImageDownloadLimiter()
    private var activeCount = 0
    private let maxConcurrent = 3
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    public func acquire() async {
        if activeCount < maxConcurrent {
            activeCount += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    public func release() {
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            next.resume()
        } else {
            activeCount = max(0, activeCount - 1)
        }
    }
}

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
    
    public func fetchImage(for url: URL, refererOverride: String? = nil, customHeaders: [String: String]? = nil) async throws -> UIImage {
        if let cached = await image(for: url) {
            return cached
        }
        var headers = customHeaders ?? [:]
        if headers["User-Agent"] == nil {
            headers["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
        }
        let referer = refererOverride ?? (url.scheme != nil && url.host != nil ? "\(url.scheme!)://\(url.host!)/" : nil)
        if headers["Referer"] == nil, let ref = referer {
            headers["Referer"] = ref.hasSuffix("/") ? ref : "\(ref)/"
        }
        let data = try await NetworkClient.shared.fetchDataWithCDNHeaders(from: url, headers: headers, refererOverride: referer)
        guard let img = UIImage(data: data) else {
            throw NetworkError.noData
        }
        await insert(img, for: url, data: data)
        return img
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
