import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import AnigmaPrimitives
import Foundation
import CryptoKit

// MARK: - Model Contract System
// ADR: Support tasks, not repos. Models are data plugged into task contracts.

/// Supported ML backends with deterministic execution guarantees
public enum MLBackend: String, Codable, Hashable, Sendable {
    case mlx = "mlx"           // Apple Silicon first-class path
    case gguf = "gguf"         // llama.cpp for wide LLM coverage
    case coreml = "coreml"     // Small models when it fits
}

/// Supported ML task types (matching MLWorker UI)
public enum ModelTaskKind: String, Codable, Hashable, Sendable {
    case inference = "inference"
    case embedding = "embedding"
    case transcription = "transcription"
    case classification = "classification"
    case imageGeneration = "image_generation"
    case speechSynthesis = "speech_synthesis"
}

/// Model trust tier - determines runtime permissions and guarantees
public enum ModelTrustTier: String, Codable, Hashable, Sendable {
    case firstClass = "first_class"     // Curated, tested, shipped with guarantees
    case compatible = "compatible"       // BYOW, runs but no UX polish promises
    case experimental = "experimental"   // Indexed but not production-runnable
    case quarantined = "quarantined"    // Stored, hashed, blocked from execution
}

/// Source of model weights
public enum ModelSource: Codable, Hashable, Sendable {
    case huggingFace(repo: String, revision: String)
    case localPath(String)
    case bundled(String)

    public var identifier: String {
        switch self {
        case .huggingFace(let repo, let revision):
            return "\(repo)@\(revision)"
        case .localPath(let path):
            return "local:\(path)"
        case .bundled(let name):
            return "bundled:\(name)"
        }
    }
}

/// Conversion receipt - full provenance for format transformations
public struct ConversionReceipt: Codable, Hashable, Sendable {
    public let inputHashes: [String: String]
    public let toolId: String
    public let toolVersion: String
    public let outputHashes: [String: String]
    public let quantization: String?
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        inputHashes: [String: String],
        toolId: String,
        toolVersion: String,
        outputHashes: [String: String],
        quantization: String? = nil,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.inputHashes = inputHashes
        self.toolId = toolId
        self.toolVersion = toolVersion
        self.outputHashes = outputHashes
        self.quantization = quantization
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// License decision result
public struct LicenseDecision: Codable, Hashable, Sendable {
    public let declared: String
    public let allowed: Bool
    public let reason: String?
    public let extraTerms: [String]
    public let timestamp: Date

    public init(
        declared: String,
        allowed: Bool,
        reason: String? = nil,
        extraTerms: [String] = [],
        timestamp: Date = Date()
    ) {
        self.declared = declared
        self.allowed = allowed
        self.reason = reason
        self.extraTerms = extraTerms
        self.timestamp = timestamp
    }
}

/// Complete model specification with provenance
public struct ModelSpec: Codable, Hashable, Sendable {
    public let id: String
    public let source: ModelSource
    public let task: ModelTaskKind
    public let backend: MLBackend
    public let trustTier: ModelTrustTier
    public let license: LicenseDecision
    public let artifactHashes: [String: String]
    public let tokenizerHash: String?
    public let conversionReceipt: ConversionReceipt?
    public let metadata: [String: String]
    public let registeredAt: Date
    public let verifiedAt: Date
    public let storageBytes: Int64

    public var isRunnable: Bool {
        switch trustTier {
        case .firstClass, .compatible:
            return true
        case .experimental, .quarantined:
            return false
        }
    }

    public var canonicalHash: String {
        var parts: [String] = []
        parts.append(id)
        parts.append(source.identifier)
        parts.append(task.rawValue)
        parts.append(backend.rawValue)
        parts.append(trustTier.rawValue)
        parts.append(license.declared)

        let sortedArtifacts = artifactHashes.sorted { $0.key < $1.key }
        for (k, v) in sortedArtifacts {
            parts.append("\(k):\(v)")
        }

        if let tokHash = tokenizerHash {
            parts.append("tokenizer:\(tokHash)")
        }

        let combined = parts.joined(separator: "|")
        return BLAKE3Digest.hex(of: Data(combined.utf8))
    }

