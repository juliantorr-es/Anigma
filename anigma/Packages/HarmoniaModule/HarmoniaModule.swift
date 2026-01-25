//
//  HarmoniaModule.swift
//  HarmoniaModule
//
//  Harmonia-specific systems and components for AI-assisted code orchestration.
//
//  This module contains:
//  - Reasoning integration for safety analysis
//  - CI/CD gate checking
//  - Adversarial scenario library
//  - Workflow and automation safety checking
//
//  The reasoning kernel acts as Harmonia's "preflight brain":
//  - Every structural change goes through reasoning analysis first
//  - Dangerous operations are blocked or flagged
//  - Adversarial scenarios become regression tests and documentation
//

import AnigmaCore
import TelemetryCore

// MARK: - Module Info

/// HarmoniaModule version information.
public enum HarmoniaModuleVersion {
    public static let major = 0
    public static let minor = 2
    public static let patch = 0
    public static let string = "\(major).\(minor).\(patch)"
}

// MARK: - Module Registration

/// Registers Harmonia-specific systems and workflows with the ECS.
/// Call this during application startup.
///
/// ## Usage
/// ```swift
/// let world = World()
/// let registry = WorkflowRegistry()
/// await HarmoniaModule.register(world: world, registry: registry)
/// ```
public enum HarmoniaModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        // Register evidence sinks for three-tier architecture compliance
        let databaseAuthority = await runtime.database
        let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: databaseAuthority)
        
        // Create TamperEvidenceSystem adapter
        let tamperEvidenceSystem = try await TamperEvidenceSystem(dbActor: databaseAdapter as! DatabaseCore.DatabaseExecutor)
        let tamperEvidenceAdapter = TamperEvidenceSystemAdapter(tamperEvidenceSystem: tamperEvidenceSystem)
        try await runtime.registerEvidenceSink(tamperEvidenceAdapter)
        
        // Create EvidenceRecorder adapter
        let evidenceRecorder = GovernedEvidenceRecorder(masterDb: databaseAdapter as! DatabaseCore.DatabaseExecutor)
        let evidenceRecorderAdapter = EvidenceRecorderAdapter(evidenceRecorder: evidenceRecorder)
        try await runtime.registerEvidenceSink(evidenceRecorderAdapter)
        
        // Delegate to legacy registration for backward compatibility
        let world = await runtime.getWorld()
        let registry = await runtime.getWorkflowRegistry()
        try await register(world: world, registry: registry)
    }

    public static func register(
        world: World,
        registry: WorkflowRegistry,
        telemetryClient: TelemetryClient? = nil,
        transparencyService: TransparencyService? = nil,
        transparencyTaskId: String? = nil
    ) async throws {
        let builder: DataFlowBuilder?
        if let transparencyService = transparencyService, let taskId = transparencyTaskId {
            builder = await transparencyService.beginTracking(taskId: taskId)
        } else {
            builder = nil
        }
        // Register orchestration/telemetry systems (minimal slice).
        await world.registerSystem(
            ConcurrencySyncSystem(telemetryClient: telemetryClient, transparencyBuilder: builder))
        await world.registerSystem(
            MetricsAggregationSystem(telemetryClient: telemetryClient, transparencyBuilder: builder)
        )
        await world.registerSystem(
            HealthCheckSystem(telemetryClient: telemetryClient, transparencyBuilder: builder))
        await world.registerSystem(ThroughputSamplingSystem())
        await world.registerSystem(RequestCleanupSystem())
        await world.registerSystem(SessionCleanupSystem())
        await world.registerSystem(SlotTimeoutSystem())

        // Register core orchestration systems
        await world.registerSystem(StepEngine())
        await world.registerSystem(MLWorkerDispatchSystem())

        // Register Aerodrome-9 demo systems
        for system in Aerodrome9Systems.all {
            await world.registerSystem(system)
        }

        // Register harness systems for autonomous coding
        // Note: These systems are defined in Harness/Systems/
        // await world.registerSystem(ProjectInitializerSystem())
        // await world.registerSystem(ProjectCodingAgentSystem())

        // Register workflows (placeholder for future expansion).
        // await registry.register(CodeRefactorWorkflow())
        // await registry.register(BatchRunWorkflow())

        await Logger.shared.info(
            "HarmoniaModule v\(HarmoniaModuleVersion.string) registered", category: "HarmoniaModule"
        )
    }

    /// Creates the Harmonia reasoning infrastructure.
    /// Call this to set up reasoning-based safety analysis.
    ///
    /// ## Usage
    /// ```swift
    /// let infra = await HarmoniaModule.createReasoningInfrastructure(auditLog: auditLog)
    /// let result = try await infra.reasoningService.analyzeWorkflowSafety(...)
    /// ```
    public static func createReasoningInfrastructure(
        auditLog: AuditLog,
        config: HarmoniaReasoningConfig = .default,
        cicdConfig: CICDGateConfig = .default
    ) async -> HarmoniaReasoningInfrastructure {

        // Create the orchestrator
        let orchestrator = ReasoningOrchestrator()
        await orchestrator.configure(auditLog: auditLog)

        // Create the reasoning service
        let reasoningService = HarmoniaReasoningService(orchestrator: orchestrator, config: config)
        await reasoningService.configure(auditLog: auditLog)

        // Create the CI/CD gate service
        let cicdGateService = HarmoniaCICDGateService(
            reasoningService: reasoningService, config: cicdConfig)
        await cicdGateService.configure(auditLog: auditLog)

        // Create the scenario library
        let scenarioLibrary = HarmoniaScenarioLibrary()
        await scenarioLibrary.configure(auditLog: auditLog)

        await Logger.shared.info(
            "Harmonia reasoning infrastructure created", category: "HarmoniaModule")

        return HarmoniaReasoningInfrastructure(
            orchestrator: orchestrator,
            reasoningService: reasoningService,
            cicdGateService: cicdGateService,
            scenarioLibrary: scenarioLibrary
        )
    }
}

