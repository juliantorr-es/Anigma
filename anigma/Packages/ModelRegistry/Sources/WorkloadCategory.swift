//
//  WorkloadCategory.swift
//  ModelRegistry
//
//  Workload categories for model specialization and lowering policies.
//

import Foundation

/// Categories of model workloads that require specialized lowering strategies.
public enum WorkloadCategory: String, Codable, Sendable, CaseIterable {
    /// Embedding models (e.g., text embeddings, retrieval)
    case embeddings = "embeddings"
    
    /// Reranker models (e.g., cross-encoder rerankers)
    case reranker = "reranker"
    
    /// Classifier models (e.g., sentiment, topic classification)
    case classifier = "classifier"
    
    /// Perception models (e.g., vision, audio, multimodal)
    case perception = "perception"
    
    /// Prefill models (e.g., autoregressive language model prefill phase)
    case prefill = "prefill"
    
    /// Decode models (e.g., autoregressive language model decode phase)
    case decode = "decode"
    
    /// Multi-modal models (e.g., vision-language, audio-text)
    case multimodal = "multimodal"
    
    /// Specialized compute models (e.g., DSP, signal processing)
    case specialized = "specialized"
}

extension WorkloadCategory {
    /// Human-readable description of the workload category
    public var description: String {
        switch self {
        case .embeddings:
            return "Embedding models for dense vector representations"
        case .reranker:
            return "Reranker models for relevance scoring"
        case .classifier:
            return "Classification models for categorical predictions"
        case .perception:
            return "Perception models for vision/audio processing"
        case .prefill:
            return "Prefill phase of autoregressive models"
        case .decode:
            return "Decode phase of autoregressive models"
        case .multimodal:
            return "Multi-modal models combining multiple modalities"
        case .specialized:
            return "Specialized compute models for domain-specific tasks"
        }
    }
    
    /// Whether this workload category supports dynamic shapes
    public var supportsDynamicShapes: Bool {
        switch self {
        case .decode, .prefill:
            return true
        case .embeddings, .reranker, .classifier, .perception, .multimodal, .specialized:
            return false
        }
    }
    
    /// Default attention style for this workload category
    public var defaultAttentionStyle: AttentionStyle {
        switch self {
        case .embeddings, .classifier:
            return .encoder
        case .reranker:
            return .crossEncoder
        case .prefill, .decode:
            return .decoder
        case .perception, .specialized:
            return .none
        case .multimodal:
            return .encoder
        }
    }
    
    /// Default normalization type for this workload category
    public var defaultNormalizationType: NormalizationType {
        switch self {
        case .embeddings, .reranker, .classifier, .multimodal:
            return .layerNorm
        case .prefill, .decode:
            return .rmsNorm
        case .perception:
            return .batchNorm
        case .specialized:
            return .instanceNorm
        }
    }
    
    /// Whether this workload typically requires fixed resolution
    public var requiresFixedResolution: Bool {
        switch self {
        case .perception:
            return true
        case .embeddings, .reranker, .classifier, .prefill, .decode, .multimodal, .specialized:
            return false
        }
    }
}