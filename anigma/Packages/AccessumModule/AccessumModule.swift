//
//  AccessumModule.swift
//  AccessumModule
//
//  Apertum Accesum client-side systems for accessibility workflows.
//
//  This module should contain:
//  - Components migrated from Apertum Accesum's ECS implementation
//  - Systems for document processing, OCR, accessibility features
//  - Workflows for client-side accessibility operations
//
//  Migration Checklist:
//  ====================
//
//  From: /Users/user/Developer/GitHub/Apertum_Accesum/Apertum Accessum/poli/core/
//
//  The ECSContracts.swift file defines the ECS infrastructure, which is now
//  provided by AnigmaCore. Domain-specific components should be migrated here.
//
//  Components to migrate/define in AccessumModule/Components/:
//  - DocumentComponent (document metadata and state)
//  - OcrStateComponent (OCR processing state)
//  - AccessibilityProfileComponent (user accessibility preferences)
//  - ImportStateComponent (import progress tracking)
//
//  Systems to migrate/define in AccessumModule/Systems/:
//  - DocumentImportSystem
//  - OcrProcessingSystem
//  - AccessibilityAdaptationSystem
//  - SyncSystem (for cloud sync)
//
//  Workflows to define in AccessumModule/Pipelines/:
//  - DocumentImportWorkflow
//  - OcrProcessingWorkflow
//  - BulkImportWorkflow
//
//  From ECSContracts.swift - already in AnigmaCore:
//  - EntityID → EntityId (typealias provided)
//  - Component protocol → AnigmaCore.Component
//  - System protocol → AnigmaCore.AsyncSystem
//  - WorldProtocol → AnigmaCore.World
//  - ECSError → AnigmaCore.ECSError
//  - GRDBLedger → define in AccessumModule if needed for persistence
//

import AnigmaCore
import TelemetryCore

// MARK: - Module Info

/// AccessumModule version information.
public enum AccessumModuleVersion {
    public static let major = 0
    public static let minor = 1
    public static let patch = 0
    public static let string = "\(major).\(minor).\(patch)"
}

// MARK: - Module Registration

/// Registers Accessum-specific systems and workflows with the ECS.
public enum AccessumModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        let world = await runtime.getWorld()
        let registry = await runtime.getWorkflowRegistry()
        try await register(world: world, registry: registry, telemetry: nil)
    }

    public static func register(
        world: World,
        registry: WorkflowRegistry,
        telemetry: TelemetryClient? = nil
    ) async throws {
        // Register minimal alt-media pipeline systems.
        await world.registerSystem(DocumentImportSystem(telemetryClient: telemetry))
        try await world.registerSystem(OCRSystem(telemetryClient: telemetry))
        await world.registerSystem(TTSSystem(telemetryClient: telemetry))
        await world.registerSystem(CloudSyncSystem(telemetryClient: telemetry))

        // Workflows can be wired here as they mature.
        // await registry.register(DocumentImportWorkflow())
        // await registry.register(OcrProcessingWorkflow())

        await Logger.shared.info("AccessumModule registered", category: "AccessumModule")
    }
}

// MARK: - Persistence Support
//
// Apertum Accesum uses GRDB for persistence. The GRDBLedger protocol from
// ECSContracts.swift can be adapted here for use with AnigmaCore entities.
//
// Example:
//
// public protocol ComponentStore: Sendable {
//     associatedtype ComponentType: Component & Codable
//     func load(for entityId: EntityId) async throws -> ComponentType?
//     func save(_ component: ComponentType, for entityId: EntityId) async throws
//     func delete(for entityId: EntityId) async throws
//     func loadAll() async throws -> [(EntityId, ComponentType)]
// }
