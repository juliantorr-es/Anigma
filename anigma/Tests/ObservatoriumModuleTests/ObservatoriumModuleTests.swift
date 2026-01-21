//
//  ObservatoriumModuleTests.swift
//  ObservatoriumModuleTests
//
//  Tests for the Observatorium observability domain.
//

import XCTest
@testable import AnigmaCore
@testable import ObservatoriumModule

final class ObservatoriumModuleTests: XCTestCase {

    var world: World!
    var governance: GovernanceController!

    override func setUp() async throws {
        world = World()
        governance = GovernanceController()
    }

    // MARK: - Metric Component Tests

    func testMetricDefinitionCreation() {
        let metric = MetricDefinitionComponent(
            name: "test.metric",
            displayName: "Test Metric",
            description: "A test metric",
            category: .performance,
            unit: .milliseconds,
            warningThreshold: 100,
            errorThreshold: 500,
            criticalThreshold: 1000
        )

        XCTAssertEqual(metric.name, "test.metric")
        XCTAssertEqual(metric.category, .performance)
        XCTAssertEqual(metric.unit, .milliseconds)
        XCTAssertTrue(metric.isEnabled)
    }

    func testMetricThresholdCheck() {
        let metric = MetricDefinitionComponent(
            name: "test.latency",
            displayName: "Test Latency",
            description: "Test latency metric",
            category: .performance,
            unit: .milliseconds,
            warningThreshold: 100,
            errorThreshold: 500,
            criticalThreshold: 1000,
            lowerIsBetter: true
        )

        // Below all thresholds
        XCTAssertNil(metric.checkThresholds(50))

        // Warning threshold
        XCTAssertEqual(metric.checkThresholds(150), .warning)

        // Error threshold
        XCTAssertEqual(metric.checkThresholds(600), .error)

        // Critical threshold
        XCTAssertEqual(metric.checkThresholds(1500), .critical)
    }

    func testBuiltInMetrics() {
        let latency = MetricDefinitionComponent.systemLatency
        XCTAssertEqual(latency.name, "system.request.latency")
        XCTAssertEqual(latency.category, .performance)

        let altMedia = MetricDefinitionComponent.altMediaTurnaroundTime
        XCTAssertEqual(altMedia.module, "Diaplasion")
        XCTAssertEqual(altMedia.unit, .hours)
    }

    // MARK: - Error Component Tests

    func testErrorRecordCreation() {
        let fingerprint = ErrorRecordComponent.createFingerprint(
            errorType: "TestError",
            message: "Something went wrong",
            module: "TestModule",
            component: "TestComponent"
        )

        let error = ErrorRecordComponent(
            fingerprint: fingerprint,
            errorType: "TestError",
            message: "Something went wrong",
            severity: .error,
            module: "TestModule",
            component: "TestComponent"
        )

        XCTAssertEqual(error.errorType, "TestError")
        XCTAssertEqual(error.state, .new)
        XCTAssertEqual(error.occurrenceCount, 1)
    }

    func testErrorFingerprintNormalization() {
        // UUIDs should be normalized
        let fp1 = ErrorRecordComponent.createFingerprint(
            errorType: "NotFound",
            message: "Entity 550e8400-e29b-41d4-a716-446655440000 not found",
            module: "Test",
            component: nil
        )

        let fp2 = ErrorRecordComponent.createFingerprint(
            errorType: "NotFound",
            message: "Entity 123e4567-e89b-12d3-a456-426614174000 not found",
            module: "Test",
            component: nil
        )

        // Same fingerprint for different UUIDs
        XCTAssertEqual(fp1, fp2)
    }

    func testErrorMergeOccurrence() {
        var error = ErrorRecordComponent(
            fingerprint: "test-fp",
            errorType: "TestError",
            message: "Test",
            module: "Test"
        )

        XCTAssertEqual(error.occurrenceCount, 1)

        error.mergeOccurrence(at: Date(), context: ["key": "value"])

        XCTAssertEqual(error.occurrenceCount, 2)
        XCTAssertEqual(error.context["key"], "value")
    }

    // MARK: - Telemetry Component Tests

    func testTelemetryEventCreation() {
        let event = TelemetryEventComponent(
            eventType: .performanceTrace,
            name: "test.trace",
            module: "TestModule",
            action: "doSomething",
            durationMs: 150.5,
            properties: [
                "count": .int(42),
                "success": .bool(true)
            ]
        )

        XCTAssertEqual(event.eventType, .performanceTrace)
        XCTAssertEqual(event.durationMs, 150.5)
        XCTAssertEqual(event.sensitivityLevel, .public)
        XCTAssertFalse(event.isRedacted)
    }

