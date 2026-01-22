//
//  Authorities.swift
//  AnigmaCore
//
//  Authority protocols for the Platform Runtime (Tier 2).
//  Authorities are the ONLY way for capability modules to interact with infrastructure.
//
//  See ADR-0006: Three-Tier Runtime Architecture
//

import Foundation
import AnigmaPrimitives
import DatabaseCore
import InferenceCore

// MARK: - Evidence Authority

/// Authority for unified evidence recording and retrieval.
/// Consolidates ReceiptEngine, CathedralModule.EvidenceStore, and HarmoniaModule.EvidenceRecorder.
public protocol EvidenceAuthority: Actor {
    /// Record evidence for an operation
    /// - All evidence flows through this single entry point
    /// - Enforces evidence format requirements from governance
    /// - Stores in unified schema
    /// - Returns cryptographically signed receipt
    func record(
        operation: OperationType,
        principal: Principal,
        payload: EvidencePayload,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async throws -> Receipt

    /// Query evidence with access control
    /// - Principal must have permission to view evidence
    /// - Returns evidence bundles matching filter
    func query(
        filter: EvidenceFilter,
        principal: Principal
    ) async throws -> [EvidenceBundle]

    /// Verify evidence chain integrity
    /// - Checks cryptographic hash
    /// - Validates chain of custody
    func verify(receiptId: ReceiptID) async throws -> VerificationResult
}

/// Sink for forwarding recorded evidence to external systems (e.g. Cathedral).
public protocol EvidenceSink: Actor {
    /// Receive evidence after it has been recorded by the runtime.
    func record(
        receipt: Receipt,
        payload: EvidencePayload,
        operation: OperationType,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async
}

/// Filter for evidence queries
public struct EvidenceFilter: Sendable {
    public let operationTypes: [OperationType]?
    public let principalIds: [String]?
    public let afterTimestamp: Date?
    public let beforeTimestamp: Date?
    public let sessionId: String?

    public init(
        operationTypes: [OperationType]? = nil,
        principalIds: [String]? = nil,
        afterTimestamp: Date? = nil,
        beforeTimestamp: Date? = nil,
        sessionId: String? = nil
    ) {
        self.operationTypes = operationTypes
        self.principalIds = principalIds
        self.afterTimestamp = afterTimestamp
        self.beforeTimestamp = beforeTimestamp
        self.sessionId = sessionId
    }
}

/// Evidence bundle with full provenance
public struct EvidenceBundle: Sendable, Identifiable {
    public let id: ReceiptID
    public let receipt: Receipt
    public let payload: EvidencePayload
    public let governanceDecision: GovernanceDecision?
    public let chainHash: String

    public init(
        id: ReceiptID,
        receipt: Receipt,
        payload: EvidencePayload,
        governanceDecision: GovernanceDecision?,
        chainHash: String
    ) {
        self.id = id
        self.receipt = receipt
        self.payload = payload
        self.governanceDecision = governanceDecision
        self.chainHash = chainHash
    }
}

/// Result of evidence verification
public struct VerificationResult: Sendable {
    public let isValid: Bool
    public let violations: [String]
    public let chainIntact: Bool
    public let timestampValid: Bool

    public init(
        isValid: Bool,
        violations: [String] = [],
        chainIntact: Bool = true,
        timestampValid: Bool = true
    ) {
        self.isValid = isValid
        self.violations = violations
        self.chainIntact = chainIntact
        self.timestampValid = timestampValid
    }
}

/// Governance decision record (from WriteGate)
public struct GovernanceDecision: Sendable, Codable {
    public let allowed: Bool
    public let reason: String?
    public let checkResults: [String: Bool]
    public let evaluatedAt: Date

    public init(
        allowed: Bool,
        reason: String? = nil,
        checkResults: [String: Bool] = [:],
        evaluatedAt: Date = Date()
    ) {
        self.allowed = allowed
        self.reason = reason
        self.checkResults = checkResults
        self.evaluatedAt = evaluatedAt
    }
}

// MARK: - Database Authority

/// Authority for governed database access.
/// Wraps DatabaseActor with governance enforcement and schema management.
public protocol DatabaseAuthority: Actor {
    /// Register a module schema
    /// - Called during module registration
    /// - Runtime performs migrations, not modules
    func registerSchema(_ schema: ModuleSchema) async throws

