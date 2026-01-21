//
//  UpdateIntegrationTests.swift
//  AnigmaCoreTests
//
//  Tests for update integration with governance, cohorts, observability, and Codex
//

import XCTest
@testable import AnigmaCore

final class UpdateIntegrationTests: XCTestCase {

    // MARK: - Operation Profile Registry Tests

    func testOperationProfileRegistration() async {
        let registry = OperationProfileRegistry()

        // Register profiles
        await registry.register(module: "Pragma", operation: "create_task", profile: .soft)
        await registry.register(module: "Pragma", operation: "bulk_import", profile: .hard)
        await registry.register(module: "Codex", operation: "view_page", profile: .readonly)

        // Lookup
        let taskProfile = await registry.getProfile(module: "Pragma", operation: "create_task")
        XCTAssertEqual(taskProfile, .soft)

        let importProfile = await registry.getProfile(module: "Pragma", operation: "bulk_import")
        XCTAssertEqual(importProfile, .hard)

        let viewProfile = await registry.getProfile(module: "Codex", operation: "view_page")
        XCTAssertEqual(viewProfile, .readonly)
    }

    func testOperationProfileFallback() async {
        let registry = OperationProfileRegistry()

        // Set module default
        await registry.registerModuleDefault(module: "Pragma", profile: .soft)

        // Set global default
        await registry.setGlobalDefault(.checkpoint)

        // Unknown operation in known module falls back to module default
        let pragmaUnknown = await registry.getProfile(module: "Pragma", operation: "unknown_op")
        XCTAssertEqual(pragmaUnknown, .soft)

        // Unknown module falls back to global default
        let unknownModule = await registry.getProfile(module: "Unknown", operation: "anything")
        XCTAssertEqual(unknownModule, .checkpoint)
    }

    func testDomainProfilePresets() {
        // Verify all domain profiles are properly defined
        XCTAssertFalse(DomainProfiles.pragmaProfiles.isEmpty)
        XCTAssertFalse(DomainProfiles.conexusProfiles.isEmpty)
        XCTAssertFalse(DomainProfiles.codexProfiles.isEmpty)
        XCTAssertFalse(DomainProfiles.diaplasionProfiles.isEmpty)
        XCTAssertFalse(DomainProfiles.transcriptumProfiles.isEmpty)
        XCTAssertFalse(DomainProfiles.dspsProfiles.isEmpty)

        // Check that combined profiles work
        let all = DomainProfiles.allProfiles
        XCTAssertTrue(all.count > 30)  // Should have substantial coverage

        // Verify some specific critical profiles
        let hardOps = all.filter { $0.profile == .hard }
        XCTAssertTrue(hardOps.contains { $0.operation == "submit_grades" })
        XCTAssertTrue(hardOps.contains { $0.operation == "batch_ocr" })
    }

    func testBatchProfileRegistration() async {
        let registry = OperationProfileRegistry()

        // Register all domain profiles
        await registry.registerBatch(DomainProfiles.allProfiles)

        // Verify they're all registered
        let profiles = await registry.listProfiles()
        XCTAssertEqual(profiles.count, DomainProfiles.allProfiles.count)

        // Spot check
        let gradeSubmit = await registry.getProfile(module: "Transcriptum", operation: "submit_grades")
        XCTAssertEqual(gradeSubmit, .hard)
    }

    // MARK: - Cohort Management Tests

    func testCohortRegistration() async {
        let manager = CohortManager()

        // Register standard cohorts
        for cohort in StandardCohorts.all {
            await manager.registerCohort(cohort)
        }

        // List cohorts (should be ordered by priority)
        let cohorts = await manager.listCohorts()
        XCTAssertEqual(cohorts.count, 5)
        XCTAssertEqual(cohorts.first?.name, "IT & Administrators")
        XCTAssertEqual(cohorts.last?.name, "Students")
    }

