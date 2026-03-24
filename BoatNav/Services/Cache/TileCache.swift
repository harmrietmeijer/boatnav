import Foundation

class TileCache {

    private let memoryCache = NSCache<NSString, NSData>()
    private let diskCacheURL: URL
    private let maxDiskSize: Int // bytes

    init(name: String = "TileCache", maxDiskSizeMB: Int = 200) {
        self.maxDiskSize = maxDiskSizeMB * 1024 * 1024

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskCacheURL = cacheDir.appendingPathComponent(name)

        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        memoryCache.countLimit = 500
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func get(key: String) -> Data? {
        let nsKey = key as NSString

        // Check memory first
        if let cached = memoryCache.object(forKey: nsKey) {
            return cached as Data
        }

        // Check disk
        let fileURL = diskCacheURL.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_"))
        if let data = try? Data(contentsOf: fileURL) {
            memoryCache.setObject(data as NSData, forKey: nsKey, cost: data.count)
            return data
        }

        return nil
    }

    func set(key: String, data: Data) {
        let nsKey = key as NSString
        memoryCache.setObject(data as NSData, forKey: nsKey, cost: data.count)

        let fileURL = diskCacheURL.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_"))
        try? data.write(to: fileURL)
    }

    func clearMemory() {
        memoryCache.removeAllObjects()
    }

    func clearDisk() {
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
}
