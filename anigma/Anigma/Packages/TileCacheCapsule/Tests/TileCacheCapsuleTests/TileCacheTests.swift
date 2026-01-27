// TileCacheTests.swift
// TileCacheCapsuleTests - Comprehensive tests for tile cache behavior

import XCTest
import TileCacheCapsule
import CapsuleCore

final class TileCacheTests: XCTestCase {
    
    // MARK: - LRU Cache Tests
    
    func testLRUCacheBasicOperations() async throws {
        let config = TileCacheConfiguration(
            maxTiles: 10,
            maxMemoryBytes: 1024 * 1024, // 1MB
            tileSize: 64
        )
        
        let cache = TileCacheFactory.createLRUCache(configuration: config)
        
        // Test cache miss
        let key1 = TileKey(x: 0, y: 0, zoom: 0, layer: "test")
        let tile1 = try await cache.getTile(key: key1)
        XCTAssertEqual(tile1.key, key1)
        
        // Test cache hit
        let tile2 = try await cache.getTile(key: key1)
        XCTAssertEqual(tile2.key, key1)
        XCTAssertEqual(tile2.accessCount, 2) // Should be incremented
        
        // Test statistics
        let stats = await cache.getStatistics()
        XCTAssertEqual(stats.hitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
        XCTAssertEqual(stats.totalTiles, 1)
    }
    
    func testLRUCacheEviction() async throws {
        let config = TileCacheConfiguration(
            maxTiles: 3, // Small cache to force eviction
            maxMemoryBytes: 1024 * 1024,
            tileSize: 64
        )
        
        let cache = TileCacheFactory.createLRUCache(configuration: config)
        
        // Fill cache to capacity
        let keys = [
            TileKey(x: 0, y: 0, zoom: 0, layer: "test"),
            TileKey(x: 1, y: 0, zoom: 0, layer: "test"),
            TileKey(x: 2, y: 0, zoom: 0, layer: "test")
        ]
        
        for key in keys {
            _ = try await cache.getTile(key: key)
        }
        
        var stats = await cache.getStatistics()
        XCTAssertEqual(stats.totalTiles, 3)
        XCTAssertEqual(stats.evictionCount, 0)
        
        // Add one more tile to trigger eviction
        let newKey = TileKey(x: 3, y: 0, zoom: 0, layer: "test")
        _ = try await cache.getTile(key: newKey)
        
        stats = await cache.getStatistics()
        XCTAssertEqual(stats.totalTiles, 3) // Should still be at max
        XCTAssertEqual(stats.evictionCount, 1)
    }
    
    func testPreloadTiles() async throws {
        let config = TileCacheConfiguration(
            maxTiles: 100,
            maxMemoryBytes: 10 * 1024 * 1024,
            tileSize: 128
        )
        
        let cache = TileCacheFactory.createLRUCache(configuration: config)
        
        // Create keys to preload
        let keys = (0..<10).map { i in
            TileKey(x: Int32(i), y: 0, zoom: 0, layer: "preload_test")
        }
        
        // Preload tiles
        try await cache.preloadTiles(keys: keys)
        
        // Verify all tiles are in cache
        for key in keys {
            let tile = try await cache.getTile(key: key)
            XCTAssertEqual(tile.key, key)
            XCTAssertEqual(tile.accessCount, 1)
        }
        
        let stats = await cache.getStatistics()
        XCTAssertEqual(stats.totalTiles, 10)
        XCTAssertEqual(stats.missCount, 10) // All misses from preload
        XCTAssertEqual(stats.hitCount, 10) // All hits from subsequent access
    }
    
    func testClearCache() async throws {
        let config = TileCacheConfiguration(
            maxTiles: 50,
            maxMemoryBytes: 5 * 1024 * 1024,
            tileSize: 256
        )
        
        let cache = TileCacheFactory.createLRUCache(configuration: config)
        
        // Add some tiles
        let keys = (0..<5).map { i in
            TileKey(x: Int32(i), y: Int32(i), zoom: 1, layer: "clear_test")
        }
        
        for key in keys {
            _ = try await cache.getTile(key: key)
        }
        
        var stats = await cache.getStatistics()
        XCTAssertGreaterThan(stats.totalTiles, 0)
        XCTAssertGreaterThan(stats.memoryUsageBytes, 0)
        
        // Clear cache
        try await cache.clearCache()
        
        stats = await cache.getStatistics()
        XCTAssertEqual(stats.totalTiles, 0)
        XCTAssertEqual(stats.memoryUsageBytes, 0)
        XCTAssertEqual(stats.hitCount, 0)
        XCTAssertEqual(stats.missCount, 0)
        XCTAssertEqual(stats.evictionCount, 0)
    }
    
    func testEvictionPolicies() async throws {
        let config = TileCacheConfiguration(
            maxTiles: 5,
            maxMemoryBytes: 1024 * 1024,
            tileSize: 64,
            evictionPolicy: .lru
        )
        
        let cache = TileCacheFactory.createLRUCache(configuration: config)
        
        // Access pattern to test LRU
        let keys = [
            TileKey(x: 0, y: 0, zoom: 0, layer: "lru_test"),
            TileKey(x: 1, y: 0, zoom: 0, layer: "lru_test"),
            TileKey(x: 2, y: 0, zoom: 0, layer: "lru_test")
        ]
        
        // Add tiles
        for key in keys {
            _ = try await cache.getTile(key: key)
        }
        
        // Access first tile again to make it most recently used
        _ = try await cache.getTile(key: keys[0])
        
        // Add more tiles to trigger eviction
        for i in 3..<7 {
            let key = TileKey(x: Int32(i), y: 0, zoom: 0, layer: "lru_test")
            _ = try await cache.getTile(key: key)
        }
        
        // First tile should still be in cache (was accessed recently)
        let tile = try await cache.getTile(key: keys[0])
        XCTAssertEqual(tile.key, keys[0])
        XCTAssertGreaterThan(tile.accessCount, 1)
    }
    
    // MARK: - Tile Generation Tests
    
    func testDefaultTileGenerator() async throws {
        let generator = DefaultTileGenerator(tileSize: 64, format: .rgba8)
        
        let key = TileKey(x: 1, y: 2, zoom: 3, layer: "gen_test")
        
        XCTAssertTrue(generator.canGenerate(key: key))
        
        let tile = try await generator.generateTile(key: key)
        XCTAssertEqual(tile.key, key)
        XCTAssertEqual(tile.format, .rgba8)
        XCTAssertEqual(tile.size.width, 64)
        XCTAssertEqual(tile.size.height, 64)
        XCTAssertEqual(tile.data.count, 64 * 64 * 4) // RGBA8
    }
    
    func testTileFormatHandling() async throws {
        let formats: [TileFormat] = [.rgba8, .rgb8, .png]
        
        for format in formats {
            let generator = DefaultTileGenerator(tileSize: 32, format: format)
            let key = TileKey(x: 0, y: 0, zoom: 0, layer: "format_test")
            
            let tile = try await generator.generateTile(key: key)
            XCTAssertEqual(tile.format, format)
            XCTAssertEqual(tile.size.width, 32)
            XCTAssertEqual(tile.size.height, 32)
            
            if !format.isCompressed {
                let expectedSize = 32 * 32 * format.bytesPerPixel
                XCTAssertEqual(tile.data.count, Int(expectedSize))
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testCachePerformance() async throws {
        let config = TileCacheConfiguration(
            maxTiles: 1000,
            maxMemoryBytes: 100 * 1024 * 1024, // 100MB
            tileSize: 256
        )
        
        let cache = TileCacheFactory.createLRUCache(configuration: config)
        
        // Generate random keys
        let keys = (0..<100).map { i in
            TileKey(x: Int32.random(in: 0..<10), y: Int32.random(in: 0..<10), zoom: UInt8.random(in: 0..<5), layer: "perf_test")
        }
        
        // Measure cache access performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<1000 {
            let key = keys.randomElement()!
            _ = try await cache.getTile(key: key)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Should complete reasonably quickly
        XCTAssertLessThan(duration, 1.0) // Less than 1 second for 1000 operations
        
        let stats = await cache.getStatistics()
        let opsPerSecond = Double(stats.hitCount + stats.missCount) / duration
        XCTAssertGreaterThan(opsPerSecond, 100) // At least 100 ops/second
    }
    
    // MARK: - Error Handling Tests
    
    func testMemoryLimitEnforcement() async throws {
        let config = TileCacheConfiguration(
            maxTiles: 100,
            maxMemoryBytes: 10 * 1024, // Very small limit: 10KB
            tileSize: 64
        )
        
        let cache = TileCacheFactory.createLRUCache(configuration: config)
        
        // Add tiles until memory limit is hit
        var tileCount = 0
        for i in 0..<50 {
            let key = TileKey(x: Int32(i), y: 0, zoom: 0, layer: "memory_test")
            _ = try await cache.getTile(key: key)
            tileCount += 1
            
            let stats = await cache.getStatistics()
            if stats.memoryUsageBytes >= config.maxMemoryBytes {
                break
            }
        }
        
        let stats = await cache.getStatistics()
        XCTAssertLessThanOrEqual(stats.memoryUsageBytes, config.maxMemoryBytes)
        XCTAssertGreaterThan(stats.evictionCount, 0) // Should have evicted tiles
    }
    
    func testInvalidKeyHandling() async throws {
        let generator = DefaultTileGenerator()
        let cache = LRUTileCache(
            configuration: TileCacheConfiguration(),
            tileGenerator: generator
        )
        
        // Default generator should accept all keys
        let key = TileKey(x: -1, y: -1, zoom: 255, layer: "invalid_test")
        
        // This should succeed
        let tile = try await cache.getTile(key: key)
        XCTAssertEqual(tile.key, key)
    }
}

// MARK: - Benchmark Extension

extension TileCacheTests {
    func testCacheBenchmarkConsistency() async throws {
        let config = TileCacheConfiguration(
            maxTiles: 100,
            maxMemoryBytes: 10 * 1024 * 1024,
            tileSize: 128
        )
        
        let cache = TileCacheFactory.createLRUCache(configuration: config)
        
        // Consistency test for repeated access patterns
        let pattern = [
            TileKey(x: 0, y: 0, zoom: 0, layer: "pattern"),
            TileKey(x: 1, y: 0, zoom: 0, layer: "pattern"),
            TileKey(x: 0, y: 1, zoom: 0, layer: "pattern"),
            TileKey(x: 1, y: 1, zoom: 0, layer: "pattern")
        ]
        
        // Run pattern multiple times
        for _ in 0..<10 {
            for key in pattern {
                _ = try await cache.getTile(key: key)
            }
        }
        
        let stats = await cache.getStatistics()
        XCTAssertEqual(stats.totalTiles, 4) // Only 4 unique tiles
        XCTAssertEqual(stats.hitCount, 36) // 40 total - 4 initial misses
        XCTAssertEqual(stats.missCount, 4)
        XCTAssertEqual(stats.hitRate, 0.9, accuracy: 0.01) // 90% hit rate
    }
}