    func testCohortCriteriaMatching() {
        // Role matching
        let roleCriteria = CohortCriteria.roles(["admin", "it_staff"])
        XCTAssertTrue(roleCriteria.matches(principalId: "user1", roles: ["admin"]))
        XCTAssertFalse(roleCriteria.matches(principalId: "user1", roles: ["student"]))

        // Department matching
        let deptCriteria = CohortCriteria.departments(["DSPS", "IT"])
        XCTAssertTrue(deptCriteria.matches(principalId: "user1", department: "DSPS"))
        XCTAssertFalse(deptCriteria.matches(principalId: "user1", department: "Math"))

        // Principal matching
        let principalCriteria = CohortCriteria.principals(["user1", "user2"])
        XCTAssertTrue(principalCriteria.matches(principalId: "user1"))
        XCTAssertFalse(principalCriteria.matches(principalId: "user3"))

        // Environment matching
        let envCriteria = CohortCriteria.environment(.staging)
        XCTAssertTrue(envCriteria.matches(principalId: "user1", environment: .staging))
        XCTAssertFalse(envCriteria.matches(principalId: "user1", environment: .production))

        // All matching
        let allCriteria = CohortCriteria.all
        XCTAssertTrue(allCriteria.matches(principalId: "anyone"))
    }

    func testAutoAssignCohort() async {
        let manager = CohortManager()

        // Register cohorts
        for cohort in StandardCohorts.all {
            await manager.registerCohort(cohort)
        }

        let clientId = UUID()

        // Auto-assign based on IT role
        let assigned = await manager.autoAssignClient(
            clientId,
            principalId: "it_user",
            roles: ["it_staff"],
            department: "IT",
            activeModules: [],
            environment: .production
        )

        XCTAssertNotNil(assigned)
        XCTAssertEqual(assigned?.name, "IT & Administrators")

        // Verify client is in cohort
        let cohort = await manager.getClientCohort(clientId)
        XCTAssertNotNil(cohort)
        XCTAssertEqual(cohort?.name, "IT & Administrators")
    }

    func testCohortRolloutState() async {
        let manager = CohortManager()

        let cohort = UpdateCohort(
            name: "Test Cohort",
            priority: 10,
            criteria: .all
        )
        await manager.registerCohort(cohort)

        let version = SemanticVersion(major: 1, minor: 1, patch: 0)

        // Initially not started
        var state = await manager.getRolloutState(cohortId: cohort.id, version: version)
        XCTAssertEqual(state, .notStarted)

        // Set to available
        await manager.setRolloutState(cohortId: cohort.id, version: version, state: .available)
        state = await manager.getRolloutState(cohortId: cohort.id, version: version)
        XCTAssertEqual(state, .available)

        // Progress through states
        await manager.setRolloutState(cohortId: cohort.id, version: version, state: .draining)
        state = await manager.getRolloutState(cohortId: cohort.id, version: version)
        XCTAssertEqual(state, .draining)

        await manager.setRolloutState(cohortId: cohort.id, version: version, state: .mandatory)
        state = await manager.getRolloutState(cohortId: cohort.id, version: version)
        XCTAssertEqual(state, .mandatory)
    }

    func testVersionAvailabilityForCohort() async {
        let manager = CohortManager()

        let fastCohort = UpdateCohort(name: "Fast", priority: 10, criteria: .roles(["admin"]))
        let slowCohort = UpdateCohort(name: "Slow", priority: 100, criteria: .all)

        await manager.registerCohort(fastCohort)
        await manager.registerCohort(slowCohort)

        let clientFast = UUID()
        let clientSlow = UUID()

        await manager.assignClient(clientFast, to: fastCohort.id)
        await manager.assignClient(clientSlow, to: slowCohort.id)

        let version = SemanticVersion(major: 1, minor: 1, patch: 0)

        // Version available only for fast cohort
        await manager.setRolloutState(cohortId: fastCohort.id, version: version, state: .available)
        await manager.setRolloutState(cohortId: slowCohort.id, version: version, state: .notStarted)

        let fastAvailable = await manager.isVersionAvailable(version, forClient: clientFast)
        let slowAvailable = await manager.isVersionAvailable(version, forClient: clientSlow)

        XCTAssertTrue(fastAvailable)
        XCTAssertFalse(slowAvailable)
    }

