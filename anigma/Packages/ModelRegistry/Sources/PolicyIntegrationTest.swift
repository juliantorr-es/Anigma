//
//  PolicyIntegrationTest.swift
//  ModelRegistry
//
//  Test integration of workload-specific lowering policies.
//

import Foundation

/// Test the integration of perception, prefill, and embedding policies
public struct PolicyIntegrationTest {
    public static func runAllTests() async throws {
        print("=== Policy Integration Tests ===")
        
        // Test PerceptionLoweringPolicy
        try await testPerceptionPolicy()
        
        // Test PrefillLoweringPolicy
        try await testPrefillPolicy()
        
        // Test EmbeddingsLoweringPolicy
        try await testEmbeddingsPolicy()
        
        print("=== All Policy Tests Passed ===")
    }
    
    private static func testPerceptionPolicy() async throws {
        print("Testing PerceptionLoweringPolicy...")
        
        let policy = PerceptionLoweringPolicy(
            resolutionVariants: [
                Resolution(width: 224, height: 224),
                Resolution(width: 512, height: 512)
            ],
            coordinateSystem: .pixel,
            preserveAspectRatio: true
        )
        
        // Test brick generation
        let constraints = InputConstraints(
            minWidth: 1,
            maxWidth: 1024,
            minHeight: 1,
            maxHeight: 1024,
            minBatchSize: 1,
            maxBatchSize: 8
        )
        
        let bricks = try policy.generateBricks(
            inputConstraints: constraints,
            memoryBudgetMB: 2048
        )
        
        assert(!bricks.isEmpty, "Should generate bricks")
        assert(bricks.count == 2, "Should generate 2 bricks for 2 resolutions")
        
        for brick in bricks {
            assert(brick.workloadCategory == .perception, "Brick should be perception category")
            assert(brick.memoryBudgetMB > 0, "Brick should have memory budget")
        }
        
        print("  ✓ Perception policy test passed")
    }
    
    private static func testPrefillPolicy() async throws {
        print("Testing PrefillLoweringPolicy...")
        
        let policy = PrefillLoweringPolicy(
            chunkSizes: [128, 256, 512],
            kvCacheConfig: KVCacheConfig(
                enabled: true,
                maxTokens: 4096
            ),
            enableFlashAttention: true,
            enableRotaryEmbeddings: true
        )
        
        // Test brick generation
        let constraints = InputConstraints(
            minSequenceLength: 1,
            maxSequenceLength: 1024,
            minBatchSize: 1,
            maxBatchSize: 4
        )
        
        let bricks = try policy.generateBricks(
            inputConstraints: constraints,
            memoryBudgetMB: 4096
        )
        
        assert(!bricks.isEmpty, "Should generate bricks")
        
        for brick in bricks {
            assert(brick.workloadCategory == .prefill, "Brick should be prefill category")
            assert(brick.metadata["kv_cache_enabled"] == "true", "Should have KV cache enabled")
            assert(brick.metadata["flash_attention"] == "true", "Should have flash attention")
        }
        
        print("  ✓ Prefill policy test passed")
    }
    
    private static func testEmbeddingsPolicy() async throws {
        print("Testing EmbeddingsLoweringPolicy...")
        
        let policy = EmbeddingsLoweringPolicy(
            poolingStrategy: .mean,
            normalizeEmbeddings: true,
            embeddingDimension: 768,
            quantizeEmbeddings: false
        )
        
        // Test brick generation
        let constraints = InputConstraints(
            minSequenceLength: 1,
            maxSequenceLength: 512,
            minBatchSize: 1,
            maxBatchSize: 16
        )
        
        let bricks = try policy.generateBricks(
            inputConstraints: constraints,
            memoryBudgetMB: 1024
        )
        
        assert(!bricks.isEmpty, "Should generate bricks")
        
        for brick in bricks {
            assert(brick.workloadCategory == .embeddings, "Brick should be embeddings category")
            assert(brick.metadata["pooling_strategy"] == "mean", "Should use mean pooling")
            assert(brick.metadata["normalize_embeddings"] == "true", "Should normalize embeddings")
        }
        
        print("  ✓ Embeddings policy test passed")
    }
    
    private static func testPipelineIntegration() async throws {
        print("Testing Pipeline Integration...")
        
        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("model_lowering_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Create pipeline
        let pipeline = ModelLoweringPipeline(workDir: tempDir)
        
        // Test with perception policy
        let perceptionPolicy = PerceptionLoweringPolicy()
        let perceptionConstraints = InputConstraints(
            minWidth: 1,
            maxWidth: 1024,
            minHeight: 1,
            maxHeight: 1024,
            minBatchSize: 1,
            maxBatchSize: 4
        )
        
        // Note: This would require an actual model file to test fully
        // For now, just verify the API compiles
        print("  ✓ Pipeline integration API compiles")
    }
}

// Helper for testing
private func assert(_ condition: Bool, _ message: String) {
    if !condition {
        fatalError("Assertion failed: \(message)")
    }
}