//
//  InferenceTypes.swift
//  HarmoniaModule
//
//  Core types for the Unified Inference Plane.
//  Provides backend-agnostic inference capabilities across MLX, llama.cpp, Ollama, and remote APIs.
//

import AnigmaCore
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
}

/// Quality tiers for model selection.
public enum QualityTier: String, Sendable, Codable, Comparable {
    case tiny  // <1B params, fastest, lowest quality
    case small  // 1-3B params
    case base  // 3-8B params
    case large  // 8-30B params
    case flagship  // 30B+ params, slowest, highest quality

    public static func < (lhs: QualityTier, rhs: QualityTier) -> Bool {
        let order: [QualityTier] = [.tiny, .small, .base, .large, .flagship]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// Cost tiers for inference operations.
public enum CostTier: String, Sendable, Codable, Comparable {
    case free  // Local inference, no cost
    case cheap  // Minimal API costs
    case metered  // Pay-per-use remote APIs
    case normal  // Standard pricing
    case premium  // High-end models

    public static func < (lhs: CostTier, rhs: CostTier) -> Bool {
        let order: [CostTier] = [.free, .cheap, .normal, .metered, .premium]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// Privacy level requirements for inference.
public enum InferencePrivacyLevel: String, Sendable, Codable {
    case restricted  // Most sensitive - local only, encrypted
    case sensitive  // Sensitive - local preferred, trusted remotes only
    case `internal`  // Internal operations - standard protections
    case `public`  // Public data - any backend allowed
}

/// Energy/performance preference.
public enum EnergyProfile: String, Sendable, Codable {
    case lowPower  // Prefer ANE/efficient backends
    case balanced  // Default behavior
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
public struct ChatMessage: Sendable, Codable {
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

    /// Default constraints for DSPS/restricted data.
    public static let dspsRestricted = InferenceConstraints(
        localOnly: true,
        privacyLevel: .restricted
    )

    /// Default constraints for general internal use.
    public static let internalDefault = InferenceConstraints(
        privacyLevel: .internal
    )

    /// Constraints for fast, low-quality tasks.
    public static let fastAndCheap = InferenceConstraints(
        minQualityTier: .tiny,
        maxCostTier: .free,
        energyPreference: .lowPower
    )
}

// MARK: - Inference Context

/// Context for an inference task (tenant, principal, workspace).
public struct InferenceContext: Sendable {
    public let tenantId: String
    public let environmentId: String
    public let principalId: String
    public let workspaceId: String?
    public let correlationId: String

    public init(
        tenantId: String,
        environmentId: String,
        principalId: String,
        workspaceId: String? = nil,
        correlationId: String = UUID().uuidString
    ) {
        self.tenantId = tenantId
        self.environmentId = environmentId
        self.principalId = principalId
        self.workspaceId = workspaceId
        self.correlationId = correlationId
    }
}

// MARK: - Inference Task

/// A complete inference task to be executed.
public struct InferenceTask: Sendable {
    public let id: String
    public let kind: InferenceTaskKind
    public let input: InferenceInput
    public let context: InferenceContext
    public let constraints: InferenceConstraints
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        kind: InferenceTaskKind,
        input: InferenceInput,
        context: InferenceContext,
        constraints: InferenceConstraints = InferenceConstraints()
    ) {
        self.id = id
        self.kind = kind
        self.input = input
        self.context = context
        self.constraints = constraints
        self.createdAt = Date()
    }
}

// MARK: - Inference Result

/// Result of an inference task.
public struct InferenceResult: Sendable {
    public let taskId: String
    public let output: InferenceOutput
    public let modelUsed: String
    public let backendUsed: BackendKind
    public let tokensIn: Int
    public let tokensOut: Int
    public let latency: Duration
    public let completedAt: Date

    public init(
        taskId: String,
        output: InferenceOutput,
        modelUsed: String,
        backendUsed: BackendKind,
        tokensIn: Int,
        tokensOut: Int,
        latency: Duration
    ) {
        self.taskId = taskId
        self.output = output
        self.modelUsed = modelUsed
        self.backendUsed = backendUsed
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.latency = latency
        self.completedAt = Date()
    }
}

/// Output from an inference task.
public enum InferenceOutput: Sendable {
    case text(String)
    case embedding([Float])
    case embeddings([[Float]])
    case classification(label: String, confidence: Double)
    case rankings([(index: Int, score: Double)])
    case toolCalls([InferenceToolCall])
}

/// A tool call from an inference result.
public struct InferenceToolCall: Sendable, Codable {
    public let id: String
    public let name: String
    public let arguments: [String: String]

    public init(id: String, name: String, arguments: [String: String]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// A streaming chunk from inference.
public struct InferenceChunk: Sendable {
    public let taskId: String
    public let delta: String
    public let isComplete: Bool
    public let tokensGenerated: Int

    public init(taskId: String, delta: String, isComplete: Bool, tokensGenerated: Int) {
        self.taskId = taskId
        self.delta = delta
        self.isComplete = isComplete
        self.tokensGenerated = tokensGenerated
    }
}

// MARK: - Backend Types

/// Kinds of inference backends.
public enum BackendKind: String, Sendable, Codable, CaseIterable {
    case mlx  // Apple MLX framework
    case llamaCpp  // llama.cpp / llama-server
    case ollama  // Ollama daemon
    case coreML  // Core ML models
    case remoteAPI  // Remote API endpoints
}

/// Status of a backend instance.
public enum BackendStatus: String, Sendable, Codable {
    case starting
    case ready
    case busy
    case degraded
    case stopped
    case failed
}

/// Format of model files.
public enum ModelFormat: String, Sendable, Codable {
    case gguf  // GGUF format for llama.cpp
    case mlx  // MLX format
    case coreML  // Core ML format
    case safetensors  // Safetensors format
    case ollama  // Ollama managed
    case remote  // Remote API-backed models
}

// MARK: - Inference Errors

public enum InferenceError: Error, LocalizedError, Sendable {
    case noSuitableModel(constraints: String)
    case backendUnavailable(backend: BackendKind)
    case modelLoadFailed(model: String, reason: String)
    case executionFailed(reason: String)
    case timeout(duration: Duration)
    case policyViolation(reason: String)
    case contextTooLarge(required: Int, available: Int)
    case rateLimited(retryAfter: Duration?)

    public var errorDescription: String? {
        switch self {
        case .noSuitableModel(let constraints):
            return "No suitable model found for constraints: \(constraints)"
        case .backendUnavailable(let backend):
            return "Backend unavailable: \(backend.rawValue)"
        case .modelLoadFailed(let model, let reason):
            return "Failed to load model '\(model)': \(reason)"
        case .executionFailed(let reason):
            return "Inference execution failed: \(reason)"
        case .timeout(let duration):
            return "Inference timed out after \(duration)"
        case .policyViolation(let reason):
            return "Policy violation: \(reason)"
        case .contextTooLarge(let required, let available):
            return "Context too large: required \(required) tokens, available \(available)"
        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Rate limited, retry after \(retry)"
            }
            return "Rate limited"
        }
    }
}

// MARK: - Governed Telemetry & Architecture

/// Telemetry collection mode for inference.
public enum TelemetryMode: String, Sendable, Codable {
    case strict
    case balanced
    case research
    case relaxed
    case `default`
}

/// Policy for telemetry collection.
public struct TelemetryPolicy: Sendable, Codable {
    public let tenantId: String
    public let recordingEnabled: Bool
    public let retentionDays: Int

    public init(tenantId: String, recordingEnabled: Bool = true, retentionDays: Int = 30) {
        self.tenantId = tenantId
        self.recordingEnabled = recordingEnabled
        self.retentionDays = retentionDays
    }
}

/// Gate for governing telemetry flow.
public actor TelemetryGate {
    private var policy: TelemetryPolicy?

    public init() {}

    public func setPolicy(_ policy: TelemetryPolicy) {
        self.policy = policy
    }

    public func shouldEmitEvent(for tenantId: String) -> Bool {
        return policy?.recordingEnabled ?? true
    }
}

public struct CreateInferenceEventConfiguration: Sendable {
    public let tenantId: String
    public let environmentId: String
    public let modelId: String
    public let taskKind: String
    public let tokensIn: Int
    public let tokensOut: Int
    public let latencyMs: Double
    public let success: Bool
    public let architectureType: String?

    public init(
        tenantId: String,
        environmentId: String,
        modelId: String,
        taskKind: String,
        tokensIn: Int,
        tokensOut: Int,
        latencyMs: Double,
        success: Bool,
        architectureType: String? = nil
    ) {
        self.tenantId = tenantId
        self.environmentId = environmentId
        self.modelId = modelId
        self.taskKind = taskKind
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.latencyMs = latencyMs
        self.success = success
        self.architectureType = architectureType
    }
}

public func createInferenceEvent(config: CreateInferenceEventConfiguration) -> [String: Any] {
    return [
        "tenantId": config.tenantId,
        "environmentId": config.environmentId,
        "modelId": config.modelId,
        "taskKind": config.taskKind,
        "tokensIn": config.tokensIn,
        "tokensOut": config.tokensOut,
        "latencyMs": config.latencyMs,
        "success": config.success,
        "architectureType": config.architectureType ?? "unknown"
    ]
}
