//
//  RuntimeTypes.swift
//  AnigmaCore
//
//  Core types for the Platform Runtime (Tier 2).
//  These types form the contract between capability modules and the runtime.
//
//  See ADR-0006: Three-Tier Runtime Architecture
//

import Foundation
import AnigmaPrimitives
import DatabaseCore

// MARK: - Principal

/// Represents an authenticated identity performing operations.
/// Used for access control and audit trails.
public struct Principal: Sendable, Codable, Hashable {
    /// Unique identifier for the principal (user ID, service account, etc.)
    public let id: String

    /// Display name for audit logs
    public let displayName: String

    /// Attributes for ABAC (Attribute-Based Access Control)
    public let attributes: [String: String]

    /// Roles for RBAC (Role-Based Access Control)
    public let roles: Set<String>

    public init(
        id: String,
        displayName: String,
        attributes: [String: String] = [:],
        roles: Set<String> = []
    ) {
        self.id = id
        self.displayName = displayName
        self.attributes = attributes
        self.roles = roles
    }

    /// System principal for internal operations
    public static let system = Principal(
        id: "system",
        displayName: "Anigma System",
        roles: ["system"]
    )

    /// Anonymous principal for unauthenticated operations
    public static let anonymous = Principal(
        id: "anonymous",
        displayName: "Anonymous User"
    )
}

// MARK: - Execution Context

/// Context for a workflow/job execution.
/// Carries authentication, project scope, and execution metadata.
public struct ExecutionContext: Sendable {
    /// Who is performing this operation
    public let principal: Principal

    /// Project scope (if applicable)
    public let projectId: String?

    /// Session identifier for grouping related operations
    public let sessionId: String

    /// When the execution started
    public let startedAt: Date

    /// Metadata for the execution
    public let metadata: [String: String]

    /// Correlation ID for distributed tracing
    public let correlationId: String

    public init(
        principal: Principal,
        projectId: String? = nil,
        sessionId: String = UUID().uuidString,
        startedAt: Date = Date(),
        metadata: [String: String] = [:],
        correlationId: String = UUID().uuidString
    ) {
        self.principal = principal
        self.projectId = projectId
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.metadata = metadata
        self.correlationId = correlationId
    }

    /// Create a child context (same principal, new correlation ID)
    public func childContext(metadata: [String: String] = [:]) -> ExecutionContext {
        ExecutionContext(
            principal: principal,
            projectId: projectId,
            sessionId: sessionId,
            startedAt: Date(),
            metadata: self.metadata.merging(metadata) { $1 },
            correlationId: UUID().uuidString
        )
    }
}

// MARK: - Receipt

/// Cryptographically signed receipt for an operation.
/// Returned from all runtime operations that mutate state or execute workflows.
public struct Receipt: Sendable, Codable, Identifiable {
    /// Unique receipt identifier
    public let id: ReceiptID

    /// Type of operation that generated this receipt
    public let operationType: String

    /// Who performed the operation
    public let principal: Principal

    /// When the operation occurred
    public let timestamp: Date

    /// Outcome of the operation
    public let outcome: OperationOutcome

    /// Summary of what happened
    public let summary: String?

    /// Metadata about the operation
    public let metadata: [String: String]

    /// Input entity references
    public let inputRefs: [EntityId]

    /// Output entity references created/modified
    public let outputRefs: [EntityId]

    /// BLAKE3 hash of the receipt content
    public let contentHash: String

    /// Duration in milliseconds
    public let durationMs: Int64

    public init(
        id: ReceiptID = ReceiptID(),
        operationType: String,
        principal: Principal,
        timestamp: Date = Date(),
        outcome: OperationOutcome,
        summary: String? = nil,
        metadata: [String: String] = [:],
        inputRefs: [EntityId] = [],
        outputRefs: [EntityId] = [],
        contentHash: String,
        durationMs: Int64 = 0
    ) {
        self.id = id
        self.operationType = operationType
        self.principal = principal
        self.timestamp = timestamp
        self.outcome = outcome
        self.summary = summary
        self.metadata = metadata
        self.inputRefs = inputRefs
        self.outputRefs = outputRefs
        self.contentHash = contentHash
        self.durationMs = durationMs
    }
}

