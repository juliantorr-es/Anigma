//
//  DoctrineGuardsCompat.swift
//  HarmoniaModule
//
//  Compact compatibility layer for doctrine guards.
//

import Foundation
import HarmoniaCore
import AnigmaPrimitives
import AnigmaCore
import DoctrineCore
import SecurityEventsManager
@preconcurrency import Foundation

private func compatSecurityEventSeverity(for doctrineSeverity: DoctrineSeverity) -> SecurityEventSeverity {
    switch doctrineSeverity {
    case .critical:
        return .critical
    case .error:
        return .high
    case .warning:
        return .medium
    default:
        return .low
    }
}

public struct DoctrineGuardResult: Sendable, Codable {
    public let allowed: Bool
    public let violations: [DoctrineViolation]
    public let warnings: [String]
    public let requiredApprovals: [DoctrineDomain]

    public init(
        allowed: Bool,
        violations: [DoctrineViolation] = [],
        warnings: [String] = [],
        requiredApprovals: [DoctrineDomain] = []
    ) {
        self.allowed = allowed
        self.violations = violations
        self.warnings = warnings
        self.requiredApprovals = requiredApprovals
    }

    public static let allowed = DoctrineGuardResult(allowed: true)
    public static let blocked = DoctrineGuardResult(allowed: false)
}

public struct ComplianceProfile: OptionSet, Sendable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let gdpr = ComplianceProfile(rawValue: 1 << 0)
    public static let ccpa = ComplianceProfile(rawValue: 1 << 1)
    public static let accessibility = ComplianceProfile(rawValue: 1 << 2)
    public static let dataRetention = ComplianceProfile(rawValue: 1 << 3)
    public static let auditTrail = ComplianceProfile(rawValue: 1 << 4)
    public static let licensing = ComplianceProfile(rawValue: 1 << 5)

    public static let `default`: ComplianceProfile = [.accessibility, .dataRetention, .auditTrail]
    public static let eu: ComplianceProfile = [.gdpr, .accessibility, .dataRetention, .auditTrail]
    public static let california: ComplianceProfile = [.ccpa, .accessibility, .dataRetention, .auditTrail]
    public static let full: ComplianceProfile = [.gdpr, .ccpa, .accessibility, .dataRetention, .auditTrail, .licensing]
}

private protocol CompatDoctrineGuarding: Actor {
    var violationStore: DoctrineViolationStore { get }
    var scoutRegistry: DoctrinalScoutRegistry { get }
    func relevantDomains(for filePath: String, proposedChange: String) -> [DoctrineDomain]
    func extraWarnings(filePath: String, proposedChange: String, context: [String: Sendable]) -> [String]
}

extension CompatDoctrineGuarding {
    fileprivate func evaluate(
        filePath: String,
        proposedChange: String,
        context: [String: Sendable]
    ) async throws -> DoctrineGuardResult {
        let domains = relevantDomains(for: filePath, proposedChange: proposedChange)
        guard !domains.isEmpty else { return .allowed }

        let tempFilePath = createTempFile(content: proposedChange, filePath: filePath)
        defer { try? FileManager.default.removeItem(atPath: tempFilePath) }

        let knownViolations = try violationStore.getViolations(inFile: filePath)
        let scannedViolations = try await scoutRegistry.scanFile(at: tempFilePath)

        let existing = filterViolations(knownViolations, allowedDomains: domains)
        let fresh = filterViolations(scannedViolations, allowedDomains: domains)
        let critical = fresh.filter { $0.severity == .critical }
        let approvals = domains
        var warnings = extraWarnings(filePath: filePath, proposedChange: proposedChange, context: context)

        if !existing.isEmpty {
            warnings.append("File has \(existing.count) unresolved doctrine violations")
        }
        if !critical.isEmpty {
            warnings.append("Critical doctrine violations found")
        } else if !fresh.isEmpty {
            warnings.append("\(fresh.count) doctrine violations require review")
        }

        return DoctrineGuardResult(
            allowed: critical.isEmpty,
            violations: critical.isEmpty ? fresh : critical,
            warnings: warnings,
            requiredApprovals: fresh.isEmpty ? [] : approvals
        )
    }

