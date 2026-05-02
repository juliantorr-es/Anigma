//
//  PrefillLoweringPolicy.swift
//  ModelRegistry
//
//  Policy for transformer prefill workloads with chunk sizes
//  and stateful KV cache support.
//

import Foundation

/// Policy for transformer prefill workloads
public struct PrefillLoweringPolicy: LoweringPolicyProtocol {
    /// Workload category this policy applies to
    public let workloadCategory: WorkloadCategory = .prefill
    
    /// Base policy configuration
    public let basePolicy: LoweringPolicy
    
    /// Supported chunk sizes for dynamic brick generation
    public let chunkSizes: [Int]
    
    /// KV cache configuration
    public let kvCacheConfig: KVCacheConfig
    
    /// Whether to enable sliding window attention
    public let enableSlidingWindow: Bool
    
    /// Window size for sliding window attention
    public let slidingWindowSize: Int?
    
    /// Whether to enable rotary position embeddings
    public let enableRotaryEmbeddings: Bool
    
    /// Rotary embedding dimension
    public let rotaryEmbeddingDim: Int?
    
    /// Whether to enable ALiBi (Attention with Linear Biases)
    public let enableALiBi: Bool
    
    /// Whether to enable flash attention optimization
    public let enableFlashAttention: Bool
    
    /// Whether to enable memory-efficient attention
    public let enableMemoryEfficientAttention: Bool
    
    /// Whether to enable chunked prefill for long sequences
    public let enableChunkedPrefill: Bool
    
    /// Maximum chunk size for chunked prefill
    public let maxChunkSize: Int?
    
    public init(
        basePolicy: LoweringPolicy? = nil,
        chunkSizes: [Int] = [64, 128, 256, 512, 1024, 2048, 4096],
        kvCacheConfig: KVCacheConfig = KVCacheConfig(),
        enableSlidingWindow: Bool = false,
        slidingWindowSize: Int? = 4096,
        enableRotaryEmbeddings: Bool = true,
        rotaryEmbeddingDim: Int? = 128,
        enableALiBi: Bool = false,
        enableFlashAttention: Bool = true,
        enableMemoryEfficientAttention: Bool = false,
        enableChunkedPrefill: Bool = true,
        maxChunkSize: Int? = 1024
    ) {
        self.basePolicy = basePolicy ?? LoweringPolicy.default(for: .prefill)
        self.chunkSizes = chunkSizes
        self.kvCacheConfig = kvCacheConfig
        self.enableSlidingWindow = enableSlidingWindow
        self.slidingWindowSize = slidingWindowSize
        self.enableRotaryEmbeddings = enableRotaryEmbeddings
        self.rotaryEmbeddingDim = rotaryEmbeddingDim
        self.enableALiBi = enableALiBi
        self.enableFlashAttention = enableFlashAttention
        self.enableMemoryEfficientAttention = enableMemoryEfficientAttention
        self.enableChunkedPrefill = enableChunkedPrefill
        self.maxChunkSize = maxChunkSize
    }
    
