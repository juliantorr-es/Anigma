//
//  Authorities.swift
//  AnigmaCore
//
//  Protocol definitions for Tier 2 Authorities.
//  These define the "governed surface" of the platform.
//
//  See ADR-0006: Three-Tier Runtime Architecture
//

import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts
import Foundation
import DatabaseCore
import InferenceCore
@_exported import GovernanceCore
import AnigmaPrimitives

// MARK: - Evidence Authority

/// Authority for recording and verifying cryptographic evidence of all platform operations.
/// Consolidates CathedralModule and scattered evidence recording logic.
public protocol EvidenceAuthority: Actor {
    /// Record evidence of an operation
    /// - Parameters:
    ///   - operation: Type of operation being recorded
    ///   - principal: Principal performing the operation
    ///   - payload: Operation-specific evidence data
    ///   - governanceDecision: Decision record from governance (if applicable)
    ///   - context: Execution context
    /// - Returns cryptographically signed receipt
    func record(
        operation: CoreOperationType,
        principal: Principal,
        payload: EvidencePayload,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async throws -> CoreReceipt

    /// Query evidence with access control
    /// - Principal must have permission to view evidence
    /// - Returns evidence bundles matching filter
    func query(
        filter: EvidenceFilter,
        principal: Principal
    ) async throws -> [EvidenceBundle]

    /// Verify a receipt and its chain of custody
    /// - Checks cryptographic hash
    /// - Validates chain of custody
    func verify(receiptId: ReceiptID) async throws -> VerificationResult
}

/// Sink for evidence recorded by the runtime (e.g., Cathedral)
public protocol EvidenceSink: Actor, Sendable {
    /// Receive evidence after it has been recorded by the runtime.
    func record(
        receipt: CoreReceipt,
        payload: EvidencePayload,
        operation: CoreOperationType,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async throws
}

/// Filter for evidence queries
public struct EvidenceFilter: Sendable {
    public let operationTypes: [CoreOperationType]?
    public let principalIds: [String]?
    public let afterTimestamp: Date?
    public let beforeTimestamp: Date?

    public init(
        operationTypes: [CoreOperationType]? = nil,
        principalIds: [String]? = nil,
        afterTimestamp: Date? = nil,
        beforeTimestamp: Date? = nil
    ) {
        self.operationTypes = operationTypes
        self.principalIds = principalIds
        self.afterTimestamp = afterTimestamp
        self.beforeTimestamp = beforeTimestamp
    }
}

/// Bundle of evidence including CoreReceipt and payload
public struct EvidenceBundle: Sendable, Identifiable {
    public let id: ReceiptID
    public let receipt: CoreReceipt
    public let payload: EvidencePayload
    public let governanceDecision: GovernanceDecision?
    public let chainHash: String

    public init(
        id: ReceiptID,
        receipt: CoreReceipt,
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
        _ block: @escaping @Sendable () async throws -> Void
    ) async throws
    
    /// Check if the database supports vector operations (e.g. pgvector)
    func isVectorAvailable() async -> Bool
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
    ) async throws -> (id: ArtifactID, receipt: CoreReceipt)

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
    ) async throws -> CoreReceipt
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
public struct ArtifactMetadata: Sendable, Codable, Identifiable {
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
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.mimeType = mimeType
        self.size = size
        self.createdAt = createdAt
        self.tags = tags
        self.metadata = metadata
    }
}

// MARK: - Inference Authority

/// Authority for governed access to AI models.
/// Enforces usage policies and ensures evidence recording.
public protocol InferenceAuthority: Actor {
    /// Perform a chat completion
    /// - Parameters:
    ///   - request: Inference request
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

    /// Perform a rerank operation
    /// - Parameters:
    ///   - request: Rerank request
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

public struct SpeculativeConfiguration: Sendable, Codable {
    public let enabled: Bool
    public let modelID: String?
}

public struct RerankRequest: Sendable, Codable {
    public let query: String
    public let documents: [String]
    public let topN: Int
}

public struct RerankResponse: Sendable, Codable {
    public let results: [RerankResult]
}

public struct RerankResult: Sendable, Codable {
    public let index: Int
    public let score: Double
}

// MARK: - Accessibility Authority

/// Authority for system interaction and UI automation.
/// Governs access to system APIs (selected text, simulation).
public protocol AccessibilityAuthority: Actor {
    /// Check if accessibility permissions are granted
    func isTrusted() async -> Bool

    /// Request accessibility permissions
    func requestPermissions() async -> Bool

