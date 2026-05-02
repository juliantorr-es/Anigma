//
//  ModelContracts.swift
//  AnigmaAppMac
//
//  Governed model contract types for court-safe ML execution.
//

import Foundation
import CryptoKit

// MARK: - Task Contracts

/// Supported ML task types with stable contract definitions
public enum TaskKind: String, Codable, Sendable, Hashable {
    case inference = "llm.inference"
    case embedding = "text.embedding"
    case transcription = "audio.transcription"
    case classification = "text.classification"
    case imageGeneration = "image.generation"
    case speechSynthesis = "audio.synthesis"
}

/// Task-specific parameter contracts
public enum TaskParams: Codable, Sendable, Hashable {
    case inference(InferenceParams)
    case embedding(EmbeddingParams)
    case transcription(TranscriptionParams)
    case classification(ClassificationParams)
    case imageGeneration(ImageGenParams)
    case speechSynthesis(TTSParams)

    public var kind: TaskKind {
        switch self {
        case .inference: return .inference
        case .embedding: return .embedding
        case .transcription: return .transcription
        case .classification: return .classification
        case .imageGeneration: return .imageGeneration
        case .speechSynthesis: return .speechSynthesis
        }
    }
}

public struct InferenceParams: Codable, Sendable, Hashable {
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let stopSequences: [String]?
    public let systemPrompt: String?

    public init(maxTokens: Int? = nil, temperature: Double? = nil, topP: Double? = nil, stopSequences: [String]? = nil, systemPrompt: String? = nil) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.stopSequences = stopSequences
        self.systemPrompt = systemPrompt
    }
}

public struct EmbeddingParams: Codable, Sendable, Hashable {
    public let normalize: Bool
    public let batchSize: Int?

    public init(normalize: Bool = true, batchSize: Int? = nil) {
        self.normalize = normalize
        self.batchSize = batchSize
    }
}

public struct TranscriptionParams: Codable, Sendable, Hashable {
    public let language: String?
    public let task: String // "transcribe" or "translate"

    public init(language: String? = nil, task: String = "transcribe") {
        self.language = language
        self.task = task
    }
}

public struct ClassificationParams: Codable, Sendable, Hashable {
    public let labels: [String]
    public let multiLabel: Bool

    public init(labels: [String], multiLabel: Bool = false) {
        self.labels = labels
        self.multiLabel = multiLabel
    }
}

public struct ImageGenParams: Codable, Sendable, Hashable {
    public let width: Int
    public let height: Int
    public let steps: Int?
    public let guidanceScale: Double?

    public init(width: Int, height: Int, steps: Int? = nil, guidanceScale: Double? = nil) {
        self.width = width
        self.height = height
        self.steps = steps
        self.guidanceScale = guidanceScale
    }
}

public struct TTSParams: Codable, Sendable, Hashable {
    public let voiceId: String?
    public let speed: Double?

    public init(voiceId: String? = nil, speed: Double? = nil) {
        self.voiceId = voiceId
        self.speed = speed
    }
}

// MARK: - ModelSpec

/// Immutable model specification with provenance
public struct ModelSpec: Codable, Sendable, Hashable, Identifiable {
    /// Stable model identifier (e.g., "mlx-community/Qwen2.5-0.5B-Instruct-4bit")
    public let modelId: String

    /// Hash of model weights/artifacts
    public let modelHash: String

    /// Task this model supports
    public let taskKind: TaskKind

    /// Backend execution format (mlx, gguf, coreml, etc.)
    public let backendFormat: String

    /// Model dimension (for embeddings) or context length (for LLMs)
    public let dimension: Int?

    /// Tokenizer hash (for reproducibility)
    public let tokenizerHash: String?

    /// License identifier
    public let license: String?

    /// Trust tier (first-class, compatible, experimental)
    public let trustTier: TrustTier

    /// Source provenance
    public let source: ModelSource

    // Identifiable conformance
    public var id: String { modelId }

    public init(
        modelId: String,
        modelHash: String,
        taskKind: TaskKind,
        backendFormat: String,
        dimension: Int? = nil,
        tokenizerHash: String? = nil,
        license: String? = nil,
        trustTier: TrustTier = .experimental,
        source: ModelSource
    ) {
        self.modelId = modelId
        self.modelHash = modelHash
        self.taskKind = taskKind
        self.backendFormat = backendFormat
        self.dimension = dimension
        self.tokenizerHash = tokenizerHash
        self.license = license
        self.trustTier = trustTier
        self.source = source
    }

    /// Canonical hash for signing
    public func canonicalHash() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

public enum TrustTier: String, Codable, Sendable, Hashable {
    case firstClass = "first-class"
    case compatible = "compatible"
    case experimental = "experimental"
}

public struct ModelSource: Codable, Sendable, Hashable {
    public let type: ModelSourceType
    public let location: String
    public let revision: String?

    public init(type: ModelSourceType, location: String, revision: String? = nil) {
        self.type = type
        self.location = location
        self.revision = revision
    }
}

public enum ModelSourceType: String, Codable, Sendable, Hashable {
    case huggingface = "huggingface"
    case local = "local"
    case bundled = "bundled"
}

// MARK: - RunSpec

/// Execution specification for a governed ML run
public struct RunSpec: Codable, Sendable, Hashable {
    /// Unique run identifier
    public let runId: String

    /// Model specification
    public let modelSpec: ModelSpec

    /// Task parameters
    public let taskParams: TaskParams

    /// Input hash (for reproducibility)
    public let inputHash: String

    /// Workflow and job correlation
    public let workflowId: String?
    public let jobId: String?

    /// Data classification (for policy gates)
    public let dataClassification: String?

    /// Timestamp
    public let timestamp: Date

    public init(
        runId: String,
        modelSpec: ModelSpec,
        taskParams: TaskParams,
        inputHash: String,
        workflowId: String? = nil,
        jobId: String? = nil,
        dataClassification: String? = nil,
        timestamp: Date = Date()
    ) {
        self.runId = runId
        self.modelSpec = modelSpec
        self.taskParams = taskParams
        self.inputHash = inputHash
        self.workflowId = workflowId
        self.jobId = jobId
        self.dataClassification = dataClassification
        self.timestamp = timestamp
    }

    /// Canonical hash for signing
    public func canonicalHash() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Evidence Head

/// Evidence head for court-safe ML execution
public struct MLEvidenceHead: Codable, Sendable {
    /// Run specification hash
    public let runSpecHash: String

    /// Model specification hash
    public let modelSpecHash: String

    /// Output hash
    public let outputHash: String

    /// CoreReceipt identifier
    public let receiptId: String

    /// Timestamp
    public let timestamp: Date

    /// Policy decision reference
    public let policyDecision: String?

    public init(
        runSpecHash: String,
        modelSpecHash: String,
        outputHash: String,
        receiptId: String,
        timestamp: Date = Date(),
        policyDecision: String? = nil
    ) {
        self.runSpecHash = runSpecHash
        self.modelSpecHash = modelSpecHash
        self.outputHash = outputHash
        self.receiptId = receiptId
        self.timestamp = timestamp
        self.policyDecision = policyDecision
    }
}
