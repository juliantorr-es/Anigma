// TileCacheCore.swift
// TileCacheCapsule - Tier 1 tile-based texture caching for Anigma
// Production-ready LRU cache with memory management and eviction

import Foundation
import CapsuleCore
import VectorOpsKit

// MARK: - Tile Cache Protocol

/// Protocol defining tile cache operations
public protocol TileCache: Sendable {
    /// Retrieve a tile from cache or generate if missing
    func getTile(key: TileKey) async throws -> CachedTile
    
    /// Preload tiles into cache
    func preloadTiles(keys: [TileKey]) async throws
    
    /// Evict tiles from cache
    func evictTiles(keys: [TileKey]) async throws
    
    /// Clear all cached tiles
    func clearCache() async throws
    
    /// Get cache statistics
    func getStatistics() -> CacheStatistics
}

// MARK: - Tile Key and Data Structures

/// Unique identifier for a cached tile
public struct TileKey: Sendable, Hashable, Codable {
    public let x: Int32
    public let y: Int32
    public let zoom: UInt8
    public let layer: String
    public let variant: String
    
    public init(x: Int32, y: Int32, zoom: UInt8, layer: String, variant: String = "default") {
        self.x = x
        self.y = y
        self.zoom = zoom
        self.layer = layer
        self.variant = variant
    }
    
    public var hashValue: Int {
        var hasher = Hasher()
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(zoom)
        hasher.combine(layer)
        hasher.combine(variant)
        return hasher.finalize()
    }
}

/// Cached tile with metadata
public struct CachedTile: Sendable {
    public let key: TileKey
    public let data: Data
    public let format: TileFormat
    public let size: (width: UInt32, height: UInt32)
    public let timestamp: TimeInterval
    public let accessCount: UInt64
    public let lastAccess: TimeInterval
    
    public init(
        key: TileKey,
        data: Data,
        format: TileFormat,
        size: (width: UInt32, height: UInt32),
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        accessCount: UInt64 = 1,
        lastAccess: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.key = key
        self.data = data
        self.format = format
        self.size = size
        self.timestamp = timestamp
        self.accessCount = accessCount
        self.lastAccess = lastAccess
    }
}

/// Supported tile formats
public enum TileFormat: String, Sendable, CaseIterable, Codable {
    case rgba8 = "rgba8"
    case rgb8 = "rgb8"
    case png = "png"
    case jpeg = "jpeg"
    case webp = "webp"
    case astc = "astc"
    case bc7 = "bc7"
    
    public var bytesPerPixel: UInt32 {
        switch self {
        case .rgba8: return 4
        case .rgb8: return 3
        case .png, .jpeg, .webp, .astc, .bc7: return 0 // Variable compression
        }
    }
    
    public var isCompressed: Bool {
        switch self {
        case .png, .jpeg, .webp, .astc, .bc7: return true
        case .rgba8, .rgb8: return false
        }
    }
}

// MARK: - Cache Configuration

/// Configuration for tile cache behavior
public struct TileCacheConfiguration: Sendable, Codable {
    /// Maximum number of tiles in cache
    public let maxTiles: UInt32
    
    /// Maximum memory usage in bytes (0 = unlimited)
    public let maxMemoryBytes: UInt64
    
    /// Tile size in pixels (assumed square)
    public let tileSize: UInt32
    
    /// Number of worker threads for tile generation
    public let workerThreads: UInt32
    
    /// Cache eviction policy
    public let evictionPolicy: EvictionPolicy
    
    /// Preload strategy
    public let preloadStrategy: PreloadStrategy
    
    public init(
        maxTiles: UInt32 = 1000,
        maxMemoryBytes: UInt64 = 512 * 1024 * 1024, // 512MB
        tileSize: UInt32 = 256,
        workerThreads: UInt32 = 4,
        evictionPolicy: EvictionPolicy = .lru,
        preloadStrategy: PreloadStrategy = .none
    ) {
        self.maxTiles = maxTiles
        self.maxMemoryBytes = maxMemoryBytes
        self.tileSize = tileSize
        self.workerThreads = workerThreads
        self.evictionPolicy = evictionPolicy
        self.preloadStrategy = preloadStrategy
    }
}

/// Cache eviction policies
public enum EvictionPolicy: String, Sendable, CaseIterable, Codable {
    case lru = "lru"              // Least Recently Used
    case lfu = "lfu"               // Least Frequently Used
    case fifo = "fifo"             // First In, First Out
    case random = "random"         // Random eviction
    case weighted = "weighted"     // Weighted by access frequency and size
}

