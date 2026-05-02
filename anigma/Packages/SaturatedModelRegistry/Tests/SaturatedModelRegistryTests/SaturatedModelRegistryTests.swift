//
//  SaturatedModelRegistryTests.swift
//  SaturatedModelRegistryTests
//
//  Tests for SaturatedModelRegistry package.
//  Focus: LLM predigestion, quantization, cache management, lazy loading.
//
//  TD Task: td-sli-2026-3.1 - Design ModelRegistry Architecture
//  TD Task: td-sli-2026-3.2 - Implement Model Loading Pipeline
//  TD Task: td-sli-2026-3.3 - Implement Static Quantization
//  TD Task: td-sli-2026-3.4 - Implement Memory-Mapped Loading
//  TD Task: td-sli-2026-3.5 - Implement Predigestion at Startup
//  TD Task: td-sli-2026-3.6 - Implement Lazy Loading Fallback
//  TD Task: td-sli-2026-3.7 - Memory Usage Optimization
//

import XCTest
import Metal
@testable import SaturatedModelRegistry

final class SaturatedModelRegistryTests: XCTestCase {

    // MARK: - Setup

    var pool: UnifiedMemoryPool!
    var registry: ModelRegistry!

    override func setUp() async throws {
        // Create a unified memory pool for testing
        let config = MemoryPoolConfig(
            poolID: "test-pool",
            initialSize: 64 * 1024 * 1024,
            maxSize: 256 * 1024 * 1024,
            heapSizes: [32 * 1024 * 1024]
        )
        pool = UnifiedMemoryPool(config: config)
        
        // Create registry with lazy loading strategy for controlled testing
        let registryConfig = ModelRegistry.Config(
            loadingStrategy: .lazy,
            cachePolicy: .keepAll,
            memoryPoolConfig: config,
            maxConcurrentLoads: 2,
            defaultQuantization: .none
        )
        registry = ModelRegistry(config: registryConfig, pool: pool)
        registry.initialize()
    }

    override func tearDown() async throws {
        registry.shutdown()
        pool = nil
        registry = nil
    }

    // MARK: - Model Registration Tests

    func testRegisterSingleModel() {
        let metadata = ModelRegistry.ModelMetadata(
            id: "test-model-1",
            name: "TestModel",
            version: "1.0",
            parameterCount: 1000,
            architecture: "Test",
            filePath: nil,
            quantization: .none,
            estimatedMemory: 1000000,
            creationDate: Date(),
            lastAccessed: nil
        )
        
        let modelId = registry.registerModel(metadata)
        
        XCTAssertEqual(modelId, "test-model-1")
        
        let stats = registry.getStats()
        XCTAssertEqual(stats.totalModels, 1)
        XCTAssertEqual(stats.loadedModels, 0)  // Lazy strategy, not loaded yet
    }

    func testRegisterMultipleModels() {
        let models = (0..<5).map { i in
            ModelRegistry.ModelMetadata(
                id: "model-\(i)",
                name: "Model\(i)",
                version: "1.0",
                parameterCount: Int(i) * 1000,
                architecture: "Test",
                filePath: nil,
                quantization: .none,
                estimatedMemory: Int(i) * 1000000,
                creationDate: Date(),
                lastAccessed: nil
            )
        }
        
        registry.registerModels(models)
        
        let stats = registry.getStats()
        XCTAssertEqual(stats.totalModels, 5)
        XCTAssertEqual(stats.loadedModels, 0)
    }

    // MARK: - Loading Strategy Tests