    /// Generate dynamic bricks based on input sizes and constraints
    public func generateBricks(
        inputConstraints: InputConstraints,
        memoryBudgetMB: Int? = nil
    ) throws -> [ModelBrick] {
        var bricks: [ModelBrick] = []
        
        // Generate bricks for each chunk size
        for chunkSize in chunkSizes {
            // Check if chunk size fits within constraints
            guard chunkSize <= inputConstraints.maxWidth else {
                continue
            }
            
            // Calculate memory usage for this chunk size
            let estimatedMemory = estimateMemoryUsage(
                sequenceLength: chunkSize,
                batchSize: inputConstraints.maxBatchSize,
                kvCacheConfig: kvCacheConfig
            )
            
            // Check memory budget if specified
            if let budget = memoryBudgetMB, estimatedMemory > budget {
                continue
            }
            
            let brick = ModelBrick(
                id: "prefill_\(chunkSize)_tokens",
                workloadCategory: .prefill,
                inputConstraints: InputConstraints.sequenceConstraints(
                    minLength: 1,
                    maxLength: chunkSize,
                    minBatchSize: 1,
                    maxBatchSize: inputConstraints.maxBatchSize
                ),
                memoryBudgetMB: estimatedMemory,
                precision: basePolicy.precision,
                attentionStyle: basePolicy.attentionStyle,
                normalizationType: basePolicy.normalizationType,
                metadata: [
                    "chunk_size": String(chunkSize),
                    "kv_cache_enabled": String(kvCacheConfig.enabled),
                    "kv_cache_strategy": kvCacheConfig.strategy.rawValue,
                    "sliding_window": String(enableSlidingWindow),
                    "sliding_window_size": slidingWindowSize.map(String.init) ?? "none",
                    "rotary_embeddings": String(enableRotaryEmbeddings),
                    "rotary_dim": rotaryEmbeddingDim.map(String.init) ?? "none",
                    "alibi": String(enableALiBi),
                    "flash_attention": String(enableFlashAttention),
                    "memory_efficient_attention": String(enableMemoryEfficientAttention),
                    "chunked_prefill": String(enableChunkedPrefill),
                    "max_chunk_size": maxChunkSize.map(String.init) ?? "none"
                ]
            )
            
            bricks.append(brick)
        }
        
        // If no bricks were generated, create a fallback brick with smallest chunk size
        if bricks.isEmpty, let smallestChunkSize = chunkSizes.first {
            let brick = ModelBrick(
                id: "prefill_fallback_\(smallestChunkSize)_tokens",
                workloadCategory: .prefill,
                inputConstraints: InputConstraints.sequenceConstraints(
                    minLength: 1,
                    maxLength: smallestChunkSize,
                    minBatchSize: 1,
                    maxBatchSize: 1
                ),
                memoryBudgetMB: estimateMemoryUsage(
                    sequenceLength: smallestChunkSize,
                    batchSize: 1,
                    kvCacheConfig: KVCacheConfig(enabled: false)
                ),
                precision: basePolicy.precision,
                attentionStyle: basePolicy.attentionStyle,
                normalizationType: basePolicy.normalizationType,
                metadata: [
                    "chunk_size": String(smallestChunkSize),
                    "kv_cache_enabled": "false",
                    "fallback": "true"
                ]
            )
            
            bricks.append(brick)
        }
        
        return bricks
    }
    
    /// Apply policy-specific transformations during lowering
    public func applyTransformations(
        to ir: ModelIR,
        stage: LoweringStage,
        outputDir: URL
    ) async throws -> ModelIR {
        var transformedIR = ir
        
        switch stage {
        case .canonicalization:
            // Apply prefill-specific canonicalization
            transformedIR.metadata["prefill_canonicalized"] = "true"
            transformedIR.metadata["attention_optimized"] = "true"
            
            if enableFlashAttention {
                transformedIR.metadata["flash_attention"] = "true"
            }
            
            if enableMemoryEfficientAttention {
                transformedIR.metadata["memory_efficient_attention"] = "true"
            }
            
            if enableRotaryEmbeddings, let dim = rotaryEmbeddingDim {
                transformedIR.metadata["rotary_embeddings"] = "true"
                transformedIR.metadata["rotary_dim"] = String(dim)
            }
            
            if enableALiBi {
                transformedIR.metadata["alibi"] = "true"
            }
            
        case .shapeDiscipline:
            // Apply shape constraints for prefill models
            transformedIR.metadata["prefill_shape_discipline"] = "true"
            transformedIR.metadata["kv_cache_enabled"] = String(kvCacheConfig.enabled)
            
            if kvCacheConfig.enabled {
                transformedIR.metadata["kv_cache_strategy"] = kvCacheConfig.strategy.rawValue
                transformedIR.metadata["kv_cache_max_tokens"] = String(kvCacheConfig.maxTokens)
                
                if kvCacheConfig.compressionEnabled {
                    transformedIR.metadata["kv_cache_compression"] = "true"
                    transformedIR.metadata["kv_cache_compression_ratio"] = String(kvCacheConfig.compressionRatio)
                }
            }
            
            if enableSlidingWindow, let windowSize = slidingWindowSize {
                transformedIR.metadata["sliding_window"] = "true"
                transformedIR.metadata["sliding_window_size"] = String(windowSize)
            }
            
            if enableChunkedPrefill, let maxChunk = maxChunkSize {
                transformedIR.metadata["chunked_prefill"] = "true"
                transformedIR.metadata["max_chunk_size"] = String(maxChunk)
            }
            
        case .loweringPasses:
            // Apply attention optimizations
            if enableFlashAttention {
                transformedIR.metadata["flash_attention_applied"] = "true"
            }
            
            if enableMemoryEfficientAttention {
                transformedIR.metadata["memory_efficient_attention_applied"] = "true"
            }
            
            // Apply KV cache optimizations
            if kvCacheConfig.enabled {
                transformedIR.metadata["kv_cache_optimized"] = "true"
                
                if kvCacheConfig.prefillOptimization {
                    transformedIR.metadata["kv_cache_prefill_optimized"] = "true"
                }
            }
            
        default:
            // Use base policy for other stages
            break
        }
        
        return transformedIR
    }
    
