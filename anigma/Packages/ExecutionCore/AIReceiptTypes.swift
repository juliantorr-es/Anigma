//
//  AIReceiptTypes.swift
//  ExecutionCore
//
//  AI-specific receipt types and metadata for comprehensive transparency.
//  Extends the base receipt system with AI operation tracking.
//

import Foundation
import TelemetryCore

// MARK: - AI Operation Metadata

/// Comprehensive metadata for AI operations captured in receipts
public struct AIOperationMetadata: Codable, Sendable {
    /// Unique identifier for the AI model used
    public let modelID: String
    
    /// Version of the model (e.g., "1.5.0", "llama-3.1-8b-v2")
    public let modelVersion: String
    
    /// Provider/service name ("mlx", "gemini", "claude", "openai", etc.)
    public let provider: String
    
    /// Type of AI task performed
    public let taskType: AITaskType
    
    /// Number of input tokens (if applicable)
    public let inputTokens: Int?
    
    /// Number of output tokens (if applicable)
    public let outputTokens: Int?
    
    /// Total inference time in milliseconds
    public let inferenceTimeMs: Int64
    
    /// Model parameters used for inference
    public let parameters: ModelParameters
    
    /// Hardware accelerator used (if known)
    public let hardware: String?
    
    /// Energy consumption estimate in Joules (if available)
    public let energyEstimateJoules: Double?
    
    /// Cache hit rate for inference (0.0-1.0)
    public let cacheHitRate: Double?
    
    /// Privacy/sensitivity level of the operation
    public let privacyLevel: PrivacyLevel
    
    /// Additional provider-specific metadata
    public let providerMetadata: [String: TelemetryValue]?
    
    public init(
        modelID: String,
        modelVersion: String,
        provider: String,
        taskType: AITaskType,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        inferenceTimeMs: Int64,
        parameters: ModelParameters,
        hardware: String? = nil,
        energyEstimateJoules: Double? = nil,
        cacheHitRate: Double? = nil,
        privacyLevel: PrivacyLevel = .standard,
        providerMetadata: [String: TelemetryValue]? = nil
    ) {
        self.modelID = modelID
        self.modelVersion = modelVersion
        self.provider = provider
        self.taskType = taskType
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.inferenceTimeMs = inferenceTimeMs
        self.parameters = parameters
        self.hardware = hardware
        self.energyEstimateJoules = energyEstimateJoules
        self.cacheHitRate = cacheHitRate
        self.privacyLevel = privacyLevel
        self.providerMetadata = providerMetadata
    }
}

/// Types of AI tasks that can be performed
public enum AITaskType: String, Sendable, Codable, CaseIterable {
    case chat = "llm_chat"
    case embedding = "embedding"
    case transcription = "transcription"
    case codeGeneration = "code_generation"
    case analysis = "analysis"
    case translation = "translation"
    case summarization = "summarization"
    case classification = "classification"
    case imageGeneration = "image_generation"
    case videoProcessing = "video_processing"
    case audioProcessing = "audio_processing"
    case reasoning = "reasoning"
    case planning = "planning"
    case orchestration = "orchestration"
    case search = "search"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .chat: return "Conversational chat/inference"
        case .embedding: return "Text embedding generation"
        case .transcription: return "Audio/video transcription"
        case .codeGeneration: return "Code generation and completion"
        case .analysis: return "Code or data analysis"
        case .translation: return "Language translation"
        case .summarization: return "Text summarization"
        case .classification: return "Content classification"
        case .imageGeneration: return "Image generation"
        case .videoProcessing: return "Video processing/analysis"
        case .audioProcessing: return "Audio processing/analysis"
        case .reasoning: return "Complex reasoning tasks"
        case .planning: return "Task planning and orchestration"
        case .orchestration: return "Multi-agent orchestration"
        case .search: return "Semantic or hybrid search"
        }
    }
    
    /// Category for UI organization
    public var category: AITaskCategory {
        switch self {
        case .chat, .reasoning, .planning, .orchestration:
            return .cognitive
        case .embedding, .search:
            return .retrieval
        case .codeGeneration, .analysis:
            return .development
        case .translation, .summarization, .classification:
            return .processing
        case .transcription, .imageGeneration, .videoProcessing, .audioProcessing:
            return .multimedia
        }
    }
}

