import Foundation
import AnigmaDaemonCore

// MARK: - Alert Service Protocol
public protocol AlertServiceProtocol: Sendable {
    func createRule(_ rule: AlertRule) async throws
    func updateRule(_ rule: AlertRule) async throws
    func deleteRule(id: UUID) async throws
    func getRules() async -> [AlertRule]
    func getActiveAlerts() async -> [Alert]
    func acknowledgeAlert(id: UUID) async throws
    func resolveAlert(id: UUID) async throws
    func evaluateAlerts() async
    func addNotificationChannel(_ channel: NotificationChannel) async throws
    func getNotificationChannels() async -> [NotificationChannel]
}

// MARK: - Alert Service Implementation
@MainActor
public final class AlertService: AlertServiceProtocol {
    private let ruleStore: InMemoryRuleStore
    private let alertStore: InMemoryAlertStore
    private let notificationEngine: NotificationEngine
    private let evaluationEngine: AlertEvaluationEngine
    
    // MARK: - Configuration
    private let configuration: AlertConfiguration
    
    public init(configuration: AlertConfiguration = .default) {
        self.configuration = configuration
        self.ruleStore = InMemoryRuleStore()
        self.alertStore = InMemoryAlertStore()
        self.notificationEngine = NotificationEngine()
        self.evaluationEngine = AlertEvaluationEngine()
        
        // Subscribe to telemetry events for evaluation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTelemetryEvent),
            name: .criticalTelemetryEvent,
            object: nil
        )
    }
    
    // MARK: - AlertServiceProtocol
    public func createRule(_ rule: AlertRule) async throws {
        try ruleStore.addRule(rule)
        evaluationEngine.updateRules(ruleStore.getRules())
    }
    
    public func updateRule(_ rule: AlertRule) async throws {
        try ruleStore.updateRule(rule)
        evaluationEngine.updateRules(ruleStore.getRules())
    }
    
    public func deleteRule(id: UUID) async throws {
        try ruleStore.deleteRule(id: id)
        evaluationEngine.updateRules(ruleStore.getRules())
    }
    
    public func getRules() async -> [AlertRule] {
        ruleStore.getRules()
    }
    
    public func getActiveAlerts() async -> [Alert] {
        alertStore.getActiveAlerts()
    }
    
    public func acknowledgeAlert(id: UUID) async throws {
        try alertStore.updateAlertStatus(id: id, status: .acknowledged)
    }
    
    public func resolveAlert(id: UUID) async throws {
        try alertStore.updateAlertStatus(id: id, status: .resolved)
    }
    
    public func evaluateAlerts() async {
        let rules = ruleStore.getRules()
        let activeAlerts = alertStore.getActiveAlerts()
        
        evaluationEngine.evaluate(rules: rules, activeAlerts: activeAlerts) { [weak self] newAlert in
            Task { @MainActor in
                await self?.handleNewAlert(newAlert)
            }
        }
    }
    
    public func addNotificationChannel(_ channel: NotificationChannel) async throws {
        try notificationEngine.addChannel(channel)
    }
    
    public func getNotificationChannels() async -> [NotificationChannel] {
        notificationEngine.getChannels()
    }
    
    // MARK: - Public Methods
    private var evaluationTask: Task<Void, Never>?
    
    public func startEvaluation() {
        guard evaluationTask == nil else { return }
        
        evaluationTask = Task {
            while !Task.isCancelled {
                await evaluateAlerts()
                try? await Task.sleep(nanoseconds: UInt64(configuration.evaluationInterval * 1_000_000_000))
            }
        }
    }
    
    public func stopEvaluation() {
        evaluationTask?.cancel()
        evaluationTask = nil
    }
    
    // MARK: - Private Methods
    @objc
    private func handleTelemetryEvent(_ notification: Notification) {
        Task { @MainActor in
            await evaluateAlerts()
        }
    }
    
    private func handleNewAlert(_ alert: Alert) async {
        try? alertStore.addAlert(alert)
        
        // Send notifications
        let channels = notificationEngine.getChannels()
        for channel in channels where channel.enabled {
            await notificationEngine.sendNotification(for: alert, through: channel)
        }
        
        // Forward to AnigmaDaemonCore
        if configuration.forwardToDaemonCore {
            // Integration with AnigmaDaemonCore would happen here
        }
    }
}

