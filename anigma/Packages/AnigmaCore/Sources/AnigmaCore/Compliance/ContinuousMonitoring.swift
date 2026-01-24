//
//  ContinuousMonitoring.swift
//  AnigmaCore
//
//  Continuous monitoring infrastructure for compliance controls.
//  Implements control probes that evaluate control effectiveness in real-time.
//
//  This is FedRAMP ConMon done right: continuous telemetry, not monthly PDFs.
//

import Foundation
import ContractsCore

// MARK: - Control Probe

/// A probe that monitors a control's effectiveness.
public struct ControlProbe: Sendable, Identifiable {
    /// Unique probe identifier.
    public let probeId: String

    /// Control(s) this probe monitors.
    public let controlIds: [String]

    /// Framework ID.
    public let frameworkId: String

    /// Human-readable name.
    public let name: String

    /// What this probe checks.
    public let description: String

    /// How often this probe runs.
    public let frequency: ProbeFrequency

    /// The evaluator function.
    public let evaluator: @Sendable () async throws -> ProbeResult

    /// Thresholds for this probe.
    public let thresholds: ProbeThresholds

    /// Tags for categorization.
    public let tags: Set<String>

    public var id: String { probeId }

    public init(
        probeId: String,
        controlIds: [String],
        frameworkId: String = "NIST-800-53-R5",
        name: String,
        description: String,
        frequency: ProbeFrequency = .hourly,
        thresholds: ProbeThresholds = .default,
        tags: Set<String> = [],
        evaluator: @escaping @Sendable () async throws -> ProbeResult
    ) {
        self.probeId = probeId
        self.controlIds = controlIds
        self.frameworkId = frameworkId
        self.name = name
        self.description = description
        self.frequency = frequency
        self.thresholds = thresholds
        self.tags = tags
        self.evaluator = evaluator
    }
}

/// How often a probe runs.
public enum ProbeFrequency: String, Sendable, Codable {
    /// Every minute.
    case minute = "minute"

    /// Every 5 minutes.
    case fiveMinutes = "5_minutes"

    /// Every 15 minutes.
    case fifteenMinutes = "15_minutes"

    /// Every hour.
    case hourly = "hourly"

    /// Every 4 hours.
    case fourHours = "4_hours"

    /// Once per day.
    case daily = "daily"

    /// Once per week.
    case weekly = "weekly"

    /// Once per month.
    case monthly = "monthly"

    /// Interval in seconds.
    public var intervalSeconds: TimeInterval {
        switch self {
        case .minute: return 60
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .hourly: return 3600
        case .fourHours: return 14400
        case .daily: return 86400
        case .weekly: return 604800
        case .monthly: return 2592000
        }
    }
}

/// Thresholds for probe evaluation.
public struct ProbeThresholds: Sendable {
    /// Score below which control is considered failing.
    public let failingThreshold: Double

    /// Score below which control is considered degraded.
    public let degradedThreshold: Double

    /// Score at or above which control is considered healthy.
    public let healthyThreshold: Double

    public init(
        failingThreshold: Double = 0.5,
        degradedThreshold: Double = 0.8,
        healthyThreshold: Double = 0.95
    ) {
        self.failingThreshold = failingThreshold
        self.degradedThreshold = degradedThreshold
        self.healthyThreshold = healthyThreshold
    }

    public static let `default` = ProbeThresholds()

    public static let strict = ProbeThresholds(
        failingThreshold: 0.7,
        degradedThreshold: 0.9,
        healthyThreshold: 0.99
    )
}

// MARK: - Probe Result

/// Result of a control probe evaluation.
public struct ProbeResult: Sendable, Codable {
    /// The probe that generated this result.
    public let probeId: String

    /// When the probe ran.
    public let evaluatedAt: Date

    /// Overall compliance score (0.0 - 1.0).
    public let score: Double

    /// Status based on thresholds.
    public let status: ProbeStatus

    /// Summary of findings.
    public let summary: String

