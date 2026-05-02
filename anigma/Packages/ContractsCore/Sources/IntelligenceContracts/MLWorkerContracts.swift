//
//  MLWorkerContracts.swift
//  ContractsCore
//
//  Contract definition for MLWorkerContracts in ContractsCore.
//

import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import AnigmaPrimitives
import Foundation
import ArgumentParser
import CryptoKit

// MARK: - ML Worker Engine Types

/// ML Worker engine enumeration with explicit cases
public enum MLWorkerEngine: String, Codable, Sendable, CaseIterable, ExpressibleByArgument {
    case mlx = "mlx"
    case llama = "llama"
    case deepseek = "deepseek"
    case coreml = "coreml"
}

// MARK: - ML Worker Task Types

/// ML Worker task enumeration
public enum MLWorkerTask: String, Codable, Sendable {
    case embed = "embed"
    case chat = "chat"
    case summarize = "summarize"
    case classify = "classify"
    case rerank = "rerank"
    case transcribe = "transcribe"
    case other = "other"
}

// MARK: - ML Worker Artifact Types

/// Reference to ML worker artifact
public struct MLArtifactRef: Sendable, Codable {
    public let path: String
    public let hash: String

    public init(path: String, hash: String) {
        self.path = path
        self.hash = hash
    }

    private enum CodingKeys: String, CodingKey {
        case path, hash
    }
}

// MARK: - ML Worker Task Options

/// Configuration options for ML worker tasks
public struct MLTaskOptions: Sendable, Codable {
    public let seed: Int
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let outputDirectory: String?

    public init(seed: Int, maxTokens: Int? = nil, temperature: Double? = nil, topP: Double? = nil, outputDirectory: String? = nil) {
        self.seed = seed
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.outputDirectory = outputDirectory
    }

    private enum CodingKeys: String, CodingKey {
        case seed, maxTokens, temperature, topP, outputDirectory
    }
}

// MARK: - ML Worker Metrics Types

/// ML worker metrics for performance tracking
public struct MLWorkerMetrics: Sendable, Codable {
    public let tokensPerSecond: Double?
    public let totalTokens: Int?
    public let processingTimeMs: Int?
    public let durationMs: Int?
    public let tokensProcessed: Int?
    public let tokensGenerated: Int?
    public let memoryBytes: Int?

    public init(
        tokensPerSecond: Double? = nil,
        totalTokens: Int? = nil,
        processingTimeMs: Int? = nil,
        durationMs: Int? = nil,
        tokensProcessed: Int? = nil,
        tokensGenerated: Int? = nil,
        memoryBytes: Int? = nil
    ) {
        self.tokensPerSecond = tokensPerSecond
        self.totalTokens = totalTokens
        self.processingTimeMs = processingTimeMs
        self.durationMs = durationMs
        self.tokensProcessed = tokensProcessed
        self.tokensGenerated = tokensGenerated
        self.memoryBytes = memoryBytes
    }
}

// MARK: - Governed Execution Types

/// Run specification for governed ML execution
public struct RunSpec: Sendable, Codable, Hashable {
    public struct Input: Sendable, Codable, Hashable {
        public let path: String?
        public let hash: String
        public let kind: String

        public init(path: String? = nil, hash: String, kind: String) {
            self.path = path
            self.hash = hash
            self.kind = kind
        }
    }

    public let runId: String
    public let taskKind: MLWorkerTask
    public let backend: String
    public let inputs: [Input]
    public let seed: Int
    public let temperature: Double?
    public let topP: Double?
    public let maxTokens: Int?

    public init(
        runId: String,
        taskKind: MLWorkerTask,
        backend: String,
        inputs: [Input],
        seed: Int = 42,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.runId = runId
        self.taskKind = taskKind
        self.backend = backend
        self.inputs = inputs
        self.seed = seed
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
    }
}

/// Device identity for runtime provenance tracking
public struct DeviceIdentity: Sendable, Codable, Hashable {
    public let osVersion: String
    public let architecture: String
    public let deviceModel: String
    public let runtimeInfo: [String: String]
    
    public init(osVersion: String, architecture: String, deviceModel: String, runtimeInfo: [String: String] = [:]) {
        self.osVersion = osVersion
        self.architecture = architecture
        self.deviceModel = deviceModel
        self.runtimeInfo = runtimeInfo
    }
}

/// Execution receipt for court-safe evidence chain
public struct ExecutionReceipt: Sendable, Codable, Hashable {
    public struct Output: Sendable, Codable, Hashable {
        public let artifactId: String
        public let path: String
        public let hash: String
        public let kind: String