/// Unique identifier for a receipt
public struct ReceiptID: Hashable, Codable, Sendable, CustomStringConvertible, Identifiable {
    public let raw: String

    public var id: String { raw }

    public init() {
        self.raw = UUID().uuidString
    }

    public init(raw: String) {
        self.raw = raw
    }

    public var description: String {
        "Receipt(\(raw.prefix(8)))"
    }
}

extension ReceiptID: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.raw = value
    }
}

/// Outcome classification for operations
public enum OperationOutcome: String, Codable, Sendable {
    case success
    case partialSuccess
    case failure
    case denied
    case requiresInput
}

// MARK: - Operation Types

/// Types of operations that generate receipts
public enum OperationType: String, Sendable {
    case workflowExecution
    case databaseMutation
    case artifactStorage
    case evidenceRecording
    case jobExecution
    case mlInference
    case fileProcessing
    case custom
}

// MARK: - Evidence Payload

/// Payload for evidence recording.
/// Contains operation-specific data that needs to be preserved.
public enum EvidencePayload: Sendable {
    case workflowExecution(workflowType: String, inputs: [EntityId], outputs: [EntityId])
    case databaseMutation(sql: String, rowsAffected: Int)
    case mlInference(model: String, prompt: String, response: String)
    case artifactStorage(artifactId: String, size: Int64)
    case custom(type: String, data: [String: String])

    public var typeIdentifier: String {
        switch self {
        case .workflowExecution: return "workflow_execution"
        case .databaseMutation: return "database_mutation"
        case .mlInference: return "ml_inference"
        case .artifactStorage: return "artifact_storage"
        case .custom(let type, _): return "custom.\(type)"
        }
    }
}

// MARK: - Module Schema

/// Schema definition for a capability module.
/// Modules register schemas with the runtime instead of creating tables directly.
public struct ModuleSchema: Sendable {
    /// Unique name for the schema (e.g., "harmonia_sessions")
    public let name: String

    /// Current version of the schema
    public let version: Int

    /// Module that owns this schema
    public let module: String

    /// Migration SQL for each version
    /// Key: version number, Value: SQL to migrate from previous version
    public let migrations: [Int: String]

    public init(
        name: String,
        version: Int,
        module: String,
        migrations: [Int: String]
    ) {
        self.name = name
        self.version = version
        self.module = module
        self.migrations = migrations
    }
}

// MARK: - Database Request/Mutation

/// A type-safe database query request
public protocol DatabaseRequest<ResultType>: Sendable {
    associatedtype ResultType: Sendable

    /// SQL query to execute
    var sql: String { get }

    /// Parameters for the query
    var parameters: [String: Any] { get }

    /// Parse a database row into the result type
    func parse(row: [String: Any]) throws -> ResultType
}

/// A database mutation (insert/update/delete)
public struct DatabaseMutation: Sendable {
    /// SQL statement to execute
    public let sql: String

    /// Parameters for the statement
    public let parameters: [DatabaseParameter]

    /// Component type being mutated (for governance)
    public let componentType: String?

    /// Entity being mutated (if applicable)
    public let entityId: EntityId?

    public init(
        sql: String,
        parameters: [DatabaseParameter] = [],
        componentType: String? = nil,
        entityId: EntityId? = nil
    ) {
        self.sql = sql
        self.parameters = parameters
        self.componentType = componentType
        self.entityId = entityId
    }
}

/// Receipt returned from a database mutation
public struct MutationReceipt: Sendable {
    /// Number of rows affected
    public let rowsAffected: Int

    /// Evidence receipt for the mutation
    public let evidence: Receipt

    public init(rowsAffected: Int, evidence: Receipt) {
        self.rowsAffected = rowsAffected
        self.evidence = evidence
    }
}

// MARK: - Artifact