    /// Detailed metrics.
    public let metrics: [ProbeMetric]

    /// Any issues found.
    public let issues: [ProbeIssue]

    /// Evidence collected.
    public let evidence: [String: ComplianceValue]

    public init(
        probeId: String,
        score: Double,
        status: ProbeStatus,
        summary: String,
        metrics: [ProbeMetric] = [],
        issues: [ProbeIssue] = [],
        evidence: [String: ComplianceValue] = [:]
    ) {
        self.probeId = probeId
        self.evaluatedAt = Date()
        self.score = score
        self.status = status
        self.summary = summary
        self.metrics = metrics
        self.issues = issues
        self.evidence = evidence
    }

    /// Creates a healthy result.
    public static func healthy(
        probeId: String,
        summary: String,
        metrics: [ProbeMetric] = [],
        evidence: [String: ComplianceValue] = [:]
    ) -> ProbeResult {
        ProbeResult(
            probeId: probeId,
            score: 1.0,
            status: .healthy,
            summary: summary,
            metrics: metrics,
            evidence: evidence
        )
    }

    /// Creates a degraded result.
    public static func degraded(
        probeId: String,
        score: Double,
        summary: String,
        issues: [ProbeIssue],
        metrics: [ProbeMetric] = [],
        evidence: [String: ComplianceValue] = [:]
    ) -> ProbeResult {
        ProbeResult(
            probeId: probeId,
            score: score,
            status: .degraded,
            summary: summary,
            metrics: metrics,
            issues: issues,
            evidence: evidence
        )
    }

    /// Creates a failing result.
    public static func failing(
        probeId: String,
        score: Double,
        summary: String,
        issues: [ProbeIssue],
        metrics: [ProbeMetric] = [],
        evidence: [String: ComplianceValue] = [:]
    ) -> ProbeResult {
        ProbeResult(
            probeId: probeId,
            score: score,
            status: .failing,
            summary: summary,
            metrics: metrics,
            issues: issues,
            evidence: evidence
        )
    }
}

/// Status of a probe result.
public enum ProbeStatus: String, Sendable, Codable {
    /// Control is operating as expected.
    case healthy = "healthy"

    /// Control is partially working or at risk.
    case degraded = "degraded"

    /// Control is not meeting requirements.
    case failing = "failing"

    /// Probe could not be evaluated.
    case error = "error"

    /// Probe is not applicable in current context.
    case notApplicable = "not_applicable"
}

/// A metric collected by a probe.
public struct ProbeMetric: Sendable, Codable {
    /// Metric name.
    public let name: String

    /// Metric value.
    public let value: Double

    /// Unit of measurement.
    public let unit: String?

    /// Expected/target value.
    public let target: Double?

    /// Whether this metric is within acceptable range.
    public let acceptable: Bool

    public init(
        name: String,
        value: Double,
        unit: String? = nil,
        target: Double? = nil,
        acceptable: Bool = true
    ) {
        self.name = name
        self.value = value
        self.unit = unit
        self.target = target
        self.acceptable = acceptable
    }
}

/// An issue found by a probe.
public struct ProbeIssue: Sendable, Codable {
    /// Issue severity.
    public let severity: FindingSeverity

    /// Issue description.
    public let description: String

    /// Affected entity or component.
    public let affected: String?

    /// Recommended remediation.
    public let remediation: String?

    public init(
        severity: FindingSeverity,
        description: String,
        affected: String? = nil,
        remediation: String? = nil
    ) {
        self.severity = severity
        self.description = description
        self.affected = affected
        self.remediation = remediation
    }
}

// MARK: - Continuous Monitoring Service