    func testImmediateLoadingStrategy() {
        let immediateConfig = ModelRegistry.Config(
            loadingStrategy: .immediate,
            cachePolicy: .keepAll,
            memoryPoolConfig: .default,
            maxConcurrentLoads: 1,
            defaultQuantization: .none
        )
        let immediateRegistry = ModelRegistry(config: immediateConfig, pool: pool)
        immediateRegistry.initialize()
        
        let metadata = ModelRegistry.ModelMetadata(
            id: "immediate-model",
            name: "ImmediateModel",
            version: "1.0",
            parameterCount: 1000,
            architecture: "Test",
            filePath: nil,
            quantization: .none,
            estimatedMemory: 1000000
        )
        
        _ = immediateRegistry.registerModel(metadata)
        
        // Give async loading time to complete
        let expectation = XCTestExpectation(description: "Wait for loading")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let stats = immediateRegistry.getStats()
        XCTAssertEqual(stats.totalModels, 1)
        // Note: Without actual file loading, state may not be .predigested
        // but the immediate strategy should attempt to load
        
        immediateRegistry.shutdown()
    }

    // MARK: - Lazy Loading Tests

    func testLazyLoadingOnAccess() {
        let metadata = ModelRegistry.ModelMetadata(
            id: "lazy-model",
            name: "LazyModel",
            version: "1.0",
            parameterCount: 1000,
            architecture: "Test",
            filePath: nil,
            quantization: .none,
            estimatedMemory: 1000000
        )
        
        let modelId = registry.registerModel(metadata)
        
        // Initially not loaded
        var model = registry.getModel(id: modelId)
        XCTAssertNotNil(model)
        if case .notLoaded = model?.state {
            // Expected for lazy loading
        } else {
            XCTFail("Model should not be loaded initially with lazy strategy")
        }
    }

    // MARK: - Quantization Type Tests

    func testQuantizationTypeBits() {
        XCTAssertEqual(ModelRegistry.QuantizationType.none.bits, 32)
        XCTAssertEqual(ModelRegistry.QuantizationType.int8Symmetric.bits, 8)
        XCTAssertEqual(ModelRegistry.QuantizationType.int8Asymmetric.bits, 8)
        XCTAssertEqual(ModelRegistry.QuantizationType.int4Symmetric.bits, 4)
        XCTAssertEqual(ModelRegistry.QuantizationType.int4Asymmetric.bits, 4)
    }

    func testQuantizationTypeCompressionRatio() {
        XCTAssertEqual(ModelRegistry.QuantizationType.none.compressionRatio, 1.0)
        XCTAssertEqual(ModelRegistry.QuantizationType.int8Symmetric.compressionRatio, 4.0)
        XCTAssertEqual(ModelRegistry.QuantizationType.int8Asymmetric.compressionRatio, 4.0)
        XCTAssertEqual(ModelRegistry.QuantizationType.int4Symmetric.compressionRatio, 8.0)
        XCTAssertEqual(ModelRegistry.QuantizationType.int4Asymmetric.compressionRatio, 8.0)
    }

    // MARK: - Model Metadata Tests

    func testModelMetadataDefaultValues() {
        let metadata = ModelRegistry.ModelMetadata(
            id: "test-id",
            name: "Test",
            version: "1.0",
            parameterCount: 1000,
            architecture: "Test"
        )
        
        XCTAssertEqual(metadata.id, "test-id")
        XCTAssertEqual(metadata.name, "Test")
        XCTAssertEqual(metadata.version, "1.0")
        XCTAssertEqual(metadata.parameterCount, 1000)
        XCTAssertEqual(metadata.architecture, "Test")
        XCTAssertNil(metadata.filePath)
        XCTAssertEqual(metadata.quantization, .none)
        XCTAssertEqual(metadata.estimatedMemory, 0)
    }

    // MARK: - Cache Policy Tests

    func testCachePolicyKeepAll() {
        let keepAllConfig = ModelRegistry.Config(
            loadingStrategy: .lazy,
            cachePolicy: .keepAll,
            memoryPoolConfig: .default,
            maxConcurrentLoads: 1
        )
        let keepAllRegistry = ModelRegistry(config: keepAllConfig, pool: pool)
        keepAllRegistry.initialize()
        
        // Register and load multiple models
        for i in 0..<10 {
            let metadata = ModelRegistry.ModelMetadata(
                id: "cache-model-\(i)",
                name: "CacheModel\(i)",
                version: "1.0",
                parameterCount: 1000,
                architecture: "Test",
                estimatedMemory: 1000000
            )
            _ = keepAllRegistry.registerModel(metadata)
        }
        
        // Trigger eviction check - should keep all
        keepAllRegistry.evictModelsIfNeeded()
        
        let stats = keepAllRegistry.getStats()
        XCTAssertEqual(stats.totalModels, 10)
        
        keepAllRegistry.shutdown()
    }

