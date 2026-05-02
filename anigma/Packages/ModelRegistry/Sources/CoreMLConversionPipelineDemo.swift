//
//  CoreMLConversionPipelineDemo.swift
//  ModelRegistry
//
//  Demonstration of enhanced CoreML conversion pipeline features.
//

import Foundation

// MARK: - Demo Types

public enum DemoWorkloadCategory: String, Codable, Sendable, CaseIterable {
    case embeddings = "embeddings"
    case reranker = "reranker"
    case classifier = "classifier"
    case perception = "perception"
    case prefill = "prefill"
    case decode = "decode"
    case multimodal = "multimodal"
    case specialized = "specialized"
}

// MARK: - Demo Implementation

public actor DemoCoreMLConversionPipeline {
    private let workDir: URL
    private let cacheDir: URL
    
    public init(workDir: URL) {
        self.workDir = workDir
        self.cacheDir = workDir.appendingPathComponent("demo_cache")
        try? FileManager.default.createDirectory(at: self.cacheDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Enhanced Features Demo
    
    public func demonstrateEnhancedFeatures() async {
        print("=== CoreML Conversion Pipeline Enhanced Features Demo ===")
        print()
        
        // 1. Demonstrate OS version targeting
        print("1. OS Version Targeting:")
        let osVersions = ["macos13", "macos14", "macos15", "macos16", "ios17", "ios18"]
        for version in osVersions {
            print("   - Supports \(version)")
        }
        print()
        
        // 2. Demonstrate quantization support
        print("2. Quantization Support:")
        let quantizations = ["int8", "fp16", "fp32"]
        for quant in quantizations {
            print("   - \(quant) quantization with calibration data")
        }
        print()
        
        // 3. Demonstrate cache management
        print("3. Cache Management:")
        let cacheKey = generateDemoCacheKey(
            modelId: "bert-base-uncased",
            targetFormat: "mlprogram",
            computeUnits: "cpuAndNeuralEngine",
            quantization: "int8",
            minOSVersion: "macos15"
        )
        print("   - Cache key generation: \(cacheKey.prefix(16))...")
        print("   - Hash-based deterministic keys")
        print()
        
        // 4. Demonstrate retry logic
        print("4. Retry Logic:")
        print("   - Configurable max retries (default: 3)")
        print("   - Exponential backoff support")
        print("   - Error recovery with progress logging")
        print()
        
        // 5. Demonstrate calibration data
        print("5. Calibration Data Support:")
        let calibrationData = generateDemoCalibrationData(for: .embeddings)
        print("   - Generated \(calibrationData.samples.count) samples")
        print("   - Sample shape: \(calibrationData.sampleShape)")
        print("   - Data type: \(calibrationData.dataType)")
        print()
        
        // 6. Demonstrate logging
        print("6. Comprehensive Logging:")
        print("   - Start/end events with timestamps")
        print("   - Progress reporting (0-100%)")
        print("   - Cache hit/miss tracking")
        print("   - Retry attempt logging")
        print()
        
        // 7. Demonstrate registry integration
        print("7. Registry Integration:")
        print("   - Store conversion receipts")
        print("   - Query existing conversions")
        print("   - Avoid duplicate conversions")
        print()
        
        print("=== Demo Complete ===")
    }
    
    // MARK: - Helper Methods
    
    private func generateDemoCacheKey(
        modelId: String,
        targetFormat: String,
        computeUnits: String,
        quantization: String?,
        minOSVersion: String
    ) -> String {
        var hasher = Hasher()
        hasher.combine(modelId)
        hasher.combine(targetFormat)
        hasher.combine(computeUnits)
        hasher.combine(quantization ?? "none")
        hasher.combine(minOSVersion)
        return String(hasher.finalize())
    }
    
    private func generateDemoCalibrationData(for category: DemoWorkloadCategory) -> CoreMLCalibrationData {
        var samples: [Data] = []
        var sampleShape: [Int]
        
        switch category {
        case .embeddings, .reranker, .classifier:
            sampleShape = [1, 512, 768]
        case .perception:
            sampleShape = [1, 3, 224, 224]
        case .prefill, .decode, .multimodal:
            sampleShape = [1, 512, 4096]
        case .specialized:
            sampleShape = [1, 1024]
        }
        
        // Generate 10 sample data points
        for _ in 0..<10 {
            let elementCount = sampleShape.reduce(1, *)
            var randomFloats = [Float](repeating: 0, count: elementCount)
            for i in 0..<randomFloats.count {
                randomFloats[i] = Float.random(in: -1.0...1.0)
            }
            let data = randomFloats.withUnsafeBufferPointer { buffer in
                Data(buffer: buffer)
            }
            samples.append(data)
        }
        
        return CoreMLCalibrationData(
            samples: samples,
            sampleShape: sampleShape,
            dataType: "float32",
            source: "demo_\(category.rawValue)"
        )
    }
    
    // MARK: - Cache Operations Demo
    
    public func demonstrateCacheOperations() async throws {
        print("=== Cache Operations Demo ===")
        
        // Create some dummy cache files
        for i in 0..<5 {
            let cacheFile = cacheDir.appendingPathComponent("cache_entry_\(i).json")
            let content = """
            {
                "model_id": "demo_model_\(i)",
                "timestamp": "2024-01-01T00:00:00Z",
                "cache_key": "key_\(i)"
            }
            """
            try content.write(to: cacheFile, atomically: true, encoding: .utf8)
        }
        
        // List cache files
        let files = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey])
        print("Cache contains \(files.count) entries")
        
        // Calculate total size
        var totalSize: Int64 = 0
        for file in files {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            totalSize += (attributes[.size] as? Int64) ?? 0
        }
        print("Total cache size: \(totalSize) bytes")
        
        // Clear cache
        try clearDemoCache()
        print("Cache cleared successfully")
        
        let remainingFiles = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
        print("Remaining files after clear: \(remainingFiles.count)")
        
        print("=== Cache Demo Complete ===")
    }
    
    private func clearDemoCache() async throws {
        let files = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
        for file in files {
            try FileManager.default.removeItem(at: file)
        }
    }
}