/// High-level categories for organizing AI tasks
public enum AITaskCategory: String, Sendable, Codable, CaseIterable {
    case cognitive = "cognitive"
    case retrieval = "retrieval"
    case development = "development"
    case processing = "processing"
    case multimedia = "multimedia"
    
    public var displayName: String {
        switch self {
        case .cognitive: return "Cognitive Tasks"
        case .retrieval: return "Information Retrieval"
        case .development: return "Development Tools"
        case .processing: return "Text Processing"
        case .multimedia: return "Multimedia Processing"
        }
    }
}

/// Model parameters used during inference
public struct ModelParameters: Codable, Sendable {
    /// Temperature for sampling (0.0-1.0)
    public let temperature: Double?
    
    /// Top-p sampling threshold
    public let topP: Double?
    
    /// Top-k sampling threshold
    public let topK: Int?
    
    /// Repetition penalty
    public let repetitionPenalty: Double?
    
    /// Random seed for reproducible generation
    public let seed: Int?
    
    /// Maximum number of tokens to generate
    public let maxTokens: Int?
    
    /// Stop sequences
    public let stopSequences: [String]?
    
    /// Frequency penalty
    public let frequencyPenalty: Double?
    
    /// Presence penalty
    public let presencePenalty: Double?
    
    public init(
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        repetitionPenalty: Double? = nil,
        seed: Int? = nil,
        maxTokens: Int? = nil,
        stopSequences: [String]? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.repetitionPenalty = repetitionPenalty
        self.seed = seed
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
    }
}

/// Privacy/sensitivity levels for AI operations
public enum PrivacyLevel: String, Sendable, Codable, CaseIterable {
    case publicData = "public"
    case standard = "standard"
    case sensitive = "sensitive"
    case confidential = "confidential"
    case restricted = "restricted"
    
    public var description: String {
        switch self {
        case .publicData: return "Public data - no restrictions"
        case .standard: return "Standard processing - default protections"
        case .sensitive: return "Sensitive data - enhanced protections"
        case .confidential: return "Confidential data - strict controls"
        case .restricted: return "Restricted data - maximum security"
        }
    }
    
    public var retentionDays: Int {
        switch self {
        case .publicData: return 365
        case .standard: return 180
        case .sensitive: return 90
        case .confidential: return 30
        case .restricted: return 7
        }
    }
}

/// Token usage information for AI operations
public struct TokenUsage: Codable, Sendable {
    /// Number of input tokens processed
    public let inputTokens: Int
    
    /// Number of output tokens generated
    public let outputTokens: Int
    
    /// Total tokens (input + output)
    public var totalTokens: Int {
        return inputTokens + outputTokens
    }
    
    /// Cost estimate in USD (if pricing known)
    public let costEstimateUSD: Double?
    
    public init(
        inputTokens: Int,
        outputTokens: Int,
        costEstimateUSD: Double? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costEstimateUSD = costEstimateUSD
    }
}

// MARK: - AI CoreReceipt Extensions

/// Extended receipt with AI-specific metadata
public struct AIReceiptWire: Codable, Sendable {
    /// Base receipt information
    public let baseReceipt: ReceiptWire
    
    /// AI operation metadata
    public let aiMetadata: AIOperationMetadata
    
    /// Token usage information
    public let tokenUsage: TokenUsage?
    
    /// Performance metrics
    public let performanceMetrics: PerformanceMetrics?
    
    /// Chain of evidence for this AI operation
    public let evidenceChain: [String]? // Array of evidence IDs
    
    public init(
        baseReceipt: ReceiptWire,
        aiMetadata: AIOperationMetadata,
        tokenUsage: TokenUsage? = nil,
        performanceMetrics: PerformanceMetrics? = nil,
        evidenceChain: [String]? = nil
    ) {
        self.baseReceipt = baseReceipt
        self.aiMetadata = aiMetadata
        self.tokenUsage = tokenUsage
        self.performanceMetrics = performanceMetrics
        self.evidenceChain = evidenceChain
    }
}