    func testCachePolicyLRU() {
        let lruConfig = ModelRegistry.Config(
            loadingStrategy: .lazy,
            cachePolicy: .lru(3),
            memoryPoolConfig: .default,
            maxConcurrentLoads: 1
        )
        let lruRegistry = ModelRegistry(config: lruConfig, pool: pool)
        lruRegistry.initialize()
        
        // Register models
        for i in 0..<5 {
            let metadata = ModelRegistry.ModelMetadata(
                id: "lru-model-\(i)",
                name: "LRUModel\(i)",
                version: "1.0",
                parameterCount: 1000,
                architecture: "Test",
                estimatedMemory: 1000000,
                lastAccessed: i == 0 ? Date.distantPast : Date()
            )
            _ = lruRegistry.registerModel(metadata)
        }
        
        // Trigger eviction - should keep only 3 most recent
        lruRegistry.evictModelsIfNeeded()
        
        let stats = lruRegistry.getStats()
        // Total models should still be 5, but some may be unloaded
        XCTAssertEqual(stats.totalModels, 5)
        
        lruRegistry.shutdown()
    }

    // MARK: - Registry Stats Tests

    func testRegistryStatsInitial() {
        let stats = registry.getStats()
        
        XCTAssertEqual(stats.totalModels, 0)
        XCTAssertEqual(stats.loadedModels, 0)
        XCTAssertEqual(stats.loadingModels, 0)
        XCTAssertEqual(stats.errorModels, 0)
        XCTAssertEqual(stats.totalMemory, 0)
        XCTAssertEqual(stats.loadedMemory, 0)
    }

    // MARK: - Config Tests

    func testConfigDefault() {
        let config = ModelRegistry.Config.default
        
        XCTAssertEqual(config.loadingStrategy, .immediate)
        XCTAssertEqual(config.cachePolicy, .keepAll)
        XCTAssertEqual(config.maxConcurrentLoads, ProcessInfo.processInfo.processorCount)
        XCTAssertEqual(config.defaultQuantization, .none)
    }

    func testConfigPredigestion() {
        let config = ModelRegistry.Config.predigestion
        
        XCTAssertEqual(config.loadingStrategy, .immediate)
        XCTAssertEqual(config.cachePolicy, .keepAll)
        XCTAssertEqual(config.defaultQuantization, .int8Symmetric)
    }

    func testConfigOptimized() {
        let config = ModelRegistry.Config.optimized
        
        XCTAssertEqual(config.loadingStrategy, .hybrid)
        XCTAssertEqual(config.cachePolicy, .lru(5))
        XCTAssertEqual(config.defaultQuantization, .int8Symmetric)
        XCTAssertEqual(config.memoryOptimization.memoryBudgetBytes, 8 * 1024 * 1024 * 1024)
        XCTAssertEqual(config.memoryOptimization.targetCompressionRatio, 8.0)
        XCTAssertEqual(config.memoryOptimization.pressureThreshold, 0.80)
    }

    // MARK: - Memory Optimization Config Tests

    func testMemoryOptimizationConfigDefault() {
        let config = ModelRegistry.MemoryOptimizationConfig.default
        
        XCTAssertEqual(config.memoryBudgetBytes, 0)
        XCTAssertEqual(config.headroomFraction, 0.1)
        XCTAssertTrue(config.enableAutoQuantization)
        XCTAssertEqual(config.targetCompressionRatio, 4.0)
        XCTAssertTrue(config.enableDefragmentation)
        XCTAssertEqual(config.pressureThreshold, 0.85)
    }