    /// Estimate memory usage for a given sequence length and batch size
    private func estimateMemoryUsage(
        sequenceLength: Int,
        batchSize: Int,
        kvCacheConfig: KVCacheConfig
    ) -> Int {
        // Simplified memory estimation for transformer models
        let hiddenSize = 4096 // Typical hidden size
        let numLayers = 32 // Typical number of layers
        let numHeads = 32 // Typical number of attention heads
        let headDim = 128 // Typical head dimension
        
        // Base memory for model weights (simplified)
        let weightsMemoryMB = 7000 // ~7GB for typical 7B model
        
        // Activation memory for forward pass
        let activationMemory = sequenceLength * batchSize * hiddenSize * 2 // 2 bytes per element for fp16
        
        // KV cache memory if enabled
        var kvCacheMemory = 0
        if kvCacheConfig.enabled {
            // Memory for K and V matrices: 2 * layers * batch * seq_len * heads * head_dim
            kvCacheMemory = 2 * numLayers * batchSize * sequenceLength * numHeads * headDim * 2 // fp16
            
            if kvCacheConfig.compressionEnabled {
                kvCacheMemory = Int(Double(kvCacheMemory) * kvCacheConfig.compressionRatio)
            }
        }
        
        let totalMemoryBytes = weightsMemoryMB * 1024 * 1024 + activationMemory + kvCacheMemory
        return totalMemoryBytes / (1024 * 1024) // Convert to MB
    }
}

/// KV cache configuration for transformer models
public struct KVCacheConfig: Codable, Sendable {
    /// Whether KV cache is enabled
    public let enabled: Bool
    
    /// KV cache strategy
    public let strategy: KVCacheStrategy
    
    /// Maximum tokens in KV cache
    public let maxTokens: Int
    
    /// Whether compression is enabled
    public let compressionEnabled: Bool
    
    /// Compression ratio (0.0 to 1.0)
    public let compressionRatio: Double
    
    /// Whether to optimize for prefill phase
    public let prefillOptimization: Bool
    
    /// Whether to enable incremental updates
    public let incrementalUpdates: Bool
    
    public init(
        enabled: Bool = true,
        strategy: KVCacheStrategy = .static,
        maxTokens: Int = 4096,
        compressionEnabled: Bool = false,
        compressionRatio: Double = 0.5,
        prefillOptimization: Bool = true,
        incrementalUpdates: Bool = true
    ) {
        self.enabled = enabled
        self.strategy = strategy
        self.maxTokens = maxTokens
        self.compressionEnabled = compressionEnabled
        self.compressionRatio = compressionRatio
        self.prefillOptimization = prefillOptimization
        self.incrementalUpdates = incrementalUpdates
    }
}

/// KV cache strategies
public enum KVCacheStrategy: String, Codable, Sendable {
    /// Static KV cache with fixed size
    case `static` = "static"
    
    /// Dynamic KV cache that grows as needed
    case dynamic = "dynamic"
    
    /// Windowed KV cache with sliding window
    case windowed = "windowed"
    
    /// Chunked KV cache for long sequences
    case chunked = "chunked"
}

// Convenience initializer for sequence-based models
extension InputConstraints {
    public static func sequenceConstraints(
        minLength: Int,
        maxLength: Int,
        minBatchSize: Int,
        maxBatchSize: Int
    ) -> InputConstraints {
        return InputConstraints(
            minWidth: minLength,
            maxWidth: maxLength,
            minHeight: 1,
            maxHeight: 1,
            minBatchSize: minBatchSize,
            maxBatchSize: maxBatchSize,
            minChannels: 1,
            maxChannels: 1
        )
    }
}

