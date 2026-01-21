import Foundation
import DataCore

public actor CacheManager {
    private let config: CacheConfig
    private var memoryCache: [String: Artifact] = [:]

    public init(config: CacheConfig = CacheConfig()) {
        self.config = config
    }

    public func get(key: String) -> Artifact? {
        return memoryCache[key]
    }

    public func set(key: String, artifact: Artifact) {
        // Simple LRU or size check would go here
        memoryCache[key] = artifact
    }

    public func clear() {
        memoryCache.removeAll()
    }
}