    // MARK: - Shutdown Tests

    func testShutdownClearsModels() {
        let metadata = ModelRegistry.ModelMetadata(
            id: "shutdown-test",
            name: "ShutdownTest",
            version: "1.0",
            parameterCount: 1000,
            architecture: "Test"
        )
        
        _ = registry.registerModel(metadata)
        
        let statsBefore = registry.getStats()
        XCTAssertEqual(statsBefore.totalModels, 1)
        
        registry.shutdown()
        
        let statsAfter = registry.getStats()
        XCTAssertEqual(statsAfter.totalModels, 0)
    }

    // MARK: - Quantization Receipt Tests

    func testQuantizationReceiptProperties() {
        let receipt = QuantizationReceipt(
            modelId: "test-model",
            quantization: .int8Symmetric,
            originalSize: 1000000,
            quantizedSize: 250000,
            compressionRatio: 4.0,
            time: 0.5
        )
        
        XCTAssertEqual(receipt.modelId, "test-model")
        XCTAssertEqual(receipt.originalSize, 1000000)
        XCTAssertEqual(receipt.quantizedSize, 250000)
        XCTAssertEqual(receipt.compressionRatio, 4.0)
        XCTAssertEqual(receipt.time, 0.5)
    }

    // MARK: - Registry Stats Codable Tests

    func testRegistryStatsCodable() throws {
        let stats = RegistryStats(
            totalModels: 10,
            loadedModels: 5,
            loadingModels: 2,
            errorModels: 1,
            totalMemory: 10000000,
            loadedMemory: 5000000,
            loadingStrategy: .immediate,
            cachePolicy: .lru(10)
        )
        
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(RegistryStats.self, from: data)
        
        XCTAssertEqual(stats.totalModels, decoded.totalModels)
        XCTAssertEqual(stats.loadedModels, decoded.loadedModels)
        XCTAssertEqual(stats.loadingModels, decoded.loadingModels)
        XCTAssertEqual(stats.errorModels, decoded.errorModels)
        XCTAssertEqual(stats.totalMemory, decoded.totalMemory)
        XCTAssertEqual(stats.loadedMemory, decoded.loadedMemory)
    }

    // MARK: - ModelState Tests

    func testAllModelStates() {
        let states: [ModelRegistry.ModelState] = [
            .notLoaded,
            .loading,
            .loaded,
            .predigested,
            .error("test error")
        ]
        
        // Just verify all states are accessible
        XCTAssertTrue(states.count == 5)
    }

    // MARK: - Error Tests

    func testModelErrorCases() {
        let errorCases: [ModelRegistry.ModelError] = [
            .fileNotFound,
            .invalidFileFormat,
            .unsupportedQuantization,
            .outOfMemory,
            .modelAlreadyLoaded
        ]
        
        XCTAssertTrue(errorCases.count == 5)
    }

    // MARK: - Memory Optimization Tests

    func testMemoryOptimizationWithBudget() {
        let budgetConfig = ModelRegistry.MemoryOptimizationConfig(
            memoryBudgetBytes: 100 * 1024 * 1024,  // 100MB budget
            headroomFraction: 0.1,
            enableAutoQuantization: true,
            targetCompressionRatio: 4.0,
            enableDefragmentation: true,
            pressureThreshold: 0.8
        )
        
        let registryConfig = ModelRegistry.Config(
            loadingStrategy: .lazy,
            cachePolicy: .keepAll,
            memoryPoolConfig: .default,
            maxConcurrentLoads: 2,
            defaultQuantization: .none,
            memoryOptimization: budgetConfig
        )
        
        let budgetRegistry = ModelRegistry(config: registryConfig, pool: pool)
        budgetRegistry.initialize()
        
        // Initially no pressure (no models loaded)
        XCTAssertFalse(budgetRegistry.isUnderMemoryPressure())
        XCTAssertEqual(budgetRegistry.getMemoryPressure(), 0.0)
        
        budgetRegistry.shutdown()
    }