    func testRolloutStatistics() async {
        let manager = CohortManager()

        let cohort1 = UpdateCohort(name: "Cohort 1", priority: 10, criteria: .all)
        let cohort2 = UpdateCohort(name: "Cohort 2", priority: 20, criteria: .all)

        await manager.registerCohort(cohort1)
        await manager.registerCohort(cohort2)

        // Add clients to cohorts
        for i in 0..<10 {
            let clientId = UUID()
            await manager.assignClient(clientId, to: i < 5 ? cohort1.id : cohort2.id)
        }

        let version = SemanticVersion(major: 1, minor: 1, patch: 0)

        await manager.setRolloutState(cohortId: cohort1.id, version: version, state: .mandatory)
        await manager.setRolloutState(cohortId: cohort2.id, version: version, state: .available)

        let stats = await manager.getRolloutStatistics(version: version)

        XCTAssertEqual(stats.version, version)
        XCTAssertEqual(stats.completed, 5)  // Cohort 1 is mandatory
        XCTAssertEqual(stats.inProgress, 5)  // Cohort 2 is available
    }

    // MARK: - Update Telemetry Tests

    func testUpdateTelemetryPayload() async {
        let recorder = UpdateTelemetryRecorder()

        let event = UpdateEvent(
            eventType: .releaseAnnounced,
            fromVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            toVersion: SemanticVersion(major: 1, minor: 1, patch: 0),
            phase: .announced,
            details: "Test release",
            affectedClients: 50
        )

        let payload = await recorder.recordEvent(event)

        XCTAssertEqual(payload.eventName, "update.release.announced")
        XCTAssertEqual(payload.properties["from_version"], "1.0.0")
        XCTAssertEqual(payload.properties["to_version"], "1.1.0")
        XCTAssertEqual(payload.properties["affected_clients"], "50")
    }

    func testMigrationTelemetry() async {
        let recorder = UpdateTelemetryRecorder()

        let record = MigrationRecord(
            id: "test-migration",
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            description: "Test migration",
            status: .completed,
            startedAt: Date().addingTimeInterval(-120),
            completedAt: Date(),
            affectedEntities: 1000,
            isReversible: true
        )

        let payload = await recorder.recordMigration(record)

        XCTAssertEqual(payload.migrationId, "test-migration")
        XCTAssertEqual(payload.status, .completed)
        XCTAssertEqual(payload.affectedEntities, 1000)
        XCTAssertNil(payload.error)
    }

    func testClientUpdateLatencyTracking() async {
        let recorder = UpdateTelemetryRecorder()

        let clientId = UUID()
        let requestTime = Date().addingTimeInterval(-7200)  // 2 hours ago

        await recorder.markUpdateRequested(clientId: clientId, at: requestTime)

        let latency = await recorder.recordClientUpdate(
            clientId: clientId,
            oldVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            newVersion: SemanticVersion(major: 1, minor: 1, patch: 0)
        )

        XCTAssertNotNil(latency)
        XCTAssertGreaterThan(latency!, 1.9)  // Should be ~2 hours
        XCTAssertLessThan(latency!, 2.1)
    }

    func testMetricsSnapshot() async {
        let recorder = UpdateTelemetryRecorder()

        let stats = UpdateStatistics(
            phase: .draining,
            currentVersion: SemanticVersion(major: 1, minor: 1, patch: 0),
            pendingVersion: SemanticVersion(major: 1, minor: 2, patch: 0),
            totalClients: 100
        )

        let snapshot = await recorder.generateMetricsSnapshot(from: stats)

        XCTAssertEqual(snapshot.phase, .draining)
        XCTAssertEqual(snapshot.totalClients, 100)
    }

    // MARK: - Update Dashboard Tests