    private func filterViolations(_ violations: [DoctrineViolation], allowedDomains: [DoctrineDomain]) -> [DoctrineViolation] {
        violations.filter { violation in
            guard let rule = DoctrineRegistry.rule(withId: violation.ruleId) else {
                return false
            }
            return allowedDomains.contains(rule.domain)
        }
    }

    private func createTempFile(content: String, filePath: String) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let fileExtension = filePath.hasSuffix(".py") ? "py" : "swift"
        let tempFile = tempDir.appendingPathComponent("doctrine_guard_\(UUID().uuidString).\(fileExtension)")
        try? content.write(to: tempFile, atomically: true, encoding: .utf8)
        return tempFile.path
    }
}

public actor CSDoctrineGuard: CompatDoctrineGuarding {
    fileprivate let violationStore: DoctrineViolationStore
    fileprivate let scoutRegistry: DoctrinalScoutRegistry
    private let securityEvents: SecurityEventsManager

    public init(
        violationStore: DoctrineViolationStore = try! DoctrineViolationStore(),
        scoutRegistry: DoctrinalScoutRegistry = DoctrinalScoutRegistry(),
        securityEvents: SecurityEventsManager
    ) {
        self.violationStore = violationStore
        self.scoutRegistry = scoutRegistry
        self.securityEvents = securityEvents
    }

    public func check(filePath: String, proposedChange: String, context: [String: Sendable] = [:]) async throws -> DoctrineGuardResult {
        let result = try await evaluate(filePath: filePath, proposedChange: proposedChange, context: context)
        if let firstCritical = result.violations.first(where: { $0.severity == .critical }) {
            try? await securityEvents.recordEvent(
                type: .doctrineViolation,
                severity: compatSecurityEventSeverity(for: firstCritical.severity),
                engineId: "cs-doctrine-guard",
                operation: "file_scan",
                details: SecurityEventDetails(
                    engineId: "cs-doctrine-guard",
                    doctrineRule: firstCritical.ruleId,
                    reason: firstCritical.context ?? firstCritical.message,
                    blockedAction: "file_scan",
                    metadata: ["ruleId": firstCritical.ruleId]
                )
            )
        }
        return result
    }

    fileprivate func relevantDomains(for filePath: String, proposedChange: String) -> [DoctrineDomain] {
        [.computerScience]
    }

    fileprivate func extraWarnings(filePath: String, proposedChange: String, context: [String: Sendable]) -> [String] {
        var warnings: [String] = []
        if proposedChange.localizedCaseInsensitiveContains("quadratic") || proposedChange.contains("O(n²)") {
            warnings.append("Proposed change may introduce quadratic complexity")
        }
        if let concurrencyContext = context["concurrency"] as? [String: Sendable],
           let introducesActors = concurrencyContext["introduces_actors"] as? Bool,
           introducesActors {
            warnings.append("Proposed change introduces actors and should receive concurrency review")
        }
        return warnings
    }
}

public actor StatisticsDoctrineGuard: CompatDoctrineGuarding {
    fileprivate let violationStore: DoctrineViolationStore
    fileprivate let scoutRegistry: DoctrinalScoutRegistry

    public init(
        violationStore: DoctrineViolationStore = try! DoctrineViolationStore(),
        scoutRegistry: DoctrinalScoutRegistry = DoctrinalScoutRegistry(),
        securityEvents _: SecurityEventsManager? = nil
    ) {
        self.violationStore = violationStore
        self.scoutRegistry = scoutRegistry
    }

    public func check(filePath: String, proposedChange: String, context: [String: Sendable] = [:]) async throws -> DoctrineGuardResult {
        try await evaluate(filePath: filePath, proposedChange: proposedChange, context: context)
    }

    fileprivate func relevantDomains(for filePath: String, proposedChange: String) -> [DoctrineDomain] {
        let normalized = filePath.lowercased() + " " + proposedChange.lowercased()
        return normalized.contains("statistics") || normalized.contains("/stats/") ? [.statistics] : []
    }

    fileprivate func extraWarnings(filePath: String, proposedChange: String, context: [String: Sendable]) -> [String] {
        var warnings: [String] = []
        let normalized = proposedChange.lowercased()
        if (normalized.contains("accuracy") || normalized.contains("precision") || normalized.contains("recall") || normalized.contains("f1")) &&
           !normalized.contains("confidence") && !normalized.contains("interval") && !normalized.contains("std") {
            warnings.append("Statistical metrics are missing uncertainty estimates")
        }
        return warnings
    }
}

