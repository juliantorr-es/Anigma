//
//  InferenceTypes.swift
//  HarmoniaCore
//
//  Core types for the Unified Inference Plane.
//  Backend-agnostic inference capabilities across MLX, CoreML, and remote APIs.
//  Migrated from HarmoniaModule - Pure value types with zero side effects.
//

import Foundation

// MARK: - Inference Task Types

/// Types of inference operations the plane can perform.
public enum InferenceTaskKind: String, Sendable, Codable, CaseIterable {
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
    case reasoning  // Two-tier reasoning
}

/// Quality tiers for model selection.
public enum QualityTier: String, Sendable, Codable, Comparable {
    case tiny      // <1B params, fastest, lowest quality
    case small     // 1-3B params
    case base      // 3-8B params
    case large     // 8-30B params
    case flagship  // 30B+ params, slowest, highest quality

    public static func < (lhs: QualityTier, rhs: QualityTier) -> Bool {
        let order: [QualityTier] = [.tiny, .small, .base, .large, .flagship]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

/// Cost tiers for inference operations.
public enum CostTier: String, Sendable, Codable, Comparable {
    case free      // Local inference, no cost
    case cheap     // Minimal API costs
    case normal    // Standard pricing
    case metered   // Pay-per-use remote APIs
    case premium   // High-end models

    public static func < (lhs: CostTier, rhs: CostTier) -> Bool {
        let order: [CostTier] = [.free, .cheap, .normal, .metered, .premium]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

/// Privacy level requirements for inference.
public enum InferencePrivacyLevel: String, Sendable, Codable {
    case restricted  // Most sensitive - local only, encrypted
    case sensitive   // Sensitive - local preferred, trusted remotes only
    case `internal`  // Internal operations - standard protections
    case `public`    // Public data - any backend allowed
}

/// Energy/performance preference.
public enum EnergyProfile: String, Sendable, Codable {
    case lowPower     // Prefer ANE/efficient backends
    case balanced     // Default behavior
    case performance  // Prefer GPU, allow higher power draw
}

// MARK: - Inference Input/Output

/// Input to an inference task.
public enum InferenceInput: Sendable {
    case text(String)
    case messages([ChatMessage])
    case batch([String])
    case structured(StructuredInput)
}

/// A chat message for conversational inference.
public struct ChatMessage: Sendable, Codable, Equatable {
    public let role: ChatRole
    public let content: String
    public let name: String?

    public init(role: ChatRole, content: String, name: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
    }
}

/// Role in a chat conversation.
public enum ChatRole: String, Sendable, Codable {
    case system
    case user
    case assistant
    case tool
}

/// Structured input for specialized tasks.
public struct StructuredInput: Sendable {
    public let type: String
    public let data: [String: String]

    public init(type: String, data: [String: String]) {
        self.type = type
        self.data = data
    }
}

// MARK: - Inference Constraints

/// Constraints for inference task execution.
public struct InferenceConstraints: Sendable {
    /// Require local-only execution (no remote APIs).
    public var localOnly: Bool

    /// Maximum acceptable latency.
    public var maxLatency: Duration?

    /// Minimum quality tier required.
    public var minQualityTier: QualityTier?

    /// Maximum cost tier allowed.
    public var maxCostTier: CostTier?

    /// Privacy level of the data being processed.
    public var privacyLevel: InferencePrivacyLevel

    /// Energy/performance preference.
    public var energyPreference: EnergyProfile?

    /// Minimum context window required (tokens).
    public var minContextWindow: Int?

    /// Preferred model families (e.g., "llama", "phi", "deepseek").
    public var preferredFamilies: [String]?

    /// Required capabilities (e.g., "tool_calling", "vision").
    public var requiredCapabilities: Set<String>?

    public init(
        localOnly: Bool = false,
        maxLatency: Duration? = nil,
        minQualityTier: QualityTier? = nil,
        maxCostTier: CostTier? = nil,
        privacyLevel: InferencePrivacyLevel = .internal,
        energyPreference: EnergyProfile? = nil,
        minContextWindow: Int? = nil,
        preferredFamilies: [String]? = nil,
        requiredCapabilities: Set<String>? = nil
    ) {
        self.localOnly = localOnly
        self.maxLatency = maxLatency
        self.minQualityTier = minQualityTier
        self.maxCostTier = maxCostTier
        self.privacyLevel = privacyLevel
        self.energyPreference = energyPreference
        self.minContextWindow = minContextWindow
        self.preferredFamilies = preferredFamilies
        self.requiredCapabilities = requiredCapabilities
    }
    
    /// Default constraints for DSPS/FERPA-compliant operations
    public static let dspsCompliant = InferenceConstraints(
        localOnly: true,
        maxCostTier: .free,
        privacyLevel: .restricted,
        energyPreference: .balanced
    )
    
    /// Constraints for public data processing
    public static let `public` = InferenceConstraints(
        localOnly: false,
        maxCostTier: .metered,
        privacyLevel: .public,
        energyPreference: .balanced
    )
}

// MARK: - Inference Result

/// Result from an inference operation.
public struct InferenceResult: Sendable {
    public let output: InferenceOutput
    public let metadata: InferenceMetadata
    public let error: Error?
    
    public init(output: InferenceOutput, metadata: InferenceMetadata, error: Error? = nil) {
        self.output = output
        self.metadata = metadata
        self.error = error
    }
    
    public var isSuccess: Bool { error == nil }
}

/// Output from an inference operation.
public enum InferenceOutput: Sendable {
    case text(String)
    case embeddings([Float])
    case classification(label: String, confidence: Double)
    case structured([String: String])
}

/// Metadata about an inference operation.
public struct InferenceMetadata: Sendable {
    public let modelUsed: String
    public let backend: String
    public let latency: Duration
    public let tokenCount: Int?
    public let timestamp: Date
    
    public init(
        modelUsed: String,
        backend: String,
        latency: Duration,
        tokenCount: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.modelUsed = modelUsed
        self.backend = backend
        self.latency = latency
        self.tokenCount = tokenCount
        self.timestamp = timestamp
    }
}
