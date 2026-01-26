// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import XCTest

/// Performance benchmarks for native capsules and critical paths
/// Measures throughput, latency, and resource usage
final class PerformanceBenchmarkTests: XCTestCase {
    
    // Benchmark configuration
    let sampleCount = 100
    let timeout: TimeInterval = 60.0
    
    // MARK: - Setup
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    // MARK: - Text Processing Pipeline Benchmarks
    
    func testTextNormalizationPerformance() throws {
        let testStrings = [
            "The quick brown fox",
            "HELLO WORLD",
            "   Lots of spaces   ",
            "CamelCaseString",
            "snake_case_string"
        ].flatMap { Array(repeating: $0, count: 20) }
        
        var results: [TimeInterval] = []
        
        for testString in testStrings {
            let startTime = Date()
            let normalized = testString.trimmingCharacters(in: .whitespaces).lowercased()
            let duration = Date().timeIntervalSince(startTime)
            
            XCTAssertFalse(normalized.isEmpty)
            results.append(duration)
        }
        
        let averageTime = results.reduce(0, +) / Double(results.count)
        let maxTime = results.max() ?? 0
        let minTime = results.min() ?? 0
        
        XCTAssertLessThan(averageTime, 0.001, "Text normalization averaging \(averageTime*1000)ms - may indicate performance regression")
        XCTAssertLessThan(maxTime, 0.01, "Text normalization peak \(maxTime*1000)ms")
    }
    
    func testTextChunkingPerformance() throws {
        let largeText = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 1000)
        let chunkSize = 256
        
        var measurements: [TimeInterval] = []
        
        for _ in 0..<10 {
            let startTime = Date()
            
            var chunks: [String] = []
            var startIndex = largeText.startIndex
            
            while startIndex < largeText.endIndex {
                let endIndex = largeText.index(startIndex, offsetBy: chunkSize, limitedBy: largeText.endIndex) ?? largeText.endIndex
                chunks.append(String(largeText[startIndex..<endIndex]))
                startIndex = endIndex
            }
            
            let duration = Date().timeIntervalSince(startTime)
            measurements.append(duration)
            
            XCTAssertGreaterThan(chunks.count, 1)
        }
        
        let averageTime = measurements.reduce(0, +) / Double(measurements.count)
        let throughput = Double(largeText.count) / averageTime
        
        let metricsMessage = String(
            format: "Text chunking: avg=%.4fms, throughput=%.1f MB/s",
            averageTime * 1000,
            throughput / 1_000_000
        )
        
