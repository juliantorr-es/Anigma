import Foundation

// MARK: - Observatorium Coordinator
@MainActor
public final class ObservatoriumCoordinator: @unchecked Sendable {
    // MARK: - Services
    public let telemetryService: TelemetryService
    public let alertService: AlertService
    public let feedbackService: FeedbackService
    
    // MARK: - Configuration
    private let configuration: ObservatoriumConfiguration
    
    // MARK: - State
    private var isRunning = false
    private var healthCheckTask: Task<Void, Never>?
    
    // MARK: - Initialization
    public init(configuration: ObservatoriumConfiguration = .default) {
        self.configuration = configuration
        
        // Initialize services with their respective configurations
        self.telemetryService = TelemetryService(
            configuration: configuration.telemetryConfig
        )
        self.alertService = AlertService(
            configuration: configuration.alertConfig
        )
        self.feedbackService = FeedbackService(
            configuration: configuration.feedbackConfig
        )
        
        // Setup inter-service communication
        setupInterServiceCommunication()
    }
    
    // MARK: - Lifecycle Management
    public func start() async {
        guard !isRunning else { return }
        
        isRunning = true
        print("⚠️  STUB NOTICE: ObservatoriumModule currently uses in-memory/simulated service providers.")
        
        // Start service-specific tasks
        await telemetryService.startCollection()
        alertService.startEvaluation()
        
        // Start health monitoring
        startHealthMonitoring()
        
        // Record system startup event
        await telemetryService.recordEvent(
            TelemetryEvent(
                type: .systemStartup,
                source: "observatorium_coordinator",
                data: [
                    "version": configuration.version,
                    "environment": configuration.environment
                ],
                severity: .info
            )
        )
        
        // Integrate with AnigmaDaemonCore
        await integrateWithDaemonCore()
        
        print("🔭 Observatorium Module Started")
    }
    
    public func stop() async {
        guard isRunning else { return }
        
        // Record system shutdown event
        await telemetryService.recordEvent(
            TelemetryEvent(
                type: .systemShutdown,
                source: "observatorium_coordinator",
                data: [
                    "uptime": Date().timeIntervalSince(configuration.startTime)
                ],
                severity: .info
            )
        )
        
        // Stop services
        await telemetryService.stopCollection()
        alertService.stopEvaluation()
        
        // Stop health monitoring
        healthCheckTask?.cancel()
        healthCheckTask = nil
        
        isRunning = false
        
        print("🔭 Observatorium Module Stopped")
    }
    
    // MARK: - Health Monitoring
    public func getSystemHealth() async -> SystemHealth {
        let now = Date()
        let uptime = now.timeIntervalSince(configuration.startTime)
        
        // Get recent metrics
        let recentMetrics = await telemetryService.getAggregatedMetrics(for: .lastHour)
        let activeAlerts = await alertService.getActiveAlerts()
        let recentFeedback = await feedbackService.getFeedbackByStatus(.open)
        
        return SystemHealth(
            isRunning: isRunning,
            uptime: uptime,
            lastHealthCheck: now,
            recentMetrics: recentMetrics,
            activeAlertsCount: activeAlerts.count,
            openFeedbackCount: recentFeedback.count,
            overallStatus: calculateOverallStatus(
                metrics: recentMetrics,
                alerts: activeAlerts,
                feedback: recentFeedback
            )
        )
    }
    
    // MARK: - Data Management
    public func exportData(for timeRange: TimeRange) async throws -> ObservatoriumExport {
        let metrics = await telemetryService.getMetrics(since: timeRange.dateInterval.start)
        let events = await telemetryService.getEvents(since: timeRange.dateInterval.start)
        let alerts = await alertService.getActiveAlerts()
        let feedback = await feedbackService.getAllFeedback()
            .filter { timeRange.dateInterval.contains($0.createdAt) }
        
        return ObservatoriumExport(
            timeRange: timeRange,
            metrics: metrics,
            events: events,
            alerts: alerts,
            feedback: feedback,
            exportedAt: Date()
        )
    }
    