    public init(
        id: String,
        source: ModelSource,
        task: ModelTaskKind,
        backend: MLBackend,
        trustTier: ModelTrustTier,
        license: LicenseDecision,
        artifactHashes: [String: String],
        tokenizerHash: String? = nil,
        conversionReceipt: ConversionReceipt? = nil,
        metadata: [String: String] = [:],
        registeredAt: Date = Date(),
        verifiedAt: Date = Date(),
        storageBytes: Int64 = 0
    ) {
        self.id = id
        self.source = source
        self.task = task
        self.backend = backend
        self.trustTier = trustTier
        self.license = license
        self.artifactHashes = artifactHashes
        self.tokenizerHash = tokenizerHash
        self.conversionReceipt = conversionReceipt
        self.metadata = metadata
        self.registeredAt = registeredAt
        self.verifiedAt = verifiedAt
        self.storageBytes = storageBytes
    }
}

/// ML task execution options
public struct ModelTaskOptions: Codable, Hashable, Sendable {
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let seed: Int?
    public let extra: [String: String]

    public init(
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        seed: Int? = nil,
        extra: [String: String] = [:]
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.seed = seed
        self.extra = extra
    }
}

/// Run specification with full provenance
public struct ModelRunSpec: Codable, Hashable, Sendable {
    public let modelHash: String
    public let inputHash: String
    public let params: ModelTaskOptions
    public let seed: Int?
    public let backendVersion: String
    public let timestamp: Date
    public let requestId: String

    public var canonicalHash: String {
        var parts: [String] = []
        parts.append(modelHash)
        parts.append(inputHash)
        parts.append(backendVersion)

        if let maxTokens = params.maxTokens {
            parts.append("max_tokens:\(maxTokens)")
        }
        if let temp = params.temperature {
            parts.append("temperature:\(temp)")
        }
        if let topP = params.topP {
            parts.append("top_p:\(topP)")
        }
        if let seed = seed {
            parts.append("seed:\(seed)")
        }

        let sortedExtra = params.extra.sorted { $0.key < $1.key }
        for (k, v) in sortedExtra {
            parts.append("\(k):\(v)")
        }

        let combined = parts.joined(separator: "|")
        return BLAKE3Digest.hex(of: Data(combined.utf8))
    }

    public init(
        modelHash: String,
        inputHash: String,
        params: ModelTaskOptions,
        seed: Int? = nil,
        backendVersion: String,
        timestamp: Date = Date(),
        requestId: String = UUID().uuidString
    ) {
        self.modelHash = modelHash
        self.inputHash = inputHash
        self.params = params
        self.seed = seed
        self.backendVersion = backendVersion
        self.timestamp = timestamp
        self.requestId = requestId
    }
}

/// Run receipt - court-safe evidence of execution
public struct ModelRunReceipt: Codable, Hashable, Sendable {
    public let runSpec: ModelRunSpec
    public let outputHash: String
    public let policyDecision: String
    public let metrics: ModelExecutionMetrics
    public let timestamp: Date
    public let signature: String?

    public init(
        runSpec: ModelRunSpec,
        outputHash: String,
        policyDecision: String,
        metrics: ModelExecutionMetrics,
        timestamp: Date = Date(),
        signature: String? = nil
    ) {
        self.runSpec = runSpec
        self.outputHash = outputHash
        self.policyDecision = policyDecision
        self.metrics = metrics
        self.timestamp = timestamp
        self.signature = signature
    }
}

/// Execution metrics for evidence
public struct ModelExecutionMetrics: Codable, Hashable, Sendable {
    public let durationMs: Int64
    public let tokensGenerated: Int?
    public let tokensPerSecond: Double?
    public let memoryUsedMB: Int64?
    public let backendInfo: String

    public init(
        durationMs: Int64,
        tokensGenerated: Int? = nil,
        tokensPerSecond: Double? = nil,
        memoryUsedMB: Int64? = nil,
        backendInfo: String
    ) {
        self.durationMs = durationMs
        self.tokensGenerated = tokensGenerated
        self.tokensPerSecond = tokensPerSecond
        self.memoryUsedMB = memoryUsedMB
        self.backendInfo = backendInfo
    }
}
