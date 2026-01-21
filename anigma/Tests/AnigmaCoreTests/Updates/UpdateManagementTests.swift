//
//  UpdateManagementTests.swift
//  AnigmaCoreTests
//
//  Tests for version management, update orchestration, checkpointing, and migrations
//

import XCTest
@testable import AnigmaCore

/// Minimal migration used for update tests.
private struct AddComponentMigration: Migration {
    let id: String
    let version: SemanticVersion
    let componentName: String
    let domain: String

    var description: String { "Add component \(componentName)" }
    var affectedDomains: [String] { [domain] }

    func up(context: MigrationContext) async throws -> DetailedMigrationResult {
        DetailedMigrationResult.success(details: "Added \(componentName)")
    }

    func down(context: MigrationContext) async throws -> DetailedMigrationResult {
        DetailedMigrationResult.success(details: "Removed \(componentName)")
    }
}

final class UpdateManagementTests: XCTestCase {

    // MARK: - Semantic Version Tests

    func testSemanticVersionParsing() {
        let v1 = SemanticVersion(string: "1.2.3")
        XCTAssertNotNil(v1)
        XCTAssertEqual(v1?.major, 1)
        XCTAssertEqual(v1?.minor, 2)
        XCTAssertEqual(v1?.patch, 3)

        let v2 = SemanticVersion(string: "2.0.0-beta+build123")
        XCTAssertNotNil(v2)
        XCTAssertEqual(v2?.major, 2)
        XCTAssertEqual(v2?.prerelease, "beta")
        XCTAssertEqual(v2?.build, "build123")
    }

    func testSemanticVersionComparison() {
        let v1 = SemanticVersion(major: 1, minor: 0, patch: 0)
        let v2 = SemanticVersion(major: 1, minor: 1, patch: 0)
        let v3 = SemanticVersion(major: 2, minor: 0, patch: 0)
        let v1beta = SemanticVersion(major: 1, minor: 0, patch: 0, prerelease: "beta")

        XCTAssertTrue(v1 < v2)
        XCTAssertTrue(v2 < v3)
        XCTAssertTrue(v1beta < v1)  // Prerelease < release
        XCTAssertTrue(v1.satisfies(minimum: v1))
        XCTAssertFalse(v1.satisfies(minimum: v2))
    }

    func testBreakingChangeDetection() {
        let v1 = SemanticVersion(major: 1, minor: 5, patch: 0)
        let v2 = SemanticVersion(major: 2, minor: 0, patch: 0)
        let v1patch = SemanticVersion(major: 1, minor: 5, patch: 1)

        XCTAssertTrue(v2.isBreakingFrom(v1))
        XCTAssertFalse(v1patch.isBreakingFrom(v1))
    }

    // MARK: - Release Manifest Tests

    func testReleaseManifestMandatory() {
        let now = Date()
        let future = now.addingTimeInterval(3600)  // 1 hour from now
        let past = now.addingTimeInterval(-3600)   // 1 hour ago

        let futureManifest = ReleaseManifest(
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            buildId: "build-123",
            mandatoryDate: future
        )
        XCTAssertFalse(futureManifest.isMandatory(at: now))
        XCTAssertNotNil(futureManifest.timeUntilMandatory(from: now))

        let pastManifest = ReleaseManifest(
            version: SemanticVersion(major: 1, minor: 2, patch: 0),
            buildId: "build-456",
            mandatoryDate: past
        )
        XCTAssertTrue(pastManifest.isMandatory(at: now))
        XCTAssertNil(pastManifest.timeUntilMandatory(from: now))
    }

    // MARK: - Update Orchestrator Tests

