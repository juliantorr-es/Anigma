//
//  PlatformRuntime.swift
//  AnigmaCore
//
//  The Platform Runtime (Tier 2) - Integration layer for Anigma.
//  This is the ONLY entry point for workflow execution, state mutations, and evidence recording.
//
//  See ADR-0006: Three-Tier Runtime Architecture
//

import Foundation
import DatabaseCore
import InferenceCore

// MARK: - Platform Runtime

/// The Platform Runtime actor.
/// Owns the World, authorities, and provides the integration layer for all capability modules.
///
/// ## Architecture
/// - **Tier 1**: Governance (policy evaluation)
/// - **Tier 2**: PlatformRuntime (THIS - integration and enforcement)
/// - **Tier 3**: Capability modules (features)
///
/// ## Usage
/// ```swift
/// // Create runtime (one per app instance)
/// let runtime = try await PlatformRuntime(config: .production)
///
/// // Register modules
/// try await HarmoniaModule.register(runtime: runtime)
/// try await DiaplasionModule.register(runtime: runtime)
///
/// // Execute workflow
/// let context = ExecutionContext(principal: user)
/// let receipt = try await runtime.execute(CodeAnalysisWorkflow(), context: context)
/// ```
public actor PlatformRuntime {
    // MARK: - Core Infrastructure

    /// The ONE World instance for this runtime
    private let world: World

    /// Workflow registry for ECS workflows
    private let workflowRegistry: WorkflowRegistry

    /// Workflow runner for ECS workflows
    private let workflowRunner: WorkflowRunner

    /// Governance controller (from Tier 1)
    public let governance: GovernanceController

    /// Configuration
    private let config: RuntimeConfiguration

    /// Initialization state
    private var isInitialized: Bool = false

    // MARK: - Authorities

    /// Evidence authority (unified evidence recording)
    public let evidence: any EvidenceAuthority

    /// Database authority (governed database access)
    public let database: any DatabaseAuthority

    /// Artifact authority (unified artifact storage)
    public let artifacts: any ArtifactAuthority

    /// Execution authority (workflow/job execution)
    public let execution: any ExecutionAuthority

    /// Inference authority (model access)
    public let inference: any InferenceAuthority

    /// Accessibility authority (system interaction)
    public let accessibility: any AccessibilityAuthority

    // MARK: - Registered Modules

    /// Registered module schemas (for migration tracking)
    private var registeredSchemas: [String: ModuleSchema] = [:]

    /// Registered workflow types
    private var registeredWorkflows: [String: Any] = [:]

    /// Registered capability module identifiers
    private var registeredModules: [String] = []

    // MARK: - Initialization

    /// Create a new platform runtime
    /// - Parameter config: Runtime configuration
    public init(config: RuntimeConfiguration = .production) async throws {
        self.config = config
        self.world = World()
        self.workflowRegistry = WorkflowRegistry()
        self.workflowRunner = WorkflowRunner(registry: workflowRegistry)

        // Initialize governance controller
        self.governance = GovernanceController()
        await governance.initialize()

        // Initialize authorities (Phase 1: Create wrappers around existing infrastructure)
        // Note: These are placeholder implementations that will be replaced in later phases

        // Database authority wraps DatabaseActor
        let dbActor = DatabaseActor(
            dbPath: config.databasePath ?? DatabaseConfiguration.defaultDatabasePath()
        )
        try await dbActor.open()
        self.database = DatabaseAuthorityImpl(
            databaseActor: dbActor,
            governance: governance,
            evidenceAuthority: nil as (any EvidenceAuthority)? // Will be wired after evidence is created
        )

        // Evidence authority consolidates evidence systems
        self.evidence = EvidenceAuthorityImpl(
            databaseAuthority: database,
            governance: governance
        )

        // Wire evidence into database authority (circular dependency resolved)
        await (database as! DatabaseAuthorityImpl).setEvidenceAuthority(evidence)

        // Artifact authority consolidates artifact storage
        self.artifacts = ArtifactAuthorityImpl(
            databaseAuthority: database,
            evidenceAuthority: evidence,
            governance: governance
        )

        // Initialize inference and accessibility placeholders for now
        let mockPlane = MockInferencePlane()
        let inferenceImpl = InferenceAuthorityImpl(
            uiPlane: mockPlane,
            workerPlane: mockPlane,
            governance: governance
        )
        self.inference = inferenceImpl

        let accessibilityImpl = MockAccessibilityAuthority()
        self.accessibility = accessibilityImpl

        // Execution authority owns workflow/job execution
        self.execution = ExecutionAuthorityImpl(
            world: world,
            governance: governance,
            evidenceAuthority: evidence,
            databaseAuthority: database,
            artifactsAuthority: artifacts,
            inferenceAuthority: inferenceImpl,
            accessibilityAuthority: accessibilityImpl
        )
    }

    /// Initialize the runtime
    /// - Must be called before using the runtime
    /// - Sets up core systems and prepares for module registration
    public func initialize() async throws {
        guard !isInitialized else {
            throw RuntimeError.alreadyInitialized
        }

        // Initialize database schemas (core tables)
        try await initializeCoreSchemas()

        // Set operating mode based on config
        if config.enforceGovernance {
            await governance.setMode(.assistive, by: "system")
        } else {
            await governance.setMode(.readOnly, by: "system")
        }

        isInitialized = true
    }

    /// Initialize core database schemas
    private func initializeCoreSchemas() async throws {
        // Create evidence tables
        try await (database as! DatabaseAuthorityImpl).executeDirectly("""
            CREATE TABLE IF NOT EXISTS evidence_bundles (
                id TEXT PRIMARY KEY,
                operation_type TEXT NOT NULL,
                principal_id TEXT NOT NULL,
                principal_name TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                outcome TEXT NOT NULL,
                summary TEXT,
                input_refs TEXT,
                output_refs TEXT,
                content_hash TEXT NOT NULL,
                duration_ms INTEGER NOT NULL,
                metadata TEXT,
                governance_decision TEXT,
                payload TEXT NOT NULL,
                chain_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )
        """)

        // Create receipt index
        try await (database as! DatabaseAuthorityImpl).executeDirectly("""
            CREATE INDEX IF NOT EXISTS idx_evidence_timestamp ON evidence_bundles(timestamp)
        """)
        try await (database as! DatabaseAuthorityImpl).executeDirectly("""
            CREATE INDEX IF NOT EXISTS idx_evidence_principal ON evidence_bundles(principal_id)
        """)

        // Create schema registry table
        try await (database as! DatabaseAuthorityImpl).executeDirectly("""
            CREATE TABLE IF NOT EXISTS schema_registry (
                name TEXT PRIMARY KEY,
                module TEXT NOT NULL,
                version INTEGER NOT NULL,
                migrated_at INTEGER NOT NULL
            )
        """)

        // Create artifact metadata table
        try await (database as! DatabaseAuthorityImpl).executeDirectly("""
            CREATE TABLE IF NOT EXISTS artifact_metadata (
                id TEXT PRIMARY KEY,
                mime_type TEXT NOT NULL,
                size INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                tags TEXT,
                metadata TEXT
            )
        """)

        // Create job queue table
        try await (database as! DatabaseAuthorityImpl).executeDirectly("""
            CREATE TABLE IF NOT EXISTS job_queue (
                id TEXT PRIMARY KEY,
                type_id TEXT NOT NULL,
                status TEXT NOT NULL,
                priority INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                scheduled_for INTEGER,
                attempts INTEGER DEFAULT 0,
                last_attempt_at INTEGER,
                completed_at INTEGER,
                error TEXT,
                job_data TEXT NOT NULL
            )
        """)
        // Create module registry table
        try await (database as! DatabaseAuthorityImpl).executeDirectly("""
            CREATE TABLE IF NOT EXISTS module_registry (
                module_name TEXT PRIMARY KEY,
                registered_at INTEGER NOT NULL,
                status TEXT NOT NULL
            )
        """)
    }

    // MARK: - Module Registration

    /// Register a capability module
    /// - Modules call this during app startup to register their capabilities
    public func registerModule<M: CapabilityModule>(_ module: M.Type) async throws {
        guard isInitialized else {
            throw RuntimeError.notInitialized
        }

        try await module.register(runtime: self)

        let moduleName = String(reflecting: module)
        if !registeredModules.contains(moduleName) {
            registeredModules.append(moduleName)
            try await recordModuleRegistration(moduleName)
        }
    }

    private func systemContext(metadata: [String: String] = [:]) -> ExecutionContext {
        ExecutionContext(principal: .system, metadata: metadata)
    }

    private func recordModuleRegistration(_ moduleName: String) async throws {
        let mutation = DatabaseMutation(
            sql: """
                INSERT INTO module_registry (module_name, registered_at, status)
                VALUES (?, ?, 'registered')
                ON CONFLICT(module_name) DO UPDATE SET
                    registered_at = excluded.registered_at,
                    status = 'registered'
                """,
            parameters: [
                .text(moduleName),
                .int(Int(Date().timeIntervalSince1970))
            ],
            componentType: "module_registration"
        )

        _ = try await database.mutate(mutation, context: systemContext(metadata: ["module": moduleName]))
    }

    /// Register an evidence sink for external systems (e.g. Cathedral)
    public func registerEvidenceSink(_ sink: any EvidenceSink) async throws {
        guard let evidenceImpl = evidence as? EvidenceAuthorityImpl else {
            throw RuntimeError.configurationError("Evidence authority does not support sinks")
        }

        await evidenceImpl.addSink(sink)
    }

    /// Legacy access for modules still bound to DatabaseActor.
    public func legacyDatabaseActor() async throws -> DatabaseActor {
        guard let databaseImpl = database as? DatabaseAuthorityImpl else {
            throw RuntimeError.configurationError("Database authority does not expose DatabaseActor")
        }

        return await databaseImpl.rawDatabaseActor()
    }

    /// Register a schema (called by modules during registration)
    public func registerSchema(_ schema: ModuleSchema) async throws {
        guard isInitialized else {
            throw RuntimeError.notInitialized
        }

        // Check if already registered at this version
        if let existing = registeredSchemas[schema.name], existing.version >= schema.version {
            return // Already migrated
        }

        // Perform migration
        try await (database as! DatabaseAuthorityImpl).migrateSchema(schema)

        // Record in registry
        registeredSchemas[schema.name] = schema
    }

    /// Register a workflow type
    public func registerWorkflow<W: PlatformWorkflow>(_ workflowType: W.Type) async {
        registeredWorkflows[W.typeIdentifier] = workflowType
    }

    /// Register a job workflow in the ECS registry
    public func registerJobWorkflow(_ workflow: any Workflow) async {
        await workflowRegistry.register(workflow)
    }

    /// Register a system with the World
    public func registerSystem(_ system: any AsyncSystem) async throws {
        try await world.registerSystem(system)
    }

    // MARK: - Workflow Execution

    /// Execute a workflow with full governance
    /// - This is THE entry point for all workflow execution
    /// - Governance is enforced
    /// - Evidence is recorded
    /// - Returns receipt
    public func execute<W: PlatformWorkflow>(
        _ workflow: W,
        context: ExecutionContext
    ) async throws -> Receipt {
        guard isInitialized else {
            throw RuntimeError.notInitialized
        }

        return try await execution.execute(workflow, context: context)
    }

    // MARK: - World Access

    /// Get the World instance
    /// - Should only be used by systems that need direct ECS access
    /// - Most operations should go through authorities instead
    public func getWorld() -> World {
        world
    }

    /// Get the ECS workflow registry
    public func getWorkflowRegistry() -> WorkflowRegistry {
        workflowRegistry
    }

    /// Get the ECS workflow runner
    public func getWorkflowRunner() -> WorkflowRunner {
        workflowRunner
    }

    // MARK: - Status

    /// Get runtime status
    public func status() async -> RuntimeStatus {
        let governanceStatus = await governance.status()
        let worldSnapshot = await world.snapshot()
        let jobWorkflowNames = await workflowRegistry.allWorkflowNames()
        let jobTypeIds = await workflowRegistry.allJobTypeIds()

        return RuntimeStatus(
            isInitialized: isInitialized,
            config: config,
            governanceStatus: governanceStatus,
            worldSnapshot: worldSnapshot,
            registeredSchemas: Array(registeredSchemas.keys),
            registeredWorkflows: Array(registeredWorkflows.keys),
            registeredJobWorkflows: jobWorkflowNames,
            registeredJobTypes: jobTypeIds,
            registeredModules: registeredModules
        )
    }

    // MARK: - Shutdown

    /// Shutdown the runtime
    /// - Closes database connections
    /// - Stops job scheduler
    /// - Cleans up resources
    public func shutdown() async {
        await (database as! DatabaseAuthorityImpl).close()
        isInitialized = false
    }
}

