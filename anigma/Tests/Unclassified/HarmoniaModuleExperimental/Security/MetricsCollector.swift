//
//  MetricsCollector.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Collects empirical metrics for security spine effectiveness.
//  Tracks blocking rates, success rates, and security violations.
//

import Foundation
import HarmoniaModule
import AnigmaCore

/// Security metrics collected over time.
public struct SecurityMetrics: Sendable, Codable {
    /// Time period these metrics cover.
    public let period: TimePeriod
    /// Total tasks processed.
    public let totalTasks: Int
    /// Tasks blocked by security.
    public let blockedTasks: Int
    /// Tasks allowed through security.
    public let allowedTasks: Int
    /// Tasks that succeeded after passing security.
    public let successfulTasks: Int
    /// Tasks that failed after passing security.
    public let failedTasks: Int
    /// Security violations detected.
    public let violations: [SecurityViolation]
    /// Capability debt tasks created.
    public let capabilityDebtTasks: Int
    /// Average processing time for allowed tasks (seconds).
    public let averageProcessingTime: TimeInterval
    /// Zone-specific metrics.
    public let zoneMetrics: [String: ZoneMetrics]
    /// Engine type-specific metrics.
    public let engineMetrics: [String: EngineMetrics]
    /// Trust tier-specific metrics.
    public let trustMetrics: [String: TrustMetrics]

    /// Calculated blocking rate (0.0 to 1.0).
    public var blockingRate: Double {
        guard totalTasks > 0 else { return 0.0 }
        return Double(blockedTasks) / Double(totalTasks)
    }

    /// Calculated success rate for allowed tasks (0.0 to 1.0).
    public var successRate: Double {
        guard allowedTasks > 0 else { return 0.0 }
        return Double(successfulTasks) / Double(allowedTasks)
    }

    /// Security effectiveness score (0.0 to 1.0).
    /// Higher is better - balances blocking risky tasks while allowing productive work.
    public var effectivenessScore: Double {
        let blockingWeight = 0.6  // Weight for blocking risky tasks
        let successWeight = 0.4   // Weight for allowing productive work

        // Ideal blocking rate is around 0.2 (20%)
        let blockingScore = 1.0 - abs(blockingRate - 0.2) * 2.5

        // Success rate should be high
        let successScore = successRate

        return (blockingScore * blockingWeight) + (successScore * successWeight)
    }

    public init(
        period: TimePeriod,
        totalTasks: Int,
        blockedTasks: Int,
        allowedTasks: Int,
        successfulTasks: Int,
        failedTasks: Int,
        violations: [SecurityViolation],
        capabilityDebtTasks: Int,
        averageProcessingTime: TimeInterval,
        zoneMetrics: [String: ZoneMetrics],
        engineMetrics: [String: EngineMetrics],
        trustMetrics: [String: TrustMetrics]
    ) {
        self.period = period
        self.totalTasks = totalTasks
        self.blockedTasks = blockedTasks
        self.allowedTasks = allowedTasks
        self.successfulTasks = successfulTasks
        self.failedTasks = failedTasks
        self.violations = violations
        self.capabilityDebtTasks = capabilityDebtTasks
        self.averageProcessingTime = averageProcessingTime
        self.zoneMetrics = zoneMetrics
        self.engineMetrics = engineMetrics
        self.trustMetrics = trustMetrics
    }
}

/// Metrics for a specific security zone.
public struct ZoneMetrics: Sendable, Codable {
    public let zone: String
    public let totalTasks: Int
    public let blockedTasks: Int
    public let allowedTasks: Int
    public let successfulTasks: Int
    public let violations: [SecurityViolation]

    public var blockingRate: Double {
        guard totalTasks > 0 else { return 0.0 }
        return Double(blockedTasks) / Double(totalTasks)
    }

    public var successRate: Double {
        guard allowedTasks > 0 else { return 0.0 }
        return Double(successfulTasks) / Double(allowedTasks)
    }
}

/// Metrics for a specific engine type.
public struct EngineMetrics: Sendable, Codable {
    public let engineType: String
    public let totalTasks: Int
    public let blockedTasks: Int
    public let allowedTasks: Int
    public let successfulTasks: Int
    public let averageProcessingTime: TimeInterval
    public let commonViolations: [String: Int]  // violation type -> count

    public var blockingRate: Double {
        guard totalTasks > 0 else { return 0.0 }
        return Double(blockedTasks) / Double(totalTasks)
    }

    public var successRate: Double {
        guard allowedTasks > 0 else { return 0.0 }
        return Double(successfulTasks) / Double(allowedTasks)
    }
}