    public func purgeOldData(olderThan date: Date) async {
        // This would implement data cleanup logic
        // For now, it's a placeholder
        print("⚠️  STUB INVOKED: purgeOldData() is placeholder-only; no data is actually deleted.")
        print("🔭 Requested purge date: \(date)")
    }
    
    // MARK: - Dashboard Data
    public func getDashboardData() async -> DashboardData {
        let metrics = await telemetryService.getAggregatedMetrics(for: .lastDay)
        let alerts = await alertService.getActiveAlerts()
        let feedback = await feedbackService.getTrendAnalysis(for: .lastWeek)
        let health = await getSystemHealth()
        
        return DashboardData(
            systemHealth: health,
            recentMetrics: metrics,
            activeAlerts: alerts,
            feedbackTrends: feedback,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Methods
    private func setupInterServiceCommunication() {
        // Setup notifications between services
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCriticalAlert),
            name: .criticalAlertTriggered,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUrgentFeedback),
            name: .urgentFeedbackSubmitted,
            object: nil
        )
    }
    
    private func startHealthMonitoring() {
        healthCheckTask = Task { @MainActor in
            while !Task.isCancelled && isRunning {
                await performHealthCheck()
                try? await Task.sleep(nanoseconds: UInt64(configuration.healthCheckInterval * 1_000_000_000))
            }
        }
    }
    
    private func performHealthCheck() async {
        let health = await getSystemHealth()
        
        // Create alert if system health is critical
        if health.overallStatus == .critical {
            let alert = Alert(
                ruleId: UUID(), // System health rule ID
                ruleName: "System Health Monitor",
                type: .system,
                severity: .critical,
                title: "Critical System Health",
                message: "System health is critical. Immediate attention required.",
                metadata: [
                    "uptime": health.uptime.description,
                    "active_alerts": health.activeAlertsCount.description
                ]
            )
            
            NotificationCenter.default.post(
                name: .criticalAlertTriggered,
                object: alert
            )
        }
    }
    
    private func integrateWithDaemonCore() async {
        // Integration with AnigmaDaemonCore
        // This would establish communication channels with the daemon
        print("🔭 Integrating with AnigmaDaemonCore")
        
        // Record integration event
        await telemetryService.recordEvent(
            TelemetryEvent(
                type: .systemStartup,
                source: "daemon_core_integration",
                data: ["status": "connected"],
                severity: .info
            )
        )
    }
    
    private func calculateOverallStatus(
        metrics: AggregatedMetrics?,
        alerts: [Alert],
        feedback: [FeedbackEntry]
    ) -> SystemHealthStatus {
        var statusScore = 100
        
        // Deduct points for critical alerts
        let criticalAlerts = alerts.filter { $0.severity == .critical }
        statusScore -= criticalAlerts.count * 30
        
        // Deduct points for high severity alerts
        let highAlerts = alerts.filter { $0.severity == .high }
        statusScore -= highAlerts.count * 15
        
        // Deduct points for urgent feedback
        let urgentFeedback = feedback.filter { $0.priority == .urgent }
        statusScore -= urgentFeedback.count * 20
        
        // Deduct points for high error rate
        if let metrics = metrics {
            if metrics.errorCount > 10 {
                statusScore -= 25
            }
        }
        
        // Determine status based on score
        switch statusScore {
        case 90...100:
            return .excellent
        case 70..<90:
            return .good
        case 50..<70:
            return .fair
        case 30..<50:
            return .poor
        default:
            return .critical
        }
    }
    
    @objc
    private func handleCriticalAlert(_ notification: Notification) {
        Task { @MainActor in
            guard let alert = notification.object as? Alert else { return }
            
            // Forward to telemetry
            await telemetryService.recordEvent(
                TelemetryEvent(
                    type: .error,
                    source: "alert_service",
                    data: [
                        "alert_id": alert.id.uuidString,
                        "severity": alert.severity.rawValue,
                        "title": alert.title
                    ],
                    severity: .critical
                )
            )
        }
    }
    
    @objc
    private func handleUrgentFeedback(_ notification: Notification) {
        Task { @MainActor in
            guard let feedback = notification.object as? FeedbackEntry else { return }
            
            // Forward to telemetry
            await telemetryService.recordEvent(
                TelemetryEvent(
                    type: .userAction,
                    source: "feedback_service",
                    data: [
                        "feedback_id": feedback.id.uuidString,
                        "priority": feedback.priority.rawValue,
                        "category": feedback.category.rawValue
                    ],
                    severity: .warning
                )
            )
        }
    }
}