// MARK: - Runtime Services Implementation

extension PlatformRuntime: RuntimeServices {
    // Already provides database, evidence, artifacts, governance, inference, accessibility as properties
}

/// Mock ML worker interface for testing
struct MockMLWorkerInterface: MLWorkerInterface, Sendable {
    func performMLTask(
        task: MLWorkerTaskKind,
        input: String,
        modelID: String?,
        options: [String: AnyHashable]
    ) async throws -> String {
        // Return a deterministic mock response
        switch task {
        case .embedding:
            return "[0.1, 0.2, 0.3]" // Simple embedding vector
        case .chat:
            return "Mock response to: \(input.prefix(50))"
        }
    }
}

/// Placeholder for inference plane using mock ML worker
struct MockInferencePlane: InferencePlane, Sendable {
    private let mlWorker: MLWorkerInterface
    
    init(mlWorker: MLWorkerInterface = MockMLWorkerInterface()) {
        self.mlWorker = mlWorker
    }
    
    func perform(_ request: InferenceRequest) async throws -> InferenceResponse {
        let mlWorkerTask: MLWorkerTaskKind
        switch request.task {
        case .embedding:
            mlWorkerTask = .embedding
        case .textGeneration, .chat, .rerank:
            mlWorkerTask = .chat
        }
        let rawOutput = try await mlWorker.performMLTask(
            task: mlWorkerTask,
            input: request.input,
            modelID: request.modelID,
            options: request.options.mapValues { optionValue in
                switch optionValue {
                case .string(let string):
                    return string as AnyHashable
                case .number(let number):
                    return number as AnyHashable
                case .integer(let integer):
                    return integer as AnyHashable
                case .boolean(let bool):
                    return bool as AnyHashable
                }
            }
        )
        return InferenceResponse(output: rawOutput)
    }
}