    /// Execute a query (read-only, no governance needed)
    /// - Returns raw database rows
    func query(_ sql: String, parameters: [String: String]) async throws -> [DatabaseRow]

    /// Execute a query with ordered parameters
    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow]

    /// Execute a governed mutation
    /// - Checks KillSwitch before execution
    /// - Checks WriteGate before execution
    /// - Records evidence after execution
    /// - Returns mutation receipt with evidence
    func mutate(
        _ mutation: DatabaseMutation,
        context: ExecutionContext
    ) async throws -> MutationReceipt

    /// Execute multiple mutations in a transaction
    /// - All mutations are governed
    /// - Either all succeed or all rollback
    func transaction(
        context: ExecutionContext,
        _ block: @Sendable () async throws -> Void
    ) async throws
}

// MARK: - Artifact Authority

/// Authority for unified artifact storage and retrieval.
/// Consolidates VaultAuthority and scattered artifact storage.
public protocol ArtifactAuthority: Actor {
    /// Store an artifact with evidence
    /// - Enforces storage policies from governance
    /// - Records evidence of storage
    /// - Returns content-addressed ID
    func store(
        _ artifact: Artifact,
        context: ExecutionContext
    ) async throws -> (id: ArtifactID, receipt: Receipt)

    /// Retrieve artifact with access control
    /// - Principal must have permission to access
    func retrieve(
        _ id: ArtifactID,
        principal: Principal
    ) async throws -> Artifact

    /// List artifacts matching filter
    func list(
        filter: ArtifactFilter,
        principal: Principal
    ) async throws -> [ArtifactMetadata]

    /// Delete artifact (governed)
    func delete(
        _ id: ArtifactID,
        context: ExecutionContext
    ) async throws -> Receipt
}

/// Filter for artifact queries
public struct ArtifactFilter: Sendable {
    public let mimeTypes: [String]?
    public let tags: [String]?
    public let createdAfter: Date?
    public let createdBefore: Date?

    public init(
        mimeTypes: [String]? = nil,
        tags: [String]? = nil,
        createdAfter: Date? = nil,
        createdBefore: Date? = nil
    ) {
        self.mimeTypes = mimeTypes
        self.tags = tags
        self.createdAfter = createdAfter
        self.createdBefore = createdBefore
    }
}

/// Metadata for an artifact (without content)
public struct ArtifactMetadata: Sendable, Identifiable {
    public let id: ArtifactID
    public let mimeType: String
    public let size: Int64
    public let createdAt: Date
    public let tags: [String]
    public let metadata: [String: String]

    public init(
        id: ArtifactID,
        mimeType: String,
        size: Int64,
        createdAt: Date,
        tags: [String],
        metadata: [String: String]
    ) {
        self.id = id
        self.mimeType = mimeType
        self.size = size
        self.createdAt = createdAt
        self.tags = tags
        self.metadata = metadata
    }
}

// MARK: - Execution Authority

/// Authority for workflow and job execution.
/// Owns the execution pipeline with governance and evidence enforcement.
public protocol ExecutionAuthority: Actor {
    /// Execute a workflow with full governance
    /// 1. Check governance (can this principal run this workflow?)
    /// 2. Execute workflow steps
    /// 3. Record evidence for each mutation
    /// 4. Return comprehensive receipt
    func execute<W: PlatformWorkflow>(
        _ workflow: W,
        context: ExecutionContext
    ) async throws -> Receipt

    /// Submit a job to the scheduler
    func submit(_ job: Job) async throws -> JobId

    /// Get job status
    func jobStatus(_ id: JobId) async throws -> JobRecord

    /// Cancel a job
    func cancel(_ id: JobId, principal: Principal) async throws
}

// MARK: - Accessibility Authority

/// Authority for system-wide accessibility features and text manipulation.
/// Governs interaction with macOS Accessibility APIs and UI automation.
public protocol AccessibilityAuthority: Actor {
    /// Check if the application has accessibility permissions
    func isTrusted() async -> Bool

    /// Request accessibility permissions from the user
    func requestPermissions() async -> Bool

    /// Get selected text from the currently active application
    /// - Returns: The selected text or nil if unavailable
    func getSelectedText(context: ExecutionContext) async throws -> String?

    /// Simulate typing text into the focused UI element
    /// - Parameter text: The string to type
    func simulateTyping(_ text: String, context: ExecutionContext) async throws