// MARK: - Observatorium Configuration
public struct ObservatoriumConfiguration: Sendable {
    public let version: String
    public let environment: String
    public let startTime: Date
    public let healthCheckInterval: TimeInterval
    public let telemetryConfig: TelemetryConfiguration
    public let alertConfig: AlertConfiguration
    public let feedbackConfig: FeedbackConfiguration
    
    public static let `default` = ObservatoriumConfiguration(
        version: "1.0.0",
        environment: "development",
        startTime: Date(),
        healthCheckInterval: 60.0, // 1 minute
        telemetryConfig: .default,
        alertConfig: .default,
        feedbackConfig: .default
    )
    
    public init(
        version: String,
        environment: String,
        startTime: Date,
        healthCheckInterval: TimeInterval,
        telemetryConfig: TelemetryConfiguration,
        alertConfig: AlertConfiguration,
        feedbackConfig: FeedbackConfiguration
    ) {
        self.version = version
        self.environment = environment
        self.startTime = startTime
        self.healthCheckInterval = healthCheckInterval
        self.telemetryConfig = telemetryConfig
        self.alertConfig = alertConfig
        self.feedbackConfig = feedbackConfig
    }
}

// MARK: - System Health
public struct SystemHealth: Sendable {
    public let isRunning: Bool
    public let uptime: TimeInterval
    public let lastHealthCheck: Date
    public let recentMetrics: AggregatedMetrics?
    public let activeAlertsCount: Int
    public let openFeedbackCount: Int
    public let overallStatus: SystemHealthStatus
    
    public init(
        isRunning: Bool,
        uptime: TimeInterval,
        lastHealthCheck: Date,
        recentMetrics: AggregatedMetrics?,
        activeAlertsCount: Int,
        openFeedbackCount: Int,
        overallStatus: SystemHealthStatus
    ) {
        self.isRunning = isRunning
        self.uptime = uptime
        self.lastHealthCheck = lastHealthCheck
        self.recentMetrics = recentMetrics
        self.activeAlertsCount = activeAlertsCount
        self.openFeedbackCount = openFeedbackCount
        self.overallStatus = overallStatus
    }
}

// MARK: - System Health Status
public enum SystemHealthStatus: String, Codable, CaseIterable, Sendable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case critical = "critical"
    
    public var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Observatorium Export
public struct ObservatoriumExport: Sendable {
    public let timeRange: TimeRange
    public let metrics: [PerformanceMetrics]
    public let events: [TelemetryEvent]
    public let alerts: [Alert]
    public let feedback: [FeedbackEntry]
    public let exportedAt: Date
    
    public init(
        timeRange: TimeRange,
        metrics: [PerformanceMetrics],
        events: [TelemetryEvent],
        alerts: [Alert],
        feedback: [FeedbackEntry],
        exportedAt: Date
    ) {
        self.timeRange = timeRange
        self.metrics = metrics
        self.events = events
        self.alerts = alerts
        self.feedback = feedback
        self.exportedAt = exportedAt
    }
}

// MARK: - Dashboard Data
public struct DashboardData: Sendable {
    public let systemHealth: SystemHealth
    public let recentMetrics: AggregatedMetrics?
    public let activeAlerts: [Alert]
    public let feedbackTrends: FeedbackTrendAnalysis?
    public let lastUpdated: Date
    
    public init(
        systemHealth: SystemHealth,
        recentMetrics: AggregatedMetrics?,
        activeAlerts: [Alert],
        feedbackTrends: FeedbackTrendAnalysis?,
        lastUpdated: Date
    ) {
        self.systemHealth = systemHealth
        self.recentMetrics = recentMetrics
        self.activeAlerts = activeAlerts
        self.feedbackTrends = feedbackTrends
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let criticalAlertTriggered = Notification.Name("criticalAlertTriggered")
}