    func testUpdateOrchestratorPhases() async {
        let version = PlatformVersion(
            current: SemanticVersion(major: 1, minor: 0, patch: 0),
            minimumClient: SemanticVersion(major: 1, minor: 0, patch: 0),
            environment: .development
        )
        let orchestrator = UpdateOrchestrator(platformVersion: version)

        // Start in stable
        var phase = await orchestrator.getPhase()
        XCTAssertEqual(phase, .stable)

        // Announce release
        let manifest = ReleaseManifest(
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            buildId: "new-build"
        )
        _ = await orchestrator.announceRelease(manifest)
        phase = await orchestrator.getPhase()
        XCTAssertEqual(phase, .announced)

        // Start drain
        _ = await orchestrator.startDrainMode()
        phase = await orchestrator.getPhase()
        XCTAssertEqual(phase, .draining)

        // Block clients
        _ = await orchestrator.blockOutdatedClients()
        phase = await orchestrator.getPhase()
        XCTAssertEqual(phase, .blocked)

        // Enter maintenance
        _ = await orchestrator.enterMaintenance()
        phase = await orchestrator.getPhase()
        XCTAssertEqual(phase, .maintenance)

        // Complete deployment
        _ = await orchestrator.completeDeployment(newVersion: SemanticVersion(major: 1, minor: 1, patch: 0))
        phase = await orchestrator.getPhase()
        XCTAssertEqual(phase, .verifying)

        // Return to stable
        _ = await orchestrator.returnToStable()
        phase = await orchestrator.getPhase()
        XCTAssertEqual(phase, .stable)
    }

    func testClientRegistrationAndStatus() async {
        let version = PlatformVersion(
            current: SemanticVersion(major: 1, minor: 0, patch: 0),
            minimumClient: SemanticVersion(major: 1, minor: 0, patch: 0),
            environment: .development
        )
        let orchestrator = UpdateOrchestrator(platformVersion: version)

        // Register current client
        let currentClient = ClientVersionState(
            clientVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            serverVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            principalId: "user1"
        )
        let status = await orchestrator.registerClient(currentClient)
        XCTAssertEqual(status, .current)

        // Announce update
        let manifest = ReleaseManifest(
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            buildId: "new-build"
        )
        _ = await orchestrator.announceRelease(manifest)

        // Check that existing client now shows update available
        let stats = await orchestrator.getStatistics()
        XCTAssertEqual(stats.totalClients, 1)
    }

    func testOperationDecisions() async {
        let version = PlatformVersion(
            current: SemanticVersion(major: 1, minor: 0, patch: 0),
            minimumClient: SemanticVersion(major: 1, minor: 0, patch: 0),
            environment: .development
        )
        let orchestrator = UpdateOrchestrator(platformVersion: version)

        // Register client
        let client = ClientVersionState(
            clientVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            serverVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            principalId: "user1"
        )
        _ = await orchestrator.registerClient(client)

        // In stable phase, all operations allowed
        var decision = await orchestrator.canProceed(clientId: client.id, operationProfile: .hard)
        XCTAssertTrue(decision.allowed)

        // Start drain mode
        let manifest = ReleaseManifest(
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            buildId: "new-build"
        )
        _ = await orchestrator.announceRelease(manifest)
        _ = await orchestrator.startDrainMode()

        // Hard operations now blocked
        decision = await orchestrator.canProceed(clientId: client.id, operationProfile: .hard)
        XCTAssertFalse(decision.allowed)

        // Soft operations still allowed
        decision = await orchestrator.canProceed(clientId: client.id, operationProfile: .soft)
        XCTAssertTrue(decision.allowed)

        // Readonly always allowed
        decision = await orchestrator.canProceed(clientId: client.id, operationProfile: .readonly)
        XCTAssertTrue(decision.allowed)
    }

    // MARK: - Checkpoint Tests

    func testDraftManagement() async {
        let service = CheckpointService()

        // Create draft
        guard let data = "Test draft content".data(using: .utf8) else {
            fatalError("Failed to unwrap data")
        }
        let draft = await service.createDraft(
            type: "TestForm",
            principalId: "user1",
            data: data,
            metadata: DraftMetadata(title: "My Draft")
        )

        XCTAssertEqual(draft.draftType, "TestForm")
        XCTAssertEqual(draft.principalId, "user1")
        XCTAssertEqual(draft.state, .active)

        // Get drafts for user
        let drafts = await service.getDrafts(forPrincipal: "user1")
        XCTAssertEqual(drafts.count, 1)

        // Update draft
        guard let newData = "Updated content".data(using: .utf8) else {
            fatalError("Failed to unwrap newData")
        }
        let updated = await service.updateDraft(draftId: draft.draftId, data: newData)
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.checkpointVersion, 2)

