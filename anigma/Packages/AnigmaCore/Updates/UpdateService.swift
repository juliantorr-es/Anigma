//
//  UpdateService.swift
//  AnigmaCore
//
//  AnigmaCore - Unified Update Service
//
//  High-level service coordinating version management, orchestration,
//  checkpointing, and migrations into a single coherent update flow.
//

import Foundation

// MARK: - Update Service

/// Unified service for managing platform updates
public actor UpdateService {
    private let orchestrator: UpdateOrchestrator
    private let checkpointService: CheckpointService
    private let migrationEngine: MigrationEngine
    private let environment: DeploymentEnvironment

    // Release storage
    private var releases: [SemanticVersion: ReleaseManifest] = [:]
    private var currentRelease: ReleaseManifest?

    public init(
        initialVersion: SemanticVersion,
        environment: DeploymentEnvironment = .development
    ) {
        let platformVersion = PlatformVersion(
            current: initialVersion,
            minimumClient: initialVersion,
            environment: environment
        )

        self.orchestrator = UpdateOrchestrator(
            platformVersion: platformVersion,
            environment: environment
        )
        self.checkpointService = CheckpointService()
        self.migrationEngine = MigrationEngine(currentVersion: initialVersion)
        self.environment = environment
    }

    // MARK: - Release Management

    /// Register a new release
    public func registerRelease(_ manifest: ReleaseManifest) {
        releases[manifest.version] = manifest
    }

    /// Get available releases
    public func getAvailableReleases() -> [ReleaseManifest] {
        return releases.values.sorted { $0.version < $1.version }
    }

    /// Get current release
    public func getCurrentRelease() -> ReleaseManifest? {
        return currentRelease
    }

    // MARK: - Update Flow

    /// Start update process
    public func startUpdate(
        to version: SemanticVersion,
        principalId: String
    ) async -> UpdateFlowResult {
        // Get release manifest
        guard let manifest = releases[version] else {
            return UpdateFlowResult(
                success: false,
                phase: .stable,
                error: "Release \(version) not found"
            )
        }

        // Check if already on this version
        let currentVersion = await orchestrator.getPlatformVersion()
        if currentVersion.current >= version {
            return UpdateFlowResult(
                success: false,
                phase: .stable,
                error: "Already on version \(currentVersion.current)"
            )
        }

        // Announce release
        let announceEvent = await orchestrator.announceRelease(manifest)

        return UpdateFlowResult(
            success: true,
            phase: await orchestrator.getPhase(),
            events: [announceEvent],
            manifest: manifest
        )
    }

    /// Begin drain mode (grace period)
    public func beginDrainMode() async -> UpdateFlowResult {
        // Trigger checkpoint sweep
        let sweepResult = await checkpointService.checkpointSweep()

        // Start drain
        let drainEvent = await orchestrator.startDrainMode()

        return UpdateFlowResult(
            success: true,
            phase: await orchestrator.getPhase(),
            events: [drainEvent],
            checkpointSweep: sweepResult
        )
    }

    /// Block outdated clients (end of grace period)
    public func endGracePeriod() async -> UpdateFlowResult {
        let blockEvent = await orchestrator.blockOutdatedClients()

        return UpdateFlowResult(
            success: true,
            phase: await orchestrator.getPhase(),
            events: [blockEvent]
        )
    }

    /// Execute update (maintenance mode + migrations)
    public func executeUpdate(
        to version: SemanticVersion,
        principalId: String
    ) async -> UpdateFlowResult {
        guard let manifest = releases[version] else {
            return UpdateFlowResult(
                success: false,
                phase: await orchestrator.getPhase(),
                error: "Release \(version) not found"
            )
        }

        // Enter maintenance
        let maintenanceEvent = await orchestrator.enterMaintenance()
        var events = [maintenanceEvent]

        // Plan migrations
        let plan = await migrationEngine.plan(to: version)

        // Execute migrations
        let context = MigrationContext(
            environment: environment,
            dryRun: false,
            principalId: principalId,
            previousVersion: await migrationEngine.getCurrentVersion(),
            targetVersion: version
        )

        let migrationResult = await migrationEngine.execute(plan: plan, context: context)

        if !migrationResult.success {
            // Migration failed - attempt rollback
            let rollbackPlan = await migrationEngine.planRollback(
                to: await orchestrator.getPlatformVersion().current
            )
            _ = await migrationEngine.rollback(plan: rollbackPlan, context: context)

            return UpdateFlowResult(
                success: false,
                phase: await orchestrator.getPhase(),
                events: events,
                migrationResult: migrationResult,
                error: "Migration failed: \(migrationResult.failedMigrations.first?.error ?? "Unknown")"
            )
        }

        // Complete deployment
        let deployEvent = await orchestrator.completeDeployment(newVersion: version)
        events.append(deployEvent)

        // Verify and return to stable
        let stableEvent = await orchestrator.returnToStable()
        events.append(stableEvent)

        // Update current release
        currentRelease = manifest

        return UpdateFlowResult(
            success: true,
            phase: await orchestrator.getPhase(),
            events: events,
            manifest: manifest,
            migrationResult: migrationResult
        )
    }

    /// Full update flow (announce → drain → block → execute)
    public func performFullUpdate(
        to version: SemanticVersion,
        principalId: String,
        gracePeriodSeconds: TimeInterval = 0
    ) async -> UpdateFlowResult {
        // Start
        var result = await startUpdate(to: version, principalId: principalId)
        guard result.success else { return result }

        var allEvents = result.events

        // Begin drain
        result = await beginDrainMode()
        allEvents.append(contentsOf: result.events)

        // Wait for grace period
        if gracePeriodSeconds > 0 {
            try? await Task.sleep(nanoseconds: UInt64(gracePeriodSeconds * 1_000_000_000))
        }

        // End grace period
        result = await endGracePeriod()
        allEvents.append(contentsOf: result.events)

        // Execute
        result = await executeUpdate(to: version, principalId: principalId)
        allEvents.append(contentsOf: result.events)

        return UpdateFlowResult(
            success: result.success,
            phase: result.phase,
            events: allEvents,
            manifest: result.manifest,
            checkpointSweep: result.checkpointSweep,
            migrationResult: result.migrationResult,
            error: result.error
        )
    }

    // MARK: - Dry Run

    /// Preview what an update would do
    public func previewUpdate(
        to version: SemanticVersion,
        principalId: String
    ) async -> UpdatePreview {
        guard let manifest = releases[version] else {
            return UpdatePreview(
                valid: false,
                error: "Release \(version) not found"
            )
        }

        // Plan migrations
        let plan = await migrationEngine.plan(to: version)

        // Dry run
        let context = MigrationContext(
            environment: environment,
            dryRun: true,
            principalId: principalId,
            previousVersion: await migrationEngine.getCurrentVersion(),
            targetVersion: version
        )

        let dryRun = await migrationEngine.dryRun(plan: plan, context: context)

        // Get current clients
        let stats = await orchestrator.getStatistics()
        let checkpointStats = await checkpointService.getStatistics()

        return UpdatePreview(
            valid: dryRun.wouldSucceed,
            manifest: manifest,
            migrationCount: plan.migrations.count,
            estimatedDuration: dryRun.estimatedDuration,
            affectedDomains: dryRun.affectedDomains,
            requiresMaintenanceMode: dryRun.requiresMaintenanceMode,
            hasIrreversibleMigrations: dryRun.hasIrreversibleSteps,
            affectedClients: stats.totalClients,
            activeDrafts: checkpointStats.activeDrafts,
            inProgressWorkflows: checkpointStats.inProgressWorkflows,
            validationIssues: dryRun.validations.filter { !$0.valid }.map { $0.message }
        )
    }

    // MARK: - Client Management

    /// Register a client session
    public func registerClient(
        clientVersion: SemanticVersion,
        principalId: String,
        deviceId: String? = nil,
        capabilities: ClientCapabilities = ClientCapabilities()
    ) async -> ClientRegistrationResult {
        let state = ClientVersionState(
            clientVersion: clientVersion,
            serverVersion: await orchestrator.getPlatformVersion().current,
            principalId: principalId,
            deviceId: deviceId,
            capabilities: capabilities
        )

        let status = await orchestrator.registerClient(state)
        let phase = await orchestrator.getPhase()

        // Get pending release info
        var pendingRelease: ReleaseManifest?
        var timeUntilMandatory: TimeInterval?

        let platformVersion = await orchestrator.getPlatformVersion()
        if let pending = platformVersion.pendingRollout,
           let manifest = releases[pending] {
            pendingRelease = manifest
            timeUntilMandatory = manifest.timeUntilMandatory()
        }

        return ClientRegistrationResult(
            sessionId: state.id,
            status: status,
            phase: phase,
            serverVersion: platformVersion.current,
            pendingRelease: pendingRelease,
            timeUntilMandatory: timeUntilMandatory,
            message: messageForStatus(status, phase: phase)
        )
    }

    /// Check if operation is allowed
    public func canPerformOperation(
        clientId: UUID,
        profile: CheckpointProfile
    ) async -> UpdateDecision {
        return await orchestrator.canProceed(clientId: clientId, operationProfile: profile)
    }

    // MARK: - Draft/Checkpoint Management

    /// Create a draft
    public func createDraft(
        type: String,
        principalId: String,
        deviceId: String? = nil,
        data: Data,
        metadata: DraftMetadata = DraftMetadata()
    ) async -> DraftComponent {
        return await checkpointService.createDraft(
            type: type,
            principalId: principalId,
            deviceId: deviceId,
            data: data,
            metadata: metadata
        )
    }

    /// Save draft
    public func saveDraft(draftId: UUID, data: Data) async -> DraftComponent? {
        return await checkpointService.updateDraft(draftId: draftId, data: data)
    }

    /// Get user's drafts
    public func getDrafts(forPrincipal principalId: String) async -> [DraftComponent] {
        return await checkpointService.getDrafts(forPrincipal: principalId)
    }

    /// Create workflow checkpoint
    public func createWorkflowCheckpoint(
        workflowType: String,
        principalId: String,
        totalSteps: Int
    ) async -> WorkflowCheckpoint {
        let version = await orchestrator.getPlatformVersion().current
        return await checkpointService.createCheckpoint(
            workflowType: workflowType,
            principalId: principalId,
            totalSteps: totalSteps,
            clientVersion: version
        )
    }

    /// Update workflow step
    public func updateWorkflowStep(
        checkpointId: UUID,
        step: Int,
        data: Data
    ) async -> WorkflowCheckpoint? {
        return await checkpointService.updateCheckpoint(
            checkpointId: checkpointId,
            step: step,
            stepData: data
        )
    }

    /// Get user's workflow checkpoints
    public func getWorkflowCheckpoints(forPrincipal principalId: String) async -> [WorkflowCheckpoint] {
        return await checkpointService.getCheckpoints(forPrincipal: principalId)
    }

    // MARK: - Migration Management

    /// Register migrations
    public func registerMigrations(_ migrations: [any Migration]) async {
        await migrationEngine.register(migrations)
    }

    /// Get migration history
    public func getMigrationHistory() async -> [MigrationRecord] {
        return await migrationEngine.getHistory()
    }

    // MARK: - Status

    /// Get update status
    public func getStatus() async -> UpdateStatus {
        let phase = await orchestrator.getPhase()
        let version = await orchestrator.getPlatformVersion()
        let stats = await orchestrator.getStatistics()
        let checkpoints = await checkpointService.getStatistics()
        let events = await orchestrator.getRecentEvents(limit: 10)

        return UpdateStatus(
            phase: phase,
            currentVersion: version.current,
            minimumClientVersion: version.minimumClient,
            pendingVersion: version.pendingRollout,
            environment: environment,
            clientStats: stats,
            checkpointStats: checkpoints,
            recentEvents: events
        )
    }

    // MARK: - Private Helpers

    private func messageForStatus(_ status: ClientUpdateStatus, phase: UpdatePhase) -> String {
        switch status {
        case .current:
            return "Client is up to date"
        case .updateAvailable:
            return "Update available. You can continue working."
        case .drainMode:
            return "Update pending. Please finish current work and save."
        case .blocked:
            return "Update required. Please restart to update."
        case .updating:
            return "Update in progress..."
        }
    }
}