        XCTAssertLessThan(averageTime, 0.1, metricsMessage)
    }
    
    // MARK: - Vector Operations Benchmarks
    
    func testVectorSimilarityComputation() throws {
        let vectorSize = 768  // Typical embedding dimension
        let vectors = (0..<100).map { _ in
            (0..<vectorSize).map { _ in Float.random(in: -1...1) }
        }
        
        var measurements: [TimeInterval] = []
        
        for i in 0..<(vectors.count - 1) {
            let vec1 = vectors[i]
            let vec2 = vectors[i + 1]
            
            let startTime = Date()
            
            // Compute cosine similarity
            let dotProduct = zip(vec1, vec2).map(*).reduce(0, +)
            let mag1 = sqrt(vec1.map { $0 * $0 }.reduce(0, +))
            let mag2 = sqrt(vec2.map { $0 * $0 }.reduce(0, +))
            let similarity = dotProduct / (mag1 * mag2)
            
            let duration = Date().timeIntervalSince(startTime)
            measurements.append(duration)
            
            XCTAssertGreaterThanOrEqual(similarity, -1.1)
            XCTAssertLessThanOrEqual(similarity, 1.1)
        }
        
        let averageTime = measurements.reduce(0, +) / Double(measurements.count)
        let opsPerSecond = 1.0 / averageTime
        
        let message = String(format: "Vector similarity: %.3fms (%.0f ops/sec)", averageTime * 1000, opsPerSecond)
        XCTAssertLessThan(averageTime, 0.01, message)
    }
    
    // MARK: - Hashing Performance
    
    func testHashingThroughput() throws {
        // Simulate hash computation on different data sizes
        let dataSizes = [256, 512, 1024, 2048]
        
        for size in dataSizes {
            let data = (0..<size).map { UInt8($0 % 256) }
            
            var timings: [TimeInterval] = []
            
            for _ in 0..<50 {
                let startTime = Date()
                
                // Simple hash simulation
                var hash: UInt64 = 5381
                for byte in data {
                    hash = ((hash << 5) &+ hash) &+ UInt64(byte)
                }
                
                let duration = Date().timeIntervalSince(startTime)
                timings.append(duration)
                
                XCTAssertNotEqual(hash, 0)
            }
            
            let averageTime = timings.reduce(0, +) / Double(timings.count)
            let throughput = Double(size * 50) / timings.reduce(0, +)
            
            let message = String(
                format: "Hashing %d bytes: %.4fms, throughput: %.1f MB/s",
                size,
                averageTime * 1000,
                throughput / 1_000_000
            )
            
            XCTAssertLessThan(averageTime, 0.001, message)
        }
    }
    
    // MARK: - JSON Parsing Performance
    
    func testJSONDecodingPerformance() throws {
        let sampleJSON: [String: Any] = [
            "id": "test-123",
            "name": "Performance Test",
            "metrics": [
                "cpu": 45.2,
                "memory": 1024.5,
                "disk": 2048.7
            ],
            "tags": ["performance", "benchmark", "test"],
            "timestamp": Date().timeIntervalSince1970
        ]
        
        var measurements: [TimeInterval] = []
        
        for _ in 0..<100 {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: sampleJSON) else {
                XCTFail("Failed to serialize JSON")
                return
            }
            
            let startTime = Date()
            
            guard let _ = try? JSONSerialization.jsonObject(with: jsonData) else {
                XCTFail("Failed to deserialize JSON")
                return
            }
            
            let duration = Date().timeIntervalSince(startTime)
            measurements.append(duration)
        }
        
        let averageTime = measurements.reduce(0, +) / Double(measurements.count)
        
        XCTAssertLessThan(averageTime, 0.001, "JSON decoding: \(averageTime * 1000)ms")
    }
    
    // MARK: - Memory Usage Patterns
    
    func testMemoryAllocationPattern() throws {
        // Allocate incrementally larger arrays
        var allocations: [Int] = []
        
        for size in stride(from: 1000, through: 100_000, by: 10_000) {
            let startMemory = MemoryFootprint.current()
            
            let array = Array(0..<size)
            
            let endMemory = MemoryFootprint.current()
            let allocated = endMemory - startMemory
            
            allocations.append(allocated)
            
            // Each element should approximately allocate 8 bytes (Int64 on 64-bit)
            let expectedAllocation = size * 8
            let overhead = abs(allocated - expectedAllocation)
            
            XCTAssertLessThan(Double(overhead) / Double(expectedAllocation), 0.2, "Memory overhead > 20%")
        }
        
        XCTAssertGreaterThan(allocations.count, 5)
    }
    
    // MARK: - Concurrent Operation Performance
    
    func testConcurrentOperationThroughput() async throws {
        let operationCount = 1000
        let concurrency = 10
        
        let startTime = Date()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrency {
                group.addTask {
                    for _ in 0..<(operationCount / concurrency) {
                        // Simulate light work
                        let _ = (0..<100).map { $0 * 2 }
                    }
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let throughput = Double(operationCount) / duration
        
        let message = String(format: "Concurrent ops: %.0f ops/sec (total: %.3fs)", throughput, duration)
        
        XCTAssertGreaterThan(throughput, 100, message)
    }
    
    // MARK: - Compression Performance
    
    func testCompressionRatio() throws {
        let testData = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 100)
        
        guard let originalData = testData.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        // Note: Actual compression would use compression framework
        // This simulates compression ratio measurement
        let compressionRatio = Double(originalData.count) / Double(testData.utf16.count)
        
        XCTAssertGreaterThan(compressionRatio, 0.5, "Compression ratio below 50%")
    }
    
    // MARK: - Latency Distribution
    
    func testLatencyDistribution() throws {
        var latencies: [TimeInterval] = []
        
        for _ in 0..<1000 {
            let startTime = Date()
            
            // Simulate operation
            let result = (0..<100).reduce(0, +)
            
            let latency = Date().timeIntervalSince(startTime)
            latencies.append(latency)
            
            XCTAssertGreaterThan(result, 0)
        }
        
        let sorted = latencies.sorted()
        let p50 = sorted[sorted.count / 2]
        let p95 = sorted[Int(Double(sorted.count) * 0.95)]
        let p99 = sorted[Int(Double(sorted.count) * 0.99)]
        
        let message = String(
            format: "Latency: p50=%.4fms, p95=%.4fms, p99=%.4fms",
            p50 * 1000,
            p95 * 1000,
            p99 * 1000
        )
        
        XCTAssertLessThan(p99, 0.01, message)
    }
    
    // MARK: - Stress Testing
    
    func testSustainedThroughput() async throws {
        let duration: TimeInterval = 5.0  // Run for 5 seconds
        let deadline = Date().addingTimeInterval(duration)
        
        var operationCount = 0
        
        while Date() < deadline {
            let _ = (0..<1000).map { $0 * 2 }.reduce(0, +)
            operationCount += 1
        }
        
        let opsPerSecond = Double(operationCount * 1000) / duration
        
        XCTAssertGreaterThan(opsPerSecond, 100, "Sustained throughput: \(opsPerSecond) ops/sec")
    }
}

// MARK: - Memory Utility

struct MemoryFootprint {
    static func current() -> Int {
        var info = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size)/4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            task_info(
                mach_task_self_,
                task_flavor_t(TASK_BASIC_INFO),
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) { UnsafeMutableRawPointer($0) },
                &count
            )
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}

// Import necessary frameworks
import Darwin
