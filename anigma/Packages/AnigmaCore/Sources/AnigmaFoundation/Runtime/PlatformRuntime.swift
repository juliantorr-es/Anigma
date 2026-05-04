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
import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts
import DatabaseCore
import InferenceCore
import AnigmaPrimitives
import MLWorkerInterfaces     // For MLWorkerInterface protocol
import OSLog
// Note: RuntimeGovernanceAPI is now in Governance.swift (same target)

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
    private static let logger = os.Logger(subsystem: "com.anigma.core", category: "PlatformRuntime")
    
    // MARK: - Core Infrastructure

    /// Runtime instance identity (for debugging same-instance verification)
    public let runtimeInstanceId: UUID = UUID()
    
    /// Database path used by this runtime (for debugging)
    public let databasePath: String

    /// The ONE World instance for this runtime
    private let world: World

    /// Workflow registry for ECS workflows
    private let workflowRegistry: any WorkflowRegistry

    /// Workflow runner for ECS workflows
    private let workflowRunner: any WorkflowRunner

    /// Governance controller (from Tier 1)
    public let governance: any GoverningController

    /// Configuration
    private let config: RuntimeConfiguration

    /// Initialization state
    private var isInitialized: Bool = false

    // MARK: - Authorities

    /// Evidence authority (unified evidence recording)
    public let evidence: any EvidenceAuthority

    /// Database authority (governed database access)
    /// Note: nonisolated to allow CLI/harness access without actor hopping
    nonisolated public let database: any DatabaseAuthority

    /// Artifact authority (unified artifact storage)
    public let artifacts: any ArtifactAuthority

    /// Execution authority (workflow/job execution)
    public let execution: any ExecutionAuthority

    /// Inference authority (model access)
    public let inference: any InferenceAuthority

    /// Accessibility authority (system interaction)
    public let accessibility: any AccessibilityAuthority

    /// Source authority (system interaction)
    public let sources: any SourceAuthority

    // MARK: - Backend Registry (td-358315)

    /// Backend registry for this runtime instance
    private let backendRegistry: BackendRegistry

    // MARK: - Registered Modules

    /// Registered module schemas (for migration tracking)
    private var registeredSchemas: [String: ModuleSchema] = [:]

    /// Registered workflow types
    private var registeredWorkflows: [String: Any] = [:]

    /// Registered capability module identifiers
    private var registeredModules: [String] = []

    // MARK: - Initialization

    /// Create a new platform runtime
    /// - Parameters:
    ///   - config: Runtime configuration
    ///   - governance: Injected governance controller
    ///   - workflowRegistry: Injected workflow registry
    ///   - workflowRunner: Injected workflow runner
    ///   - inferencePlane: Optional inference plane for AI model access (defaults to MockInferencePlane)
    ///   - database: Optional DatabaseExecutor. If nil, one will be created from config.databasePath.
    ///     
    /// IMPORTANT: Composition roots should provide a DatabaseExecutor via this parameter.
    /// Only composition roots should create DatabaseActor directly.
    /// See ADR-0018 and td-317bbb for details.
    public init(
        config: RuntimeConfiguration = .production,
        governance: (any GoverningController)? = nil,
        workflowRegistry: (any WorkflowRegistry)? = nil,
        workflowRunner: (any WorkflowRunner)? = nil,
        inferencePlane: (any InferencePlane)? = nil,
        database: (any DatabaseExecutor)? = nil
    ) async throws {
        self.config = config
        self.databasePath = config.databasePath ?? DatabaseConfiguration.defaultDatabasePath()
        self.world = World()
        
        // Use injected components or default implementations if available in this module
        self.workflowRegistry = workflowRegistry ?? DefaultWorkflowRegistry()
        self.workflowRunner = workflowRunner ?? DefaultWorkflowRunner(registry: self.workflowRegistry)
        
        // Initialize governance controller (injected or default)
        // Note: Concrete GoverningController implementation is in AnigmaGovernance module.
        // If not provided, we might need a dummy or wait for late injection.
        guard let governance = governance else {
            throw GenericCoreError.internalError("GoverningController must be provided to PlatformRuntime")
        }
        self.governance = governance
        // await governance.initialize() // Should be called by the owner or here if appropriate

        // Initialize authorities (Phase 1: Create wrappers around existing infrastructure)
        // Note: These are placeholder implementations that will be replaced in later phases

        // Database authority wraps DatabaseActor
        // If a DatabaseActor was provided, use it directly.
        // If a DatabaseExecutor was provided, it must be a DatabaseActor.
        // Otherwise, create a new DatabaseActor from config.
        let dbActor: DatabaseActor
        if let database = database as? DatabaseActor {
            // Use provided DatabaseActor directly
            dbActor = database
        } else if let database = database {
            // This should not happen - DatabaseExecutor should be DatabaseActor
            // for PlatformRuntime initialization
            throw GenericCoreError.internalError(
                "PlatformRuntime requires a DatabaseActor, not a generic DatabaseExecutor. " +
                "Composition roots should pass DatabaseActor via the database parameter. " +
                "See ADR-0018 and td-317bbb."
            )
        } else {
            // Legacy: create DatabaseActor from config
            dbActor = DatabaseActor(path: databasePath)
        }
        try await dbActor.open()
        self.database = DatabaseAuthorityImpl(
            databaseActor: dbActor,
            governance: governance,
            evidenceAuthority: nil as (any EvidenceAuthority)? // Will be wired after evidence is created
        )

        // Backend registry for backend management (td-358315)
        self.backendRegistry = BackendRegistry()

        // Evidence authority consolidates evidence systems
        // TODO: td-358315 - Create proper AccessController implementation
        let mockAccessController = MockAccessController()  // Stub for now
        let mockSigner = MockReceiptSigner()  // TODO: td-d65648 - Replace with injected DefaultReceiptSigner
        self.evidence = EvidenceAuthorityImpl(
            database: self.database,
            signer: mockSigner,
            accessController: mockAccessController,
            governance: governance
        )

        // Wire evidence into database authority (circular dependency resolved)
        await (self.database as! DatabaseAuthorityImpl).setEvidenceAuthority(evidence)

        // Artifact authority consolidates artifact storage
        self.artifacts = ArtifactAuthorityImpl(
            databaseAuthority: self.database,
            evidenceAuthority: evidence,
            governance: governance
        )

        // Initialize inference plane (use provided one or default to mock)
        let inferencePlaneToUse = inferencePlane ?? MockInferencePlane()
        let inferenceImpl = InferenceAuthorityImpl(
            uiPlane: inferencePlaneToUse,
            workerPlane: inferencePlaneToUse,
            governance: governance
        )
        self.inference = inferenceImpl

        let accessibilityImpl = MockAccessibilityAuthority()
        self.accessibility = accessibilityImpl

        // Source authority manages content sources
        let sourcesImpl = SourceAuthorityImpl(
            databaseAuthority: self.database,
            evidenceAuthority: evidence,
            governance: governance
        )
        self.sources = sourcesImpl

        // Execution authority owns workflow/job execution
        self.execution = ExecutionAuthorityImpl(
            world: world,
            governance: governance,
            evidenceAuthority: evidence,
            databaseAuthority: self.database,
            artifactsAuthority: artifacts,
            inferenceAuthority: inferenceImpl,
            accessibilityAuthority: accessibilityImpl,
            sourcesAuthority: sourcesImpl
        )
    }

    /// Initialize the runtime
    /// - Must be called before using the runtime
    /// - Sets up core systems and prepares for module registration
    public func initialize() async throws {
        guard !isInitialized else {
            throw RuntimeInitializationError.alreadyInitialized
        }

        // Initialize database schemas (core tables + governance tables)
        try await initializeCoreSchemas()

        try await validateDatabaseBootstrap()
        
        // Initialize governance with database (creates governance tables, seeds defaults)
        try await governance.initialize(using: DatabaseAuthorityAdapter(databaseAuthority: self.database))

        // Initialize sources (creates sources table)
        try await (sources as! SourceAuthorityImpl).initialize()

        // Mode is already seeded by governance.initialize(using:) based on whether global mode exists
        // Default seed is assistive, which matches our enforceGovernance=true expectation

        isInitialized = true
    }

    /// Initialize core database schemas
    private func initializeCoreSchemas() async throws {
        let db = databaseExecutor()

        // Create evidence tables
        try await db.executeAsync("""
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
        try await db.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_evidence_timestamp ON evidence_bundles(timestamp)
        """)
        try await db.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_evidence_principal ON evidence_bundles(principal_id)
        """)

        // Create schema registry table
        try await SchemaRegistry.ensureRegistryTable(using: db)

        // Create artifact metadata table
        try await db.executeAsync("""
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
        try await db.executeAsync("""
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
        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS module_registry (
                module_name TEXT PRIMARY KEY,
                registered_at INTEGER NOT NULL,
                status TEXT NOT NULL
            )
        """)
        
        // Create Harmonia memory tables
        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS harmonia_memories (
                id TEXT PRIMARY KEY,
                content TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                project_id TEXT,
                embedding BLOB,
                embedding_dim INTEGER,
                embedding_model TEXT,
                metadata TEXT
            )
        """)
        
        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS harmonia_chunks (
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL,
                content TEXT NOT NULL,
                file_path TEXT NOT NULL,
                start_line INTEGER NOT NULL,
                end_line INTEGER NOT NULL,
                content_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                embedding BLOB,
                embedding_dim INTEGER,
                embedding_model TEXT
            )
        """)
        
        // Create FTS5 virtual tables for full-text search
        try await db.executeAsync("""
            CREATE VIRTUAL TABLE IF NOT EXISTS harmonia_memories_fts USING fts5(
                content,
                content='harmonia_memories',
                content_rowid='rowid'
            )
        """)
        
        try await db.executeAsync("""
            CREATE VIRTUAL TABLE IF NOT EXISTS harmonia_chunks_fts USING fts5(
                content,
                content='harmonia_chunks',
                content_rowid='rowid'
            )
        """)
        
        // Create FTS synchronization triggers for harmonia_memories
        try await db.executeAsync("""
            CREATE TRIGGER IF NOT EXISTS harmonia_memories_ai
            AFTER INSERT ON harmonia_memories
            BEGIN
                INSERT INTO harmonia_memories_fts(rowid, content)
                VALUES (new.rowid, new.content);
            END
        """)
        
        try await db.executeAsync("""
            CREATE TRIGGER IF NOT EXISTS harmonia_memories_ad
            AFTER DELETE ON harmonia_memories
            BEGIN
                INSERT INTO harmonia_memories_fts(harmonia_memories_fts, rowid, content)
                VALUES ('delete', old.rowid, old.content);
            END
        """)
        
        try await db.executeAsync("""
            CREATE TRIGGER IF NOT EXISTS harmonia_memories_au
            AFTER UPDATE ON harmonia_memories
            BEGIN
                INSERT INTO harmonia_memories_fts(harmonia_memories_fts, rowid, content)
                VALUES ('delete', old.rowid, old.content);
                INSERT INTO harmonia_memories_fts(rowid, content)
                VALUES (new.rowid, new.content);
            END
        """)
        
        // Create FTS synchronization triggers for harmonia_chunks
        try await db.executeAsync("""
            CREATE TRIGGER IF NOT EXISTS harmonia_chunks_ai
            AFTER INSERT ON harmonia_chunks
            BEGIN
                INSERT INTO harmonia_chunks_fts(rowid, content)
                VALUES (new.rowid, new.content);
            END
        """)
        
        try await db.executeAsync("""
            CREATE TRIGGER IF NOT EXISTS harmonia_chunks_ad
            AFTER DELETE ON harmonia_chunks
            BEGIN
                INSERT INTO harmonia_chunks_fts(harmonia_chunks_fts, rowid, content)
                VALUES ('delete', old.rowid, old.content);
            END
        """)
        
        try await db.executeAsync("""
            CREATE TRIGGER IF NOT EXISTS harmonia_chunks_au
            AFTER UPDATE ON harmonia_chunks
            BEGIN
                INSERT INTO harmonia_chunks_fts(harmonia_chunks_fts, rowid, content)
                VALUES ('delete', old.rowid, old.content);
                INSERT INTO harmonia_chunks_fts(rowid, content)
                VALUES (new.rowid, new.content);
            END
        """)
    }

    private func validateDatabaseBootstrap() async throws {
        guard let databaseImpl = database as? DatabaseAuthorityImpl else {
            throw RuntimeInitializationError.configurationError("Database authority does not expose validation")
        }

        let dbActor = await databaseImpl.rawDatabaseActor()
        let report = try await dbActor.validateBootstrap()
        Self.logger.info(
            "Database bootstrap validated for \(self.databasePath, privacy: .public) (quickCheck=\(report.quickCheckResult, privacy: .public), foreignKeyViolations=\(report.foreignKeyViolationCount, privacy: .public))"
        )
    }

    // MARK: - Module Registration

    /// Register a capability module
    /// - Modules call this during app startup to register their capabilities
    public func registerModule<M: CapabilityModule>(_ module: M.Type) async throws {
        guard isInitialized else {
            throw RuntimeInitializationError.notInitialized
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
    /// - TODO: td-358315 - Implement evidence sink registration in EvidenceAuthorityImpl
    public func registerEvidenceSink(_ sink: any EvidenceSink) async throws {
        guard let evidenceImpl = evidence as? EvidenceAuthorityImpl else {
            throw RuntimeInitializationError.configurationError("Evidence authority does not support sinks")
        }

        // TODO: Implement addSink method in EvidenceAuthorityImpl
        // await evidenceImpl.addSink(sink)
        throw RuntimeInitializationError.configurationError("Evidence sink registration not yet implemented")
    }

    /// Legacy access for modules still bound to DatabaseActor.
    public func legacyDatabaseActor() async throws -> DatabaseActor {
        guard let databaseImpl = database as? DatabaseAuthorityImpl else {
            throw RuntimeInitializationError.configurationError("Database authority does not expose DatabaseActor")
        }

        return await databaseImpl.rawDatabaseActor()
    }

    /// Preferred executor view of the governed database.
    public nonisolated func databaseExecutor() -> any DatabaseExecutor {
        DatabaseAuthorityAdapter(databaseAuthority: self.database)
    }

    /// Register a schema (called by modules during registration)
    public func registerSchema(_ schema: ModuleSchema) async throws {
        guard isInitialized else {
            throw RuntimeInitializationError.notInitialized
        }

        // Check if already registered at this version
        if let existing = registeredSchemas[schema.name], existing.version >= schema.version {
            return // Already migrated
        }

        // Perform migration
        try await database.registerSchema(schema)

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
    ) async throws -> CoreReceipt {
        guard isInitialized else {
            throw RuntimeInitializationError.notInitialized
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

    /// Create the governed memory store adapter for runtime-backed memory retrieval.
    public func makeMemoryStore() -> MemoryStoreAdapter {
        MemoryStoreAdapter(database: database)
    }

    /// Validate the runtime memory seam with a governed round trip.
    public func validateMemoryStoreRoundTrip(
        projectId: String,
        userId: String,
        seed: String
    ) async throws -> (storedId: String, results: [SimilarMemoryResult]) {
        let memoryStore = makeMemoryStore()
        try await memoryStore.initializeSchema()

        let storedId = try await memoryStore.store(
            content: seed,
            metadata: [
                "projectId": projectId,
                "userId": userId,
                "sessionId": UUID().uuidString,
                "source": "runtime-validation",
                "embeddingModel": "validation-stub"
            ],
            embedding: [0.1, 0.2, 0.3, 0.4]
        )

        let results = try await memoryStore.searchSimilar(
            embedding: [0.1, 0.2, 0.3, 0.4],
            embeddingModel: "validation-stub",
            projectId: projectId,
            limit: 1,
            threshold: 0.0,
            scanLimit: 10
        )

        return (storedId, results)
    }
    
    #if DEBUG
    /// Diagnostic method for debugging: returns runtime instance identity and database path
    /// Used to verify that different code paths are operating on the same runtime instance
    /// ONLY AVAILABLE IN DEBUG BUILDS
    public func runtimeDiagnostics() -> (instanceId: UUID, dbPath: String) {
        return (runtimeInstanceId, databasePath)
    }
    #endif

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

// MARK: - RuntimeGovernanceAPI Conformance

extension PlatformRuntime: RuntimeGovernanceAPI {
    /// Set governance operating mode (global or project-scoped).
    /// Delegates to GoverningController with database persistence.
    public func setMode(
        _ mode: OperatingMode,
        for projectId: String?,
        by principal: Principal
    ) async throws {
        guard isInitialized else {
            throw RuntimeInitializationError.notInitialized
        }
        
        // Use database adapter for governance persistence
        let dbAdapter = DatabaseAuthorityAdapter(databaseAuthority: self.database)
        try await governance.setMode(mode, for: projectId, by: principal, using: dbAdapter)
    }
    
    /// Show the effective operating mode for a project or global.
    /// Returns the mode and its source (project/global/default).
    public func showMode(
        for projectId: String?
    ) async throws -> (effective: OperatingMode, source: ModeSource) {
        guard isInitialized else {
            throw RuntimeInitializationError.notInitialized
        }
        
        let effectiveMode = await governance.getMode(for: projectId)
        
        // Determine source by checking database
        let source: ModeSource
        
        if let pid = projectId {
            // Check if project-specific mode exists
            let projectSQL = "SELECT mode FROM governance_modes WHERE project_id = ?"
            let projectResult = try await database.query(projectSQL, parameters: [DatabaseParameter.text(pid)])
            
            if !projectResult.isEmpty {
                source = ModeSource.project
            } else {
                // Check if global mode exists
                let globalSQL = "SELECT mode FROM governance_modes WHERE project_id = 'global'"
                let globalResult = try await database.query(globalSQL, parameters: [])
                source = globalResult.isEmpty ? ModeSource.defaultMode : ModeSource.global
            }
        } else {
            // Global query
            let globalSQL = "SELECT mode FROM governance_modes WHERE project_id = 'global'"
            let globalResult = try await database.query(globalSQL, parameters: [])
            source = globalResult.isEmpty ? ModeSource.defaultMode : ModeSource.global
        }
        
        return (effectiveMode, source)
    }
    
    /// Clear a project-specific mode override, reverting to global mode.
    /// Removes the project entry from the database.
    public func clearMode(
        for projectId: String?,
        by principal: Principal
    ) async throws {
        guard isInitialized else {
            throw RuntimeInitializationError.notInitialized
        }
        
        // projectId must not be nil for clearMode
        guard let pid = projectId else {
            throw RuntimeInitializationError.invalidArgument("clearMode requires a non-nil projectId")
        }
        
        let context = ExecutionContext(
            principal: principal,
            projectId: pid,
            sessionId: "mode-clear"
        )
        
        let sql = "DELETE FROM governance_modes WHERE project_id = ?"
        let mutation = DatabaseMutation(
            sql: sql,
            parameters: [DatabaseParameter.text(pid)],
            componentType: "governance",
            entityId: nil
        )
        
        _ = try await database.mutate(mutation, context: context)
        
        // Update in-memory cache in governance
        await governance.clearProjectMode(pid)
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
        case .embedding, .embed:
            return "[0.1, 0.2, 0.3]" // Simple embedding vector
        case .chat, .generate:
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
        case .embedding, .embed:
            mlWorkerTask = .embedding
        case .textGeneration, .chat, .summarize, .classify, .toolCall, .codeGeneration, .codeExplanation, .extraction, .translation, .rerank:
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

// MARK: - Runtime Kill Switch API

extension PlatformRuntime: RuntimeKillSwitchAPI {
    /// Engage the kill switch (blocks writes).
    public func setKillSwitch(active: Bool, for projectId: String?, reason: String?, by principal: Principal) async throws {
        guard isInitialized else {
            throw RuntimeInitializationError.notInitialized
        }
        
        try await governance.setKillSwitch(active: active, for: projectId, reason: reason, by: principal, using: database)
    }
    
    /// Show the kill switch status.
    public func showKillSwitch(for projectId: String?) async throws -> (active: Bool, reason: String?) {
        guard isInitialized else {
            throw RuntimeInitializationError.notInitialized
        }
        
        return try await governance.showKillSwitch(for: projectId)
    }

    /// Checks if a write operation is allowed for a project.
    public func isWriteAllowed(forProject projectId: String?) async -> Bool {
        let killSwitch = await governance.killSwitch
        return await killSwitch.isWriteAllowed(forProject: projectId)
    }

    /// Engages the kill switch (blocks writes).
    public func activate(reason: String, by principalId: String) async {
        let killSwitch = await governance.killSwitch
        await killSwitch.activate(reason: reason, by: principalId)
    }
    
    /// Gets the current status of the kill switch.
    public func killSwitchStatus() async -> (isActive: Bool, activationReason: String?) {
        let killSwitch = await governance.killSwitch
        return await killSwitch.killSwitchStatus()
    }

    /// Deactivates the kill switch.
    public func deactivate(by principalId: String) async {
        let killSwitch = await governance.killSwitch
        await killSwitch.deactivate(by: principalId)
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

/// Placeholder for access controller when full implementation is not available
/// TODO: td-358315 - Replace with proper AccessController implementation
actor MockAccessController: AccessController {
    func evaluate(_ request: AccessRequest) async -> AccessDecision {
        return AccessDecision(
            allowed: true,
            policyId: "mock_policy",
            reason: "Mock access controller allows all",
            conditions: []
        )
    }
    
    func checkAccess(_ request: AccessRequest) async throws {
        // Allow all access in mock
    }
    
    func addPolicy(_ policy: any AccessPolicy) async {
        // No-op in mock
    }
    
    func listPolicies() async -> [any AccessPolicy] {
        // Return empty list in mock
        return []
    }
}

/// Mock ReceiptSigner for use when a real signer is not available
/// TODO: td-d65648 - Replace with injected DefaultReceiptSigner from daemon
struct MockReceiptSigner: ReceiptSigner {
    public init() {}

    public var signerID: String {
        return "mock-platform-runtime"
    }

    public func sign(data: Data) async throws -> String {
        // Mock signature - uses BLAKE3 hash like DefaultReceiptSigner
        // In production, use injected DefaultReceiptSigner from daemon
        return BLAKE3Digest.hex(of: data)
    }

    public func verify(data: Data, signature: String) async throws -> Bool {
        let expected = BLAKE3Digest.hex(of: data)
        return expected == signature
    }
    
    func listPolicies() async -> [any AccessPolicy] {
        return []
    }
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
    public static func local(config: RuntimeConfiguration = .production, inferencePlane: (any InferencePlane)? = nil) async throws -> PlatformRuntime {
        let runtime = try await PlatformRuntime(config: config, inferencePlane: inferencePlane)
        try await runtime.initialize()
        return runtime
    }

    /// Create a testing runtime (no governance, no evidence)
    public static func testing(inferencePlane: (any InferencePlane)? = nil) async throws -> PlatformRuntime {
        let runtime = try await PlatformRuntime(config: RuntimeConfiguration.testing, inferencePlane: inferencePlane)
        try await runtime.initialize()
        return runtime
    }

    /// Create a daemon runtime (high concurrency, full enforcement)
    public static func daemon(inferencePlane: (any InferencePlane)? = nil) async throws -> PlatformRuntime {
        let runtime = try await PlatformRuntime(config: RuntimeConfiguration.daemon, inferencePlane: inferencePlane)
        try await runtime.initialize()
        return runtime
    }
    
    // MARK: - CLI/Kernel Compatibility
    
    /// Kernel-specific configuration (stable seam for CLI and harness)
    public struct KernelConfig {
        public let databasePath: String
        public let enforceGovernance: Bool
        public let principalId: String?
        
        public init(databasePath: String, enforceGovernance: Bool, principalId: String? = nil) {
            self.databasePath = databasePath
            self.enforceGovernance = enforceGovernance
            self.principalId = principalId
        }
    }
    
    /// Create a kernel runtime (for CLI and harness usage)
    /// This is a stable seam that won't churn across internal refactors.
    public static func makeForKernel(_ config: KernelConfig) async throws -> PlatformRuntime {
        let runtimeConfig = RuntimeConfiguration(
            mode: .local,
            databasePath: config.databasePath,
            enforceGovernance: config.enforceGovernance,
            recordEvidence: config.enforceGovernance
        )
        let runtime = try await PlatformRuntime(config: runtimeConfig)
        try await runtime.initialize()
        return runtime
    }

    // MARK: - Backend Registry (td-358315)

    /// Backend registration and readiness management
    private actor BackendRegistry {
        /// Registered backends
        private var registeredBackends: [BackendId: any PlatformBackend] = [:]
        
        /// Backend capability contracts
        private var backendContracts: [BackendId: BackendCapabilityContract] = [:]
        
        /// Backend readiness checkers
        private var readinessCheckers: [BackendId: @Sendable (any PlatformBackend) async -> BackendReadinessCheck] = [:]
        
        /// Register a backend with PlatformRuntime
        func registerBackend(
            _ backend: any PlatformBackend,
            contract: BackendCapabilityContract,
            readinessChecker: @escaping @Sendable (any PlatformBackend) async -> BackendReadinessCheck
        ) async throws -> BackendRegistrationReceipt {
            // Validate backend ID matches contract
            guard backend.backendId == contract.backendId else {
                throw RuntimeInitializationError.invalidArgument(
                    "Backend ID mismatch: backend.backendId != contract.backendId"
                )
            }
            
            // Check if already registered
            if registeredBackends[backend.backendId] != nil {
                throw RuntimeInitializationError.invalidArgument(
                    "Backend already registered: \(backend.backendId)"
                )
            }
            
            // Register backend
            registeredBackends[backend.backendId] = backend
            backendContracts[backend.backendId] = contract
            readinessCheckers[backend.backendId] = readinessChecker
            
            // Initialize backend
            try await backend.initialize()
            
            // Create registration receipt
            let receipt = BackendRegistrationReceipt(
                backendId: backend.backendId,
                registeredAt: Date(),
                context: ["module": "PlatformRuntime", "operation": "backend_registration"]
            )
            
            return receipt
        }
        
        /// Check backend readiness
        func backendReadiness(for backendId: BackendId) async -> BackendReadinessCheck {
            guard let backend = registeredBackends[backendId] else {
                return BackendReadinessCheck(
                    backendId: backendId,
                    isReady: false,
                    state: .unregistered,
                    contractCompatibility: .incompatible,
                    lifecycleState: .uninitialized,
                    denialReason: "Backend not registered: \(backendId)"
                )
            }
            
            guard let checker = readinessCheckers[backendId] else {
                return BackendReadinessCheck(
                    backendId: backendId,
                    isReady: false,
                    state: .registered,
                    contractCompatibility: .incompatible,
                    lifecycleState: .uninitialized,
                    denialReason: "Readiness checker not found for: \(backendId)"
                )
            }
            
            // Perform readiness check
            return await checker(backend)
        }
        
        /// Select a ready backend for execution
        func selectBackend(
            contractId: String,
            minVersion: Int
        ) async throws -> (any PlatformBackend, BackendReadinessCheck) {
            // Find backends with matching contract
            let matchingBackends = backendContracts.filter { _, contract in
                contract.contractId == contractId && contract.contractVersion >= minVersion
            }
            
            guard !matchingBackends.isEmpty else {
                throw RuntimeInitializationError.executionFailed(
                    "No backend found for contract: \(contractId) v\(minVersion)+"
                )
            }
            
            // Check readiness for each matching backend
            for (backendId, _) in matchingBackends {
                let readiness = await backendReadiness(for: backendId)
                
                if readiness.isReady {
                    guard let backend = registeredBackends[backendId] else {
                        continue
                    }
                    return (backend, readiness)
                }
            }
            
            // No ready backends found
            throw RuntimeInitializationError.executionFailed(
                "No ready backend found for contract: \(contractId) v\(minVersion)+"
            )
        }
        
        /// Execute with backend readiness enforcement
        func executeWithBackend<
            B: PlatformBackend,
            T
        >(
            backendId: BackendId,
            operation: BackendOperationContext,
            block: @Sendable (B) async throws -> T
        ) async throws -> (T, MutationReceipt) {
            // Check backend readiness
            let readiness = await backendReadiness(for: backendId)
            
            guard readiness.isReady else {
                let error = RuntimeInitializationError.writeBlocked(
                    violation: GovernanceViolation(
                        principal: "system",
                        projectId: nil,
                        operation: operation.operationType,
                        module: "PlatformRuntime",
                        evaluatedModeSource: "backendReadiness",
                        failedChecks: [
                            GovernanceViolation.FailedCheck(
                                checkId: "readinessGate",
                                message: readiness.denialReason ?? "Backend not ready: \(readiness.state.rawValue)"
                            )
                        ]
                    )
                )
                throw error
            }
            
            // Get backend
            guard let backend = registeredBackends[backendId] as? B else {
                throw RuntimeInitializationError.configurationError(
                    "Backend type mismatch for: \(backendId)"
                )
            }
            
            // Create execution context
            let executionContext = ExecutionContext(
                principal: .system,
                metadata: [
                    "backendId": backendId.rawValue,
                    "operationId": operation.operationId,
                    "operationType": operation.operationType
                ]
            )
            
            // Execute operation
            let result = try await block(backend)
            
            // Record evidence (placeholder - real implementation would use evidenceAuthority)
            let evidencePayload = EvidencePayload.custom(
                type: "backend_operation",
                data: [
                    "backendId": backendId.rawValue,
                    "operationId": operation.operationId,
                    "operationType": operation.operationType,
                    "readinessState": readiness.state.rawValue
                ]
            )
            
            // Create mutation receipt
            let receipt = MutationReceipt(
                rowsAffected: 0, // Not applicable for backend operations
                evidence: CoreReceipt(
                    operationType: operation.operationType,
                    principal: .system,
                    outcome: .success,
                    summary: "Backend operation executed: \(operation.operationType)",
                    contentHash: "backend-op-\(operation.operationId.prefix(8))"
                )
            )
            
            return (result, receipt)
        }
        
        /// Shutdown all registered backends
        func shutdownAllBackends() async {
            for (_, backend) in registeredBackends {
                await backend.shutdown()
            }
            registeredBackends.removeAll()
            backendContracts.removeAll()
            readinessCheckers.removeAll()
        }
    }

    /// Register a backend with PlatformRuntime
    public func registerBackend(
        _ backend: any PlatformBackend,
        contract: BackendCapabilityContract,
        readinessChecker: @escaping @Sendable (any PlatformBackend) async -> BackendReadinessCheck
    ) async throws -> BackendRegistrationReceipt {
        try await self.backendRegistry.registerBackend(backend, contract: contract, readinessChecker: readinessChecker)
    }
    
    /// Check backend readiness status
    public func backendReadiness(for backendId: BackendId) async -> BackendReadinessCheck {
        await self.backendRegistry.backendReadiness(for: backendId)
    }
    
    /// Select a ready backend for execution
    public func selectBackend(
        contractId: String,
        minVersion: Int
    ) async throws -> (any PlatformBackend, BackendReadinessCheck) {
        try await backendRegistry.selectBackend(contractId: contractId, minVersion: minVersion)
    }
    
    /// Execute with backend readiness enforcement
    public func executeWithBackend<
        B: PlatformBackend,
        T
    >(
        backendId: BackendId,
        operation: BackendOperationContext = BackendOperationContext(operationType: "backend_operation"),
        block: @Sendable (B) async throws -> T
    ) async throws -> (T, MutationReceipt) {
        try await backendRegistry.executeWithBackend(backendId: backendId, operation: operation, block: block)
    }

    /// Shutdown all registered backends
    public func shutdownBackends() async {
        await backendRegistry.shutdownAllBackends()
    }
}
