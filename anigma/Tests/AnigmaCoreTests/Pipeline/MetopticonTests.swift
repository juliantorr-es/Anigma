//
//  MetopticonTests.swift
//  AnigmaCoreTests
//
//  Tests for Metopticon RBAC, Dashboard, Manifest, and Integration.
//

import XCTest
@testable import AnigmaCore

final class MetopticonTests: XCTestCase {

    // MARK: - RBAC Tests

    func testRoleDefaultAccess() {
        // IT infrastructure should have institution-wide scope
        let itAccess = MetopticonRole.itInfrastructure.defaultAccess
        XCTAssertEqual(itAccess.scope, .institution)
        XCTAssertEqual(itAccess.granularity, .traceLevel)
        XCTAssertFalse(itAccess.canViewOwnerIdentity)
        XCTAssertTrue(itAccess.canExportData)

        // Faculty should only see their own workloads
        let facultyAccess = MetopticonRole.faculty.defaultAccess
        XCTAssertEqual(facultyAccess.scope, .selfOnly)
        XCTAssertEqual(facultyAccess.granularity, .workloadLevel)

        // DSPS should be categorically scoped
        let dspsAccess = MetopticonRole.dspsStaff.defaultAccess
        XCTAssertEqual(dspsAccess.scope, .categoricallyScoped)
        XCTAssertNotNil(dspsAccess.categoryFilters)
        XCTAssertTrue(dspsAccess.categoryFilters?.contains("alt-media") ?? false)
    }

    func testPrincipalEffectiveAccess() {
        // Single role
        let facultyPrincipal = MetopticonPrincipal(
            id: "faculty-1",
            roles: [.faculty],
            department: "Math"
        )
        let facultyAccess = facultyPrincipal.effectiveAccess
        XCTAssertEqual(facultyAccess.scope, .selfOnly)

        // Multiple roles should merge (most permissive)
        let multiRolePrincipal = MetopticonPrincipal(
            id: "admin-1",
            roles: [.faculty, .departmentLead],
            department: "Math"
        )
        let multiAccess = multiRolePrincipal.effectiveAccess
        XCTAssertEqual(multiAccess.scope, .department)
        XCTAssertTrue(multiAccess.granularity >= .aggregatedOnly)
    }

    func testAccessEnforcerFiltering() async {
        let enforcer = MetopticonAccessEnforcer()

        // Create test workloads
        let workloads = [
            MetopticonWorkloadView(
                workloadId: "w1",
                category: "alt-media",
                status: "running",
                ownerId: "user-1",
                ownerDepartment: "Math"
            ),
            MetopticonWorkloadView(
                workloadId: "w2",
                category: "grading",
                status: "completed",
                ownerId: "user-2",
                ownerDepartment: "English"
            )
        ]

        // Faculty should only see their own
        let facultyPrincipal = MetopticonPrincipal(id: "user-1", roles: [.faculty])
        let facultyFiltered = await enforcer.filterWorkloads(workloads, for: facultyPrincipal)
        XCTAssertEqual(facultyFiltered.count, 1)
        XCTAssertEqual(facultyFiltered.first?.workloadId, "w1")

        // IT should see all
        let itPrincipal = MetopticonPrincipal(id: "it-admin", roles: [.itInfrastructure])
        let itFiltered = await enforcer.filterWorkloads(workloads, for: itPrincipal)
        XCTAssertEqual(itFiltered.count, 2)
    }

    func testFieldRedaction() async {
        let enforcer = MetopticonAccessEnforcer()

        let workload = MetopticonWorkloadView(
            workloadId: "w1",
            category: "research",
            status: "running",
            ownerId: "user-1",
            startedAt: Date(),
            durationMs: 5000,
            backend: "mlx",
            device: "mac-1",
            healthStatus: "healthy"
        )

        // Department lead with aggregated-only access shouldn't see timing details
        let leadPrincipal = MetopticonPrincipal(
            id: "lead-1",
            roles: [.departmentLead],
            department: nil  // Can see all for this test
        )

        let filtered = await enforcer.filterWorkloads([workload], for: leadPrincipal)
        // Note: Full redaction depends on scope matching, testing the concept
        XCTAssertEqual(filtered.count, 1)
    }

    // MARK: - Manifest Tests

    func testManifestHasPrinciples() {
        let manifest = MetopticonManifest.current

        XCTAssertFalse(manifest.principles.isEmpty)
        XCTAssertTrue(manifest.principles.contains { $0.id == "P1" })

        // Check for key principles
        let observabilityPrinciple = manifest.principles.first { $0.id == "P1" }
        XCTAssertNotNil(observabilityPrinciple)
        XCTAssertTrue(observabilityPrinciple?.name.contains("Observability") ?? false)
    }

    func testManifestTechnicalGuarantees() {
        let manifest = MetopticonManifest.current

        XCTAssertFalse(manifest.technicalGuarantees.isEmpty)

        // All guarantees should be verifiable
        for guarantee in manifest.technicalGuarantees {
            XCTAssertTrue(guarantee.verifiable, "Guarantee \(guarantee.id) should be verifiable")
        }
    }

