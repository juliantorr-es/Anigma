//
//  LoweringPolicy.swift
//  ModelRegistry
//
//  Policy structures for workload-specific model lowering rules.
//

import Foundation

/// Policy governing how models are lowered for specific workloads
public struct LoweringPolicy: Codable, Sendable {
    /// Workload category this policy applies to
    public let workloadCategory: WorkloadCategory
    
    /// Attention mechanism style to use
    public let attentionStyle: AttentionStyle
    
    /// Normalization type to apply
    public let normalizationType: NormalizationType
    
    /// Whether to remove optional branches (dropout, etc.)
    public let removeOptionalBranches: Bool
    
    /// Whether to fuse linear+activation operations
    public let fuseLinearActivation: Bool
    
    /// Whether to allow dynamic shapes
    public let allowDynamicShapes: Bool
    
    /// Maximum sequence length (tokens) for text models
    public let maxTokens: Int?
    
    /// Maximum batch size for inference
    public let maxBatchSize: Int?
    
    /// Fixed resolution for vision models
    public let fixedResolution: Resolution?
    
    /// Operation replacements for unsupported ops
    public let opReplacements: [String: String]
    
    /// Precision requirements (e.g., fp16, int8)
    public let precision: Precision
    
    /// Memory budget constraints in MB
    public let memoryBudgetMB: Int?
    
    /// Performance target (e.g., latency in ms)
    public let performanceTarget: PerformanceTarget?
    
    /// Whether to enable quantization
    public let enableQuantization: Bool
    
    /// Quantization scheme if enabled
    public let quantizationScheme: QuantizationScheme?
    
    public init(
        workloadCategory: WorkloadCategory,
        attentionStyle: AttentionStyle,
        normalizationType: NormalizationType,
        removeOptionalBranches: Bool,
        fuseLinearActivation: Bool,
        allowDynamicShapes: Bool,
        maxTokens: Int?,
        maxBatchSize: Int?,
        fixedResolution: Resolution?,
        opReplacements: [String: String],
        precision: Precision = .fp16,
        memoryBudgetMB: Int? = nil,
        performanceTarget: PerformanceTarget? = nil,
        enableQuantization: Bool = false,
        quantizationScheme: QuantizationScheme? = nil
    ) {
        self.workloadCategory = workloadCategory
        self.attentionStyle = attentionStyle
        self.normalizationType = normalizationType
        self.removeOptionalBranches = removeOptionalBranches
        self.fuseLinearActivation = fuseLinearActivation
        self.allowDynamicShapes = allowDynamicShapes
        self.maxTokens = maxTokens
        self.maxBatchSize = maxBatchSize
        self.fixedResolution = fixedResolution
        self.opReplacements = opReplacements
        self.precision = precision
        self.memoryBudgetMB = memoryBudgetMB
        self.performanceTarget = performanceTarget
        self.enableQuantization = enableQuantization
        self.quantizationScheme = quantizationScheme
    }
}

/// Attention mechanism styles
public enum AttentionStyle: String, Codable, Sendable {
    /// Encoder-style attention (full self-attention)
    case encoder = "encoder"
    
    /// Decoder-style attention (causal mask)
    case decoder = "decoder"
    
    /// Cross-encoder attention (query-key-value attention)
    case crossEncoder = "cross_encoder"
    
    /// No attention mechanism
    case none = "none"
}

/// Normalization types
public enum NormalizationType: String, Codable, Sendable {
    /// Layer normalization
    case layerNorm = "layer_norm"
    
    /// RMS normalization
    case rmsNorm = "rms_norm"
    
    /// Batch normalization
    case batchNorm = "batch_norm"
    
    /// Instance normalization
    case instanceNorm = "instance_norm"
    
    /// Group normalization
    case groupNorm = "group_norm"
}

/// Precision requirements
public enum Precision: String, Codable, Sendable {
    /// 32-bit floating point
    case fp32 = "fp32"
    
    /// 16-bit floating point
    case fp16 = "fp16"
    
    /// 8-bit integer
    case int8 = "int8"
    
    /// 4-bit integer
    case int4 = "int4"
    
    /// Mixed precision
    case mixed = "mixed"
}

/// Performance targets
public struct PerformanceTarget: Codable, Sendable {
    /// Target latency in milliseconds
    public let latencyMS: Double?
    
    /// Target throughput in inferences per second
    public let throughputIPS: Double?
    
    /// Target power consumption in watts
    public let powerWatts: Double?
    
    public init(
        latencyMS: Double? = nil,
        throughputIPS: Double? = nil,
        powerWatts: Double? = nil
    ) {
        self.latencyMS = latencyMS
        self.throughputIPS = throughputIPS
        self.powerWatts = powerWatts
    }
}

/// Quantization schemes
public enum QuantizationScheme: String, Codable, Sendable {
    /// Weight-only quantization
    case weightOnly = "weight_only"
    
    /// Dynamic quantization
    case dynamic = "dynamic"
    
    /// Static quantization
    case `static` = "static"
    