/// Placeholder for accessibility authority when full implementation is not available
actor MockAccessibilityAuthority: AccessibilityAuthority {
    func isTrusted() async -> Bool { return false }
    func requestPermissions() async -> Bool { return false }
    func getSelectedText(context: ExecutionContext) async throws -> String? { return nil }
    func simulateTyping(_ text: String, context: ExecutionContext) async throws {}
    func getCaretRect(context: ExecutionContext) async throws -> CGRect? { return nil }
}

// MARK: - Capability Module Protocol

/// Protocol for capability modules that can register with the runtime
public protocol CapabilityModule: Sendable {
    /// Register the module's capabilities with the runtime
    /// - Called once during app startup
    /// - Modules should register schemas, workflows, and systems here
    static func register(runtime: PlatformRuntime) async throws
}

// MARK: - Runtime Status

/// Status of the platform runtime
public struct RuntimeStatus: Sendable {
    public let isInitialized: Bool
    public let config: RuntimeConfiguration
    public let governanceStatus: GovernanceStatus
    public let worldSnapshot: WorldSnapshot
    public let registeredSchemas: [String]
    public let registeredWorkflows: [String]
    public let registeredJobWorkflows: [String]
    public let registeredJobTypes: [String]
    public let registeredModules: [String]

    public init(
        isInitialized: Bool,
        config: RuntimeConfiguration,
        governanceStatus: GovernanceStatus,
        worldSnapshot: WorldSnapshot,
        registeredSchemas: [String],
        registeredWorkflows: [String],
        registeredJobWorkflows: [String],
        registeredJobTypes: [String],
        registeredModules: [String]
    ) {
        self.isInitialized = isInitialized
        self.config = config
        self.governanceStatus = governanceStatus
        self.worldSnapshot = worldSnapshot
        self.registeredSchemas = registeredSchemas
        self.registeredWorkflows = registeredWorkflows
        self.registeredJobWorkflows = registeredJobWorkflows
        self.registeredJobTypes = registeredJobTypes
        self.registeredModules = registeredModules
    }
}

// MARK: - Convenience Factory Methods

extension PlatformRuntime {
    /// Create a local runtime (in-process)
    public static func local(config: RuntimeConfiguration = .production) async throws -> PlatformRuntime {
        let runtime = try await PlatformRuntime(config: config)
        try await runtime.initialize()
        return runtime
    }

    /// Create a testing runtime (no governance, no evidence)
    public static func testing() async throws -> PlatformRuntime {
        let runtime = try await PlatformRuntime(config: .testing)
        try await runtime.initialize()
        return runtime
    }

    /// Create a daemon runtime (high concurrency, full enforcement)
    public static func daemon() async throws -> PlatformRuntime {
        let runtime = try await PlatformRuntime(config: .daemon)
        try await runtime.initialize()
        return runtime
    }
}
