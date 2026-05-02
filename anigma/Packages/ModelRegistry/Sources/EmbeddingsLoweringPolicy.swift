//
//  EmbeddingsLoweringPolicy.swift
//  ModelRegistry
//
//  Policy for embedding models with pooling strategies and normalization.
//

import Foundation

/// Policy for embedding models
public struct EmbeddingsLoweringPolicy: LoweringPolicyProtocol {
    /// Workload category this policy applies to
    public let workloadCategory: WorkloadCategory = .embeddings
    
    /// Base policy configuration
    public let basePolicy: LoweringPolicy
    
    /// Pooling strategy for generating embeddings
    public let poolingStrategy: PoolingStrategy
    
    /// Whether to apply L2 normalization to embeddings
    public let normalizeEmbeddings: Bool
    
    /// Whether to enable dynamic sequence lengths
    public let dynamicSequenceLength: Bool
    
    /// Whether to enable mean pooling
    public let enableMeanPooling: Bool
    
    /// Whether to enable max pooling
    public let enableMaxPooling: Bool
    
    /// Whether to enable CLS token pooling
    public let enableCLSPooling: Bool
    
    /// Whether to enable attention pooling
    public let enableAttentionPooling: Bool
    
    /// Dimensionality of output embeddings
    public let embeddingDimension: Int?
    
    /// Whether to enable quantization of embeddings
    public let quantizeEmbeddings: Bool
    
    /// Quantization bits for embeddings
    public let quantizationBits: Int?
    
    public init(
        basePolicy: LoweringPolicy? = nil,
        poolingStrategy: PoolingStrategy = .mean,
        normalizeEmbeddings: Bool = true,
        dynamicSequenceLength: Bool = true,
        enableMeanPooling: Bool = true,
        enableMaxPooling: Bool = false,
        enableCLSPooling: Bool = true,
        enableAttentionPooling: Bool = false,
        embeddingDimension: Int? = 768,
        quantizeEmbeddings: Bool = false,
        quantizationBits: Int? = 8
    ) {
        self.basePolicy = basePolicy ?? LoweringPolicy.default(for: .embeddings)
        self.poolingStrategy = poolingStrategy
        self.normalizeEmbeddings = normalizeEmbeddings
        self.dynamicSequenceLength = dynamicSequenceLength
        self.enableMeanPooling = enableMeanPooling
        self.enableMaxPooling = enableMaxPooling
        self.enableCLSPooling = enableCLSPooling
        self.enableAttentionPooling = enableAttentionPooling
        self.embeddingDimension = embeddingDimension
        self.quantizeEmbeddings = quantizeEmbeddings
        self.quantizationBits = quantizationBits
    }
    