/// Service that orchestrates continuous control monitoring.
public actor ContinuousMonitoringService {
    /// Registered probes.
    private var probes: [String: ControlProbe] = [:]

    /// Latest results per probe.
    private var latestResults: [String: ProbeResult] = [:]

    /// Result history (limited).
    private var resultHistory: [String: [ProbeResult]] = [:]

    /// Maximum history entries per probe.
    private let maxHistoryPerProbe = 100

    /// Audit log for compliance events.
    private var auditLog: (any AuditLogging)?

    /// Whether monitoring is running.
    private var isRunning = false

    public init() {}

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Registers a probe.
    public func registerProbe(_ probe: ControlProbe) {
        probes[probe.probeId] = probe
    }

    /// Unregisters a probe.
    public func unregisterProbe(_ probeId: String) {
        probes.removeValue(forKey: probeId)
    }

    /// Gets all registered probes.
    public func getProbes() -> [ControlProbe] {
        Array(probes.values)
    }

    /// Gets probes for a specific control.
    public func getProbesForControl(_ controlId: String) -> [ControlProbe] {
        probes.values.filter { $0.controlIds.contains(controlId) }
    }

    /// Runs a specific probe.
    public func runProbe(_ probeId: String) async -> ProbeResult? {
        guard let probe = probes[probeId] else { return nil }

        do {
            let result = try await probe.evaluator()
            recordResult(result, for: probeId)

            // Log to audit if status is not healthy
            if result.status != .healthy, let log = auditLog {
                try? await log.record(
                    eventType: ContractsCore.AuditEventType.policyEvaluated,
                    principal: "compliance_monitor",
                    module: "ContinuousMonitoringService",
                    description: "Probe \(probeId) status: \(result.status.rawValue) - \(result.summary)",
                    metadata: [
                        "probe_id": probeId,
                        "status": result.status.rawValue,
                        "score": String(result.score)
                    ]
                )
            }

            return result
        } catch {
            let errorResult = ProbeResult(
                probeId: probeId,
                score: 0,
                status: .error,
                summary: "Probe evaluation failed: \(error.localizedDescription)",
                issues: [ProbeIssue(severity: .high, description: error.localizedDescription)]
            )
            recordResult(errorResult, for: probeId)
            return errorResult
        }
    }

    /// Runs all probes.
    public func runAllProbes() async -> [ProbeResult] {
        var results: [ProbeResult] = []

        for probeId in probes.keys {
            if let result = await runProbe(probeId) {
                results.append(result)
            }
        }

        return results
    }

    /// Gets the latest result for a probe.
    public func getLatestResult(_ probeId: String) -> ProbeResult? {
        latestResults[probeId]
    }

    /// Gets all latest results.
    public func getAllLatestResults() -> [ProbeResult] {
        Array(latestResults.values)
    }

    /// Gets result history for a probe.
    public func getResultHistory(_ probeId: String) -> [ProbeResult] {
        resultHistory[probeId] ?? []
    }

    /// Computes overall compliance status.
    public func getOverallStatus() -> ComplianceStatus {
        let results = Array(latestResults.values)

        guard !results.isEmpty else {
            return ComplianceStatus(
                overallScore: 1.0,
                status: .healthy,
                probeCount: 0,
                healthyCount: 0,
                degradedCount: 0,
                failingCount: 0,
                errorCount: 0,
                evaluatedAt: Date()
            )
        }

        let healthyCount = results.filter { $0.status == .healthy }.count
        let degradedCount = results.filter { $0.status == .degraded }.count
        let failingCount = results.filter { $0.status == .failing }.count
        let errorCount = results.filter { $0.status == .error }.count

        let averageScore = results.map { $0.score }.reduce(0, +) / Double(results.count)

        let status: ProbeStatus
        if failingCount > 0 || errorCount > 0 {
            status = .failing
        } else if degradedCount > 0 {
            status = .degraded
        } else {
            status = .healthy
        }

        return ComplianceStatus(
            overallScore: averageScore,
            status: status,
            probeCount: results.count,
            healthyCount: healthyCount,
            degradedCount: degradedCount,
            failingCount: failingCount,
            errorCount: errorCount,
            evaluatedAt: Date()
        )
    }

    /// Gets compliance status per control.
    public func getControlStatus() -> [String: ControlComplianceStatus] {
        var statusByControl: [String: [ProbeResult]] = [:]

        // Group results by control
        for probe in probes.values {
            if let result = latestResults[probe.probeId] {
                for controlId in probe.controlIds {
                    statusByControl[controlId, default: []].append(result)
                }
            }
        }

        // Compute status per control
        var result: [String: ControlComplianceStatus] = [:]
        for (controlId, results) in statusByControl {
            let score = results.map { $0.score }.reduce(0, +) / Double(results.count)
            let worstStatus = results.map { $0.status }.min { lhs, rhs in
                statusPriority(lhs) > statusPriority(rhs)
            } ?? .healthy

            result[controlId] = ControlComplianceStatus(
                controlId: controlId,
                score: score,
                status: worstStatus,
                probeResults: results,
                evaluatedAt: Date()
            )
        }

        return result
    }

    // MARK: - Private Helpers

    private func recordResult(_ result: ProbeResult, for probeId: String) {
        latestResults[probeId] = result

        var history = resultHistory[probeId] ?? []
        history.append(result)

        // Trim history
        if history.count > maxHistoryPerProbe {
            history = Array(history.suffix(maxHistoryPerProbe))
        }

        resultHistory[probeId] = history
    }

    private func statusPriority(_ status: ProbeStatus) -> Int {
        switch status {
        case .healthy: return 4
        case .notApplicable: return 3
        case .degraded: return 2
        case .error: return 1
        case .failing: return 0
        }
    }
}

