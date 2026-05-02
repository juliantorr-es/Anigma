//
//  InferenceTypes.swift
//  InferenceCore
//
//  Contracts for inference execution across the runtime boundary.
//

import Foundation
import IntelligenceContracts
import FoundationContracts

/// Supported inference tasks.
public enum InferenceTaskKind: String, Codable, Sendable, CaseIterable {
    case textGeneration
    case chat
    case summarize
    case embed
    case classify
    case rerank
    case toolCall
    case codeGeneration
    case codeExplanation
    case extraction
    case translation
    case embedding
}

/// Value type for inference options.
public enum InferenceOptionValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case integer(Int)
    case boolean(Bool)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else {
            throw DecodingError.typeMismatch(
                InferenceOptionValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported option value"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        }
    }

    public var asBool: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }

    public var asString: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var asInt: Int? {
        if case .integer(let value) = self { return value }
        return nil
    }

    public var asDouble: Double? {
        if case .number(let value) = self { return value }
        if case .integer(let value) = self { return Double(value) }
        return nil
    }
}

/// Inference request payload.
public struct InferenceRequest: Codable, Sendable, Equatable {
    public let task: InferenceTaskKind
    public let input: String
    public let attachments: [ArtifactReference] // For Vision/Multimodal
    public let modelID: String?
    public let options: [String: InferenceOptionValue]
    public let correlationId: String

    public init(
        task: InferenceTaskKind,
        input: String,
        attachments: [ArtifactReference] = [],
        modelID: String? = nil,
        options: [String: InferenceOptionValue] = [:],
        correlationId: String = UUID().uuidString
    ) {
        self.task = task
        self.input = input
        self.attachments = attachments
        self.modelID = modelID
        self.options = options
        self.correlationId = correlationId
    }
}

/// Rerank request payload.
public struct RerankRequest: Codable, Sendable, Equatable {
    public let query: String
    public let documents: [String]
    public let modelID: String?
    public let topK: Int?
    public let options: [String: InferenceOptionValue]
    public let correlationId: String

    public init(
        query: String,
        documents: [String],
        modelID: String? = nil,
        topK: Int? = nil,
        options: [String: InferenceOptionValue] = [:],
        correlationId: String = UUID().uuidString
    ) {
        self.query = query
        self.documents = documents
        self.modelID = modelID
        self.topK = topK
        self.options = options
        self.correlationId = correlationId
    }
}

/// Rerank result item.
public struct RerankResultItem: Codable, Sendable, Equatable {
    public let index: Int
    public let score: Double
    public let document: String?

    public init(index: Int, score: Double, document: String? = nil) {
        self.index = index
        self.score = score
        self.document = document
    }
}

/// Rerank response payload.
public struct RerankResponse: Codable, Sendable, Equatable {
    public let results: [RerankResultItem]
    public let usage: InferenceUsage
    public let metadata: [String: String]

    public init(results: [RerankResultItem], usage: InferenceUsage = .init(), metadata: [String: String] = [:]) {
        self.results = results
        self.usage = usage
        self.metadata = metadata
    }
}

public struct ArtifactReference: Codable, Sendable, Equatable {
    public let id: String
    public let type: String // "image", "pdf", "document"
}

/// Usage stats returned by inference.
public struct InferenceUsage: Codable, Sendable, Equatable {
    public let inputTokens: Int?
    public let outputTokens: Int?

