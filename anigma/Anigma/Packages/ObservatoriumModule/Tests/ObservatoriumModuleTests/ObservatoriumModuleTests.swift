import XCTest
@testable import ObservatoriumModule

final class ObservatoriumModuleTests: XCTestCase {
    
    // MARK: - Telemetry Tests
    
    func testTelemetryEventCreation() {
        let event = TelemetryEvent(
            type: .systemStartup,
            source: "test",
            data: ["test_key": "test_value"],
            severity: .info
        )
        
        XCTAssertEqual(event.type, .systemStartup)
        XCTAssertEqual(event.source, "test")
        XCTAssertEqual(event.severity, .info)
        XCTAssertNotNil(event.id)
        XCTAssertNotNil(event.timestamp)
    }
    
    func testPerformanceMetricsCreation() {
        let networkIO = NetworkIO(bytesIn: 1000, bytesOut: 2000, connections: 5)
        let metrics = PerformanceMetrics(
            cpuUsage: 0.5,
            memoryUsage: 1_000_000_000,
            diskUsage: 100_000_000_000,
            networkIO: networkIO
        )
        
        XCTAssertEqual(metrics.cpuUsage, 0.5)
        XCTAssertEqual(metrics.memoryUsage, 1_000_000_000)
        XCTAssertEqual(metrics.diskUsage, 100_000_000_000)
        XCTAssertEqual(metrics.networkIO.bytesIn, 1000)
        XCTAssertEqual(metrics.networkIO.bytesOut, 2000)
        XCTAssertEqual(metrics.networkIO.connections, 5)
    }
    
    // MARK: - Alert Tests
    
    func testAlertRuleCreation() {
        let condition = AlertCondition(metric: "cpu_usage", op: .greaterThan, threshold: 0.8)
        let rule = AlertRule(
            name: "High CPU Usage",
            description: "Alert when CPU usage exceeds 80%",
            type: .performance,
            conditions: [condition],
            severity: .high
        )
        
        XCTAssertEqual(rule.name, "High CPU Usage")
        XCTAssertEqual(rule.type, .performance)
        XCTAssertEqual(rule.severity, .high)
        XCTAssertEqual(rule.conditions.count, 1)
        XCTAssertTrue(rule.enabled)
    }
    
    func testAlertCreation() {
        let alert = Alert(
            ruleId: UUID(),
            ruleName: "Test Rule",
            type: .system,
            severity: .critical,
            title: "Critical Alert",
            message: "This is a critical alert"
        )
        
        XCTAssertEqual(alert.ruleName, "Test Rule")
        XCTAssertEqual(alert.type, .system)
        XCTAssertEqual(alert.severity, .critical)
        XCTAssertEqual(alert.status, .active)
        XCTAssertEqual(alert.title, "Critical Alert")
    }
    
    func testAlertStatusUpdate() {
        var alert = Alert(
            ruleId: UUID(),
            ruleName: "Test Rule",
            type: .system,
            severity: .medium,
            title: "Medium Alert",
            message: "This is a medium alert"
        )
        
        alert.acknowledge()
        XCTAssertEqual(alert.status, .acknowledged)
        XCTAssertNotNil(alert.acknowledgedAt)
        
        alert.resolve()
        XCTAssertEqual(alert.status, .resolved)
        XCTAssertNotNil(alert.resolvedAt)
    }
    
    // MARK: - Feedback Tests
    
    func testFeedbackEntryCreation() {
        let feedback = FeedbackEntry(
            type: .userReport,
            category: .ui,
            priority: .medium,
            title: "UI Issue",
            description: "The button is not working properly",
            source: "mobile_app"
        )
        
        XCTAssertEqual(feedback.type, .userReport)
        XCTAssertEqual(feedback.category, .ui)
        XCTAssertEqual(feedback.priority, .medium)
        XCTAssertEqual(feedback.status, .open)
        XCTAssertEqual(feedback.title, "UI Issue")
    }
    
    func testFeedbackStatusUpdate() {
        var feedback = FeedbackEntry(
            type: .bug,
            category: .functionality,
            priority: .high,
            title: "Bug Report",
            description: "App crashes on startup",
            source: "desktop_app"
        )
        
        feedback.updateStatus(.inProgress)
        XCTAssertEqual(feedback.status, .inProgress)
        
        feedback.updateStatus(.resolved)
        XCTAssertEqual(feedback.status, .resolved)
        XCTAssertNotNil(feedback.resolvedAt)
    }
    
    // MARK: - TimeRange Tests
    
    func testTimeRangeDateIntervals() {
        let now = Date()
        
        let lastHour = TimeRange.lastHour.dateInterval
        XCTAssertEqual(lastHour.end, now)
        XCTAssertEqual(lastHour.duration, 3600) // 1 hour
        
        let lastDay = TimeRange.lastDay.dateInterval
        XCTAssertEqual(lastDay.end, now)
        XCTAssertEqual(lastDay.duration, 86400) // 24 hours
    }
    
    // MARK: - Severity Level Tests
    
    func testTelemetrySeverityLevels() {
        XCTAssertEqual(TelemetrySeverity.debug.level, 1)
        XCTAssertEqual(TelemetrySeverity.info.level, 2)
        XCTAssertEqual(TelemetrySeverity.warning.level, 3)
        XCTAssertEqual(TelemetrySeverity.error.level, 4)
        XCTAssertEqual(TelemetrySeverity.critical.level, 5)
    }
    