        public init(artifactId: String, path: String, hash: String, kind: String) {
            self.artifactId = artifactId
            self.path = path
            self.hash = hash
            self.kind = kind
        }
    }

    public let receiptSchemaVersion: Int
    public let runId: String
    public let modelId: String
    public let modelHash: String
    public let tokenizerHash: String?
    public let taskKind: MLWorkerTask
    public let backend: String
    public let inputs: [RunSpec.Input]
    public let outputs: [Output]
    public let seed: Int
    public let temperature: Double?
    public let topP: Double?
    public let maxTokens: Int?
    public let executionTimeMs: Int?
    public let tokensGenerated: Int?
    public let timestamp: Date
    public var deterministicHash: String
    public let deviceIdentity: DeviceIdentity?
    public let embeddingDimension: Int?
    public let poolingMode: String?
    public let preprocessingPolicyHash: String?

    public init(
        receiptSchemaVersion: Int = 0,
        runId: String,
        modelId: String,
        modelHash: String,
        tokenizerHash: String? = nil,
        taskKind: MLWorkerTask,
        backend: String,
        inputs: [RunSpec.Input],
        outputs: [Output],
        seed: Int,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        executionTimeMs: Int? = nil,
        tokensGenerated: Int? = nil,
        timestamp: Date = Date(),
        deterministicHash: String = "",
        deviceIdentity: DeviceIdentity? = nil,
        embeddingDimension: Int? = nil,
        poolingMode: String? = nil,
        preprocessingPolicyHash: String? = nil
    ) {
        self.receiptSchemaVersion = receiptSchemaVersion
        self.runId = runId
        self.modelId = modelId
        self.modelHash = modelHash
        self.tokenizerHash = tokenizerHash
        self.taskKind = taskKind
        self.backend = backend
        self.inputs = inputs
        self.outputs = outputs
        self.seed = seed
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.executionTimeMs = executionTimeMs
        self.tokensGenerated = tokensGenerated
        self.timestamp = timestamp
        self.deterministicHash = deterministicHash
        self.deviceIdentity = deviceIdentity
        self.embeddingDimension = embeddingDimension
        self.poolingMode = poolingMode
        self.preprocessingPolicyHash = preprocessingPolicyHash
    }

    public func computeHash() -> String {
        var parts: [String] = []
        parts.append("\(receiptSchemaVersion)")
        parts.append(runId)
        parts.append(modelId)
        parts.append(modelHash)
        if let tokHash = tokenizerHash {
            parts.append(tokHash)
        }
        parts.append(taskKind.rawValue)
        parts.append(backend)

        for input in inputs.sorted(by: { $0.hash < $1.hash }) {
            parts.append(input.hash)
        }

        for output in outputs.sorted(by: { $0.hash < $1.hash }) {
            parts.append(output.hash)
        }

        parts.append("\(seed)")
        if let temp = temperature {
            parts.append("\(temp)")
        }
        if let topP = topP {
            parts.append("\(topP)")
        }
        if let maxTokens = maxTokens {
            parts.append("\(maxTokens)")
        }

        // Schema version 1+ includes additional fields
        if receiptSchemaVersion >= 1 {
            if let device = deviceIdentity {
                parts.append("device:\(device.osVersion)")
                parts.append("device:\(device.architecture)")
                parts.append("device:\(device.deviceModel)")
                // Sort runtimeInfo keys for determinism
                for key in device.runtimeInfo.keys.sorted() {
                    if let value = device.runtimeInfo[key] {
                        parts.append("runtime:\(key):\(value)")
                    }
                }
            }
            if let dim = embeddingDimension {
                parts.append("embeddingDimension:\(dim)")
            }
            if let mode = poolingMode {
                parts.append("poolingMode:\(mode)")
            }
            if let policyHash = preprocessingPolicyHash {
                parts.append("preprocessingPolicyHash:\(policyHash)")
            }
        }

        let combined = parts.joined(separator: "|")
        return BLAKE3Digest.hex(of: Data(combined.utf8))
    }
}

/// ML worker engine metadata for provenance tracking
public struct MLWorkerEngineMetadata: Sendable, Codable {
    public let binaryHash: String
    public let version: String
    public let modelId: String?
    public let modelHash: String?
    public let binaryVersion: String?

    public init(
        binaryHash: String,
        version: String,
        modelId: String? = nil,
        modelHash: String? = nil,
        binaryVersion: String? = nil
    ) {
        self.binaryHash = binaryHash
        self.version = version
        self.modelId = modelId
        self.modelHash = modelHash
        self.binaryVersion = binaryVersion
    }
}

// MARK: - ML Worker Status Types

/// ML Worker execution status
public enum MLWorkerStatus: String, Codable, Sendable {
    case completed = "completed"
    case failed = "failed"
    case timeout = "timeout"
}

