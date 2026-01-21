import Foundation

public struct IngestionOptions: Codable, Sendable {
    public let chunkSize: Int
    public let sampleSize: Int?
    public let inferTypes: Bool
    public let failFast: Bool

    public init(chunkSize: Int = 1000, sampleSize: Int? = nil, inferTypes: Bool = true, failFast: Bool = false) {
        self.chunkSize = chunkSize
        self.sampleSize = sampleSize
        self.inferTypes = inferTypes
        self.failFast = failFast
    }
}

public struct CacheConfig: Codable, Sendable {
    public let maxMemoryUsage: Int // In bytes
    public let maxDiskUsage: Int // In bytes
    public let ttl: TimeInterval

    public init(maxMemoryUsage: Int = 100 * 1024 * 1024, maxDiskUsage: Int = 1 * 1024 * 1024 * 1024, ttl: TimeInterval = 3600) {
        self.maxMemoryUsage = maxMemoryUsage
        self.maxDiskUsage = maxDiskUsage
        self.ttl = ttl
    }
}