// MARK: - Alert Configuration
public struct AlertConfiguration: Sendable {
    public let maxActiveAlerts: Int
    public let maxStoredAlerts: Int
    public let evaluationInterval: TimeInterval
    public let forwardToDaemonCore: Bool
    
    public static let `default` = AlertConfiguration(
        maxActiveAlerts: 1000,
        maxStoredAlerts: 10000,
        evaluationInterval: 60.0, // 1 minute
        forwardToDaemonCore: true
    )
    
    public init(
        maxActiveAlerts: Int,
        maxStoredAlerts: Int,
        evaluationInterval: TimeInterval,
        forwardToDaemonCore: Bool
    ) {
        self.maxActiveAlerts = maxActiveAlerts
        self.maxStoredAlerts = maxStoredAlerts
        self.evaluationInterval = evaluationInterval
        self.forwardToDaemonCore = forwardToDaemonCore
    }
}

// MARK: - In-Memory Rule Store
@MainActor
private final class InMemoryRuleStore {
    private var rules: [UUID: AlertRule] = [:]
    
    func addRule(_ rule: AlertRule) throws {
        guard rules[rule.id] == nil else {
            throw AlertServiceError.ruleAlreadyExists
        }
        rules[rule.id] = rule
    }
    
    func updateRule(_ rule: AlertRule) throws {
        guard rules[rule.id] != nil else {
            throw AlertServiceError.ruleNotFound
        }
        rules[rule.id] = rule
    }
    
    func deleteRule(id: UUID) throws {
        guard rules.removeValue(forKey: id) != nil else {
            throw AlertServiceError.ruleNotFound
        }
    }
    
    func getRules() -> [AlertRule] {
        Array(rules.values)
    }
}

// MARK: - In-Memory Alert Store
@MainActor
private final class InMemoryAlertStore {
    private var alerts: [UUID: Alert] = [:]
    private let maxStoredAlerts: Int
    
    init(maxStoredAlerts: Int = 10000) {
        self.maxStoredAlerts = maxStoredAlerts
    }
    
    func addAlert(_ alert: Alert) throws {
        alerts[alert.id] = alert
        
        // Cleanup old resolved alerts if we exceed the limit
        if alerts.count > maxStoredAlerts {
            let resolvedAlerts = alerts.values.filter { $0.status == .resolved }
            let oldestResolved = resolvedAlerts.sorted { ($0.resolvedAt ?? Date.distantFuture) < ($1.resolvedAt ?? Date.distantFuture) }
            
            for alert in oldestResolved.prefix(alerts.count - maxStoredAlerts) {
                alerts.removeValue(forKey: alert.id)
            }
        }
    }
    
    func updateAlertStatus(id: UUID, status: AlertStatus) throws {
        guard var alert = alerts[id] else {
            throw AlertServiceError.alertNotFound
        }
        
        switch status {
        case .acknowledged:
            alert.acknowledge()
        case .resolved:
            alert.resolve()
        default:
            // For other statuses, we'd need a different approach
            // This is a simplified implementation
            break
        }
        
        alerts[id] = alert
    }
    
    func getActiveAlerts() -> [Alert] {
        alerts.values.filter { $0.status == .active || $0.status == .acknowledged }
    }
}

// MARK: - Alert Evaluation Engine
@MainActor
private final class AlertEvaluationEngine {
    private var rules: [AlertRule] = []
    private var lastTriggered: [UUID: Date] = [:]
    
    func updateRules(_ rules: [AlertRule]) {
        self.rules = rules.filter { $0.enabled }
    }
    
    func evaluate(
        rules: [AlertRule],
        activeAlerts: [Alert],
        onNewAlert: @escaping @Sendable (Alert) -> Void
    ) {
        self.rules = rules.filter { $0.enabled }
        
        for rule in self.rules {
            if shouldTriggerRule(rule, activeAlerts: activeAlerts) {
                let alert = Alert(
                    ruleId: rule.id,
                    ruleName: rule.name,
                    type: rule.type,
                    severity: rule.severity,
                    title: "Alert: \(rule.name)",
                    message: rule.description,
                    metadata: ["rule_id": rule.id.uuidString]
                )
                
                onNewAlert(alert)
                lastTriggered[rule.id] = Date()
            }
        }
    }
    