    func testUpdateDashboardData() {
        let dashboard = UpdateDashboardData(
            currentPhase: .stable,
            currentVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            clientBreakdown: ClientVersionBreakdown(
                total: 100,
                current: 90,
                outdated: 5,
                draining: 3,
                blocked: 2
            )
        )

        XCTAssertEqual(dashboard.clientBreakdown.currentPercentage, 90.0)
        XCTAssertNil(dashboard.pendingVersion)
    }

    func testRolloutProgress() {
        let progress = RolloutProgress(
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            startedAt: Date().addingTimeInterval(-3600),
            percentComplete: 75.0,
            cohortProgress: [
                CohortProgress(cohortName: "IT", state: .mandatory, clientsTotal: 10, clientsUpdated: 10),
                CohortProgress(cohortName: "Staff", state: .draining, clientsTotal: 50, clientsUpdated: 30)
            ]
        )

        XCTAssertEqual(progress.cohortProgress.count, 2)
        XCTAssertEqual(progress.cohortProgress[0].percentComplete, 100.0)
        XCTAssertEqual(progress.cohortProgress[1].percentComplete, 60.0)
    }

    func testUpdateReportGeneration() {
        let dashboard = UpdateDashboardData(
            currentPhase: .draining,
            currentVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            pendingVersion: SemanticVersion(major: 1, minor: 1, patch: 0),
            clientBreakdown: ClientVersionBreakdown(
                total: 100,
                current: 50,
                outdated: 20,
                draining: 25,
                blocked: 5
            ),
            rolloutProgress: RolloutProgress(
                version: SemanticVersion(major: 1, minor: 1, patch: 0),
                startedAt: Date(),
                percentComplete: 50.0
            ),
            recentEvents: [
                UpdateEventSummary(
                    timestamp: Date(),
                    eventType: "release_announced",
                    description: "Version 1.1.0 announced",
                    affectedClients: 100
                )
            ]
        )

        let report = UpdateReportGenerator.generateAdminSummary(from: dashboard)

        XCTAssertTrue(report.contains("Update Status Report"))
        XCTAssertTrue(report.contains("draining"))
        XCTAssertTrue(report.contains("1.0.0"))
        XCTAssertTrue(report.contains("1.1.0"))
        XCTAssertTrue(report.contains("50.0%"))
    }

    // MARK: - Release Documentation Tests

    func testReleaseDocumentationBuilder() {
        let doc = ReleaseDocumentationBuilder(
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            buildId: "build-123"
        )
        .summary("This release includes new features and bug fixes.")
        .releaseType(.minor)
        .addChange(category: .features, ChangeItem(
            description: "Added new DSPS workflow",
            module: "DSPS"
        ))
        .addChange(category: .bugFixes, ChangeItem(
            description: "Fixed alt-media queue display"
        ))
        .addMigration(MigrationNote(
            migrationId: "add-dsps-fields",
            description: "Adds new fields to DSPS cases",
            affectedDomains: ["DSPS", "Conexus"],
            dataImpact: .additive
        ))
        .addKnownIssue(KnownIssue(
            description: "Slow performance on large PDFs",
            severity: .minor,
            workaround: "Split large PDFs before processing"
        ))
        .addStakeholderNote(role: "DSPS Staff", note: "The new workflow simplifies case intake.")
        .affectedModules(["DiaplasionModule", "ConexusModule", "DSPS"])
        .build()

        XCTAssertEqual(doc.releaseVersion, SemanticVersion(major: 1, minor: 1, patch: 0))
        XCTAssertEqual(doc.releaseType, .minor)
        XCTAssertEqual(doc.whatChanged.count, 2)
        XCTAssertEqual(doc.migrationNotes.count, 1)
        XCTAssertEqual(doc.knownIssues.count, 1)
        XCTAssertEqual(doc.stakeholderNotes.count, 1)
        XCTAssertEqual(doc.affectedModules.count, 3)
    }

