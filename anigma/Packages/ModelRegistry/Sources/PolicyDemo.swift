//
//  PolicyDemo.swift
//  ModelRegistry
//
//  Demo showing usage of workload-specific lowering policies.
//

import Foundation

/// Demo for workload-specific lowering policies
public struct PolicyDemo {
    public static func run() async throws {
        print("=== Workload-Specific Lowering Policy Demo ===\n")
        
        // Create a temporary directory for demo
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("policy_demo_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // 1. Perception Policy Demo
        print("1. Perception Model Policy")
        print("   -----------------------")
        let perceptionPolicy = PerceptionLoweringPolicy(
            resolutionVariants: [
                Resolution(width: 224, height: 224),
                Resolution(width: 384, height: 384),
                Resolution(width: 512, height: 512)
            ],
            coordinateSystem: .pixel,
            preserveAspectRatio: true,
            paddingStrategy: .zero,
            colorSpaceConversion: .rgbToBgr,
            documentOptions: DocumentProcessingOptions(
                orientationHandling: .autoDetect,
                enableTextDetection: true
            )
        )
        
        let perceptionConstraints = InputConstraints(
            minWidth: 1,
            maxWidth: 1024,
            minHeight: 1,
            maxHeight: 1024,
            minBatchSize: 1,
            maxBatchSize: 8,
            minChannels: 3,
            maxChannels: 3
        )
        
        let perceptionBricks = try perceptionPolicy.generateBricks(
            inputConstraints: perceptionConstraints,
            memoryBudgetMB: 2048
        )
        
        print("   Generated \(perceptionBricks.count) bricks:")
        for brick in perceptionBricks {
            print("   - \(brick.id): \(brick.inputConstraints.maxWidth)x\(brick.inputConstraints.maxHeight), \(brick.memoryBudgetMB)MB")
        }
        print()
        
        // 2. Prefill Policy Demo
        print("2. Prefill Model Policy")
        print("   --------------------")
        let prefillPolicy = PrefillLoweringPolicy(
            chunkSizes: [256, 512, 1024, 2048],
            kvCacheConfig: KVCacheConfig(
                enabled: true,
                strategy: .static,
                maxTokens: 4096,
                compressionEnabled: true,
                compressionRatio: 0.5
            ),
            enableSlidingWindow: true,
            slidingWindowSize: 4096,
            enableRotaryEmbeddings: true,
            rotaryEmbeddingDim: 128,
            enableFlashAttention: true,
            enableChunkedPrefill: true,
            maxChunkSize: 1024
        )
        
        let prefillConstraints = InputConstraints.sequenceConstraints(
            minLength: 1,
            maxLength: 4096,
            minBatchSize: 1,
            maxBatchSize: 4
        )
        
        let prefillBricks = try prefillPolicy.generateBricks(
            inputConstraints: prefillConstraints,
            memoryBudgetMB: 8192
        )
        
        print("   Generated \(prefillBricks.count) bricks:")
        for brick in prefillBricks {
            print("   - \(brick.id): max \(brick.inputConstraints.maxSequenceLength) tokens, \(brick.memoryBudgetMB)MB")
            print("     KV Cache: \(brick.metadata["kv_cache_enabled"] ?? "false")")
            print("     Flash Attention: \(brick.metadata["flash_attention"] ?? "false")")
        }
        print()
        
        // 3. Embeddings Policy Demo
        print("3. Embeddings Model Policy")
        print("   -----------------------")
        let embeddingsPolicy = EmbeddingsLoweringPolicy(
            poolingStrategy: .mean,
            normalizeEmbeddings: true,
            dynamicSequenceLength: true,
            enableMeanPooling: true,
            enableCLSPooling: true,
            embeddingDimension: 768,
            quantizeEmbeddings: true,
            quantizationBits: 8
        )
        
        let embeddingsConstraints = InputConstraints.sequenceConstraints(
            minLength: 1,
            maxLength: 512,
            minBatchSize: 1,
            maxBatchSize: 32
        )
        
        let embeddingsBricks = try embeddingsPolicy.generateBricks(
            inputConstraints: embeddingsConstraints,
            memoryBudgetMB: 1024
        )
        
        print("   Generated \(embeddingsBricks.count) bricks:")
        for brick in embeddingsBricks {
            print("   - \(brick.id): max \(brick.inputConstraints.maxWidth) tokens, \(brick.memoryBudgetMB)MB")
            print("     Pooling: \(brick.metadata["pooling_strategy"] ?? "none")")
            print("     Quantized: \(brick.metadata["quantize_embeddings"] ?? "false")")
        }
        print()
        
        // 4. Pipeline Integration Demo
        print("4. Pipeline Integration")
        print("   --------------------")
        let pipeline = ModelLoweringPipeline(workDir: tempDir)
        
        print("   Pipeline created with work directory: \(tempDir.path)")
        print("   Supports workload-specific policies via:")
        print("   - applyLowering(modelPath:policy:)")
        print("   - applyLoweringWithTransformations(modelPath:policy:)")
        print("   - generateBricks(modelPath:policy:inputConstraints:memoryBudgetMB:)")
        print()
        
        // 5. Dynamic Brick Generation Summary
        print("5. Dynamic Brick Generation Summary")
        print("   --------------------------------")
        let totalBricks = perceptionBricks.count + prefillBricks.count + embeddingsBricks.count
        print("   Total bricks generated: \(totalBricks)")
        print("   - Perception: \(perceptionBricks.count) bricks")
        print("   - Prefill: \(prefillBricks.count) bricks")
        print("   - Embeddings: \(embeddingsBricks.count) bricks")
        print()
        
        print("   Brick generation considers:")
        print("   - Input constraints (resolution, sequence length, batch size)")
        print("   - Memory budget constraints")
        print("   - Workload-specific optimizations")
        print("   - Platform capabilities")
        print()
        
        print("=== Demo Complete ===")
    }
    
    /// Example of using policies with actual model files
    public static func exampleUsage() {
        print("\n=== Example Usage ===\n")
        
        print("""
        // 1. Create a policy for your workload
        let policy = PerceptionLoweringPolicy(
            resolutionVariants: [Resolution(width: 224, height: 224)],
            coordinateSystem: .pixel
        )
        
        // 2. Create the lowering pipeline
        let pipeline = ModelLoweringPipeline(workDir: temporaryDirectory)
        
        // 3. Generate bricks for your model
        let constraints = InputConstraints(
            minWidth: 1,
            maxWidth: 1024,
            minHeight: 1,
            maxHeight: 1024,
            minBatchSize: 1,
            maxBatchSize: 4
        )
        
        let bricks = try await pipeline.generateBricks(
            modelPath: "path/to/model.pt",
            policy: policy,
            inputConstraints: constraints,
            memoryBudgetMB: 2048
        )
        
        // 4. Apply lowering with the policy
        let result = try await pipeline.applyLoweringWithTransformations(
            modelPath: "path/to/model.pt",
            policy: policy
        )
        
        // 5. Use the lowered model
        print("Lowered model saved to: \\(result.outputPath)")
        """)
    }
}