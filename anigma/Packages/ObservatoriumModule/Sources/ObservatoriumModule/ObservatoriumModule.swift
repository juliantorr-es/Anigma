import Foundation

// Main module export for Observatorium
public typealias Observatorium = ObservatoriumModule

public enum HealthSummaryStatus: String, Codable, Sendable {
    case healthy
    case degraded
    case unhealthy
}

public struct HealthSummary: Sendable {
    public let status: HealthSummaryStatus
    public let activeAlerts: Int
    public let recentErrors: Int

    public init(status: HealthSummaryStatus, activeAlerts: Int, recentErrors: Int) {
        self.status = status
        self.activeAlerts = activeAlerts
        self.recentErrors = recentErrors
    }
}

@MainActor
public final class ObservatoriumModule: @unchecked Sendable {
    public static let shared = ObservatoriumModule()
    
    private let coordinator: ObservatoriumCoordinator
    
    private init() {
        self.coordinator = ObservatoriumCoordinator()
    }
    
    public func start() async {
        await coordinator.start()
    }
    
    public func stop() async {
        await coordinator.stop()
    }

    public var alerts: AlertService {
        coordinator.alertService
    }

    public var telemetryService: TelemetryService {
        coordinator.telemetryService
    }
    
    public var alertService: AlertService {
        coordinator.alertService
    }
    
    public var feedbackService: FeedbackService {
        coordinator.feedbackService
    }

    public func getSystemHealth() async -> SystemHealth {
        await coordinator.getSystemHealth()
    }

    public func getHealthSummary() async -> HealthSummary {
        let health = await coordinator.getSystemHealth()
        let status: HealthSummaryStatus
        switch health.overallStatus {
        case .excellent, .good:
            status = .healthy
        case .fair:
            status = .degraded
        case .poor, .critical:
            status = .unhealthy
        }

        return HealthSummary(
            status: status,
            activeAlerts: health.activeAlertsCount,
            recentErrors: health.recentMetrics?.errorCount ?? 0
        )
    }
}