    func testAlertSeverityPriority() {
        XCTAssertEqual(AlertSeverity.low.priority, 1)
        XCTAssertEqual(AlertSeverity.medium.priority, 2)
        XCTAssertEqual(AlertSeverity.high.priority, 3)
        XCTAssertEqual(AlertSeverity.critical.priority, 4)
    }
    
    func testFeedbackPriorityLevels() {
        XCTAssertEqual(FeedbackPriority.low.level, 1)
        XCTAssertEqual(FeedbackPriority.medium.level, 2)
        XCTAssertEqual(FeedbackPriority.high.level, 3)
        XCTAssertEqual(FeedbackPriority.urgent.level, 4)
    }
    
    // MARK: - Sentiment Analysis Tests
    
    func testSentimentScoreClassification() {
        let positiveSentiment = SentimentScore(positive: 0.8, negative: 0.1, neutral: 0.1, compound: 0.7)
        XCTAssertEqual(positiveSentiment.classification, .positive)
        
        let negativeSentiment = SentimentScore(positive: 0.1, negative: 0.8, neutral: 0.1, compound: -0.7)
        XCTAssertEqual(negativeSentiment.classification, .negative)
        
        let neutralSentiment = SentimentScore(positive: 0.3, negative: 0.3, neutral: 0.4, compound: 0.0)
        XCTAssertEqual(neutralSentiment.classification, .neutral)
    }
    
    // MARK: - System Health Tests
    
    func testSystemHealthStatusColor() {
        XCTAssertEqual(SystemHealthStatus.excellent.color, "green")
        XCTAssertEqual(SystemHealthStatus.good.color, "blue")
        XCTAssertEqual(SystemHealthStatus.fair.color, "yellow")
        XCTAssertEqual(SystemHealthStatus.poor.color, "orange")
        XCTAssertEqual(SystemHealthStatus.critical.color, "red")
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultConfigurations() {
        let telemetryConfig = TelemetryConfiguration.default
        XCTAssertEqual(telemetryConfig.maxStoredEvents, 10000)
        XCTAssertEqual(telemetryConfig.collectionInterval, 30.0)
        XCTAssertTrue(telemetryConfig.forwardToDaemonCore)
        
        let alertConfig = AlertConfiguration.default
        XCTAssertEqual(alertConfig.maxActiveAlerts, 1000)
        XCTAssertEqual(alertConfig.evaluationInterval, 60.0)
        XCTAssertTrue(alertConfig.forwardToDaemonCore)
        
        let feedbackConfig = FeedbackConfiguration.default
        XCTAssertEqual(feedbackConfig.maxStoredFeedback, 50000)
        XCTAssertTrue(feedbackConfig.autoAnalysis)
        XCTAssertTrue(feedbackConfig.forwardToDaemonCore)
    }
    
    // MARK: - Model Serialization Tests
    
    func testTelemetryEventSerialization() throws {
        let event = TelemetryEvent(
            type: .performanceMetric,
            source: "test",
            data: ["cpu_usage": 0.75, "memory_usage": "4GB"],
            severity: .warning
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        
        let decoder = JSONDecoder()
        let decodedEvent = try decoder.decode(TelemetryEvent.self, from: data)
        
        XCTAssertEqual(event.id, decodedEvent.id)
        XCTAssertEqual(event.type, decodedEvent.type)
        XCTAssertEqual(event.source, decodedEvent.source)
        XCTAssertEqual(event.severity, decodedEvent.severity)
    }
    
    func testAlertRuleSerialization() throws {
        let condition = AlertCondition(metric: "disk_usage", op: .greaterThanOrEqual, threshold: 0.9)
        let rule = AlertRule(
            name: "Disk Space Alert",
            description: "Alert when disk usage exceeds 90%",
            type: .system,
            conditions: [condition],
            severity: .critical,
            notificationChannels: ["email", "slack"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(rule)
        
        let decoder = JSONDecoder()
        let decodedRule = try decoder.decode(AlertRule.self, from: data)
        
        XCTAssertEqual(rule.id, decodedRule.id)
        XCTAssertEqual(rule.name, decodedRule.name)
        XCTAssertEqual(rule.type, decodedRule.type)
        XCTAssertEqual(rule.severity, decodedRule.severity)
        XCTAssertEqual(rule.conditions.count, decodedRule.conditions.count)
        XCTAssertEqual(rule.notificationChannels, decodedRule.notificationChannels)
    }
}

// MARK: - Performance Tests

extension ObservatoriumModuleTests {
    
    func testTelemetryEventPerformance() {
        measure {
            for _ in 0..<1000 {
                let event = TelemetryEvent(
                    type: .performanceMetric,
                    source: "performance_test",
                    data: ["test_metric": Double.random(in: 0...1)],
                    severity: .info
                )
                _ = event.id // Ensure event is created
            }
        }
    }
    
    func testAlertCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                let alert = Alert(
                    ruleId: UUID(),
                    ruleName: "Performance Test Alert",
                    type: .performance,
                    severity: .medium,
                    title: "Test Alert",
                    message: "This is a test alert"
                )
                _ = alert.id // Ensure alert is created
            }
        }
    }
}