/// Metrics for a specific trust tier.
public struct TrustMetrics: Sendable, Codable {
    public let trustTier: String
    public let totalTasks: Int
    public let blockedTasks: Int
    public let allowedTasks: Int
    public let successfulTasks: Int
    public let averageCapabilities: Int

    public var blockingRate: Double {
        guard totalTasks > 0 else { return 0.0 }
        return Double(blockedTasks) / Double(totalTasks)
    }

    public var successRate: Double {
        guard allowedTasks > 0 else { return 0.0 }
        return Double(successfulTasks) / Double(allowedTasks)
    }
}

/// Security violation detected.
public struct SecurityViolation: Sendable, Codable {
    public let id: UUID
    public let type: ViolationType
    public let severity: ViolationSeverity
    public let taskId: UUID?
    public let engineType: String?
    public let zone: String?
    public let trustTier: String?
    public let description: String
    public let detectedAt: Date
    public let resolvedAt: Date?

    public init(
        id: UUID = UUID(),
        type: ViolationType,
        severity: ViolationSeverity,
        taskId: UUID? = nil,
        engineType: String? = nil,
        zone: String? = nil,
        trustTier: String? = nil,
        description: String,
        detectedAt: Date = Date(),
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.taskId = taskId
        self.engineType = engineType
        self.zone = zone
        self.trustTier = trustTier
        self.description = description
        self.detectedAt = detectedAt
        self.resolvedAt = resolvedAt
    }
}

/// Type of security violation.
public enum ViolationType: String, Sendable, Codable {
    case capability = "capability"
    case doctrine = "doctrine"
    case zone = "zone"
    case trust = "trust"
    case isolation = "isolation"
    case provenance = "provenance"
    case audit = "audit"
}