    func testTelemetryEventRedaction() {
        let event = TelemetryEventComponent(
            eventType: .userAction,
            name: "user.click",
            module: "UI",
            action: "click",
            principalId: "user123",
            properties: [
                "button": .string("submit"),
                "longValue": .string("this is a very long string that should be redacted")
            ],
            sensitivityLevel: .restricted
        )

        let redacted = event.redacted()

        XCTAssertEqual(redacted.principalId, "<redacted>")
        XCTAssertTrue(redacted.isRedacted)
    }

    func testPerformanceTraceBuilder() {
        let trace = TelemetryEventComponent.performanceTrace(
            module: "Diaplasion",
            action: "processDocument",
            durationMs: 2500,
            properties: ["pages": .int(10)],
            correlationId: "job-123"
        )

        XCTAssertEqual(trace.eventType, .performanceTrace)
        XCTAssertEqual(trace.module, "Diaplasion")
        XCTAssertEqual(trace.durationMs, 2500)
        XCTAssertEqual(trace.correlationId, "job-123")
    }

    // MARK: - Feedback Component Tests

    func testFeedbackCreation() {
        let feedback = FeedbackComponent(
            feedbackType: .bug,
            title: "Button doesn't work",
            description: "When I click submit, nothing happens",
            userSeverity: .high,
            module: "Pragma",
            reporterId: "user123"
        )

        XCTAssertEqual(feedback.feedbackType, .bug)
        XCTAssertEqual(feedback.state, .submitted)
        XCTAssertEqual(feedback.userSeverity, .high)
    }

    func testBugReportBuilder() {
        let bug = FeedbackComponent.bugReport(
            title: "OCR fails on scanned PDFs",
            description: "When processing scanned documents, OCR returns empty text",
            severity: .blocker,
            module: "Diaplasion",
            reporterId: "dsps-staff-1",
            currentPath: "/diaplasion/jobs/123"
        )

        XCTAssertEqual(bug.feedbackType, .bug)
        XCTAssertEqual(bug.userSeverity, .blocker)
        XCTAssertEqual(bug.module, "Diaplasion")
        XCTAssertFalse(bug.diagnosticInfo.isEmpty)
    }

    // MARK: - Alert Component Tests

    func testAlertCreation() {
        let alert = AlertComponent(
            alertType: .threshold,
            title: "High latency detected",
            message: "Request latency exceeded 1000ms",
            severity: .error,
            category: .performance,
            module: "System",
            source: .metric,
            thresholdValue: 1000,
            actualValue: 1500
        )

        XCTAssertEqual(alert.alertType, .threshold)
        XCTAssertEqual(alert.state, .triggered)
        XCTAssertEqual(alert.fireCount, 1)
    }

    func testAlertRefire() {
        var alert = AlertComponent(
            alertType: .threshold,
            title: "Test Alert",
            message: "Test",
            severity: .warning,
            category: .performance,
            module: "Test",
            source: .metric
        )

        XCTAssertEqual(alert.fireCount, 1)

        alert.refire()

        XCTAssertEqual(alert.fireCount, 2)
    }

    func testAlertAcknowledge() {
        var alert = AlertComponent(
            alertType: .threshold,
            title: "Test Alert",
            message: "Test",
            severity: .warning,
            category: .performance,
            module: "Test",
            source: .metric
        )

        alert.acknowledge(by: "operator-1")

        XCTAssertEqual(alert.state, .acknowledged)
        XCTAssertEqual(alert.acknowledgedBy, "operator-1")
        XCTAssertNotNil(alert.acknowledgedAt)
    }

    func testAlertResolve() {
        var alert = AlertComponent(
            alertType: .threshold,
            title: "Test Alert",
            message: "Test",
            severity: .warning,
            category: .performance,
            module: "Test",
            source: .metric
        )

        alert.resolve(notes: "Fixed by restarting the service", by: "operator-1")

        XCTAssertEqual(alert.state, .resolved)
        XCTAssertEqual(alert.resolutionNotes, "Fixed by restarting the service")
        XCTAssertNotNil(alert.resolvedAt)
    }

    func testThresholdAlertBuilder() {
        let metric = MetricDefinitionComponent.systemLatency
        let alert = AlertComponent.thresholdAlert(
            metric: metric,
            actualValue: 1500,
            severity: .critical
        )

        XCTAssertEqual(alert.alertType, .threshold)
        XCTAssertEqual(alert.severity, .critical)
        XCTAssertEqual(alert.metricId, metric.id)
        XCTAssertEqual(alert.actualValue, 1500)
    }