// MARK: - Harmonia Reasoning Infrastructure

/// Container for Harmonia reasoning services.
public struct HarmoniaReasoningInfrastructure: Sendable {
    /// The underlying reasoning orchestrator.
    public let orchestrator: ReasoningOrchestrator

    /// The Harmonia-specific reasoning service.
    public let reasoningService: HarmoniaReasoningService

    /// The CI/CD gate service.
    public let cicdGateService: HarmoniaCICDGateService

    /// The adversarial scenario library.
    public let scenarioLibrary: HarmoniaScenarioLibrary

    public init(
        orchestrator: ReasoningOrchestrator,
        reasoningService: HarmoniaReasoningService,
        cicdGateService: HarmoniaCICDGateService,
        scenarioLibrary: HarmoniaScenarioLibrary
    ) {
        self.orchestrator = orchestrator
        self.reasoningService = reasoningService
        self.cicdGateService = cicdGateService
        self.scenarioLibrary = scenarioLibrary
    }
}

// MARK: - Re-exports

// Re-export reasoning types for convenience
public typealias HarmoniaReasoningDomainType = HarmoniaReasoningDomain
public typealias HarmoniaReasoningResultType = HarmoniaReasoningResult
public typealias HarmoniaCICDGateResultType = HarmoniaCICDGateResult

// MARK: - Bonkers++ Inference Infrastructure

extension HarmoniaModule {
    /// Creates the bonkers++ inference infrastructure with full governance.
    /// This is the "institution-grade" inference system with:
    /// - Institutional model charters
    /// - Tri-memory architecture
    /// - Self-tuning selection policies
    /// - Behavior governance
    /// - Gremlin-based adversarial testing
    ///
    /// ## Usage
    /// ```swift
    /// let infra = await HarmoniaModule.createBonkersInference()
    /// let session = await infra.startSession(tenantId: "ccsf", ...)
    /// let result = try await infra.runInference(task: task, session: session)
    /// ```
    public static func createBonkersInference(
        config: BonkersInferenceConfig = .default
    ) async -> BonkersInferenceInfrastructure {
        await BonkersInferenceFactory.create(config: config)
    }