// MARK: - ML Worker Request/Response Types

/// ML Worker request with explicit contract conformance
public struct MLWorkerRequest: Sendable, Codable {
    public let requestId: String
    public let runId: String
    public let stepId: String
    public let engine: MLWorkerEngine
    public let task: MLWorkerTask
    public let inputs: [MLArtifactRef]
    public let options: MLTaskOptions

    public init(requestId: String, runId: String, stepId: String, engine: MLWorkerEngine, task: MLWorkerTask, inputs: [MLArtifactRef], options: MLTaskOptions) {
        self.requestId = requestId
        self.runId = runId
        self.stepId = stepId
        self.engine = engine
        self.task = task
        self.inputs = inputs
        self.options = options
    }

    private enum CodingKeys: String, CodingKey {
        case requestId, runId, stepId, engine, task, inputs, options
    }
}

/// ML Worker response with explicit contract conformance
public struct MLWorkerResponse: Sendable, Codable {
    /// Metrics for performance tracking
    public let metrics: MLWorkerMetrics?
    /// Engine metadata for provenance tracking
    public let engineMeta: MLWorkerEngineMetadata?
    /// Error message for failed responses
    public let errorMessage: String?
    public let requestId: String
    public let status: MLWorkerStatus
    public let outputs: [MLArtifactRef]

    public init(
        requestId: String,
        status: MLWorkerStatus,
        outputs: [MLArtifactRef],
        metrics: MLWorkerMetrics? = nil,
        engineMeta: MLWorkerEngineMetadata? = nil,
        errorMessage: String? = nil
    ) {
        self.requestId = requestId
        self.status = status
        self.outputs = outputs
        self.metrics = metrics
        self.engineMeta = engineMeta
        self.errorMessage = errorMessage
    }

    private enum CodingKeys: String, CodingKey {
        case metrics, engineMeta, errorMessage, requestId, status, outputs
    }
}

// MARK: - Embedding Types

/// Embedding header metadata for transport
public struct EmbeddingHeader: Sendable, Codable {
    public let modelHash: String
    public let engine: EngineMetadata
    public let argv: [String]
    public let options: [String: String]
    public let dimensions: Int
    /// Explicit embedding dimension (vector length). Optional for backward compatibility.
    public let embeddingDimension: Int?
    public let dataPath: String

    public init(modelHash: String, engine: EngineMetadata, argv: [String], options: [String: String], dimensions: Int, dataPath: String, embeddingDimension: Int? = nil) {
        self.modelHash = modelHash
        self.engine = engine
        self.argv = argv
        self.options = options
        self.dimensions = dimensions
        self.dataPath = dataPath
        self.embeddingDimension = embeddingDimension
    }

    private enum CodingKeys: String, CodingKey {
        case modelHash, engine, argv, options, dimensions, dataPath, embeddingDimension
    }
}

/// Engine metadata for transport
public struct EngineMetadata: Sendable, Codable {
    public let binaryHash: String
    public let version: String

    public init(binaryHash: String, version: String) {
        self.binaryHash = binaryHash
        self.version = version
    }

    private enum CodingKeys: String, CodingKey {
        case binaryHash, version
    }
}

// MARK: - Contract Conformances

extension MLWorkerRequest: WorkflowContract {
    public static let id = ContractID(
        name: "mlworker.request",
        major: 1,
        minor: 0,
        schemaHash: "blake3:mlworker-request-v1.0"
    )

    public static func validateInvariants(_ value: MLWorkerRequest) throws {
        // Validate required fields
        guard !value.requestId.isEmpty else {
            throw ValidationError.invalidRequest("requestId cannot be empty")
        }
        guard !value.runId.isEmpty else {
            throw ValidationError.invalidRequest("runId cannot be empty")
        }
        guard !value.stepId.isEmpty else {
            throw ValidationError.invalidRequest("stepId cannot be empty")
        }
        guard !value.inputs.isEmpty else {
            throw ValidationError.invalidRequest("inputs cannot be empty")
        }
    }
}

extension MLWorkerResponse: WorkflowContract {
    public static let id = ContractID(
        name: "mlworker.response",
        major: 1,
        minor: 0,
        schemaHash: "blake3:mlworker-response-v1.0"
    )

    public static func validateInvariants(_ value: MLWorkerResponse) throws {
        // Validate response structure
        guard !value.requestId.isEmpty else {
            throw ValidationError.invalidResponse("requestId cannot be empty")
        }
        guard !value.outputs.isEmpty || value.status == .failed else {
            throw ValidationError.invalidResponse("successful responses must have outputs")
        }
    }
}