    public init(inputTokens: Int? = nil, outputTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// Inference response payload.
public struct InferenceResponse: Codable, Sendable, Equatable {
    public let output: String
    public let usage: InferenceUsage
    public let metadata: [String: String]
    public let provenance: InferenceProvenance?

    public init(output: String, usage: InferenceUsage = .init(), metadata: [String: String] = [:], provenance: InferenceProvenance? = nil) {
        self.output = output
        self.usage = usage
        self.metadata = metadata
        self.provenance = provenance
    }
}

/// Provenance information for inference responses
public struct InferenceProvenance: Codable, Sendable, Equatable {
    public let isGrounded: Bool
    public let confidence: CalibratedConfidence?
    public let coverageSummary: AnswerCoverageSummary?
    public let missingContext: [MissingContextWarning]?
    public let sources: [AnswerProvenanceSource]?
    public let receipts: [AnswerProvenanceReceipt]?

    public init(
        isGrounded: Bool,
        confidence: CalibratedConfidence? = nil,
        coverageSummary: AnswerCoverageSummary? = nil,
        missingContext: [MissingContextWarning]? = nil,
        sources: [AnswerProvenanceSource]? = nil,
        receipts: [AnswerProvenanceReceipt]? = nil
    ) {
        self.isGrounded = isGrounded
        self.confidence = confidence
        self.coverageSummary = coverageSummary
        self.missingContext = missingContext
        self.sources = sources
        self.receipts = receipts
    }
}

/// Errors emitted by inference adapters.
public enum InferenceError: Error, LocalizedError, Sendable {
    case unavailable(String)
    case invalidRequest(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let detail):
            return "Inference unavailable: \(detail)"
        case .invalidRequest(let detail):
            return "Inference request invalid: \(detail)"
        case .executionFailed(let detail):
            return "Inference execution failed: \(detail)"
        }
    }
}

/// Inference execution priority.
public enum InferencePriority: String, Codable, Sendable {
    case ui
    case background
}

/// Configuration for speculative decoding.
public struct SpeculativeConfiguration: Codable, Sendable {
    public let draftModelID: String
    public let maxDraftTokens: Int

    public init(draftModelID: String, maxDraftTokens: Int = 5) {
        self.draftModelID = draftModelID
        self.maxDraftTokens = maxDraftTokens
    }
}

/// Deterministic tree verification metadata for speculative decoding.
public struct SpeculativeTreeVerificationMetadata: Codable, Sendable, Equatable {
    public let treeHash: String
    public let depthLevel: Int
    public let nodeCount: Int
    public let verificationTimestampMs: Int64

    public init(treeHash: String, depthLevel: Int, nodeCount: Int, verificationTimestampMs: Int64) {
        self.treeHash = treeHash
        self.depthLevel = depthLevel
        self.nodeCount = nodeCount
        self.verificationTimestampMs = verificationTimestampMs
    }
}

/// Result type for speculative tree verification.
public struct SpeculativeVerificationResult: Codable, Sendable, Equatable {
    public let isValid: Bool
    public let metadata: SpeculativeTreeVerificationMetadata
    public let rejectionReason: String?
    public let speculativeTokensAccepted: Int

    public init(
        isValid: Bool,
        metadata: SpeculativeTreeVerificationMetadata,
        rejectionReason: String? = nil,
        speculativeTokensAccepted: Int = 0
    ) {
        self.isValid = isValid
        self.metadata = metadata
        self.rejectionReason = rejectionReason
        self.speculativeTokensAccepted = speculativeTokensAccepted
    }
}

/// Status of an inference plane.
public struct InferencePlaneStatus: Codable, Sendable {
    public let planeId: String
    public let isAvailable: Bool
    public let currentLoad: Double

    public init(planeId: String, isAvailable: Bool, currentLoad: Double) {
        self.planeId = planeId
        self.isAvailable = isAvailable
        self.currentLoad = currentLoad
    }
}

/// Contract surface for inference execution.
public protocol InferencePlane: Sendable {
    /// Execute the inference request and return a response.
    func perform(_ request: InferenceRequest) async throws -> InferenceResponse
}

/// Protocol to abstract MLX engine implementation without direct import
public protocol MLXEngineProtocol: Sendable {
    func loadModel() async throws
    func unload() async
    func generate(prompt: String, maxTokens: Int, temperature: Float) async throws -> String
    func generateStream(prompt: String, maxTokens: Int, temperature: Float) -> AsyncThrowingStream<String, Error>
    func embed(text: String) async throws -> [Float]
}
