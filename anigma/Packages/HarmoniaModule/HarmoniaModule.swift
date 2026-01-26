//
//  HarmoniaModule.swift
//  HarmoniaModule
//
//  Harmonia-specific systems and components for AI-assisted code orchestration.
//

import AnigmaCore
import TelemetryCore
import DatabaseCore
import CathedralModule
import ContractsCore
import Foundation

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
        // Implementation placeholder
        print("HarmoniaModule registered")
    }

    public static func createReasoningInfrastructure(
        auditLog: any AuditLogging,
        config: HarmoniaReasoningConfig = .default,
        cicdConfig: CICDGateConfig = .default
    ) async -> HarmoniaReasoningInfrastructure {
        let orchestrator = ReasoningOrchestrator()
        let reasoningService = HarmoniaReasoningService(orchestrator: orchestrator, config: config)
        return HarmoniaReasoningInfrastructure(
            orchestrator: orchestrator,
            reasoningService: reasoningService,
            cicdGateService: HarmoniaCICDGateService(reasoningService: reasoningService, config: cicdConfig),
            scenarioLibrary: HarmoniaScenarioLibrary()
        )
    }
}

// MARK: - Harmonia Reasoning Infrastructure

public struct HarmoniaReasoningInfrastructure: Sendable {
    public let orchestrator: ReasoningOrchestrator
    public let reasoningService: HarmoniaReasoningService
    public let cicdGateService: HarmoniaCICDGateService
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

// Protocol for TamperEvidenceSystem if needed for older references
// (Now using the one from AnigmaCore)