        // Submit draft
        let submitted = await service.submitDraft(draft.draftId)
        XCTAssertEqual(submitted?.state, .submitted)

        // Active drafts should now be empty
        let activeDrafts = await service.getDrafts(forPrincipal: "user1")
        XCTAssertEqual(activeDrafts.count, 0)
    }

    func testWorkflowCheckpoints() async {
        let service = CheckpointService()

        // Create checkpoint
        let checkpoint = await service.createCheckpoint(
            workflowType: "MultiStepForm",
            principalId: "user1",
            totalSteps: 5,
            clientVersion: SemanticVersion(major: 1, minor: 0, patch: 0)
        )

        XCTAssertEqual(checkpoint.currentStep, 0)
        XCTAssertEqual(checkpoint.totalSteps, 5)
        XCTAssertEqual(checkpoint.progress, 0)

        // Update steps
        guard let step1Data = "Step 1 data".data(using: .utf8) else {
            fatalError("Failed to unwrap step1Data")
        }
        let updated = await service.updateCheckpoint(
            checkpointId: checkpoint.checkpointId,
            step: 1,
            stepData: step1Data
        )
        XCTAssertEqual(updated?.currentStep, 1)
        XCTAssertEqual(updated?.progress, 0.2)

        // Complete
        let completed = await service.completeCheckpoint(checkpoint.checkpointId)
        XCTAssertEqual(completed?.state, .completed)
    }

    func testCheckpointSweep() async {
        let service = CheckpointService()

        // Create multiple drafts and checkpoints
        guard let data = "Test".data(using: .utf8) else {
            fatalError("Failed to unwrap data")
        }
        _ = await service.createDraft(type: "Form1", principalId: "user1", data: data)
        _ = await service.createDraft(type: "Form2", principalId: "user1", data: data)
        _ = await service.createCheckpoint(workflowType: "Workflow1", principalId: "user1", totalSteps: 3)

        // Perform sweep
        let result = await service.checkpointSweep()

        XCTAssertEqual(result.draftsSaved, 2)
        XCTAssertEqual(result.checkpointsPaused, 1)

        // Verify states changed
        let stats = await service.getStatistics()
        XCTAssertEqual(stats.activeDrafts, 0)
        XCTAssertEqual(stats.savedDrafts, 2)
        XCTAssertEqual(stats.pausedWorkflows, 1)
    }

    // MARK: - Migration Engine Tests

    func testMigrationPlanning() async {
        let engine = MigrationEngine(currentVersion: SemanticVersion(major: 1, minor: 0, patch: 0))

        // Register migrations
        let migration1 = AddComponentMigration(
            id: "add-foo",
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            componentName: "FooComponent",
            domain: "Test"
        )
        let migration2 = AddComponentMigration(
            id: "add-bar",
            version: SemanticVersion(major: 1, minor: 2, patch: 0),
            componentName: "BarComponent",
            domain: "Test"
        )
        await engine.register([migration1, migration2])

        // Plan to 1.1.0
        let plan1 = await engine.plan(to: SemanticVersion(major: 1, minor: 1, patch: 0))
        XCTAssertEqual(plan1.migrations.count, 1)

        // Plan to 1.2.0
        let plan2 = await engine.plan(to: SemanticVersion(major: 1, minor: 2, patch: 0))
        XCTAssertEqual(plan2.migrations.count, 2)
    }

    func testMigrationExecution() async {
        let engine = MigrationEngine(currentVersion: SemanticVersion(major: 1, minor: 0, patch: 0))

        let migration = AddComponentMigration(
            id: "add-test",
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            componentName: "TestComponent",
            domain: "Test"
        )
        await engine.register(migration)

        let plan = await engine.plan(to: SemanticVersion(major: 1, minor: 1, patch: 0))

        let context = MigrationContext(
            environment: .development,
            principalId: "admin",
            targetVersion: SemanticVersion(major: 1, minor: 1, patch: 0)
        )

        let result = await engine.execute(plan: plan, context: context)

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.completedMigrations.count, 1)

        // Check version updated
        let currentVersion = await engine.getCurrentVersion()
        XCTAssertEqual(currentVersion, SemanticVersion(major: 1, minor: 1, patch: 0))

        // Check migration recorded
        let wasExecuted = await engine.wasExecuted("add-test")
        XCTAssertTrue(wasExecuted)
    }

    func testMigrationDryRun() async {
        let engine = MigrationEngine(currentVersion: SemanticVersion(major: 1, minor: 0, patch: 0))

        let migration = AddComponentMigration(
            id: "add-test",
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            componentName: "TestComponent",
            domain: "Test"
        )
        await engine.register(migration)

        let plan = await engine.plan(to: SemanticVersion(major: 1, minor: 1, patch: 0))

        let context = MigrationContext(
            environment: .development,
            dryRun: true,
            principalId: "admin",
            targetVersion: SemanticVersion(major: 1, minor: 1, patch: 0)
        )

        let result = await engine.dryRun(plan: plan, context: context)

        XCTAssertTrue(result.wouldSucceed)
        XCTAssertEqual(result.validations.count, 1)

        // Version should NOT have changed
        let currentVersion = await engine.getCurrentVersion()
        XCTAssertEqual(currentVersion, SemanticVersion(major: 1, minor: 0, patch: 0))
    }

    // MARK: - Update Service Tests

    func testUpdateServiceFullFlow() async {
        let service = UpdateService(
            initialVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            environment: .development
        )

        // Register new release
        let manifest = ReleaseManifest(
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            buildId: "build-111",
            notes: "Test release"
        )
        await service.registerRelease(manifest)

        // Preview update
        let preview = await service.previewUpdate(
            to: SemanticVersion(major: 1, minor: 1, patch: 0),
            principalId: "admin"
        )
        XCTAssertTrue(preview.valid)

        // Perform full update (with no grace period for testing)
        let result = await service.performFullUpdate(
            to: SemanticVersion(major: 1, minor: 1, patch: 0),
            principalId: "admin",
            gracePeriodSeconds: 0
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.phase, .stable)

        // Check status
        let status = await service.getStatus()
        XCTAssertEqual(status.currentVersion, SemanticVersion(major: 1, minor: 1, patch: 0))
    }

    func testClientRegistration() async {
        let service = UpdateService(
            initialVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            environment: .development
        )

        // Register current client
        let result = await service.registerClient(
            clientVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            principalId: "user1"
        )

        XCTAssertEqual(result.status, .current)
        XCTAssertEqual(result.phase, .stable)
        XCTAssertEqual(result.serverVersion, SemanticVersion(major: 1, minor: 0, patch: 0))
    }

    func testDraftsThroughService() async {
        let service = UpdateService(
            initialVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            environment: .development
        )

        // Create draft
        guard let data = "Test data".data(using: .utf8) else {
            fatalError("Failed to unwrap data")
        }
        let draft = await service.createDraft(
            type: "TestForm",
            principalId: "user1",
            data: data
        )

        XCTAssertEqual(draft.draftType, "TestForm")

        // Get drafts
        let drafts = await service.getDrafts(forPrincipal: "user1")
        XCTAssertEqual(drafts.count, 1)

        // Save draft
        guard let newData = "Updated".data(using: .utf8) else {
            fatalError("Failed to unwrap newData")
        }
        let saved = await service.saveDraft(draftId: draft.draftId, data: newData)
        XCTAssertNotNil(saved)
    }
}