/// Overall compliance status.
public struct ComplianceStatus: Sendable, Codable {
    public let overallScore: Double
    public let status: ProbeStatus
    public let probeCount: Int
    public let healthyCount: Int
    public let degradedCount: Int
    public let failingCount: Int
    public let errorCount: Int
    public let evaluatedAt: Date
}

/// Compliance status for a single control.
public struct ControlComplianceStatus: Sendable {
    public let controlId: String
    public let score: Double
    public let status: ProbeStatus
    public let probeResults: [ProbeResult]
    public let evaluatedAt: Date
}

// MARK: - Standard Probes

/// Factory for creating standard compliance probes.
public enum StandardProbes {

    /// Creates a probe for AC-2 account management.
    public static func accountManagementProbe(
        identityChecker: @escaping @Sendable () async -> (staleAccounts: Int, totalAccounts: Int, recentDeprovisionings: Int)
    ) -> ControlProbe {
        ControlProbe(
            probeId: "probe.ac2.account_review",
            controlIds: ["AC-2"],
            name: "Account Management Review",
            description: "Checks for stale accounts and proper deprovisioning",
            frequency: .daily,
            tags: ["access_control", "identity"]
        ) {
            let (stale, total, deprov) = await identityChecker()

            let staleRatio = total > 0 ? Double(stale) / Double(total) : 0
            let score = 1.0 - min(staleRatio * 2, 1.0) // Penalize stale accounts

            var issues: [ProbeIssue] = []
            if stale > 0 {
                issues.append(ProbeIssue(
                    severity: stale > 5 ? .high : .medium,
                    description: "\(stale) potentially stale accounts detected",
                    remediation: "Review and deprovision inactive accounts"
                ))
            }

            let status: ProbeStatus = score >= 0.95 ? .healthy : (score >= 0.8 ? .degraded : .failing)

            return ProbeResult(
                probeId: "probe.ac2.account_review",
                score: score,
                status: status,
                summary: "Reviewed \(total) accounts, \(stale) stale, \(deprov) recent deprovisionings",
                metrics: [
                    ProbeMetric(name: "total_accounts", value: Double(total)),
                    ProbeMetric(name: "stale_accounts", value: Double(stale), target: 0, acceptable: stale == 0),
                    ProbeMetric(name: "recent_deprovisionings", value: Double(deprov))
                ],
                issues: issues
            )
        }
    }