    func testMarkdownGeneration() {
        let doc = ReleaseDocumentationBuilder(
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            buildId: "build-123"
        )
        .summary("Test release")
        .addChange(category: .features, ChangeItem(description: "Feature 1"))
        .addChange(category: .bugFixes, ChangeItem(description: "Bug fix 1"))
        .build()

        let markdown = ReleaseDocumentationGenerator.generateMarkdown(from: doc)

        XCTAssertTrue(markdown.contains("# Release 1.1.0"))
        XCTAssertTrue(markdown.contains("## Summary"))
        XCTAssertTrue(markdown.contains("Test release"))
        XCTAssertTrue(markdown.contains("### Features"))
        XCTAssertTrue(markdown.contains("Feature 1"))
        XCTAssertTrue(markdown.contains("### Bug Fixes"))
        XCTAssertTrue(markdown.contains("Bug fix 1"))
    }

    func testCodexPageContentGeneration() {
        let doc = ReleaseDocumentationBuilder(
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            buildId: "build-123"
        )
        .summary("Test release")
        .addBreakingChange(BreakingChange(
            description: "API changed",
            affectedFeature: "REST API",
            migrationPath: "Update client library"
        ))
        .build()

        let content = ReleaseDocumentationGenerator.generateCodexPageContent(from: doc)

        XCTAssertEqual(content.title, "Release 1.1.0")
        XCTAssertEqual(content.contentType, .markdown)
        XCTAssertTrue(content.metadata.hasBreakingChanges)
        XCTAssertFalse(content.metadata.hasMigrations)
    }

    func testStakeholderSummaryGeneration() {
        let doc = ReleaseDocumentationBuilder(
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            buildId: "build-123"
        )
        .summary("Major improvements to alt-media processing")
        .addStakeholderNote(
            role: "DSPS Staff",
            note: "Your workflow has been streamlined. Check the new intake form."
        )
        .addBreakingChange(BreakingChange(
            description: "Old intake form removed",
            affectedFeature: "Intake",
            migrationPath: "Use new intake wizard"
        ))
        .build()

        let summary = ReleaseDocumentationGenerator.generateStakeholderSummary(
            from: doc,
            for: "DSPS Staff"
        )

        XCTAssertTrue(summary.contains("Summary for DSPS Staff"))
        XCTAssertTrue(summary.contains("workflow has been streamlined"))
        XCTAssertTrue(summary.contains("Action Required"))
        XCTAssertTrue(summary.contains("Old intake form removed"))
    }

    // MARK: - Update Write Check Tests

    func testUpdatePhaseCheck() async {
        let version = PlatformVersion(
            current: SemanticVersion(major: 1, minor: 0, patch: 0),
            minimumClient: SemanticVersion(major: 1, minor: 0, patch: 0),
            environment: .development
        )
        let orchestrator = UpdateOrchestrator(platformVersion: version)

        // Register a client
        let client = ClientVersionState(
            clientVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            serverVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
            principalId: "user1"
        )
        _ = await orchestrator.registerClient(client)

        // Create check
        let check = UpdatePhaseCheck(
            orchestrator: orchestrator,
            clientIdProvider: { client.id },
            profileProvider: { _ in .soft }
        )

        // In stable, should pass
        let proposal = WriteProposal(
            principal: "user1",
            module: "Pragma",
            operation: "create_task"
        )

        var result = await check.evaluate(proposal)
        XCTAssertTrue(result.passed)

        // Announce and drain
        let manifest = ReleaseManifest(
            version: SemanticVersion(major: 1, minor: 1, patch: 0),
            buildId: "new"
        )
        _ = await orchestrator.announceRelease(manifest)
        _ = await orchestrator.startDrainMode()

        // Soft operations still allowed in drain
        result = await check.evaluate(proposal)
        XCTAssertTrue(result.passed)

        // Check with hard profile
        let hardCheck = UpdatePhaseCheck(
            orchestrator: orchestrator,
            clientIdProvider: { client.id },
            profileProvider: { _ in .hard }
        )

        result = await hardCheck.evaluate(proposal)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.message.contains("not allowed"))
    }
}