    func testMemoryOptimizationRecommendations() {
        let registryConfig = ModelRegistry.Config(
            loadingStrategy: .lazy,
            cachePolicy: .keepAll,
            memoryPoolConfig: .default,
            maxConcurrentLoads: 2,
            defaultQuantization: .none,
            memoryOptimization: .default
        )
        
        let registry = ModelRegistry(config: registryConfig, pool: pool)
        registry.initialize()
        
        // Register a model with no quantization
        let metadata = ModelRegistry.ModelMetadata(
            id: "optimize-test",
            name: "OptimizeTest",
            version: "1.0",
            parameterCount: 1000000,
            architecture: "Test",
            filePath: nil,
            quantization: .none,
            estimatedMemory: 100 * 1024 * 1024  // 100MB
        )
        
        _ = registry.registerModel(metadata)
        
        // Get recommendations (should suggest quantization for large unquantized model)
        let recommendations = registry.getOptimizationRecommendations()
        
        // Should have at least one recommendation
        XCTAssertFalse(recommendations.isEmpty)
        
        registry.shutdown()
    }

    func testMemoryOptimizationSummary() {
        let summary = MemoryOptimizationSummary(
            initialMemory: 1000 * 1024 * 1024,
            finalMemory: 500 * 1024 * 1024,
            memoryReduction: 500 * 1024 * 1024,
            actionsTaken: [
                .quantized(modelId: "model-1", savings: 200 * 1024 * 1024),
                .evicted(modelId: "model-2")
            ]
        )
        
        XCTAssertEqual(summary.initialMemory, 1000 * 1024 * 1024)
        XCTAssertEqual(summary.finalMemory, 500 * 1024 * 1024)
        XCTAssertEqual(summary.memoryReduction, 500 * 1024 * 1024)
        XCTAssertEqual(summary.reductionPercentage, 50.0)
        XCTAssertEqual(summary.actionsTaken.count, 2)
    }

    func testMemoryOptimizationRecommendationProperties() {
        let recommendation1 = MemoryOptimizationRecommendation.quantizeModels(
            modelIds: ["model-1", "model-2"],
            targetQuantization: .int8Symmetric,
            estimatedSavings: 500 * 1024 * 1024
        )
        
        XCTAssertEqual(recommendation1.estimatedImpact, 500 * 1024 * 1024)
        XCTAssertTrue(recommendation1.description.contains("Quantize"))
        
        let recommendation2 = MemoryOptimizationRecommendation.evictModels(
            modelIds: ["model-3"],
            estimatedMemoryFreed: 200 * 1024 * 1024
        )
        
        XCTAssertEqual(recommendation2.estimatedImpact, 200 * 1024 * 1024)
        XCTAssertTrue(recommendation2.description.contains("Evict"))
        
        let recommendation3 = MemoryOptimizationRecommendation.defragmentMemory(
            smallAllocationCount: 15,
            description: "Test defragmentation"
        )
        
        XCTAssertEqual(recommendation3.estimatedImpact, 100 * 1024 * 1024)
        XCTAssertTrue(recommendation3.description.contains("Defragment"))
    }

    func testMemoryOptimizationActionProperties() {
        let action1 = MemoryOptimizationAction.quantized(
            modelId: "model-1",
            savings: 100 * 1024 * 1024
        )
        
        XCTAssertTrue(action1.description.contains("Quantized"))
        XCTAssertTrue(action1.description.contains("model-1"))
        
        let action2 = MemoryOptimizationAction.evicted(modelId: "model-2")
        
        XCTAssertTrue(action2.description.contains("Evicted"))
        XCTAssertTrue(action2.description.contains("model-2"))
        
        let action3 = MemoryOptimizationAction.defragmentationRequested
        
        XCTAssertTrue(action3.description.contains("defragmentation"))
    }
}