    /// Creates a probe for AU-9 audit integrity.
    public static func auditIntegrityProbe(
        integrityChecker: @escaping @Sendable () async -> (verified: Bool, entriesChecked: Int, failures: Int)
    ) -> ControlProbe {
        ControlProbe(
            probeId: "probe.au9.integrity_check",
            controlIds: ["AU-9"],
            name: "Audit Log Integrity",
            description: "Verifies integrity of audit log entries via hash chain",
            frequency: .hourly,
            thresholds: .strict,
            tags: ["audit", "integrity"]
        ) {
            let (verified, checked, failures) = await integrityChecker()

            let score = verified ? 1.0 : 0.0

            var issues: [ProbeIssue] = []
            if !verified {
                issues.append(ProbeIssue(
                    severity: .critical,
                    description: "Audit log integrity verification failed with \(failures) failures",
                    remediation: "Investigate potential tampering and restore from backup if necessary"
                ))
            }

            return ProbeResult(
                probeId: "probe.au9.integrity_check",
                score: score,
                status: verified ? .healthy : .failing,
                summary: verified ? "Audit log integrity verified (\(checked) entries)" : "INTEGRITY FAILURE",
                metrics: [
                    ProbeMetric(name: "entries_checked", value: Double(checked)),
                    ProbeMetric(name: "failures", value: Double(failures), target: 0, acceptable: failures == 0)
                ],
                issues: issues
            )
        }
    }

    /// Creates a probe for CP-9 backup compliance.
    public static func backupComplianceProbe(
        backupChecker: @escaping @Sendable () async -> (lastBackupAge: TimeInterval, targetRPO: TimeInterval, backupSuccess: Bool)
    ) -> ControlProbe {
        ControlProbe(
            probeId: "probe.cp9.backup_compliance",
            controlIds: ["CP-9"],
            name: "Backup Compliance",
            description: "Verifies backup frequency meets RPO requirements",
            frequency: .hourly,
            tags: ["backup", "contingency"]
        ) {
            let (age, rpo, success) = await backupChecker()

            let rpoCompliance = age <= rpo
            let score = rpoCompliance && success ? 1.0 : (rpoCompliance ? 0.7 : 0.3)

            var issues: [ProbeIssue] = []
            if !rpoCompliance {
                issues.append(ProbeIssue(
                    severity: .high,
                    description: "Last backup (\(Int(age / 3600))h ago) exceeds RPO target (\(Int(rpo / 3600))h)",
                    remediation: "Run backup immediately and investigate scheduling issues"
                ))
            }
            if !success {
                issues.append(ProbeIssue(
                    severity: .medium,
                    description: "Last backup attempt was not successful",
                    remediation: "Review backup logs and resolve issues"
                ))
            }

            let status: ProbeStatus = (rpoCompliance && success) ? .healthy : (!rpoCompliance ? .failing : .degraded)

            return ProbeResult(
                probeId: "probe.cp9.backup_compliance",
                score: score,
                status: status,
                summary: "Last backup: \(Int(age / 3600))h ago, RPO target: \(Int(rpo / 3600))h",
                metrics: [
                    ProbeMetric(name: "backup_age_hours", value: age / 3600, unit: "hours", target: rpo / 3600, acceptable: rpoCompliance),
                    ProbeMetric(name: "rpo_hours", value: rpo / 3600, unit: "hours"),
                    ProbeMetric(name: "last_success", value: success ? 1 : 0, target: 1, acceptable: success)
                ],
                issues: issues
            )
        }
    }