public actor LawComplianceDoctrineGuard: CompatDoctrineGuarding {
    fileprivate let violationStore: DoctrineViolationStore
    fileprivate let scoutRegistry: DoctrinalScoutRegistry
    private let activeProfiles: [ComplianceProfile]

    public init(
        violationStore: DoctrineViolationStore = try! DoctrineViolationStore(),
        scoutRegistry: DoctrinalScoutRegistry = DoctrinalScoutRegistry(),
        activeProfiles: [ComplianceProfile] = [.default]
    ) {
        self.violationStore = violationStore
        self.scoutRegistry = scoutRegistry
        self.activeProfiles = activeProfiles
    }

    public func check(filePath: String, proposedChange: String, context: [String: Sendable] = [:]) async throws -> DoctrineGuardResult {
        try await evaluate(filePath: filePath, proposedChange: proposedChange, context: context)
    }

    fileprivate func relevantDomains(for filePath: String, proposedChange: String) -> [DoctrineDomain] {
        [.lawCompliance, .privacy, .accessibility]
    }

    fileprivate func extraWarnings(filePath: String, proposedChange: String, context: [String: Sendable]) -> [String] {
        var warnings: [String] = []
        let normalized = proposedChange.lowercased()
        if activeProfiles.contains(.gdpr) && (normalized.contains("personal") || normalized.contains("pii")) && !normalized.contains("consent") {
            warnings.append("Personal data changes may require GDPR review")
        }
        if activeProfiles.contains(.accessibility) && (filePath.contains("UI") || filePath.contains("View") || filePath.contains("Component")) {
            warnings.append("UI changes may require accessibility review")
        }
        if activeProfiles.contains(.dataRetention) && (normalized.contains("store") || normalized.contains("persist") || normalized.contains("cache")) {
            warnings.append("Data storage changes may have retention requirements")
        }
        return warnings
    }
}

public actor DoctrineGuardRegistry {
    private let csGuard: CSDoctrineGuard
    private let statsGuard: StatisticsDoctrineGuard
    private let lawGuard: LawComplianceDoctrineGuard

    public init(
        csGuard: CSDoctrineGuard,
        statsGuard: StatisticsDoctrineGuard,
        lawGuard: LawComplianceDoctrineGuard
    ) {
        self.csGuard = csGuard
        self.statsGuard = statsGuard
        self.lawGuard = lawGuard
    }

    public func checkAll(filePath: String, proposedChange: String, context: [String: Sendable] = [:]) async throws -> DoctrineGuardResult {
        let cs = try await csGuard.check(filePath: filePath, proposedChange: proposedChange, context: context)
        let stats = try await statsGuard.check(filePath: filePath, proposedChange: proposedChange, context: context)
        let law = try await lawGuard.check(filePath: filePath, proposedChange: proposedChange, context: context)

        return DoctrineGuardResult(
            allowed: cs.allowed && stats.allowed && law.allowed,
            violations: cs.violations + stats.violations + law.violations,
            warnings: cs.warnings + stats.warnings + law.warnings,
            requiredApprovals: Array(Set(cs.requiredApprovals + stats.requiredApprovals + law.requiredApprovals))
        )
    }

    public func getComplianceSummary(filePath: String) async throws -> [DoctrineDomain: Bool] {
        let violations = try DoctrineViolationStore().getViolations(inFile: filePath)
        var summary: [DoctrineDomain: Bool] = [:]

        for domain in DoctrineDomain.allCases {
            let failing = violations.contains { violation in
                guard let rule = DoctrineRegistry.rule(withId: violation.ruleId) else { return false }
                return rule.domain == domain && (violation.severity == .critical || violation.severity == .error)
            }
            summary[domain] = !failing
        }

        return summary
    }
}