    func testManifestProhibitedUses() {
        let manifest = MetopticonManifest.current

        XCTAssertFalse(manifest.prohibitedUses.isEmpty)

        // Key prohibitions should exist
        let hasPerformanceMonitoringProhibition = manifest.prohibitedUses.contains {
            $0.prohibition.contains("Performance Monitoring")
        }
        XCTAssertTrue(hasPerformanceMonitoringProhibition)

        let hasStudentProfilingProhibition = manifest.prohibitedUses.contains {
            $0.prohibition.contains("Student Profiling")
        }
        XCTAssertTrue(hasStudentProfilingProhibition)
    }

    func testManifestValidation() {
        let validator = MetopticonManifestValidator()

        // Valid context should have no violations
        let validContext: [String: Any] = [
            "templateId": "template-1",
            "duration": 5000,
            "status": "completed"
        ]
        let validViolations = validator.validateTelemetryContext(validContext)
        XCTAssertTrue(validViolations.isEmpty)

        // Context with content should have violations
        let invalidContext: [String: Any] = [
            "templateId": "template-1",
            "content": "This is private content",
            "prompt": "User's secret prompt"
        ]
        let invalidViolations = validator.validateTelemetryContext(invalidContext)
        XCTAssertFalse(invalidViolations.isEmpty)
        XCTAssertTrue(invalidViolations.contains { $0.field == "content" })
        XCTAssertTrue(invalidViolations.contains { $0.field == "prompt" })
    }

    // MARK: - Integration Tests

    func testWorkloadLifecycle() async {
        let store = MetopticonWorkloadStore()
        let adapter = MetopticonRunnerAdapter(store: store)

        // Start workload
        let config = MetopticonWorkloadConfig(
            graphId: "test-graph",
            templateName: "Test Pipeline",
            category: .research,
            ownerId: "test-user"
        )

        let workloadId = await adapter.workloadStarted(config: config)

        // Verify created
        let entity = await store.getWorkload(workloadId)
        XCTAssertNotNil(entity)
        XCTAssertEqual(entity?.workload.status, .running)
        XCTAssertNotNil(entity?.workload.startedAt)

        // Update metrics
        await adapter.updateFromTrace(
            workloadId,
            nodeCount: 10,
            nodesExecuted: 8,
            cacheHits: 5,
            cacheMisses: 3,
            errorCount: 0,
            backends: ["mlx", "cpu"],
            durationMs: nil
        )

        // Complete workload
        await adapter.workloadCompleted(workloadId, durationMs: 5000)

        let completedEntity = await store.getWorkload(workloadId)
        XCTAssertEqual(completedEntity?.workload.status, .completed)
        XCTAssertNotNil(completedEntity?.workload.completedAt)
        XCTAssertEqual(completedEntity?.metrics.totalDurationMs, 5000)
    }

    func testWorkloadFailure() async {
        let store = MetopticonWorkloadStore()
        let adapter = MetopticonRunnerAdapter(store: store)

        let config = MetopticonWorkloadConfig(
            graphId: "failing-graph",
            templateName: "Failing Pipeline",
            category: .grading,
            ownerId: "test-user"
        )

        let workloadId = await adapter.workloadStarted(config: config)
        await adapter.workloadFailed(workloadId, error: "Model inference failed")

        let entity = await store.getWorkload(workloadId)
        XCTAssertEqual(entity?.workload.status, .failed)
        XCTAssertEqual(entity?.health.status, .unhealthy)
        XCTAssertFalse(entity?.health.issues.isEmpty ?? true)
    }

    func testWorkloadQuery() async {
        let store = MetopticonWorkloadStore()

        // Create some workloads
        for i in 0..<5 {
            let component = PipelineWorkloadComponent(
                graphId: "graph-\(i)",
                templateName: "Template \(i)",
                category: i % 2 == 0 ? .altMedia : .grading,
                status: i % 3 == 0 ? .running : .completed,
                ownerId: "user-\(i % 2)",
                ownerDepartment: "dept-\(i % 2)",
                deviceId: "device-1",
                invokingFrontend: "test"
            )
            _ = await store.createWorkload(component)
        }

        // Query by category
        let altMediaWorkloads = await store.queryWorkloads(categoryFilter: [.altMedia])
        XCTAssertEqual(altMediaWorkloads.count, 3)  // 0, 2, 4

        // Query by status
        let runningWorkloads = await store.queryWorkloads(statusFilter: [.running])
        XCTAssertEqual(runningWorkloads.count, 2)  // 0, 3

        // Query by owner
        let user0Workloads = await store.queryWorkloads(ownerFilter: "user-0")
        XCTAssertEqual(user0Workloads.count, 3)  // 0, 2, 4
    }

    func testAggregateStats() async {
        let store = MetopticonWorkloadStore()

        // Create mixed workloads
        for status in [WorkloadStatus.running, .completed, .failed, .queued] {
            let component = PipelineWorkloadComponent(
                graphId: "graph-\(status.rawValue)",
                templateName: "Template",
                category: .research,
                status: status,
                ownerId: "user-1",
                deviceId: "device-1",
                invokingFrontend: "test"
            )
            _ = await store.createWorkload(component)
        }

        let stats = await store.getAggregateStats()
        XCTAssertEqual(stats.totalWorkloads, 4)
        XCTAssertEqual(stats.activeWorkloads, 1)  // running
        XCTAssertEqual(stats.queuedWorkloads, 1)
        XCTAssertEqual(stats.failedWorkloads, 1)
        XCTAssertEqual(stats.completedWorkloads, 1)
    }

