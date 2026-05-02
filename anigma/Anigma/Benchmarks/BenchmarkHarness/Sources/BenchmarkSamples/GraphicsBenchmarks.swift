// GraphicsBenchmarks.swift
// BenchmarkHarness - Performance benchmarks for graphics components

import Foundation
import BenchmarkHarness
import RendererKit
import AnimationKit

// MARK: - Renderer Benchmarks

public struct RendererInitializationBenchmark: BenchmarkCase {
    public let name = "Renderer Initialization"
    public let iterations = 100
    
    public mutating func setUp() async throws {
        // Any setup needed
    }
    
    public mutating func run() async throws {
        let renderer = MetalRenderer()
        let config = RendererConfiguration(
            preferredBackend: .metal,
            maxFramesInFlight: 3,
            viewportSize: (1920, 1080)
        )
        
        try await renderer.initialize(config: config)
    }
    
    public mutating func tearDown() async throws {
        // Cleanup
    }
}

public struct PipelineCreationBenchmark: BenchmarkCase {
    public let name = "Pipeline Creation"
    public let iterations = 1000
    
    private let descriptor = RenderPipelineDescriptor(
        vertexFunction: """
        vertex float4 vertex_main(uint vertexID [[vertex_id]]) {
            return float4(float(vertexID) * 0.1, 0.0, 0.0, 1.0);
        }
        """,
        fragmentFunction: """
        fragment float4 fragment_main() {
            return float4(1.0, 0.0, 0.0, 1.0);
        }
        """
    )
    
    public mutating func setUp() async throws {}
    public mutating func run() async throws {
        BenchmarkBlackhole.consume(descriptor)
    }
    
    public mutating func tearDown() async throws {}
}

// MARK: - Tile Cache Benchmarks

public struct TileCacheGetBenchmark: BenchmarkCase {
    public let name = "Tile Cache Get Operations"
    public let iterations = 10000
    
    private var cache: any TileCache?
    private var keys: [TileKey] = []
    
    public mutating func setUp() async throws {
        let config = TileCacheConfiguration(
            maxTiles: 1000,
            maxMemoryBytes: 100 * 1024 * 1024, // 100MB
            tileSize: 256
        )
        
        cache = TileCacheFactory.createLRUCache(configuration: config)
        
        // Pre-populate keys
        for i in 0..<100 {
            let key = TileKey(x: Int32(i % 10), y: Int32(i / 10), zoom: 0, layer: "test")
            keys.append(key)
        }
    }
    
    public mutating func run() async throws {
        guard let cache = cache else { return }

        for key in keys {
            _ = try await cache.getTile(key: key)
        }
    }
    
    public mutating func tearDown() async throws {
        try await cache?.clearCache()
    }
}

public struct TileCacheEvictionBenchmark: BenchmarkCase {
    public let name = "Tile Cache Eviction"
    public let iterations = 100
    
    private var cache: any TileCache?
    private var keys: [TileKey] = []
    
    public mutating func setUp() async throws {
        let config = TileCacheConfiguration(
            maxTiles: 100, // Small cache to trigger evictions
            maxMemoryBytes: 10 * 1024 * 1024, // 10MB
            tileSize: 256
        )
        
        cache = TileCacheFactory.createLRUCache(configuration: config)
        
        // Generate more keys than cache can hold
        for i in 0..<200 {
            let key = TileKey(x: Int32(i), y: Int32(i), zoom: UInt8(i % 10), layer: "test")
            keys.append(key)
        }
    }
    
    public mutating func run() async throws {
        guard let cache = cache else { return }

        // Access tiles to trigger evictions
        for key in keys {
            _ = try await cache.getTile(key: key)
        }
    }
    
    public mutating func tearDown() async throws {
        try await cache?.clearCache()
    }
}

// MARK: - Animation Benchmarks

public struct AnimationEvaluationBenchmark: BenchmarkCase {
    public let name = "Animation Evaluation"
    public let iterations = 100000
    
    private var animation: KeyframeAnimation?
    