    /// Creates the bonkers++ inference infrastructure configured for CCSF DSPS.
    /// Pre-configured with appropriate charter, policies, and constraints.
    public static func createCCSFDSPSInference() async -> BonkersInferenceInfrastructure {
        await BonkersInferenceFactory.createForCCSFDSPS()
    }
}

// MARK: - Additional Re-exports for Bonkers++ Components

// Institutional Model System
public typealias InstitutionalCharterType = InstitutionalCharter
public typealias InstitutionalModelBundleType = InstitutionalModelBundle

// Tri-Memory Architecture
public typealias ShortTermMemoryType = ShortTermMemory
public typealias LongTermMemoryType = LongTermMemory
public typealias PersistentMemoryType = PersistentMemory

// Self-Tuning Selection
public typealias ArchitectureSelectionPolicyType = ArchitectureSelectionPolicy
public typealias SelectionPolicyServiceType = SelectionPolicyService

// Behavior Governance
public typealias AgentBehaviorGovernorType = AgentBehaviorGovernor
public typealias AgentBehaviorConstraintsType = AgentBehaviorConstraints

// Learning Impact
public typealias LearningImpactMeasurerType = LearningImpactMeasurer
public typealias ReasoningTraceType = ReasoningTrace

// MARK: - Radically Legible AI Infrastructure

extension HarmoniaModule {
    /// Creates the Radically Legible AI infrastructure.
    /// This provides full transparency for every inference operation:
    /// - Processing receipts showing exactly what happened
    /// - Data flow graphs showing where data went
    /// - Reasoning traces with structured explanations
    /// - Institutional learning with consent and revocability
    ///
    /// ## Usage
    /// ```swift
    /// let service = await HarmoniaModule.createRadicallyLegibleService()
    /// let context = await service.beginTask(task, domain: "dsps", policy: policy)
    /// // ... do inference ...
    /// let bundle = await service.completeTask(context: context, result: result, ...)
    /// print(bundle.transparency.renderFullReport())
    /// ```
    public static func createRadicallyLegibleService() async -> RadicallyLegibleService {
        let service = RadicallyLegibleService()

        // Pre-register CCSF charters
        await service.registerCharter(PresetLearningCharters.ccsfDSPS)
        await service.registerCharter(PresetLearningCharters.academicRecords)

        await Logger.shared.info(
            "Radically Legible AI infrastructure created", category: "HarmoniaModule")

        return service
    }
}

// MARK: - Radically Legible Re-exports

// Processing Receipts
public typealias ProcessingReceiptType = ProcessingReceipt
public typealias ReceiptGeneratorType = ReceiptGenerator
public typealias PipelineStageType = PipelineStage
public typealias EngineUsageType = EngineUsage

// Data Flow Transparency
public typealias DataFlowGraphType = DataFlowGraph
public typealias DataFlowNodeType = DataFlowNode
public typealias DataFlowEdgeType = DataFlowEdge
public typealias DataFlowBuilderType = DataFlowBuilder

// Test-Time Compute Governance
public typealias ReasoningBudgetType = ReasoningBudget
public typealias StructuredReasoningTraceType = StructuredReasoningTrace
public typealias ReasoningGovernorType = ReasoningGovernor
public typealias DomainBudgetRegistryType = DomainBudgetRegistry

// Institutional Learning
public typealias LearningCharterType = InstitutionalCharter
public typealias LearningConfigurationType = LearningConfiguration
public typealias LearningTraceType = LearningTrace
public typealias InstitutionalLearningServiceType = InstitutionalLearningService

