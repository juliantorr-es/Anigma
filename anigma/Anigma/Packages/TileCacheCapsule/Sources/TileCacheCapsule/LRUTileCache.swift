// LRUTileCache.swift
// TileCacheCapsule - Production-ready LRU tile cache implementation

import Foundation
import CapsuleCore

// MARK: - LRU Node

/// Doubly-linked list node for LRU tracking
private class LRUNode: Sendable {
    let key: TileKey
    var tile: CachedTile
    weak var previous: LRUNode?
    var next: LRUNode?
    
    init(tile: CachedTile) {
        self.key = tile.key
        self.tile = tile
    }
}

// MARK: - LRU Tile Cache Implementation

/// High-performance LRU tile cache with thread safety and memory management
public actor LRUTileCache: TileCache {
    private let configuration: TileCacheConfiguration
    private let tileGenerator: TileGenerator
    
    // LRU tracking
    private var head: LRUNode?
    private var tail: LRUNode?
    
    // Fast lookup
    private var tileMap: [TileKey: LRUNode] = [:]
    
    // Statistics
    private var hitCount: UInt64 = 0
    private var missCount: UInt64 = 0
    private var evictionCount: UInt64 = 0
    private var generationCount: UInt64 = 0
    private var totalGenerationTime: TimeInterval = 0.0
    
    // Memory tracking
    private var currentMemoryUsage: UInt64 = 0
    
    public init(configuration: TileCacheConfiguration, tileGenerator: TileGenerator) {
        self.configuration = configuration
        self.tileGenerator = tileGenerator
    }
    
    // MARK: - TileCache Protocol Implementation
    
    public func getTile(key: TileKey) async throws -> CachedTile {
        if let node = tileMap[key] {
            // Cache hit - move to front and update access
            moveToHead(node)
            hitCount += 1
            node.tile.accessCount += 1
            node.tile.lastAccess = Date().timeIntervalSince1970
            return node.tile
        } else {
            // Cache miss - generate new tile
            missCount += 1
            let tile = try await generateAndCacheTile(for: key)
            return tile
        }
    }
    
    public func preloadTiles(keys: [TileKey]) async throws {
        let startTime = Date().timeIntervalSince1970
        
        // Filter out tiles that are already cached
        let keysToLoad = keys.filter { tileMap[$0] == nil }
        
        // Batch generation for better performance
        await withTaskGroup(of: Void.self) { group in
            for key in keysToLoad {
                group.addTask {
                    _ = try? await self.generateAndCacheTile(for: key)
                }
            }
        }
        
        let endTime = Date().timeIntervalSince1970
        let duration = endTime - startTime
    }
    
    public func evictTiles(keys: [TileKey]) async throws {
        for key in keys {
            if let node = tileMap[key] {
                removeNode(node)
                tileMap.removeValue(forKey: key)
                evictionCount += 1
            }
        }
    }
    
    public func clearCache() async throws {
        // Clear all mappings and nodes
        tileMap.removeAll()
        head = nil
        tail = nil
        currentMemoryUsage = 0
        
        // Reset statistics (preserve generation stats)
        hitCount = 0
        missCount = 0
        evictionCount = 0
    }
    
    public func getStatistics() -> CacheStatistics {
        let avgGenTime = generationCount > 0 ? totalGenerationTime / Double(generationCount) : 0.0
        return CacheStatistics(
            totalTiles: UInt32(tileMap.count),
            memoryUsageBytes: currentMemoryUsage,
            hitCount: hitCount,
            missCount: missCount,
            evictionCount: evictionCount,
            generationCount: generationCount,
            averageGenerationTime: avgGenTime
        )
    }
    
    // MARK: - Private Implementation
    
    private func generateAndCacheTile(for key: TileKey) async throws -> CachedTile {
        let startTime = Date().timeIntervalSince1970
        
        guard tileGenerator.canGenerate(key: key) else {
            throw CapsuleError.invalidInput(
                field: "key",
                constraint: "Cannot generate tile for key: \(key)"
            )
        }
        
        // Generate the tile
        let tile = try await tileGenerator.generateTile(key: key)
        
        // Update generation statistics
        generationCount += 1
        let endTime = Date().timeIntervalSince1970
        totalGenerationTime += (endTime - startTime)
        
        // Add to cache
        let node = LRUNode(tile: tile)
        tileMap[key] = node
        
        // Update memory usage
        let tileMemory = UInt64(tile.data.count)
        currentMemoryUsage += tileMemory
        
        // Insert at head of LRU list
        addToHead(node)
        
        // Enforce memory and tile limits
        try enforceMemoryLimit()
        try enforceTileLimit()
        
        return tile
    }
    
    private func enforceMemoryLimit() throws {
        guard configuration.maxMemoryBytes > 0 else { return }
        
        while currentMemoryUsage > configuration.maxMemoryBytes && tail != nil {
            guard let nodeToEvict = tail else { break }
            evictNode(nodeToEvict)
        }
    }
    
    private func enforceTileLimit() throws {
        while tileMap.count > Int(configuration.maxTiles) && tail != nil {
            guard let nodeToEvict = tail else { break }
            evictNode(nodeToEvict)
        }
    }
    
    private func evictNode(_ node: LRUNode) {
        removeNode(node)
        tileMap.removeValue(forKey: node.key)
        currentMemoryUsage -= UInt64(node.tile.data.count)
        evictionCount += 1
    }
    
    // MARK: - LRU List Management
    
    private func addToHead(_ node: LRUNode) {
        node.previous = nil
        node.next = head
        
        head?.previous = node
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    private func removeNode(_ node: LRUNode) {
        if let previous = node.previous {
            previous.next = node.next
        } else {
            head = node.next
        }
        
        if let next = node.next {
            next.previous = node.previous
        } else {
            tail = node.previous
        }
        
        node.previous = nil
        node.next = nil
    }
    
    private func moveToHead(_ node: LRUNode) {
        removeNode(node)
        addToHead(node)
    }
}

// MARK: - Thread-Safe Tile Cache Factory

/// Factory for creating optimized tile cache instances
public enum TileCacheFactory {
    /// Create an LRU tile cache with default generator
    public static func createLRUCache(
        configuration: TileCacheConfiguration = TileCacheConfiguration()
    ) -> any TileCache {
        let generator = DefaultTileGenerator(
            tileSize: configuration.tileSize,
            format: .rgba8
        )
        return LRUTileCache(configuration: configuration, tileGenerator: generator)
    }
    
    /// Create an LRU tile cache with custom generator
    public static func createLRUCache(
        configuration: TileCacheConfiguration = TileCacheConfiguration(),
        tileGenerator: TileGenerator
    ) -> any TileCache {
        return LRUTileCache(configuration: configuration, tileGenerator: tileGenerator)
    }
}