// MARK: - Result Types

/// Result of update flow step
public struct UpdateFlowResult: Sendable {
    public let success: Bool
    public let phase: UpdatePhase
    public var events: [UpdateEvent] = []
    public var manifest: ReleaseManifest?
    public var checkpointSweep: CheckpointSweepResult?
    public var migrationResult: MigrationExecutionResult?
    public var error: String?
}

/// Preview of what an update would do
public struct UpdatePreview: Sendable {
    public let valid: Bool
    public var manifest: ReleaseManifest?
    public var migrationCount: Int = 0
    public var estimatedDuration: TimeInterval = 0
    public var affectedDomains: [String] = []
    public var requiresMaintenanceMode: Bool = false
    public var hasIrreversibleMigrations: Bool = false
    public var affectedClients: Int = 0
    public var activeDrafts: Int = 0
    public var inProgressWorkflows: Int = 0
    public var validationIssues: [String] = []
    public var error: String?
}

/// Result of client registration
public struct ClientRegistrationResult: Sendable {
    public let sessionId: UUID
    public let status: ClientUpdateStatus
    public let phase: UpdatePhase
    public let serverVersion: SemanticVersion
    public let pendingRelease: ReleaseManifest?
    public let timeUntilMandatory: TimeInterval?
    public let message: String
}

/// Current update status
public struct UpdateStatus: Sendable {
    public let phase: UpdatePhase
    public let currentVersion: SemanticVersion
    public let minimumClientVersion: SemanticVersion
    public let pendingVersion: SemanticVersion?
    public let environment: DeploymentEnvironment
    public let clientStats: UpdateStatistics
    public let checkpointStats: CheckpointStatistics
    public let recentEvents: [UpdateEvent]
}