// Radically Legible Service
public typealias RadicallyLegibleServiceType = RadicallyLegibleService
public typealias TaskContextType = TaskContext
public typealias TaskCompletionBundleType = TaskCompletionBundle
public typealias TransparencyBundleType = TransparencyBundle

// MARK: - Themis Architecture (Greek Mythology Naming)

extension HarmoniaModule {
    /// Creates the Themis governance orchestrator.
    /// This is the unified, canonical entry point for all governed inference.
    ///
    /// The Themis architecture coordinates:
    /// - **Themis**: Institutional charters and governance
    /// - **Mnemosyne**: Tri-memory architecture
    /// - **Moirae**: Self-tuning routing and selection
    /// - **Eunomia**: Agent behavior governance
    /// - **Aletheia**: Telemetry and transparency
    /// - **Arete**: Learning impact measurement
    /// - **Eris**: Adversarial testing
    ///
    /// ## Usage
    /// ```swift
    /// let themis = await HarmoniaModule.createThemisOrchestrator(preset: .ccsfDSPS)
    /// let session = await themis.startSession(tenantId: "ccsf", principalId: "staff1", domain: .dsps)
    /// let result = try await themis.runTask(task, session: session)
    /// print(result.renderReport())
    /// await themis.endSession(session.sessionId)
    /// ```
    public static func createThemisOrchestrator(
        config: ThemisConfig = .default
    ) async -> ThemisOrchestrator {
        await ThemisOrchestrator.create(config: config)
    }

    /// Creates a Themis orchestrator with a preset configuration.
    public static func createThemisOrchestrator(
        preset: ThemisPreset
    ) async -> ThemisOrchestrator {
        await ThemisOrchestrator.create(preset: preset)
    }

    /// Creates a Themis orchestrator configured for CCSF DSPS operations.
    public static func createCCSFDSPSThemis() async -> ThemisOrchestrator {
        await ThemisOrchestrator.create(preset: .ccsfDSPS)
    }
}

// MARK: - Themis Re-exports

// Core Orchestrator
public typealias ThemisOrchestratorType = ThemisOrchestrator
public typealias ThemisConfigType = ThemisConfig
public typealias ThemisPresetType = ThemisPreset
public typealias ThemisResultType = ThemisResult
public typealias ThemisSessionContextType = ThemisSessionContext

// Charter Layer (Themis = divine law)
public typealias ThemisCharterType = ThemisCharter
public typealias NemesisConstraintType = NemesisConstraint
public typealias EunomiaGuardrailsType = EunomiaGuardrails

// Memory Layer (Mnemosyne = memory)
public typealias LetheBufferType = LetheBuffer
public typealias MnemosyneArchiveType = MnemosyneArchive
public typealias ArcheionStoreType = ArcheionStore

// Routing Layer (Moirae = fates)
public typealias MoiraeRoutingPolicyType = MoiraeRoutingPolicy
public typealias MoiraRoutingRuleType = MoiraRoutingRule
public typealias AnankeConstraintType = AnankeConstraint

// Behavior Layer (Eunomia = good order)
public typealias EunomiaGovernorType = EunomiaGovernor
public typealias EunomiaConstraintsType = EunomiaConstraints

// Transparency Layer (Aletheia = truth)
// Removed: AletheiaManifestType (type deleted in Stage 3)
public typealias AletheiaReceiptType = AletheiaReceipt

// Learning Layer (Arete = excellence)
public typealias AreteImpactMeasurerType = AreteImpactMeasurer

// Testing Layer (Eris = strife)
public typealias ErisTrialBuilderType = ErisTrialBuilder
public typealias AgonScenarioType = AgonScenario
public typealias ErisReportType = ErisReport

extension HarmoniaModule {
    /// Creates an ArtifactStore configured with the runtime's ArtifactAuthority.
    public static func createArtifactStore(with runtime: PlatformRuntime) async -> ArtifactStore {
        return ArtifactStore(artifactAuthority: await runtime.artifacts)
    }
}