/// Performance metrics for AI operations
public struct PerformanceMetrics: Codable, Sendable {
    /// Preprocessing time in milliseconds
    public let preprocessingTimeMs: Int64?
    
    /// Inference time in milliseconds
    public let inferenceTimeMs: Int64
    
    /// Postprocessing time in milliseconds
    public let postprocessingTimeMs: Int64?
    
    /// Memory usage in bytes
    public let memoryUsageBytes: Int64?
    
    /// GPU utilization percentage (0-100)
    public let gpuUtilizationPercent: Double?
    
    /// CPU utilization percentage (0-100)
    public let cpuUtilizationPercent: Double?
    
    /// Network bandwidth in bytes per second
    public let networkBandwidthBps: Double?
    
    /// Disk I/O in bytes per second
    public let diskIOBps: Double?
    
    public init(
        preprocessingTimeMs: Int64? = nil,
        inferenceTimeMs: Int64,
        postprocessingTimeMs: Int64? = nil,
        memoryUsageBytes: Int64? = nil,
        gpuUtilizationPercent: Double? = nil,
        cpuUtilizationPercent: Double? = nil,
        networkBandwidthBps: Double? = nil,
        diskIOBps: Double? = nil
    ) {
        self.preprocessingTimeMs = preprocessingTimeMs
        self.inferenceTimeMs = inferenceTimeMs
        self.postprocessingTimeMs = postprocessingTimeMs
        self.memoryUsageBytes = memoryUsageBytes
        self.gpuUtilizationPercent = gpuUtilizationPercent
        self.cpuUtilizationPercent = cpuUtilizationPercent
        self.networkBandwidthBps = networkBandwidthBps
        self.diskIOBps = diskIOBps
    }
}

// MARK: - CoreReceipt Extensions for AI Operations

extension ReceiptWire {
    /// Creates a receipt specifically for AI operations
    public static func createAIReceipt(
        actionName: String,
        authority: String,
        decision: ReceiptDecision,
        reasonCode: String,
        timestampMs: Int64,
        inputsHash: TelemetryHash,
        outputsHash: TelemetryHash? = nil,
        previousReceiptHash: String? = nil,
        metadata: [String: TelemetryValue] = [:],
        aiMetadata: AIOperationMetadata
    ) -> ReceiptWire {
        // Merge AI metadata into the main metadata
        var enhancedMetadata = metadata
        
        do {
            let aiMetadataData = try JSONEncoder().encode(aiMetadata)
            let aiMetadataString = String(data: aiMetadataData, encoding: .utf8) ?? ""
            enhancedMetadata["ai_operation"] = .string(aiMetadataString)
        } catch {
            // If encoding fails, add error information
            enhancedMetadata["ai_operation_error"] = .string("Failed to encode AI metadata")
        }
        
        return ReceiptWire.create(
            actionName: actionName,
            authority: authority,
            decision: decision,
            reasonCode: reasonCode,
            timestampMs: timestampMs,
            inputsHash: inputsHash,
            outputsHash: outputsHash,
            previousReceiptHash: previousReceiptHash,
            metadata: enhancedMetadata
        )
    }
    
    /// Extracts AI metadata from receipt metadata
    public func extractAIMetadata() -> AIOperationMetadata? {
        guard let aiMetadataValue = metadata["ai_operation"],
              case .string(let aiMetadataString) = aiMetadataValue else {
            return nil
        }
        
        guard let data = aiMetadataString.data(using: .utf8) else {
            return nil
        }
        
        return try? JSONDecoder().decode(AIOperationMetadata.self, from: data)
    }
    
    /// Checks if this receipt contains an AI operation
    public var isAIOperation: Bool {
        return extractAIMetadata() != nil
    }
    
    /// Gets the AI task type if this is an AI operation
    public var aiTaskType: AITaskType? {
        return extractAIMetadata()?.taskType
    }
}