    public mutating func setUp() async throws {
        let target = AnimationTarget(objectID: "test", property: "position")
        
        let animation = try! AnimationBuilder()
            .target(target)
            .duration(1.0)
            .keyframe(0.0, .float(0.0))
            .keyframe(0.5, .float(100.0))
            .keyframe(1.0, .float(0.0))
            .easeInOut()
            .build()
        
        self.animation = animation
    }
    
    public mutating func run() async throws {
        guard let animation = animation else { return }
        
        for i in 0..<iterations {
            let time = Double(i) / Double(iterations)
            let value = animation.evaluate(at: time)
            BenchmarkBlackhole.consume(value)
        }
    }
    
    public mutating func tearDown() async throws {}
}

public struct TimelineUpdateBenchmark: BenchmarkCase {
    public let name = "Timeline Update"
    public let iterations = 1000
    
    private var timeline: AnimationTimeline?
    private var animations: [KeyframeAnimation] = []
    
    public mutating func setUp() async throws {
        timeline = AnimationTimeline()
        
        // Create multiple animations
        for i in 0..<100 {
            let target = AnimationTarget(objectID: "obj_\(i)", property: "position")
            let animation = try! AnimationBuilder()
                .target(target)
                .duration(2.0)
                .keyframe(0.0, .float(0.0))
                .keyframe(1.0, .float(Float(i * 10)))
                .easeInOut()
                .repeatCount(0) // Infinite loop
                .build()
            
            animations.append(animation)
        }
    }
    
    public mutating func run() async throws {
        guard let timeline = timeline else { return }

        for animation in animations {
            await timeline.add(animation)
        }

        // Run timeline updates
        for _ in 0..<iterations {
            let updates = await timeline.update(deltaTime: 0.016) // 60 FPS
            BenchmarkBlackhole.consume(updates)
        }
    }
    
    public mutating func tearDown() async throws {
        await timeline?.reset()
    }
}

// MARK: - Memory Usage Benchmarks

public struct MemoryUsageBenchmark: BenchmarkCase {
    public let name = "Graphics Memory Usage"
    public let iterations = 1
    
    public mutating func setUp() async throws {}
    
    public mutating func run() async throws {
        // Test memory usage of various graphics operations
        
        // Tile cache memory
        let tileConfig = TileCacheConfiguration(
            maxTiles: 1000,
            maxMemoryBytes: 512 * 1024 * 1024, // 512MB
            tileSize: 512
        )
        
        let tileCache = TileCacheFactory.createLRUCache(configuration: tileConfig)

        // Generate many tiles to test memory usage
        for i in 0..<500 {
            let key = TileKey(x: Int32(i % 20), y: Int32(i / 20), zoom: 0, layer: "memory_test")
            _ = try await tileCache.getTile(key: key)
        }

        let stats = await tileCache.getStatistics()
        BenchmarkBlackhole.consume(stats.memoryUsageBytes)
        
        // Animation memory
        var animations: [KeyframeAnimation] = []
        for i in 0..<1000 {
            let target = AnimationTarget(objectID: "mem_test_\(i)", property: "test")
            let animation = try! AnimationBuilder()
                .target(target)
                .duration(1.0)
                .keyframe(0.0, .vector4(Vector4(0, 0, 0, 0)))
                .keyframe(1.0, .vector4(Vector4(1, 1, 1, 1)))
                .easeInOut()
                .build()
            
            animations.append(animation)
        }
        
        BenchmarkBlackhole.consume(animations.count)
    }
    
    public mutating func tearDown() async throws {}
}

// MARK: - Benchmark Collection

public extension Array where Element == BenchmarkCase {
    static func graphicsBenchmarks() -> [BenchmarkCase] {
        return [
            RendererInitializationBenchmark(),
            PipelineCreationBenchmark(),
            TileCacheGetBenchmark(),
            TileCacheEvictionBenchmark(),
            AnimationEvaluationBenchmark(),
            TimelineUpdateBenchmark(),
            MemoryUsageBenchmark()
        ]
    }
}