    /// Creates a probe for SC-12 key management.
    public static func keyManagementProbe(
        keyChecker: @escaping @Sendable () async -> (totalKeys: Int, expiredKeys: Int, nearExpiry: Int, rotationsDue: Int)
    ) -> ControlProbe {
        ControlProbe(
            probeId: "probe.sc12.key_management",
            controlIds: ["SC-12"],
            name: "Key Management",
            description: "Monitors cryptographic key lifecycle and rotation",
            frequency: .daily,
            tags: ["crypto", "keys"]
        ) {
            let (total, expired, nearExpiry, rotationsDue) = await keyChecker()

            let hasExpired = expired > 0
            let score = hasExpired ? 0.3 : (rotationsDue > 0 ? 0.7 : 1.0)

            var issues: [ProbeIssue] = []
            if hasExpired {
                issues.append(ProbeIssue(
                    severity: .critical,
                    description: "\(expired) cryptographic keys have expired",
                    remediation: "Rotate expired keys immediately"
                ))
            }
            if rotationsDue > 0 {
                issues.append(ProbeIssue(
                    severity: .medium,
                    description: "\(rotationsDue) keys due for rotation",
                    remediation: "Schedule key rotation within policy window"
                ))
            }
            if nearExpiry > 0 {
                issues.append(ProbeIssue(
                    severity: .low,
                    description: "\(nearExpiry) keys approaching expiry",
                    remediation: "Plan for upcoming key rotations"
                ))
            }

            let status: ProbeStatus = hasExpired ? .failing : (rotationsDue > 0 ? .degraded : .healthy)

            return ProbeResult(
                probeId: "probe.sc12.key_management",
                score: score,
                status: status,
                summary: "Managing \(total) keys, \(expired) expired, \(rotationsDue) due for rotation",
                metrics: [
                    ProbeMetric(name: "total_keys", value: Double(total)),
                    ProbeMetric(name: "expired_keys", value: Double(expired), target: 0, acceptable: expired == 0),
                    ProbeMetric(name: "near_expiry", value: Double(nearExpiry)),
                    ProbeMetric(name: "rotations_due", value: Double(rotationsDue), target: 0, acceptable: rotationsDue == 0)
                ],
                issues: issues
            )
        }
    }

    /// Creates a probe for SI-4 system monitoring.
    public static func systemMonitoringProbe(
        monitoringChecker: @escaping @Sendable () async -> (eventsLast24h: Int, alertsLast24h: Int, unresolvedAlerts: Int, monitoringGaps: Int)
    ) -> ControlProbe {
        ControlProbe(
            probeId: "probe.si4.monitoring",
            controlIds: ["SI-4"],
            name: "System Monitoring",
            description: "Verifies system monitoring is active and responsive",
            frequency: .fifteenMinutes,
            tags: ["monitoring", "security"]
        ) {
            let (events, alerts, unresolved, gaps) = await monitoringChecker()

            let hasGaps = gaps > 0
            let score = hasGaps ? 0.5 : (unresolved > 10 ? 0.7 : 1.0)

            var issues: [ProbeIssue] = []
            if hasGaps {
                issues.append(ProbeIssue(
                    severity: .high,
                    description: "Monitoring gaps detected in \(gaps) areas",
                    remediation: "Review monitoring configuration and ensure all critical systems are covered"
                ))
            }
            if unresolved > 10 {
                issues.append(ProbeIssue(
                    severity: .medium,
                    description: "\(unresolved) unresolved alerts require attention",
                    remediation: "Triage and address outstanding alerts"
                ))
            }

            let status: ProbeStatus = hasGaps ? .failing : (unresolved > 10 ? .degraded : .healthy)

            return ProbeResult(
                probeId: "probe.si4.monitoring",
                score: score,
                status: status,
                summary: "\(events) events, \(alerts) alerts in last 24h, \(unresolved) unresolved",
                metrics: [
                    ProbeMetric(name: "events_24h", value: Double(events)),
                    ProbeMetric(name: "alerts_24h", value: Double(alerts)),
                    ProbeMetric(name: "unresolved_alerts", value: Double(unresolved), target: 0, acceptable: unresolved <= 10),
                    ProbeMetric(name: "monitoring_gaps", value: Double(gaps), target: 0, acceptable: gaps == 0)
                ],
                issues: issues
            )
        }
    }
}

// MARK: - Accessibility Probes

/// Factory for creating accessibility compliance probes.
public enum AccessibilityProbes {