/// Preload strategies
public enum PreloadStrategy: String, Sendable, CaseIterable, Codable {
    case none = "none"
    case adjacent = "adjacent"     // Load adjacent tiles
    case predict = "predict"       // Predictive loading based on movement
    case full = "full"            // Load entire zoom level
}

// MARK: - Cache Statistics

/// Cache performance statistics
public struct CacheStatistics: Sendable, Codable {
    public let totalTiles: UInt32
    public let memoryUsageBytes: UInt64
    public let hitCount: UInt64
    public let missCount: UInt64
    public let evictionCount: UInt64
    public let generationCount: UInt64
    public let averageGenerationTime: TimeInterval
    public let hitRate: Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0.0
    }
    
    public init(
        totalTiles: UInt32 = 0,
        memoryUsageBytes: UInt64 = 0,
        hitCount: UInt64 = 0,
        missCount: UInt64 = 0,
        evictionCount: UInt64 = 0,
        generationCount: UInt64 = 0,
        averageGenerationTime: TimeInterval = 0.0
    ) {
        self.totalTiles = totalTiles
        self.memoryUsageBytes = memoryUsageBytes
        self.hitCount = hitCount
        self.missCount = missCount
        self.evictionCount = evictionCount
        self.generationCount = generationCount
        self.averageGenerationTime = averageGenerationTime
    }
}

// MARK: - Tile Generation

/// Protocol for tile generation
public protocol TileGenerator: Sendable {
    /// Generate a tile for the given key
    func generateTile(key: TileKey) async throws -> CachedTile
    
    /// Check if a tile can be generated for this key
    func canGenerate(key: TileKey) -> Bool
    
    /// Estimate generation time for this tile
    func estimateGenerationTime(key: TileKey) -> TimeInterval
}

/// Default tile generator that creates procedural tiles
public actor DefaultTileGenerator: TileGenerator {
    private let tileSize: UInt32
    private let format: TileFormat
    
    public init(tileSize: UInt32 = 256, format: TileFormat = .rgba8) {
        self.tileSize = tileSize
        self.format = format
    }
    
    public func generateTile(key: TileKey) async throws -> CachedTile {
        let startTime = Date().timeIntervalSince1970
        
        // Generate procedural tile data based on key
        let data = try await generateProceduralData(for: key)
        
        let endTime = Date().timeIntervalSince1970
        let generationTime = endTime - startTime
        
        return CachedTile(
            key: key,
            data: data,
            format: format,
            size: (tileSize, tileSize),
            timestamp: startTime
        )
    }
    
    public func canGenerate(key: TileKey) -> Bool {
        return true // Default generator can create any tile
    }
    
    public func estimateGenerationTime(key: TileKey) -> TimeInterval {
        return 0.001 // 1ms estimate for procedural generation
    }
    
    private func generateProceduralData(for key: TileKey) async throws -> Data {
        switch format {
        case .rgba8:
            return try generateRGBA8Data(for: key)
        case .rgb8:
            return try generateRGB8Data(for: key)
        case .png:
            return try generatePNGData(for: key)
        default:
            throw CapsuleError.invalidInput(
                field: "format",
                constraint: "Unsupported format for procedural generation: \(format)"
            )
        }
    }
    
    private func generateRGBA8Data(for key: TileKey) throws -> Data {
        let pixelCount = Int(tileSize * tileSize)
        var data = Data(capacity: pixelCount * 4)
        
        // Generate a pattern based on tile coordinates
        for y in 0..<tileSize {
            for x in 0..<tileSize {
                let r = UInt8((Int(key.x) + Int(x)) % 256)
                let g = UInt8((Int(key.y) + Int(y)) % 256)
                let b = UInt8(Int(key.zoom) * 50 % 256)
                let a: UInt8 = 255
                
                data.append(contentsOf: [r, g, b, a])
            }
        }
        
        return data
    }
    
    private func generateRGB8Data(for key: TileKey) throws -> Data {
        let pixelCount = Int(tileSize * tileSize)
        var data = Data(capacity: pixelCount * 3)
        
        for y in 0..<tileSize {
            for x in 0..<tileSize {
                let r = UInt8((Int(key.x) + Int(x)) % 256)
                let g = UInt8((Int(key.y) + Int(y)) % 256)
                let b = UInt8(Int(key.zoom) * 50 % 256)
                
                data.append(contentsOf: [r, g, b])
            }
        }
        
        return data
    }
    
    private func generatePNGData(for key: TileKey) throws -> Data {
        // For now, just generate RGBA8 data and convert to PNG later
        let rgbaData = try generateRGBA8Data(for: key)
        // TODO: Implement PNG encoding
        return rgbaData
    }
}