// MARK: - Usage Example

/*
 Example of using the enhanced CoreMLConversionPipeline:
 
 // Create pipeline with enhanced features
 let workDir = URL(fileURLWithPath: "/tmp/coreml_conversions")
 let registry = InMemoryCoreMLRegistry()
 let pipeline = CoreMLConversionPipeline(
     workDir: workDir,
     registry: registry,
     maxRetries: 3,
     retryDelay: 2.0
 )
 
 // Register a demo model
 let modelSpec = ModelSpec(
     id: "bert-base-uncased",
     artifactHashes: ["model.safetensors": "abc123"]
 )
 let modelEntry = ModelRegistryEntry(
     id: modelSpec.id,
     spec: modelSpec,
     installPath: "/path/to/model"
 )
 registry.registerModel(modelEntry)
 
 // Convert with enhanced features
 do {
     // Generate calibration data
     let calibrationData = pipeline.generateCalibrationData(
         for: .embeddings,
         sampleCount: 50
     )
     
     // Perform conversion
     let receipt = try await pipeline.convertToCoreML(
         modelId: "bert-base-uncased",
         targetFormat: .mlprogram,
         computeUnits: .cpuAndNeuralEngine,
         quantization: .int8,
         minOSVersion: "macos15",
         calibrationData: calibrationData,
         storeInRegistry: true
     )
     
     print("Conversion successful!")
     print("Output hashes: \(receipt.outputHashes)")
     print("Placement analysis: \(receipt.placementAnalysis)")
     
     // Get cache stats
     let cacheStats = try await pipeline.getCacheStats()
     print("Cache: \(cacheStats.total) entries, \(cacheStats.size) bytes")
     
 } catch {
     print("Conversion failed: \(error)")
 }
 */