    /// Creates a probe for WCAG color contrast.
    public static func colorContrastProbe(
        contrastChecker: @escaping @Sendable () async -> (elementsChecked: Int, failures: Int, avgContrast: Double)
    ) -> ControlProbe {
        ControlProbe(
            probeId: "probe.wcag.contrast",
            controlIds: ["1.4.3"],
            frameworkId: "WCAG-2.1",
            name: "Color Contrast",
            description: "Checks text contrast ratios meet WCAG 2.1 AA requirements",
            frequency: .daily,
            tags: ["accessibility", "wcag", "perceivable"]
        ) {
            let (checked, failures, avg) = await contrastChecker()

            let failureRatio = checked > 0 ? Double(failures) / Double(checked) : 0
            let score = 1.0 - failureRatio

            var issues: [ProbeIssue] = []
            if failures > 0 {
                issues.append(ProbeIssue(
                    severity: failures > 5 ? .high : .medium,
                    description: "\(failures) elements fail contrast requirements",
                    remediation: "Adjust colors to achieve minimum 4.5:1 contrast ratio"
                ))
            }

            let status: ProbeStatus = failures == 0 ? .healthy : (failureRatio < 0.1 ? .degraded : .failing)

            return ProbeResult(
                probeId: "probe.wcag.contrast",
                score: score,
                status: status,
                summary: "\(checked) elements checked, \(failures) failures, avg contrast \(String(format: "%.1f", avg)):1",
                metrics: [
                    ProbeMetric(name: "elements_checked", value: Double(checked)),
                    ProbeMetric(name: "failures", value: Double(failures), target: 0, acceptable: failures == 0),
                    ProbeMetric(name: "avg_contrast", value: avg, target: 4.5, acceptable: avg >= 4.5)
                ],
                issues: issues
            )
        }
    }

    /// Creates a probe for keyboard accessibility.
    public static func keyboardAccessibilityProbe(
        keyboardChecker: @escaping @Sendable () async -> (interactiveElements: Int, keyboardAccessible: Int, focusTraps: Int)
    ) -> ControlProbe {
        ControlProbe(
            probeId: "probe.wcag.keyboard",
            controlIds: ["2.1.1", "2.1.2"],
            frameworkId: "WCAG-2.1",
            name: "Keyboard Accessibility",
            description: "Verifies all interactive elements are keyboard accessible without traps",
            frequency: .daily,
            tags: ["accessibility", "wcag", "operable"]
        ) {
            let (total, accessible, traps) = await keyboardChecker()

            let accessibilityRatio = total > 0 ? Double(accessible) / Double(total) : 1.0
            let hasTrap = traps > 0
            let score = hasTrap ? 0 : accessibilityRatio

            var issues: [ProbeIssue] = []
            if hasTrap {
                issues.append(ProbeIssue(
                    severity: .critical,
                    description: "\(traps) keyboard traps detected",
                    remediation: "Ensure all focusable elements allow keyboard navigation away"
                ))
            }
            if accessible < total {
                issues.append(ProbeIssue(
                    severity: .high,
                    description: "\(total - accessible) interactive elements not keyboard accessible",
                    remediation: "Add keyboard event handlers to all interactive elements"
                ))
            }

            let status: ProbeStatus = hasTrap ? .failing : (accessibilityRatio >= 1.0 ? .healthy : .degraded)

            return ProbeResult(
                probeId: "probe.wcag.keyboard",
                score: score,
                status: status,
                summary: "\(accessible)/\(total) elements keyboard accessible, \(traps) traps",
                metrics: [
                    ProbeMetric(name: "interactive_elements", value: Double(total)),
                    ProbeMetric(name: "keyboard_accessible", value: Double(accessible), target: Double(total), acceptable: accessible == total),
                    ProbeMetric(name: "focus_traps", value: Double(traps), target: 0, acceptable: traps == 0)
                ],
                issues: issues
            )
        }
    }
}