    /// Quantization-aware training
    case qat = "qat"
}

/// Image/video resolution
public struct Resolution: Codable, Sendable {
    /// Width in pixels
    public let width: Int
    
    /// Height in pixels
    public let height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

extension LoweringPolicy {
    /// Creates a default policy for a given workload category
    public static func `default`(for category: WorkloadCategory) -> LoweringPolicy {
        switch category {
        case .embeddings:
            return LoweringPolicy(
                workloadCategory: .embeddings,
                attentionStyle: .encoder,
                normalizationType: .layerNorm,
                removeOptionalBranches: true,
                fuseLinearActivation: true,
                allowDynamicShapes: false,
                maxTokens: 512,
                maxBatchSize: 32,
                fixedResolution: nil,
                opReplacements: [
                    "gelu": "relu",
                    "swish": "sigmoid"
                ],
                precision: .fp16,
                memoryBudgetMB: 512,
                performanceTarget: PerformanceTarget(latencyMS: 10.0, throughputIPS: 100.0),
                enableQuantization: true,
                quantizationScheme: .weightOnly
            )
            
        case .reranker:
            return LoweringPolicy(
                workloadCategory: .reranker,
                attentionStyle: .crossEncoder,
                normalizationType: .layerNorm,
                removeOptionalBranches: true,
                fuseLinearActivation: true,
                allowDynamicShapes: false,
                maxTokens: 256,
                maxBatchSize: 16,
                fixedResolution: nil,
                opReplacements: [:],
                precision: .fp16,
                memoryBudgetMB: 256,
                performanceTarget: PerformanceTarget(latencyMS: 5.0, throughputIPS: 200.0)
            )
            
        case .classifier:
            return LoweringPolicy(
                workloadCategory: .classifier,
                attentionStyle: .encoder,
                normalizationType: .layerNorm,
                removeOptionalBranches: true,
                fuseLinearActivation: true,
                allowDynamicShapes: false,
                maxTokens: 128,
                maxBatchSize: 64,
                fixedResolution: nil,
                opReplacements: [:],
                precision: .fp16,
                memoryBudgetMB: 128,
                performanceTarget: PerformanceTarget(latencyMS: 2.0, throughputIPS: 500.0)
            )
            
        case .perception:
            return LoweringPolicy(
                workloadCategory: .perception,
                attentionStyle: .none,
                normalizationType: .batchNorm,
                removeOptionalBranches: true,
                fuseLinearActivation: true,
                allowDynamicShapes: false,
                maxTokens: nil,
                maxBatchSize: 8,
                fixedResolution: Resolution(width: 1024, height: 1024),
                opReplacements: [:],
                precision: .fp16,
                memoryBudgetMB: 1024,
                performanceTarget: PerformanceTarget(latencyMS: 50.0, throughputIPS: 20.0)
            )
            
        case .prefill:
            return LoweringPolicy(
                workloadCategory: .prefill,
                attentionStyle: .decoder,
                normalizationType: .rmsNorm,
                removeOptionalBranches: true,
                fuseLinearActivation: false,
                allowDynamicShapes: true,
                maxTokens: 256,
                maxBatchSize: 1,
                fixedResolution: nil,
                opReplacements: [:],
                precision: .fp16,
                memoryBudgetMB: 2048,
                performanceTarget: PerformanceTarget(latencyMS: 100.0)
            )
            
        case .decode:
            return LoweringPolicy(
                workloadCategory: .decode,
                attentionStyle: .decoder,
                normalizationType: .rmsNorm,
                removeOptionalBranches: true,
                fuseLinearActivation: false,
                allowDynamicShapes: true,
                maxTokens: 1,
                maxBatchSize: 1,
                fixedResolution: nil,
                opReplacements: [:],
                precision: .fp16,
                memoryBudgetMB: 1024,
                performanceTarget: PerformanceTarget(latencyMS: 20.0)
            )
            
        case .multimodal:
            return LoweringPolicy(
                workloadCategory: .multimodal,
                attentionStyle: .encoder,
                normalizationType: .layerNorm,
                removeOptionalBranches: true,
                fuseLinearActivation: true,
                allowDynamicShapes: false,
                maxTokens: 512,
                maxBatchSize: 4,
                fixedResolution: Resolution(width: 224, height: 224),
                opReplacements: [:],
                precision: .fp16,
                memoryBudgetMB: 1536,
                performanceTarget: PerformanceTarget(latencyMS: 75.0, throughputIPS: 13.0)
            )
            
        case .specialized:
            return LoweringPolicy(
                workloadCategory: .specialized,
                attentionStyle: .none,
                normalizationType: .instanceNorm,
                removeOptionalBranches: false,
                fuseLinearActivation: false,
                allowDynamicShapes: true,
                maxTokens: nil,
                maxBatchSize: nil,
                fixedResolution: nil,
                opReplacements: [:],
                precision: .fp32,
                memoryBudgetMB: nil,
                performanceTarget: nil
            )
        }
    }
}