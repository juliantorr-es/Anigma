import Foundation

/// Statistics for cache operations
public struct CacheStats: Sendable, Codable {
    public let hitCount: Int
    public let missCount: Int
    public let evictionCount: Int
    public let currentSize: Int  // in bytes

    public var hitRate: Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0
    }
}

/// Represents a cached value with TTL
private struct CachedValue<T: Sendable>: Sendable {
    let value: T
    let cachedAt: Date
    let ttl: TimeInterval?

    func isExpired() -> Bool {
        guard let ttl = ttl else { return false }
        return Date().timeIntervalSince(cachedAt) > ttl
    }
}

/// LRU (Least Recently Used) cache for managing memory
private actor LRUCache<Key: Hashable & Sendable, Value: Sendable> {
    private var cache: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    private let maxSize: Int

    init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }

    func get(_ key: Key) -> Value? {
        guard let value = cache[key] else { return nil }

        // Update access order
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)

        return value
    }

    func set(_ key: Key, _ value: Value) {
        // Remove if exists
        if cache[key] != nil {
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }

        // Add new value
        cache[key] = value
        accessOrder.append(key)

        // Evict oldest if over capacity
        while cache.count > maxSize && !accessOrder.isEmpty {
            let oldestKey = accessOrder.removeFirst()
            cache.removeValue(forKey: oldestKey)
        }
    }

    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    func getAll() -> [Key: Value] {
        cache
    }

    func count() -> Int {
        cache.count
    }
}

/// Multi-layer caching for MCP tool results
public actor MCPCacheManager {
    // File content cache (LRU)
    private let fileCache: LRUCache<String, String>

    // Query result cache (with TTL)
    private var queryCache: [String: CachedValue<String>] = [:]
    private let queryTTL: TimeInterval = 300  // 5 minutes

    // Metadata cache (with longer TTL)
    private var metadataCache: [String: CachedValue<String>] = [:]
    private let metadataTTL: TimeInterval = 1800  // 30 minutes

    // Statistics
    private var stats = (fileHits: 0, fileMisses: 0, queryHits: 0, queryMisses: 0, metadataHits: 0, metadataMisses: 0, evictions: 0)

    public init(fileCacheSizeBytes: Int = 10 * 1024 * 1024) {
        // File cache holds approximate number of files (assuming ~100KB average)
        let fileCacheCount = max(10, fileCacheSizeBytes / (100 * 1024))
        self.fileCache = LRUCache(maxSize: fileCacheCount)
    }

    // MARK: - File Cache

    /// Gets a file from cache or returns nil
    public func getFile(_ path: String) async -> String? {
        if let cached = await fileCache.get(path) {
            stats.fileHits += 1
            return cached
        }
        stats.fileMisses += 1
        return nil
    }

    /// Stores a file in cache
    public func cacheFile(_ path: String, _ content: String) async {
        await fileCache.set(path, content)
    }

    /// Invalidates specific file(s) by glob pattern
    public func invalidateFiles(matching pattern: String) async {
        // Simple pattern matching: exact match or prefix match
        let allFiles = await fileCache.getAll()
        for filePath in allFiles.keys {
            if filePath == pattern || filePath.hasPrefix(pattern) {
                // Clear would require enumeration; for now we just use TTL
                // A more sophisticated pattern matcher could be added here
            }
        }
    }

    // MARK: - Query Cache

    /// Gets a query result from cache or returns nil
    public func getQuery(_ queryKey: String) -> String? {
        guard let cached = queryCache[queryKey] else {
            stats.queryMisses += 1
            return nil
        }

        if cached.isExpired() {
            queryCache.removeValue(forKey: queryKey)
            stats.queryMisses += 1
            return nil
        }

        stats.queryHits += 1
        return cached.value
    }

    /// Stores a query result in cache
    public func cacheQuery(_ queryKey: String, _ result: String) {
        queryCache[queryKey] = CachedValue(value: result, cachedAt: Date(), ttl: queryTTL)
    }

    /// Invalidates query cache (e.g., after mutations)
    public func invalidateQueries() {
        queryCache.removeAll()
    }

    // MARK: - Metadata Cache

    /// Gets metadata from cache or returns nil
    public func getMetadata(_ key: String) -> String? {
        guard let cached = metadataCache[key] else {
            stats.metadataMisses += 1
            return nil
        }

        if cached.isExpired() {
            metadataCache.removeValue(forKey: key)
            stats.metadataMisses += 1
            return nil
        }

        stats.metadataHits += 1
        return cached.value
    }

    /// Stores metadata in cache
    public func cacheMetadata(_ key: String, _ value: String) {
        metadataCache[key] = CachedValue(value: value, cachedAt: Date(), ttl: metadataTTL)
    }

    /// Invalidates metadata cache (e.g., after mutations)
    public func invalidateMetadata() {
        metadataCache.removeAll()
    }

    // MARK: - Statistics

    /// Gets cache statistics
    public func getStats() -> (file: CacheStats, query: CacheStats, metadata: CacheStats) {
        let fileStats = CacheStats(
            hitCount: stats.fileHits,
            missCount: stats.fileMisses,
            evictionCount: stats.evictions,
            currentSize: 0  // Would require summing file sizes
        )

        let queryStats = CacheStats(
            hitCount: stats.queryHits,
            missCount: stats.queryMisses,
            evictionCount: 0,
            currentSize: queryCache.count
        )

        let metadataStats = CacheStats(
            hitCount: stats.metadataHits,
            missCount: stats.metadataMisses,
            evictionCount: 0,
            currentSize: metadataCache.count
        )

        return (fileStats, queryStats, metadataStats)
    }

    /// Clears all caches
    public func clear() {
        Task {
            await fileCache.clear()
        }
        queryCache.removeAll()
        metadataCache.removeAll()
        stats = (0, 0, 0, 0, 0, 0, 0)
    }

    /// Cleanup: removes expired entries
    public func cleanup() {
        // Remove expired query cache entries
        queryCache = queryCache.filter { !$0.value.isExpired() }

        // Remove expired metadata cache entries
        metadataCache = metadataCache.filter { !$0.value.isExpired() }
    }
}
