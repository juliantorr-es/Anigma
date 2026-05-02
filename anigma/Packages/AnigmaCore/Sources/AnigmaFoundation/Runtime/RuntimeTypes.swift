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
import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts
import DatabaseCore
import GovernanceCore

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
public struct ExecutionContext: Sendable, Codable {
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
    
    /// Compatibility trace ID (UUID representation of correlationId)
    public let traceId: UUID
    
    /// Compatibility timestamp (alias for startedAt)
    public let timestamp: Date

    public init(
        principal: Principal,
        projectId: String? = nil,
        sessionId: String = UUID().uuidString,
        startedAt: Date = Date(),
        metadata: [String: String] = [:],
        correlationId: String = UUID().uuidString
    ) {
        self.principal = principal
        // Normalize projectId: treat empty strings as nil
        let trimmed = projectId?.trimmingCharacters(in: .whitespaces)
        self.projectId = (trimmed == nil || trimmed!.isEmpty) ? nil : trimmed
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.timestamp = startedAt
        self.metadata = metadata
        self.correlationId = correlationId
        // Ensure traceId is a valid UUID, fallback to new one if correlationId is not a UUID string
        self.traceId = UUID(uuidString: correlationId) ?? UUID()
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

// MARK: - CoreReceipt

/// Cryptographically signed receipt for an operation.
/// Returned from all runtime operations that mutate state or execute workflows.
public struct CoreReceipt: Sendable, Codable, Identifiable {
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
        "CoreReceipt(\(raw.prefix(8)))"
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
public enum CoreOperationType: String, Sendable {
    case workflowExecution
    case databaseMutation
    case artifactStorage
    case evidenceRecording
    case jobExecution
    case mlInference
    case fileProcessing
    case governance
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
    case hardwareHeartbeat(missionID: UUID, powerWatts: Float, opsPerJoule: Float, timestamp: Date)
    case custom(type: String, data: [String: String])

    public var typeIdentifier: String {
        switch self {
        case .workflowExecution: return "workflow_execution"
        case .databaseMutation: return "database_mutation"
        case .mlInference: return "ml_inference"
        case .artifactStorage: return "artifact_storage"
        case .hardwareHeartbeat: return "hardware_heartbeat"
        case .custom(let type, _): return "custom.\(type)"
        }
    }

    public func serialize() -> Data {
        var data = Data()
        data.append(typeIdentifier.data(using: .utf8) ?? Data())
        
        switch self {
        case .workflowExecution(let workflowType, let inputs, let outputs):
            data.append(workflowType.data(using: .utf8) ?? Data())
            for input in inputs { data.append(input.raw.uuidString.data(using: .utf8) ?? Data()) }
            for output in outputs { data.append(output.raw.uuidString.data(using: .utf8) ?? Data()) }
        case .databaseMutation(let sql, let rowsAffected):
            data.append(sql.data(using: .utf8) ?? Data())
            data.append(String(rowsAffected).data(using: .utf8) ?? Data())
        case .mlInference(let model, let prompt, let response):
            data.append(model.data(using: .utf8) ?? Data())
            data.append(prompt.data(using: .utf8) ?? Data())
            data.append(response.data(using: .utf8) ?? Data())
        case .artifactStorage(let artifactId, let size):
            data.append(artifactId.data(using: .utf8) ?? Data())
            data.append(String(size).data(using: .utf8) ?? Data())
        case .hardwareHeartbeat(let missionID, let powerWatts, let opsPerJoule, let timestamp):
            data.append(missionID.uuidString.data(using: .utf8) ?? Data())
            data.append(String(powerWatts).data(using: .utf8) ?? Data())
            data.append(String(opsPerJoule).data(using: .utf8) ?? Data())
            data.append(String(timestamp.timeIntervalSince1970).data(using: .utf8) ?? Data())
        case .custom(_, let customData):
            let sortedKeys = customData.keys.sorted()
            for key in sortedKeys {
                data.append(key.data(using: .utf8) ?? Data())
                data.append(customData[key]?.data(using: .utf8) ?? Data())
            }
        }
        return data
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

/// CoreReceipt returned from a database mutation
public struct MutationReceipt: Sendable {
    /// Number of rows affected
    public let rowsAffected: Int

    /// Evidence receipt for the mutation
    public let evidence: CoreReceipt

    public init(rowsAffected: Int, evidence: CoreReceipt) {
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

public enum RuntimeInitializationError: Error, LocalizedError, Sendable {
    case notInitialized
    case alreadyInitialized
    case governanceViolation(String)
    case writeBlocked(violation: GovernanceViolation)
    case evidenceRecordingFailed(String)
    case databaseError(String)
    case artifactNotFound(ArtifactID)
    case workflowExecutionFailed(String)
    case executionFailed(String)
    case configurationError(String)
    case invalidArgument(String)
    case systemNotFound(String)
    
    public var isGovernanceViolation: Bool {
        if case .governanceViolation = self {
            return true
        }
        if case .writeBlocked = self {
            return true
        }
        return false
    }

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Runtime not initialized"
        case .alreadyInitialized:
            return "Runtime already initialized"
        case .governanceViolation(let details):
            return "Governance violation: \(details)"
        case .writeBlocked(violation: let violation):
            return "Write blocked: \(violation.humanReadableMessage)"
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
        case .invalidArgument(let details):
            return "Invalid argument: \(details)"
        case .systemNotFound(let systemName):
            return "System not found: \(systemName)"
        }
    }
}

// MARK: - Governance Violation Extraction

/// Utility for extracting GovernanceViolation from any error type that wraps it.
/// This provides a stable API for long-running operations to detect governance denials
/// regardless of which error enum wrapper is used by the underlying authority.
public enum GovernanceViolationExtractor {
    /// Extract a GovernanceViolation from an error, if present.
    /// - Parameter error: Any error that might contain a governance violation
    /// - Returns: The wrapped GovernanceViolation, or nil if the error is not a governance denial
    public static func extract(from error: Error) -> GovernanceViolation? {
        // RuntimeInitializationError.writeBlocked (thrown by authorities)
        if let runtimeError = error as? RuntimeInitializationError,
           case .writeBlocked(let violation) = runtimeError {
            return violation
        }
        
        // GovernanceError.writeBlocked (thrown by governance layer)
        // Note: We can't directly import GovernanceError here without creating a circular dependency
        // in the module structure, so we use type name matching as a fallback
        if String(describing: type(of: error)).contains("GovernanceError") {
            let mirror = Mirror(reflecting: error)
            for child in mirror.children {
                if child.label == "writeBlocked",
                   let violation = child.value as? GovernanceViolation {
                    return violation
                }
            }
        }
        
        return nil
    }
}