    /// Generate dynamic bricks based on input sizes and constraints
    public func generateBricks(
        inputConstraints: InputConstraints,
        memoryBudgetMB: Int? = nil
    ) throws -> [ModelBrick] {
        var bricks: [ModelBrick] = []
        
        // Define sequence length variants for embedding models
        let sequenceLengths = [64, 128, 256, 512, 1024]
        
        // Generate bricks for each sequence length
        for seqLen in sequenceLengths {
            // Check if sequence length fits within constraints
            guard seqLen <= inputConstraints.maxWidth else {
                continue
            }
            
            // Calculate memory usage for this sequence length
            let estimatedMemory = estimateMemoryUsage(
                sequenceLength: seqLen,
                batchSize: inputConstraints.maxBatchSize,
                embeddingDimension: embeddingDimension ?? 768
            )
            
            // Check memory budget if specified
            if let budget = memoryBudgetMB, estimatedMemory > budget {
                continue
            }
            
            let brick = ModelBrick(
                id: "embeddings_\(seqLen)_seqlen",
                workloadCategory: .embeddings,
                inputConstraints: InputConstraints.sequenceConstraints(
                    minLength: 1,
                    maxLength: seqLen,
                    minBatchSize: 1,
                    maxBatchSize: inputConstraints.maxBatchSize
                ),
                memoryBudgetMB: estimatedMemory,
                precision: basePolicy.precision,
                attentionStyle: basePolicy.attentionStyle,
                normalizationType: basePolicy.normalizationType,
                metadata: [
                    "max_sequence_length": String(seqLen),
                    "pooling_strategy": poolingStrategy.rawValue,
                    "normalize_embeddings": String(normalizeEmbeddings),
                    "dynamic_sequence_length": String(dynamicSequenceLength),
                    "embedding_dimension": embeddingDimension.map(String.init) ?? "auto",
                    "quantize_embeddings": String(quantizeEmbeddings),
                    "quantization_bits": quantizationBits.map(String.init) ?? "none",
                    "mean_pooling": String(enableMeanPooling),
                    "max_pooling": String(enableMaxPooling),
                    "cls_pooling": String(enableCLSPooling),
                    "attention_pooling": String(enableAttentionPooling)
                ]
            )
            
            bricks.append(brick)
        }
        
        // If no bricks were generated, create a fallback brick
        if bricks.isEmpty {
            let brick = ModelBrick(
                id: "embeddings_fallback_128",
                workloadCategory: .embeddings,
                inputConstraints: InputConstraints.sequenceConstraints(
                    minLength: 1,
                    maxLength: 128,
                    minBatchSize: 1,
                    maxBatchSize: 1
                ),
                memoryBudgetMB: estimateMemoryUsage(
                    sequenceLength: 128,
                    batchSize: 1,
                    embeddingDimension: embeddingDimension ?? 768
                ),
                precision: basePolicy.precision,
                attentionStyle: basePolicy.attentionStyle,
                normalizationType: basePolicy.normalizationType,
                metadata: [
                    "max_sequence_length": "128",
                    "pooling_strategy": poolingStrategy.rawValue,
                    "normalize_embeddings": String(normalizeEmbeddings),
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
            // Apply embeddings-specific canonicalization
            transformedIR.metadata["embeddings_canonicalized"] = "true"
            transformedIR.metadata["pooling_strategy"] = poolingStrategy.rawValue
            transformedIR.metadata["normalize_embeddings"] = String(normalizeEmbeddings)
            
            if let dim = embeddingDimension {
                transformedIR.metadata["embedding_dimension"] = String(dim)
            }
            
        case .shapeDiscipline:
            // Apply shape constraints for embedding models
            transformedIR.metadata["embeddings_shape_discipline"] = "true"
            transformedIR.metadata["dynamic_sequence_length"] = String(dynamicSequenceLength)
            
            // Configure pooling options
            if enableMeanPooling {
                transformedIR.metadata["mean_pooling_enabled"] = "true"
            }
            
            if enableMaxPooling {
                transformedIR.metadata["max_pooling_enabled"] = "true"
            }
            
            if enableCLSPooling {
                transformedIR.metadata["cls_pooling_enabled"] = "true"
            }
            
            if enableAttentionPooling {
                transformedIR.metadata["attention_pooling_enabled"] = "true"
            }
            
        case .loweringPasses:
            // Apply pooling optimizations
            transformedIR.metadata["pooling_optimized"] = "true"
            
            // Apply quantization if enabled
            if quantizeEmbeddings, let bits = quantizationBits {
                transformedIR.metadata["embeddings_quantized"] = "true"
                transformedIR.metadata["quantization_bits"] = String(bits)
            }
            
            // Apply normalization if enabled
            if normalizeEmbeddings {
                transformedIR.metadata["normalization_applied"] = "true"
            }
            
        default:
            // Use base policy for other stages
            break
        }
        
        return transformedIR
    }
    
    /// Estimate memory usage for embedding models
    private func estimateMemoryUsage(
        sequenceLength: Int,
        batchSize: Int,
        embeddingDimension: Int
    ) -> Int {
        // Simplified memory estimation for embedding models
        let hiddenSize = embeddingDimension
        _ = 12 // Typical for embedding models (numLayers)
        
        // Base memory for model weights
        let weightsMemoryMB = 500 // ~500MB for typical embedding model
        
        // Activation memory
        let activationMemory = sequenceLength * batchSize * hiddenSize * 2 // fp16
        
        // Output embedding memory
        let outputMemory = batchSize * embeddingDimension * 2 // fp16
        
        let totalMemoryBytes = (weightsMemoryMB * 1024 * 1024) + activationMemory + outputMemory
        return totalMemoryBytes / (1024 * 1024) // Convert to MB
    }
}

/// Pooling strategies for embedding models
public enum PoolingStrategy: String, Codable, Sendable {
    /// Mean pooling across sequence
    case mean = "mean"
    
    /// Max pooling across sequence
    case max = "max"
    
    /// CLS token pooling (use first token)
    case cls = "cls"
    
    /// Attention-based pooling
    case attention = "attention"
    
    /// Mean-Max hybrid pooling
    case meanMax = "mean_max"
    
    /// Last token pooling
    case last = "last"
}

// Extension for InputConstraints to support embedding-specific parameters
extension InputConstraints {
    /// Convenience accessor for sequence length constraints
    public var sequenceLengthRange: ClosedRange<Int> {
        return minWidth...maxWidth
    }
}