    /// Get currently selected text in the focused application
    func getSelectedText(context: ExecutionContext) async throws -> String?

    /// Simulate typing text
    func simulateTyping(_ text: String, context: ExecutionContext) async throws

    /// Get the screen coordinates of the text caret
    func getCaretRect(context: ExecutionContext) async throws -> CGRect?
}

// MARK: - Source Authority

/// Authority for managing content sources (Intake).
/// Governs access to external data sources and persistent connection state.
public protocol SourceAuthority: Actor {
    /// List all registered sources
    func listSources(principal: Principal) async throws -> [AnigmaSource]

    /// Add a new content source
    func addSource(_ source: AnigmaSource, context: ExecutionContext) async throws -> (id: String, receipt: CoreReceipt)

    /// Update an existing content source
    func updateSource(_ source: AnigmaSource, context: ExecutionContext) async throws -> CoreReceipt

    /// Remove a content source
    func removeSource(id: String, context: ExecutionContext) async throws -> CoreReceipt

    /// Get status of a specific source
    func getSourceStatus(id: String, principal: Principal) async throws -> AnigmaSourceStatus
}

// MARK: - Execution Authority

/// Authority for executing workflows and background jobs.
/// THE entry point for multi-authority operations.
public protocol ExecutionAuthority: Actor {
    /// Execute a workflow (governed)
    /// - Enforces access control
    /// - Records operation evidence
    /// - Returns CoreReceipt
    func execute<W: PlatformWorkflow>(
        _ workflow: W,
        context: ExecutionContext
    ) async throws -> CoreReceipt

    /// Submit a job to the scheduler
    func submit(_ job: Job) async throws -> JobId

    /// Get job status
    func jobStatus(_ id: JobId) async throws -> JobRecord

    /// Cancel a job
    func cancel(_ id: JobId, principal: Principal) async throws
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

// MARK: - Runtime Services

/// Services provided by the runtime to workflows.
/// Workflows use this protocol to access governed authorities.
public protocol RuntimeServices: Actor, RuntimeGovernanceAPI, RuntimeKillSwitchAPI {
    var database: any DatabaseAuthority { get }
    var evidence: any EvidenceAuthority { get }
    var artifacts: any ArtifactAuthority { get }
    var governance: any GoverningController { get }
    var inference: any InferenceAuthority { get }
    var accessibility: any AccessibilityAuthority { get }
    var sources: any SourceAuthority { get }
    
    #if DEBUG
    /// Diagnostic method for debugging: returns runtime instance identity and database path
    /// ONLY AVAILABLE IN DEBUG BUILDS
    func runtimeDiagnostics() -> (instanceId: UUID, dbPath: String)
    #endif
}

// MARK: - Sandbox Authority    
    /// Authority for secure code execution in a restricted environment.
    public protocol SandboxAuthority: Actor {
        /// Execute code in a sandbox
        /// - Parameters:
        ///   - code: Source code to execute
        ///   - language: Programming language
        ///   - constraints: Resource and permission constraints
        ///   - context: Execution context
        /// - Returns: Result of execution (output, status)
        func execute(
            code: String,
            language: ToolLanguage,
            constraints: SandboxConstraints,
            context: ExecutionContext
        ) async throws -> ToolResult
    }
    
    public enum ToolLanguage: String, Sendable, Codable {
        case python
        case swift
        case bash
    }
    
    public struct SandboxConstraints: Sendable, Codable {
        public let timeoutSeconds: Int
        public let maxMemoryMB: Int
        public let allowNetwork: Bool
        public let allowFileSystem: Bool
        public let allowedPaths: [String]
    
        public init(
            timeoutSeconds: Int = 30,
            maxMemoryMB: Int = 512,
            allowNetwork: Bool = false,
            allowFileSystem: Bool = false,
            allowedPaths: [String] = []
        ) {
            self.timeoutSeconds = timeoutSeconds
            self.maxMemoryMB = maxMemoryMB
            self.allowNetwork = allowNetwork
            self.allowFileSystem = allowFileSystem
            self.allowedPaths = allowedPaths
        }
    }
    
    public struct ToolResult: Sendable, Codable {
        public let stdout: String
        public let stderr: String
        public let exitCode: Int32
        public let durationMs: Int64
        public let timedOut: Bool
    
        public init(
            stdout: String,
            stderr: String,
            exitCode: Int32,
            durationMs: Int64,
            timedOut: Bool = false
        ) {
            self.stdout = stdout
            self.stderr = stderr
            self.exitCode = exitCode
            self.durationMs = durationMs
            self.timedOut = timedOut
        }
    }
    