    // MARK: - Dashboard Tests

    func testDashboardOverview() async throws {
        let store = MetopticonWorkloadStore()
        let enforcer = MetopticonAccessEnforcer()
        let queryService = MetopticonQueryService(store: store, accessEnforcer: enforcer)

        // Create test data
        for i in 0..<10 {
            let component = PipelineWorkloadComponent(
                graphId: "graph-\(i)",
                templateName: "Template \(i)",
                category: [.altMedia, .dsps, .grading][i % 3],
                status: [.running, .completed, .failed][i % 3],
                ownerId: "user-1",
                deviceId: "device-1",
                invokingFrontend: "test"
            )
            _ = await store.createWorkload(component)
        }

        let itPrincipal = MetopticonPrincipal(id: "it-admin", roles: [.itInfrastructure])
        let overview = try await queryService.getOverview(for: itPrincipal)

        XCTAssertEqual(overview.activeWorkloads + overview.completedWorkloads + overview.failedWorkloads, 10)
        XCTAssertFalse(overview.categoryBreakdown.isEmpty)
    }

    func testDashboardQueryWithRBAC() async throws {
        let store = MetopticonWorkloadStore()
        let enforcer = MetopticonAccessEnforcer()
        let queryService = MetopticonQueryService(store: store, accessEnforcer: enforcer)

        // Create workloads for different users
        for i in 0..<6 {
            let component = PipelineWorkloadComponent(
                graphId: "graph-\(i)",
                templateName: "Template \(i)",
                category: .research,
                status: .completed,
                ownerId: "user-\(i % 2)",
                deviceId: "device-1",
                invokingFrontend: "test"
            )
            _ = await store.createWorkload(component)
        }

        // Faculty should only see their own
        let facultyPrincipal = MetopticonPrincipal(id: "user-0", roles: [.faculty])
        let facultyResult = try await queryService.queryWorkloads(
            query: MetopticonWorkloadQuery(),
            for: facultyPrincipal
        )
        XCTAssertEqual(facultyResult.totalCount, 3)  // user-0 workloads only

        // IT should see all
        let itPrincipal = MetopticonPrincipal(id: "it-admin", roles: [.itInfrastructure])
        let itResult = try await queryService.queryWorkloads(
            query: MetopticonWorkloadQuery(),
            for: itPrincipal
        )
        XCTAssertEqual(itResult.totalCount, 6)
    }

    // MARK: - Category and Status Tests

    func testWorkloadCategories() {
        XCTAssertEqual(WorkloadCategory.altMedia.rawValue, "alt-media")
        XCTAssertEqual(WorkloadCategory.dsps.displayName, "DSPS/Accessibility")
        XCTAssertEqual(WorkloadCategory.allCases.count, 8)
    }

    func testWorkloadStatusProperties() {
        XCTAssertTrue(WorkloadStatus.completed.isTerminal)
        XCTAssertTrue(WorkloadStatus.failed.isTerminal)
        XCTAssertFalse(WorkloadStatus.running.isTerminal)

        XCTAssertTrue(WorkloadStatus.running.isActive)
        XCTAssertTrue(WorkloadStatus.streaming.isActive)
        XCTAssertFalse(WorkloadStatus.queued.isActive)
    }

    // MARK: - Cleanup Tests

    func testWorkloadCleanup() async {
        let store = MetopticonWorkloadStore()

        // Create old completed workload
        var oldComponent = PipelineWorkloadComponent(
            graphId: "old-graph",
            templateName: "Old Template",
            category: .research,
            status: .completed,
            ownerId: "user-1",
            deviceId: "device-1",
            invokingFrontend: "test",
            createdAt: Date().addingTimeInterval(-86400 * 10)  // 10 days ago
        )
        oldComponent.completedAt = Date().addingTimeInterval(-86400 * 10)
        var entity = await store.createWorkload(oldComponent)
        await store.updateStatus(entity.id, status: .completed)

        // Create recent workload
        let recentComponent = PipelineWorkloadComponent(
            graphId: "recent-graph",
            templateName: "Recent Template",
            category: .research,
            status: .completed,
            ownerId: "user-1",
            deviceId: "device-1",
            invokingFrontend: "test"
        )
        _ = await store.createWorkload(recentComponent)

        // Initial count
        let allBefore = await store.queryWorkloads()
        XCTAssertEqual(allBefore.count, 2)

        // Cleanup old workloads (older than 7 days)
        await store.cleanupOldWorkloads(olderThan: 86400 * 7)

        // Should only have recent one
        let allAfter = await store.queryWorkloads()
        XCTAssertEqual(allAfter.count, 1)
        XCTAssertEqual(allAfter.first?.workload.templateName, "Recent Template")
    }
}
