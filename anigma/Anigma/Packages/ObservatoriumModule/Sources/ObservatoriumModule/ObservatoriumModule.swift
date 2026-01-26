import Foundation
import AnigmaDaemonCore

// Main module export for Observatorium
public typealias Observatorium = ObservatoriumModule

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
    
    public var telemetryService: TelemetryService {
        coordinator.telemetryService
    }
    
    public var alertService: AlertService {
        coordinator.alertService
    }
    
    public var feedbackService: FeedbackService {
        coordinator.feedbackService
    }
}