    // MARK: - Telemetry Service Tests

    func testTelemetryServiceRecordTrace() async {
        let service = TelemetryService(world: world, governance: governance)

        await service.recordTrace(
            module: "Test",
            action: "doWork",
            durationMs: 100
        )

        let stats = await service.getStatistics()
        XCTAssertEqual(stats.eventsReceived, 1)
    }

    func testTelemetryServiceRecordMetric() async {
        let service = TelemetryService(world: world, governance: governance)

        await service.recordMetric(
            name: "system.request.latency",
            value: 150
        )

        let stats = await service.getStatistics()
        XCTAssertEqual(stats.metricsReceived, 1)
    }

    func testTelemetryServiceMetricRegistration() async {
        let service = TelemetryService(world: world, governance: governance)

        let customMetric = MetricDefinitionComponent(
            name: "custom.metric",
            displayName: "Custom Metric",
            description: "A custom test metric",
            category: .domain,
            unit: .count
        )

        await service.registerMetric(customMetric)

        let retrieved = await service.getMetric(name: "custom.metric")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.displayName, "Custom Metric")
    }

    // MARK: - Error Service Tests

    func testErrorServiceRecordError() async {
        let service = ErrorService(world: world, governance: governance)

        let error = await service.recordError(
            type: "TestError",
            message: "Something went wrong",
            module: "TestModule"
        )

        XCTAssertEqual(error.errorType, "TestError")
        XCTAssertEqual(error.state, .new)

        let stats = await service.getStatistics()
        XCTAssertEqual(stats.totalErrorsReceived, 1)
    }

    func testErrorServiceClustering() async {
        let service = ErrorService(world: world, governance: governance)

        // Record same error multiple times
        for _ in 0..<5 {
            _ = await service.recordError(
                type: "DuplicateError",
                message: "Same error message",
                module: "TestModule"
            )
        }

        let clusters = await service.getClusters()
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters.first?.totalOccurrences, 5)
    }

    func testErrorServiceGetRecentErrors() async {
        let service = ErrorService(world: world, governance: governance)

        for i in 0..<10 {
            _ = await service.recordError(
                type: "Error\(i)",
                message: "Error message \(i)",
                module: "TestModule"
            )
        }

        let recent = await service.getRecentErrors(limit: 5)
        XCTAssertEqual(recent.count, 5)
    }

    // MARK: - Feedback Service Tests

    func testFeedbackServiceSubmit() async {
        let service = FeedbackService(world: world, governance: governance)

        let feedback = await service.submitBugReport(
            title: "Test Bug",
            description: "Something is broken",
            severity: .high,
            module: "TestModule",
            reporterId: "user123"
        )

        XCTAssertEqual(feedback.state, .acknowledged)

        let stats = await service.getStatistics()
        XCTAssertEqual(stats.totalSubmitted, 1)
    }

    func testFeedbackServiceTriage() async throws {
        let service = FeedbackService(world: world, governance: governance)

        let feedback = await service.submitBugReport(
            title: "Test Bug",
            description: "Something is broken",
            severity: .high,
            module: "TestModule",
            reporterId: "user123"
        )

        let triaged = try await service.triageFeedback(
            id: feedback.id,
            notes: "Confirmed issue, needs investigation",
            severity: .error,
            assigneeId: "dev123",
            principal: "triage-lead"
        )

        XCTAssertEqual(triaged.state, .triaged)
        XCTAssertEqual(triaged.triagedSeverity, .error)
        XCTAssertEqual(triaged.assigneeId, "dev123")
    }

    func testFeedbackServiceResolve() async throws {
        let service = FeedbackService(world: world, governance: governance)

        let feedback = await service.submitFeatureRequest(
            title: "Add dark mode",
            description: "Would love a dark theme",
            module: "UI",
            reporterId: "user456"
        )

        let resolved = try await service.resolveFeedback(
            id: feedback.id,
            resolution: "Added in v0.2.0",
            principal: "dev123"
        )

        XCTAssertEqual(resolved.state, .resolved)

        let stats = await service.getStatistics()
        XCTAssertEqual(stats.totalResolved, 1)
    }

    // MARK: - Alert Service Tests

    func testAlertServiceTrigger() async {
        let service = AlertService(world: world, governance: governance)

        let alert = await service.triggerAlert(AlertComponent(
            alertType: .threshold,
            title: "Test Alert",
            message: "Test message",
            severity: .warning,
            category: .performance,
            module: "Test",
            source: .metric
        ))

        XCTAssertEqual(alert.state, .triggered)

        let stats = await service.getStatistics()
        XCTAssertEqual(stats.totalTriggered, 1)
    }

    func testAlertServiceDedup() async {
        let service = AlertService(world: world, governance: governance)

        let metricId = MetricId()

        // Trigger same alert twice
        let alert1 = await service.triggerAlert(AlertComponent(
            alertType: .threshold,
            title: "Test Alert",
            message: "Test message",
            severity: .warning,
            category: .performance,
            module: "Test",
            source: .metric,
            metricId: metricId
        ))

        let alert2 = await service.triggerAlert(AlertComponent(
            alertType: .threshold,
            title: "Test Alert",
            message: "Test message",
            severity: .warning,
            category: .performance,
            module: "Test",
            source: .metric,
            metricId: metricId
        ))

        // Should be same alert, re-fired
        XCTAssertEqual(alert1.id, alert2.id)
        XCTAssertEqual(alert2.fireCount, 2)
    }

    func testAlertServiceAcknowledge() async throws {
        let service = AlertService(world: world, governance: governance)

        let alert = await service.triggerAlert(AlertComponent(
            alertType: .error,
            title: "Error Alert",
            message: "Something went wrong",
            severity: .error,
            category: .error,
            module: "Test",
            source: .errorAggregation
        ))

        let acked = try await service.acknowledgeAlert(id: alert.id, by: "operator-1")

        XCTAssertEqual(acked.state, .acknowledged)
        XCTAssertEqual(acked.acknowledgedBy, "operator-1")
    }

    func testAlertServiceResolve() async throws {
        let service = AlertService(world: world, governance: governance)

        let alert = await service.triggerAlert(AlertComponent(
            alertType: .error,
            title: "Error Alert",
            message: "Something went wrong",
            severity: .error,
            category: .error,
            module: "Test",
            source: .errorAggregation
        ))

        let resolved = try await service.resolveAlert(
            id: alert.id,
            notes: "Fixed by deploying hotfix",
            by: "operator-1"
        )

        XCTAssertEqual(resolved.state, .resolved)
        XCTAssertEqual(resolved.resolutionNotes, "Fixed by deploying hotfix")
    }

    // MARK: - Unified Observatorium Service Tests

    func testObservatoriumServiceTrace() async {
        let service = ObservatoriumService(world: world, governance: governance)

        await service.trace(
            module: "Diaplasion",
            action: "processDocument",
            durationMs: 1500
        )

        let stats = await service.telemetry.getStatistics()
        XCTAssertEqual(stats.eventsReceived, 1)
    }

    func testObservatoriumServiceMeasure() async {
        let service = ObservatoriumService(world: world, governance: governance)

        let result = await service.measure(module: "Test", action: "compute") {
            // Simulate some work
            try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
            return 42
        }

        XCTAssertEqual(result, 42)

        let stats = await service.telemetry.getStatistics()
        XCTAssertEqual(stats.eventsReceived, 1)
    }

    func testObservatoriumServiceHealthSummary() async {
        let service = ObservatoriumService(world: world, governance: governance)

        let health = await service.getHealthSummary()

        XCTAssertEqual(health.status, .healthy)
        XCTAssertEqual(health.activeAlerts, 0)
        XCTAssertEqual(health.recentErrors, 0)
    }

    func testObservatoriumServiceDashboard() async {
        let service = ObservatoriumService(world: world, governance: governance)

        // Add some activity
        await service.error(type: "TestError", message: "Test", module: "Test")
        await service.trace(module: "Test", action: "work", durationMs: 100)

        let dashboard = await service.getOperationsDashboard()

        XCTAssertNotNil(dashboard.generatedAt)
        XCTAssertEqual(dashboard.errorStats.totalErrorsReceived, 1)
        XCTAssertEqual(dashboard.telemetryStats.eventsReceived, 1)
    }

    func testObservatoriumServiceWeeklyReport() async {
        let service = ObservatoriumService(world: world, governance: governance)

        // Add some feedback
        _ = await service.feedback.submitBugReport(
            title: "Bug 1",
            description: "Test bug",
            severity: .medium,
            module: "Test",
            reporterId: "user1"
        )

        let now = Date()
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) else {
            fatalError("Failed to unwrap weekAgo")
        }

        let report = await service.generateWeeklyReport(from: weekAgo, to: now)

        XCTAssertEqual(report.feedbackReceived, 1)
    }
}