    /// Get the bounding rect of the insertion point (caret) in the focused element
    /// - Returns: The bounding rect in screen coordinates
    func getCaretRect(context: ExecutionContext) async throws -> CGRect?
}

// MARK: - Inference Authority

/// Authority for LLM inference and model management.
/// Governs local and remote model execution with performance and cost optimization.
public protocol InferenceAuthority: Actor {
    /// Execute a chat completion
    /// - Parameters:
    ///   - request: Completion request details
    ///   - priority: Execution priority (.ui, .background)
    ///   - context: Execution context
    func chatCompletion(
        _ request: InferenceRequest,
        priority: InferencePriority,
        speculativeConfig: SpeculativeConfiguration?,
        context: ExecutionContext
    ) async throws -> InferenceResponse

    /// Execute a background task (e.g., entity extraction, summarization)
    /// - Uses the worker model plane
    func backgroundTask(
        _ task: InferenceRequest,
        context: ExecutionContext
    ) async throws -> InferenceResponse

    /// Execute a reranking task
    /// - Parameters:
    ///   - request: Rerank request details
    ///   - priority: Execution priority
    ///   - context: Execution context
    func rerank(
        _ request: RerankRequest,
        priority: InferencePriority,
        context: ExecutionContext
    ) async throws -> RerankResponse

    /// Get health and status of inference planes
    func getStatus() async -> [InferencePlaneStatus]
}

// MARK: - Sandbox Authority

/// Authority for secure, isolated execution of untrusted code or tools.
public protocol SandboxAuthority: Actor {
    /// Execute a tool in a restricted sandbox
    /// - Parameters:
    ///   - code: The code or script to execute
    ///   - language: The language runtime (.python, .javascript, .wasm)
    ///   - constraints: Resource and access constraints
    func execute(
        code: String,
        language: ToolLanguage,
        constraints: SandboxConstraints,
        context: ExecutionContext
    ) async throws -> ToolResult
}

public enum ToolLanguage: String, Sendable, Codable {
    case python, javascript, wasm, shell
}

public struct SandboxConstraints: Sendable, Codable {
    public let allowNetwork: Bool
    public let allowFileSystem: Bool
    public let maxMemoryMb: Int
    public let timeoutSeconds: Int
}

public struct ToolResult: Sendable, Codable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int
}

// MARK: - Handoff Authority

/// Authority for delegating tasks between different execution planes (Local, Apple Intelligence, Cloud).
public protocol HandoffAuthority: Actor {
    /// Determine the best plane for a task based on privacy and performance requirements
    func determinePlane(for task: InferenceRequest, context: ExecutionContext) async -> HandoffDecision
}

public struct HandoffDecision: Sendable, Codable {
    public let plane: ExecutionPlane
    public let reason: String
}

public enum ExecutionPlane: String, Sendable, Codable {
    case localSecure       /// On-device, governed by Anigma
    case appleIntelligence /// macOS native AI (ImagePlayground, etc.)
    case governedCloud     /// Institutional cloud (Azure/AWS)
}

// MARK: - Workflow Protocol

/// Protocol for workflows that can be executed by the runtime.
public protocol PlatformWorkflow: Sendable {
    /// Type identifier for this workflow
    static var typeIdentifier: String { get }

    /// Execute the workflow
    /// - Parameters:
    ///   - context: Execution context with principal and metadata
    ///   - runtime: The platform runtime (for accessing authorities)
    /// - Returns: Workflow result with outputs
    func execute(
        context: ExecutionContext,
        runtime: RuntimeServices
    ) async throws -> PlatformWorkflowResult
}

/// Services provided by the runtime to workflows
public protocol RuntimeServices: Actor {
    var database: any DatabaseAuthority { get }
    var evidence: any EvidenceAuthority { get }
    var artifacts: any ArtifactAuthority { get }
    var governance: GovernanceController { get }
    var inference: any InferenceAuthority { get }
    var accessibility: any AccessibilityAuthority { get }
}

/// Result of a workflow execution
public struct PlatformWorkflowResult: Sendable {
    public let outcome: OperationOutcome
    public let summary: String?
    public let outputRefs: [EntityId]
    public let metadata: [String: String]

    public init(
        outcome: OperationOutcome,
        summary: String? = nil,
        outputRefs: [EntityId] = [],
        metadata: [String: String] = [:]
    ) {
        self.outcome = outcome
        self.summary = summary
        self.outputRefs = outputRefs
        self.metadata = metadata
    }
}