/// An artifact (file, binary data, ML model, etc.)
public struct Artifact: Sendable {
    /// Content-addressed identifier (hash of content)
    public let id: ArtifactID

    /// MIME type
    public let mimeType: String

    /// Size in bytes
    public let size: Int64

    /// Creation timestamp
    public let createdAt: Date

    /// Tags for categorization
    public let tags: [String]

    /// Metadata
    public let metadata: [String: String]

    /// Content (may be loaded lazily)
    public let content: Data?

    public init(
        id: ArtifactID,
        mimeType: String,
        size: Int64,
        createdAt: Date = Date(),
        tags: [String] = [],
        metadata: [String: String] = [:],
        content: Data? = nil
    ) {
        self.id = id
        self.mimeType = mimeType
        self.size = size
        self.createdAt = createdAt
        self.tags = tags
        self.metadata = metadata
        self.content = content
    }
}

/// Content-addressed artifact identifier
public struct ArtifactID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let hash: String

    public init(hash: String) {
        self.hash = hash
    }

    public var description: String {
        "Artifact(\(hash.prefix(8)))"
    }
}

// MARK: - Runtime Configuration

/// Configuration for PlatformRuntime
public struct RuntimeConfiguration: Sendable {
    /// Runtime mode (local vs remote)
    public let mode: RuntimeMode

    /// Database path (for local mode)
    public let databasePath: String?

    /// Daemon URL (for remote mode)
    public let daemonURL: String?

    /// Enable governance enforcement
    public let enforceGovernance: Bool

    /// Enable evidence recording
    public let recordEvidence: Bool

    /// Maximum concurrent jobs
    public let maxConcurrentJobs: Int

    public init(
        mode: RuntimeMode = .local,
        databasePath: String? = nil,
        daemonURL: String? = nil,
        enforceGovernance: Bool = true,
        recordEvidence: Bool = true,
        maxConcurrentJobs: Int = 10
    ) {
        self.mode = mode
        self.databasePath = databasePath
        self.daemonURL = daemonURL
        self.enforceGovernance = enforceGovernance
        self.recordEvidence = recordEvidence
        self.maxConcurrentJobs = maxConcurrentJobs
    }

    /// Production configuration (local, all enforcement enabled)
    public static let production = RuntimeConfiguration(
        mode: .local,
        enforceGovernance: true,
        recordEvidence: true
    )

    /// Testing configuration (local, no enforcement)
    public static let testing = RuntimeConfiguration(
        mode: .local,
        enforceGovernance: false,
        recordEvidence: false
    )

    /// Daemon configuration (local, full enforcement, high concurrency)
    public static let daemon = RuntimeConfiguration(
        mode: .local,
        enforceGovernance: true,
        recordEvidence: true,
        maxConcurrentJobs: 50
    )
}

/// Runtime execution mode
public enum RuntimeMode: String, Sendable {
    /// Local execution (in-process)
    case local

    /// Remote execution (via daemon)
    case remote
}

// MARK: - Runtime Errors

public enum RuntimeError: Error, LocalizedError, Sendable {
    case notInitialized
    case alreadyInitialized
    case governanceViolation(String)
    case evidenceRecordingFailed(String)
    case databaseError(String)
    case artifactNotFound(ArtifactID)
    case workflowExecutionFailed(String)
    case executionFailed(String)
    case configurationError(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Runtime not initialized"
        case .alreadyInitialized:
            return "Runtime already initialized"
        case .governanceViolation(let details):
            return "Governance violation: \(details)"
        case .evidenceRecordingFailed(let details):
            return "Evidence recording failed: \(details)"
        case .databaseError(let details):
            return "Database error: \(details)"
        case .artifactNotFound(let id):
            return "Artifact not found: \(id)"
        case .workflowExecutionFailed(let details):
            return "Workflow execution failed: \(details)"
        case .executionFailed(let details):
            return "Execution failed: \(details)"
        case .configurationError(let details):
            return "Configuration error: \(details)"
        }
    }
}