    private func shouldTriggerRule(_ rule: AlertRule, activeAlerts: [Alert]) -> Bool {
        // Check cooldown period
        if let lastTriggered = lastTriggered[rule.id] {
            let timeSinceLastTrigger = Date().timeIntervalSince(lastTriggered)
            if timeSinceLastTrigger < rule.cooldownInterval {
                return false
            }
        }
        
        // Check if there's already an active alert for this rule
        let hasActiveAlert = activeAlerts.contains { $0.ruleId == rule.id && ($0.status == .active || $0.status == .acknowledged) }
        if hasActiveAlert {
            return false
        }
        
        // Evaluate conditions (simplified implementation)
        return evaluateConditions(rule.conditions)
    }
    
    private func evaluateConditions(_ conditions: [AlertCondition]) -> Bool {
        // This is a simplified implementation
        // In a real system, you'd query actual metrics and evaluate each condition
        for condition in conditions {
            // Simulate metric evaluation
            let currentValue = Double.random(in: 0...100)
            
            switch condition.op {
            case .greaterThan:
                if currentValue <= condition.threshold {
                    return false
                }
            case .lessThan:
                if currentValue >= condition.threshold {
                    return false
                }
            case .greaterThanOrEqual:
                if currentValue < condition.threshold {
                    return false
                }
            case .lessThanOrEqual:
                if currentValue > condition.threshold {
                    return false
                }
            case .equal:
                if currentValue != condition.threshold {
                    return false
                }
            case .notEqual:
                if currentValue == condition.threshold {
                    return false
                }
            }
        }
        
        return true
    }
}

// MARK: - Notification Engine
@MainActor
private final class NotificationEngine {
    private var channels: [UUID: NotificationChannel] = [:]
    
    func addChannel(_ channel: NotificationChannel) throws {
        channels[channel.id] = channel
    }
    
    func getChannels() -> [NotificationChannel] {
        Array(channels.values)
    }
    
    func sendNotification(for alert: Alert, through channel: NotificationChannel) async {
        switch channel.type {
        case .email:
            await sendEmailNotification(for: alert, channel: channel)
        case .slack:
            await sendSlackNotification(for: alert, channel: channel)
        case .webhook:
            await sendWebhookNotification(for: alert, channel: channel)
        case .push:
            await sendPushNotification(for: alert, channel: channel)
        case .sms:
            await sendSMSNotification(for: alert, channel: channel)
        }
    }
    
    // MARK: - Private Notification Methods
    private func sendEmailNotification(for alert: Alert, channel: NotificationChannel) async {
        // Simulate email sending
        print("Sending email notification for alert: \(alert.title)")
    }
    
    private func sendSlackNotification(for alert: Alert, channel: NotificationChannel) async {
        // Simulate Slack notification
        print("Sending Slack notification for alert: \(alert.title)")
    }
    
    private func sendWebhookNotification(for alert: Alert, channel: NotificationChannel) async {
        // Simulate webhook call
        print("Sending webhook notification for alert: \(alert.title)")
    }
    
    private func sendPushNotification(for alert: Alert, channel: NotificationChannel) async {
        // Simulate push notification
        print("Sending push notification for alert: \(alert.title)")
    }
    
    private func sendSMSNotification(for alert: Alert, channel: NotificationChannel) async {
        // Simulate SMS sending
        print("Sending SMS notification for alert: \(alert.title)")
    }
}

// MARK: - Alert Service Error
public enum AlertServiceError: Error, LocalizedError {
    case ruleAlreadyExists
    case ruleNotFound
    case alertNotFound
    case invalidRule
    
    public var errorDescription: String? {
        switch self {
        case .ruleAlreadyExists:
            return "Alert rule already exists"
        case .ruleNotFound:
            return "Alert rule not found"
        case .alertNotFound:
            return "Alert not found"
        case .invalidRule:
            return "Invalid alert rule"
        }
    }
}