/// Severity of security violation.
public enum ViolationSeverity: String, Sendable, Codable, Comparable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"

    public static func < (lhs: ViolationSeverity, rhs: ViolationSeverity) -> Bool {
        let order: [ViolationSeverity] = [.info, .warning, .error, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// Time period for metrics collection.
public enum TimePeriod: Sendable, Codable {
    case hour
    case day
    case week
    case month
    case quarter
    case year
    case custom(start: Date, end: Date)

    public var description: String {
        switch self {
        case .hour: return "hour"
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .quarter: return "quarter"
        case .year: return "year"
        case .custom(let start, let end):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "\(formatter.string(from: start)) to \(formatter.string(from: end))"
        }
    }
}

/// Collects and analyzes security metrics.
public actor MetricsCollector {
    private var taskMetrics: [TaskMetric] = []
    private var violations: [SecurityViolation] = []
    private var capabilityDebtTasks: [CapabilityDebtTask] = []

    private let metricsStore: MetricsStore?

    public init(metricsStore: MetricsStore? = nil) {
        self.metricsStore = metricsStore
    }

    /// Record a task processing event.
    public func recordTask(
        taskId: UUID,
        engineType: String,
        zone: String,
        trustTier: String,
        capabilities: [String],
        blocked: Bool,
        success: Bool? = nil,
        processingTime: TimeInterval? = nil,
        error: String? = nil
    ) {
        let metric = TaskMetric(
            taskId: taskId,
            engineType: engineType,
            zone: zone,
            trustTier: trustTier,
            capabilities: capabilities,
            blocked: blocked,
            success: success,
            processingTime: processingTime,
            error: error,
            recordedAt: Date()
        )

        taskMetrics.append(metric)

        // Trim old metrics (keep last 10,000)
        if taskMetrics.count > 10000 {
            taskMetrics.removeFirst(taskMetrics.count - 10000)
        }

        // Store in persistent store if available
        Task {
            try? await metricsStore?.storeTaskMetric(metric)
        }
    }

    /// Record a security violation.
    public func recordViolation(
        type: ViolationType,
        severity: ViolationSeverity,
        taskId: UUID? = nil,
        engineType: String? = nil,
        zone: String? = nil,
        trustTier: String? = nil,
        description: String
    ) {
        let violation = SecurityViolation(
            type: type,
            severity: severity,
            taskId: taskId,
            engineType: engineType,
            zone: zone,
            trustTier: trustTier,
            description: description
        )

        violations.append(violation)

        // Trim old violations (keep last 1,000)
        if violations.count > 1000 {
            violations.removeFirst(violations.count - 1000)
        }

        // Store in persistent store if available
        Task {
            try? await metricsStore?.storeViolation(violation)
        }
    }

    /// Record a capability debt task.
    public func recordCapabilityDebtTask(
        taskId: UUID,
        engineType: String,
        reason: String,
        requiredCapabilities: [String]
    ) {
        let resolvedEngine = EngineType(rawValue: engineType) ?? .migration
        let resolvedReason: String
        if requiredCapabilities.isEmpty {
            resolvedReason = reason
        } else {
            resolvedReason = "\(reason) (required: \(requiredCapabilities.joined(separator: ", ")))"
        }
        let debtTask = CapabilityDebtTask(
            originalTaskId: taskId.uuidString,
            engineType: resolvedEngine,
            reason: resolvedReason,
            createdAt: Date()
        )

        capabilityDebtTasks.append(debtTask)

        // Trim old debt tasks (keep last 500)
        if capabilityDebtTasks.count > 500 {
            capabilityDebtTasks.removeFirst(capabilityDebtTasks.count - 500)
        }

        // Store in persistent store if available
        Task {
            try? await metricsStore?.storeCapabilityDebtTask(debtTask)
        }
    }

    /// Get metrics for a specific time period.
    public func getMetrics(for period: TimePeriod) -> SecurityMetrics {
        let filteredMetrics = filterMetrics(for: period)

        // Calculate basic metrics
        let totalTasks = filteredMetrics.count
        let blockedTasks = filteredMetrics.filter { $0.blocked }.count
        let allowedTasks = totalTasks - blockedTasks
        let successfulTasks = filteredMetrics.filter { !$0.blocked && ($0.success == true) }.count
        let failedTasks = allowedTasks - successfulTasks

        // Calculate average processing time
        let processingTimes = filteredMetrics.compactMap { $0.processingTime }
        let averageProcessingTime = processingTimes.isEmpty ? 0.0 : processingTimes.reduce(0.0, +) / Double(processingTimes.count)

        // Calculate zone metrics
        let zoneMetrics = calculateZoneMetrics(from: filteredMetrics)

        // Calculate engine metrics
        let engineMetrics = calculateEngineMetrics(from: filteredMetrics)

        // Calculate trust metrics
        let trustMetrics = calculateTrustMetrics(from: filteredMetrics)

        // Filter violations for period
        let periodViolations = filterViolations(for: period)

        // Filter debt tasks for period
        let periodDebtTasks = filterDebtTasks(for: period)

        return SecurityMetrics(
            period: period,
            totalTasks: totalTasks,
            blockedTasks: blockedTasks,
            allowedTasks: allowedTasks,
            successfulTasks: successfulTasks,
            failedTasks: failedTasks,
            violations: periodViolations,
            capabilityDebtTasks: periodDebtTasks.count,
            averageProcessingTime: averageProcessingTime,
            zoneMetrics: zoneMetrics,
            engineMetrics: engineMetrics,
            trustMetrics: trustMetrics
        )
    }

    /// Get current metrics (last hour).
    public func getCurrentMetrics() -> SecurityMetrics {
        return getMetrics(for: .hour)
    }

    /// Get metrics trend over multiple periods.
    public func getMetricsTrend(periods: [TimePeriod]) -> [SecurityMetrics] {
        return periods.map { getMetrics(for: $0) }
    }

    /// Get security effectiveness score for current period.
    public func getEffectivenessScore() -> Double {
        let metrics = getCurrentMetrics()
        return metrics.effectivenessScore
    }

    /// Get recommendations based on metrics.
    public func getRecommendations() -> [SecurityRecommendation] {
        let metrics = getCurrentMetrics()
        var recommendations: [SecurityRecommendation] = []

        // Check blocking rate
        if metrics.blockingRate > 0.4 {
            recommendations.append(.init(
                type: .highBlockingRate,
                severity: DoctrineCore.DoctrineSeverity.warning,
                description: "High blocking rate (\(Int(metrics.blockingRate * 100))%) may indicate overly restrictive security",
                suggestion: "Consider adjusting capability policies or adding more granular capabilities"
            ))
        } else if metrics.blockingRate < 0.05 {
            recommendations.append(.init(
                type: .lowBlockingRate,
                severity: DoctrineCore.DoctrineSeverity.warning,
                description: "Low blocking rate (\(Int(metrics.blockingRate * 100))%) may indicate insufficient security",
                suggestion: "Consider enabling more security checks for risky operations"
            ))
        }

        // Check success rate
        if metrics.successRate < 0.7 {
            recommendations.append(.init(
                type: .lowSuccessRate,
                severity: DoctrineCore.DoctrineSeverity.error,
                description: "Low success rate (\(Int(metrics.successRate * 100))%) for allowed tasks",
                suggestion: "Investigate why tasks are failing after passing security checks"
            ))
        }

        // Check zone-specific issues
        for (zone, zoneMetric) in metrics.zoneMetrics {
            if zone == "production" && zoneMetric.blockingRate < 0.3 {
                recommendations.append(.init(
                    type: .productionSecurity,
                    severity: DoctrineCore.DoctrineSeverity.critical,
                    description: "Production zone has low blocking rate (\(Int(zoneMetric.blockingRate * 100))%)",
                    suggestion: "Increase security restrictions for production zone"
                ))
            }
        }

        // Check for common violations
        let commonViolations = Dictionary(grouping: metrics.violations) { $0.type }
        for (type, typeViolations) in commonViolations {
            if typeViolations.count > 10 {
                recommendations.append(.init(
                    type: .commonViolation(type),
                    severity: DoctrineCore.DoctrineSeverity.warning,
                    description: "\(typeViolations.count) \(type.rawValue) violations detected",
                    suggestion: "Review \(type.rawValue) policies and consider adjustments"
                ))
            }
        }

        // Check capability debt
        if metrics.capabilityDebtTasks > 5 {
            recommendations.append(.init(
                type: .capabilityDebt,
                severity: .info,
                description: "\(metrics.capabilityDebtTasks) capability debt tasks pending",
                suggestion: "Review and address capability debt tasks to unblock work"
            ))
        }

        return recommendations
    }

    /// Reset all metrics (for testing).
    public func reset() {
        taskMetrics.removeAll()
        violations.removeAll()
        capabilityDebtTasks.removeAll()
    }

    // MARK: - Private Methods

    private func filterMetrics(for period: TimePeriod) -> [TaskMetric] {
        let cutoffDate = getCutoffDate(for: period)
        return taskMetrics.filter { $0.recordedAt >= cutoffDate }
    }

    private func filterViolations(for period: TimePeriod) -> [SecurityViolation] {
        let cutoffDate = getCutoffDate(for: period)
        return violations.filter { $0.detectedAt >= cutoffDate }
    }

    private func filterDebtTasks(for period: TimePeriod) -> [CapabilityDebtTask] {
        let cutoffDate = getCutoffDate(for: period)
        return capabilityDebtTasks.filter { $0.createdAt >= cutoffDate }
    }

    private func getCutoffDate(for period: TimePeriod) -> Date {
        let now = Date()
        let calendar = Calendar.current

        switch period {
        case .hour:
            return calendar.date(byAdding: .hour, value: -1, to: now) ?? now
        case .day:
            return calendar.date(byAdding: .day, value: -1, to: now) ?? now
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .custom(let start, _):
            return start
        }
    }

    private func calculateZoneMetrics(from metrics: [TaskMetric]) -> [String: ZoneMetrics] {
        let grouped = Dictionary(grouping: metrics) { $0.zone }

        return grouped.mapValues { zoneMetrics in
            let total = zoneMetrics.count
            let blocked = zoneMetrics.filter { $0.blocked }.count
            let allowed = total - blocked
            let successful = zoneMetrics.filter { !$0.blocked && ($0.success == true) }.count

            // Get violations for this zone
            let zoneViolations = violations.filter { $0.zone == zoneMetrics.first?.zone }

            return ZoneMetrics(
                zone: zoneMetrics.first?.zone ?? "unknown",
                totalTasks: total,
                blockedTasks: blocked,
                allowedTasks: allowed,
                successfulTasks: successful,
                violations: zoneViolations
            )
        }
    }

    private func calculateEngineMetrics(from metrics: [TaskMetric]) -> [String: EngineMetrics] {
        let grouped = Dictionary(grouping: metrics) { $0.engineType }

        return grouped.mapValues { engineMetrics in
            let total = engineMetrics.count
            let blocked = engineMetrics.filter { $0.blocked }.count
            let allowed = total - blocked
            let successful = engineMetrics.filter { !$0.blocked && ($0.success == true) }.count

            // Calculate average processing time
            let processingTimes = engineMetrics.compactMap { $0.processingTime }
            let avgTime = processingTimes.isEmpty ? 0.0 : processingTimes.reduce(0.0, +) / Double(processingTimes.count)

            // Get common violations for this engine type
            let engineViolations = violations.filter { $0.engineType == engineMetrics.first?.engineType }
            let violationCounts = Dictionary(grouping: engineViolations) { $0.type.rawValue }
                .mapValues { $0.count }

            return EngineMetrics(
                engineType: engineMetrics.first?.engineType ?? "unknown",
                totalTasks: total,
                blockedTasks: blocked,
                allowedTasks: allowed,
                successfulTasks: successful,
                averageProcessingTime: avgTime,
                commonViolations: violationCounts
            )
        }
    }

    private func calculateTrustMetrics(from metrics: [TaskMetric]) -> [String: TrustMetrics] {
        let grouped = Dictionary(grouping: metrics) { $0.trustTier }

        return grouped.mapValues { trustMetrics in
            let total = trustMetrics.count
            let blocked = trustMetrics.filter { $0.blocked }.count
            let allowed = total - blocked
            let successful = trustMetrics.filter { !$0.blocked && ($0.success == true) }.count

            // Calculate average capabilities
            let avgCapabilities = trustMetrics.isEmpty ? 0 : trustMetrics.map { $0.capabilities.count }.reduce(0, +) / trustMetrics.count

            return TrustMetrics(
                trustTier: trustMetrics.first?.trustTier ?? "unknown",
                totalTasks: total,
                blockedTasks: blocked,
                allowedTasks: allowed,
                successfulTasks: successful,
                averageCapabilities: avgCapabilities
            )
        }
    }
}

// MARK: - Supporting Types

private struct TaskMetric: Sendable, Codable {
    let taskId: UUID
    let engineType: String
    let zone: String
    let trustTier: String
    let capabilities: [String]
    let blocked: Bool
    let success: Bool?
    let processingTime: TimeInterval?
    let error: String?
    let recordedAt: Date
}

public struct SecurityRecommendation: Sendable, Codable {
    public enum RecommendationType: String, Sendable, Codable {
        case highBlockingRate = "high_blocking_rate"
        case lowBlockingRate = "low_blocking_rate"
        case lowSuccessRate = "low_success_rate"
        case productionSecurity = "production_security"
        case commonViolation(ViolationType) = "common_violation"
        case capabilityDebt = "capability_debt"
    }

    public let type: RecommendationType
    public let severity: ViolationSeverity
    public let description: String
    public let suggestion: String
    public let createdAt: Date

    public init(
        type: RecommendationType,
        severity: ViolationSeverity,
        description: String,
        suggestion: String,
        createdAt: Date = Date()
    ) {
        self.type = type
        self.severity = severity
        self.description = description
        self.suggestion = suggestion
        self.createdAt = createdAt
    }
}

// MARK: - Metrics Store Protocol

public protocol MetricsStore: Sendable {
    func storeTaskMetric(_ metric: TaskMetric) async throws
    func storeViolation(_ violation: SecurityViolation) async throws
    func storeCapabilityDebtTask(_ debtTask: CapabilityDebtTask) async throws
    func getTaskMetrics(since date: Date) async throws -> [TaskMetric]
    func getViolations(since date: Date) async throws -> [SecurityViolation]
    func getCapabilityDebtTasks(since date: Date) async throws -> [CapabilityDebtTask]
}

// MARK: - Default Implementation (In-Memory)

actor InMemoryMetricsStore: MetricsStore {
    private var taskMetrics: [TaskMetric] = []
    private var violations: [SecurityViolation] = []
    private var capabilityDebtTasks: [CapabilityDebtTask] = []

    func storeTaskMetric(_ metric: TaskMetric) async throws {
        taskMetrics.append(metric)
    }

    func storeViolation(_ violation: SecurityViolation) async throws {
        violations.append(violation)
    }

    func storeCapabilityDebtTask(_ debtTask: CapabilityDebtTask) async throws {
        capabilityDebtTasks.append(debtTask)
    }

    func getTaskMetrics(since date: Date) async throws -> [TaskMetric] {
        return taskMetrics.filter { $0.recordedAt >= date }
    }

    func getViolations(since date: Date) async throws -> [SecurityViolation] {
        return violations.filter { $0.detectedAt >= date }
    }

    func getCapabilityDebtTasks(since date: Date) async throws -> [CapabilityDebtTask] {
        return capabilityDebtTasks.filter { $0.createdAt >= date }
    }
}

// MARK: - Logging Helper

private func logInfo(_ message: String, category: String = "MetricsCollector") {
    print("[INFO][\(category)] \(message)")
}

private func logWarning(_ message: String, category: String = "MetricsCollector") {
    print("[WARNING][\(category)] \(message)")
}

private func logError(_ message: String, category: String = "MetricsCollector") {
    print("[ERROR][\(category)] \(message)")
}
