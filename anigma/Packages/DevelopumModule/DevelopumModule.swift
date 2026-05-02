//
//  DevelopumModule.swift
//  DevelopumModule
//
//  Develop mode capability module for Anigma IDE features.
//
//  This module provides:
//  - Monaco editor integration with governed workflows
//  - Artifact-first file operations with receipts
//  - IndexCapsule for fast file/text search
//  - Repository session management
//  - Bridge contracts for deterministic evidence hashing
//
//  ## Key Principles
//
//  1. Monaco is UI-only; all side effects go through job/receipt systems
//  2. File saves create immutable artifacts first, then optionally mirror to working tree
//  3. Bridge messages use canonical JSON (JCS) for deterministic evidence hashing
//  4. Virtual anigma:// URIs for document references, content served via RPC
//  5. Workflow-managed state (RepoSession lifecycle tied to workflows)
//  6. Honest scoping: IndexCapsule does fast file/text search, semantic navigation deferred to LSP
//
//  ## Topics
//
//  ### Module Registration
//
//  - ``register(runtime:)"
//  - ``createArtifactService(with:databaseService:telemetry:)"
//  - ``createReceiptService(databaseService:telemetry:)"
//
//  ### Services
//
//  - ``DevelopumDatabaseService"
//  - ``DevelopumArtifactService"
//  - ``DevelopumReceiptService"
//  - ``IndexCapsule"
//
//  ### Models
//
//  - ``RepoRecord"
//  - ``WorkspaceState"
//  - ``IndexArtifactRecord"
//
//  ### Bridge
//
//  - ``DevelopumBridgeMessage"
//  - ``DevelopumMessageType"
//

import AnigmaCore
import TelemetryCore
import DatabaseCore
import ExecutionCore
import Foundation

// MARK: - Module Info

/// DevelopumModule version information.
///
/// Use ``DevelopumModuleVersion/string`` to get the version string for display.
public enum DevelopumModuleVersion {
    /// Major version number.
    public static let major = 0
    /// Minor version number.
    public static let minor = 1
    /// Patch version number.
    public static let patch = 0
    /// Full version string in semantic versioning format.
    public static let string = "\(major).\(minor).\(patch)"
}

// MARK: - Module Registration

/// Develop mode capability module for Anigma IDE features.
///
/// Register this module with your ``PlatformRuntime`` to enable develop mode:
///
/// ```swift
/// try await DevelopumModule.register(runtime: runtime)
/// ```
///
/// The module registers:
/// - ``DevelopumEditorSystem`` for editor state management
/// - ``DevelopumIndexSystem`` for file indexing
/// - All workflows for file operations and session management
public enum DevelopumModule: CapabilityModule {
    /// Registers Develop mode capabilities with the runtime.
    ///
    /// This method:
    /// 1. Uses the runtime database executor for migrations
    /// 2. Runs database migrations for Developum tables
    /// 3. Registers ``DevelopumEditorSystem`` and ``DevelopumIndexSystem``
    /// 4. Registers all workflows with the workflow registry
    ///
    /// - Parameter runtime: The platform runtime to register with.
    /// - Throws: Errors if database operations or system registration fails.
    public static func register(runtime: PlatformRuntime) async throws {
        let databaseExecutor = runtime.databaseExecutor()
        try await DevelopumMigration.migrate(databaseExecutor)

        let world = await runtime.getWorld()
        let registry = await runtime.getWorkflowRegistry()
        let databaseService = DevelopumDatabaseService(databaseAuthority: runtime.database)

        let editorSystem = DevelopumEditorSystem(databaseService: databaseService, telemetryClient: nil)
        await world.registerSystem(editorSystem)

        let indexSystem = DevelopumIndexSystem(databaseService: databaseService, telemetryClient: nil)
        await world.registerSystem(indexSystem)

        let openFileWorkflow = OpenFileWorkflow(databaseService: databaseService)
        await registry.register(openFileWorkflow)

        let saveFileWorkflow = SaveFileWorkflow(databaseService: databaseService)
        await registry.register(saveFileWorkflow)

        let searchFilesWorkflow = SearchFilesWorkflow(databaseService: databaseService)
        await registry.register(searchFilesWorkflow)

        let indexFileWorkflow = IndexFileWorkflow(databaseService: databaseService)
        await registry.register(indexFileWorkflow)

        let createSessionWorkflow = CreateRepoSessionWorkflow(databaseService: databaseService)
        await registry.register(createSessionWorkflow)

        let closeSessionWorkflow = CloseRepoSessionWorkflow(databaseService: databaseService)
        await registry.register(closeSessionWorkflow)

        logInfo("DevelopumModule v\(DevelopumModuleVersion.string) registered", category: "DevelopumModule")
    }
}

// MARK: - Persistence Support

extension DevelopumModule {
    /// Creates a DevelopumArtifactService configured with the runtime's ArtifactAuthority.
    public static func createArtifactService(
        with runtime: PlatformRuntime,
        databaseService: DevelopumDatabaseService,
        telemetry: TelemetryClient? = nil
    ) async -> DevelopumArtifactService {
        return DevelopumArtifactService(
            artifactAuthority: await runtime.artifacts,
            databaseService: databaseService
        )
    }
    
    /// Creates a DevelopumReceiptService for evidence generation.
    public static func createReceiptService(
        databaseService: DevelopumDatabaseService,
        telemetry: TelemetryClient? = nil
    ) -> DevelopumReceiptService {
        return DevelopumReceiptService(
            databaseService: databaseService,
            telemetryClient: telemetry
        )
    }
}

// MARK: - Re-exports

public typealias DevelopumRepoRecord = RepoRecord
public typealias DevelopumWorkspaceState = WorkspaceState
public typealias DevelopumIndexArtifact = IndexArtifactRecord
