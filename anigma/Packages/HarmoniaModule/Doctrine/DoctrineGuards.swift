//
//  DoctrineGuards.swift
//  HarmoniaModule
//
//  Guards that check doctrine compliance before allowing changes.
//  Integration point for migration engines and AST rules.
//

import AnigmaCore
import DoctrineCore
@preconcurrency import Foundation
import SecurityEventsManager

private func securityEventSeverity(for doctrineSeverity: DoctrineSeverity) -> SecurityEventSeverity {
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

private func isStatisticsFile(filePath: String, proposedChange: String) -> Bool {
    let normalizedPath = filePath.lowercased()
    if normalizedPath.contains("/statistics") || normalizedPath.contains("/stats/") {
        return true
    }

    let normalizedChange = proposedChange.lowercased()
    return normalizedChange.contains("statistics")
}

/// Result of a doctrine guard check.
public struct DoctrineGuardResult: Sendable, Codable {
    public let allowed: Bool
    public let violations: [DoctrineCore.DoctrineViolation]  // Use fully qualified name
    public let warnings: [String]
    public let requiredApprovals: [DoctrineCore.DoctrineDomain]  // Use fully qualified name

    public init(
        allowed: Bool,
        violations: [DoctrineCore.DoctrineViolation] = [],
        warnings: [String] = [],
        requiredApprovals: [DoctrineCore.DoctrineDomain] = []
    ) {
        self.allowed = allowed
        self.violations = violations
        self.warnings = warnings
        self.requiredApprovals = requiredApprovals
    }

    public static let allowed = DoctrineGuardResult(allowed: true)
    public static let blocked = DoctrineGuardResult(allowed: false)
}

/// Guard that checks computer science doctrine compliance.
public actor CSDoctrineGuard {
    private let violationStore: DoctrineCore.DoctrineViolationStore  // Use fully qualified name
    private let scoutRegistry: DoctrinalScoutRegistry
    private let securityEvents: SecurityEventsManager

    public init(
        violationStore: DoctrineCore.DoctrineViolationStore =
            try! DoctrineCore.DoctrineViolationStore(),  // Use fully qualified name
        scoutRegistry: DoctrinalScoutRegistry = DoctrinalScoutRegistry(),
        securityEvents: SecurityEventsManager = SecurityEventsManager()
    ) {
        self.violationStore = violationStore
        self.scoutRegistry = scoutRegistry
        self.securityEvents = securityEvents
    }

    /// Check if a proposed change complies with CS doctrine.
    public func check(
        filePath: String,
        proposedChange: String,
        context: [String: Sendable] = [:]
    ) async throws -> DoctrineGuardResult {
        var violations: [DoctrineCore.DoctrineViolation] = []
        var warnings: [String] = []
        var requiredApprovals: [DoctrineCore.DoctrineDomain] = []

        // 1. Check existing violations in the file
        let existingViolations = try violationStore.getViolations(inFile: filePath)
        let csViolations = existingViolations.filter {
            if let rule = DoctrineCore.DoctrineRegistry.rule(withId: $0.ruleId) {  // Use fully qualified name
                return rule.domain == DoctrineCore.DoctrineDomain.computerScience  // Use fully qualified name
            }
            return false
        }

        if !csViolations.isEmpty {
            warnings.append("File has \(csViolations.count) unresolved CS doctrine violations")
            requiredApprovals.append(DoctrineCore.DoctrineDomain.computerScience)  // Use fully qualified name
        }

        // 2. Scan the proposed change for new violations
        let tempFilePath = createTempFile(content: proposedChange, filePath: filePath)
        defer { try? FileManager.default.removeItem(atPath: tempFilePath) }

        let newViolations = try await scoutRegistry.scanFile(at: tempFilePath)
        let newCSViolations = newViolations.filter {
            if let rule = DoctrineCore.DoctrineRegistry.rule(withId: $0.ruleId) {  // Use fully qualified name
                return rule.domain == DoctrineCore.DoctrineDomain.computerScience  // Use fully qualified name
            }
            return false
        }

        // 3. Check for critical violations
        let criticalViolations = newCSViolations.filter {
            $0.severity == DoctrineCore.DoctrineSeverity.critical
        }  // Use fully qualified name
        if !criticalViolations.isEmpty {
            violations.append(contentsOf: criticalViolations)

            // Log security event for each critical violation
            for violation in criticalViolations {
                // Assuming SecurityEventsManager.logDoctrineViolation takes DoctrineCore.DoctrineViolation
                await securityEvents.logDoctrineViolation(
                    engineId: "cs-doctrine-guard",
                    operation: "file_scan",
                    ruleId: violation.ruleId,
                    reason: violation.context ?? "No context",  // Use message for context
                    severity: securityEventSeverity(for: violation.severity)
                )
            }

            return DoctrineGuardResult(
                allowed: false,
                violations: violations,
                warnings: warnings + ["Critical CS doctrine violations found"],
                requiredApprovals: requiredApprovals
            )
        }

        // 4. Check for error violations (may require approval)
        let errorViolations = newCSViolations.filter {
            $0.severity == DoctrineCore.DoctrineSeverity.error
        }  // Use fully qualified name
        if !errorViolations.isEmpty {
            violations.append(contentsOf: errorViolations)
            warnings.append("\(errorViolations.count) CS doctrine errors found")
            requiredApprovals.append(DoctrineCore.DoctrineDomain.computerScience)  // Use fully qualified name

            // Log security event for error violations
            for violation in errorViolations {
                await securityEvents.logDoctrineViolation(
                    engineId: "cs-doctrine-guard",
                    operation: "file_scan",
                    ruleId: violation.ruleId,
                    reason: "\(violation.context ?? "No context") (requires approval)",
                    severity: securityEventSeverity(for: violation.severity)
                )
            }
        }

        // 5. Check for warning violations
        let warningViolations = newCSViolations.filter {
            $0.severity == DoctrineCore.DoctrineSeverity.warning
        }  // Use fully qualified name
        if !warningViolations.isEmpty {
            warnings.append("\(warningViolations.count) CS doctrine warnings found")
        }

        // 6. Check complexity constraints from context
        if let complexityContext = context["complexity"] as? [String: Sendable] {
            if let maxComplexity = complexityContext["max"] as? String {
                if maxComplexity.contains("O(n²)") || maxComplexity.contains("quadratic") {
                    warnings.append("Proposed change introduces quadratic complexity")
                    requiredApprovals.append(DoctrineCore.DoctrineDomain.computerScience)  // Use fully qualified name
                }
            }
        }

        // 7. Check concurrency constraints
        if let concurrencyContext = context["concurrency"] as? [String: Sendable] {
            if let introducesActors = concurrencyContext["introduces_actors"] as? Bool,
                introducesActors {
                warnings.append(
                    "Proposed change introduces new actors - requires concurrency review")
                requiredApprovals.append(DoctrineCore.DoctrineDomain.computerScience)  // Use fully qualified name
            }
        }

        return DoctrineGuardResult(
            allowed: violations.isEmpty || requiredApprovals.isEmpty,
            violations: violations,
            warnings: warnings,
            requiredApprovals: requiredApprovals
        )
    }

    private func createTempFile(content: String, filePath: String? = nil) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let fileExtension = (filePath?.hasSuffix(".py") ?? false) ? "py" : "swift"
        let tempFile = tempDir.appendingPathComponent(
            "doctrine_check_\(UUID().uuidString).\(fileExtension)")

        try? content.write(to: tempFile, atomically: true, encoding: .utf8)
        return tempFile.path
    }
}

/// Guard that checks statistics doctrine compliance.
public actor StatisticsDoctrineGuard {
    private let violationStore: DoctrineCore.DoctrineViolationStore  // Use fully qualified name
    private let scoutRegistry: DoctrinalScoutRegistry
    private let securityEvents: SecurityEventsManager

    public init(
        violationStore: DoctrineCore.DoctrineViolationStore =
            try! DoctrineCore.DoctrineViolationStore(),  // Use fully qualified name
        scoutRegistry: DoctrinalScoutRegistry = DoctrinalScoutRegistry(),
        securityEvents: SecurityEventsManager = SecurityEventsManager()
    ) {
        self.violationStore = violationStore
        self.scoutRegistry = scoutRegistry
        self.securityEvents = securityEvents
    }

    /// Check if a proposed change complies with statistics doctrine.
    public func check(
        filePath: String,
        proposedChange: String,
        context: [String: Sendable] = [:]
    ) async throws -> DoctrineGuardResult {
        var violations: [DoctrineCore.DoctrineViolation] = []
        var warnings: [String] = []
        var requiredApprovals: [DoctrineCore.DoctrineDomain] = []

        // 1. Check if this is a statistics-related file
        if !isStatisticsFile(filePath: filePath, proposedChange: proposedChange) {
            return DoctrineGuardResult.allowed  // Use fully qualified name
        }

        // 2. Check existing violations
        let existingViolations = try violationStore.getViolations(inFile: filePath)
        let statsViolations = existingViolations.filter {
            if let rule = DoctrineCore.DoctrineRegistry.rule(withId: $0.ruleId) {  // Use fully qualified name
                return rule.domain == DoctrineCore.DoctrineDomain.statistics  // Use fully qualified name
            }
            return false
        }

        if !statsViolations.isEmpty {
            warnings.append(
                "File has \(statsViolations.count) unresolved statistics doctrine violations")
            requiredApprovals.append(DoctrineCore.DoctrineDomain.statistics)  // Use fully qualified name
        }

        // 3. Scan the proposed change
        let tempFilePath = createTempFile(content: proposedChange, filePath: filePath)
        defer { try? FileManager.default.removeItem(atPath: tempFilePath) }

        let newViolations = try await scoutRegistry.scanFile(at: tempFilePath)
        let newStatsViolations = newViolations.filter {
            if let rule = DoctrineCore.DoctrineRegistry.rule(withId: $0.ruleId) {  // Use fully qualified name
                return rule.domain == DoctrineCore.DoctrineDomain.statistics  // Use fully qualified name
            }
            return false
        }

        // 4. Check for critical violations (p-hacking, data leakage)
        let criticalViolations = newStatsViolations.filter {
            $0.severity == DoctrineCore.DoctrineSeverity.critical
        }  // Use fully qualified name
        if !criticalViolations.isEmpty {
            violations.append(contentsOf: criticalViolations)
            return DoctrineGuardResult(
                allowed: false,
                violations: violations,
                warnings: warnings + ["Critical statistics doctrine violations found"],
                requiredApprovals: requiredApprovals
            )
        }

        // 5. Check for error violations
        let errorViolations = newStatsViolations.filter {
            $0.severity == DoctrineCore.DoctrineSeverity.error
        }  // Use fully qualified name
        if !errorViolations.isEmpty {
            violations.append(contentsOf: errorViolations)
            warnings.append("\(errorViolations.count) statistics doctrine errors found")
            requiredApprovals.append(DoctrineCore.DoctrineDomain.statistics)  // Use fully qualified name
        }

        // 6. Check context for statistical experiments
        if let experimentContext = context["experiment"] as? [String: Sendable] {
            if let hasHypothesis = experimentContext["has_hypothesis"] as? Bool, !hasHypothesis {
                let violation = DoctrineCore.DoctrineViolation(  // Use fully qualified name and add message
                    ruleId: "stats.design.undeclared_hypothesis",
                    severity: DoctrineCore.DoctrineSeverity.error,  // Use fully qualified name
                    message: "Statistical experiment without declared hypothesis",
                    filePath: filePath,
                    context: "Statistical experiment without declared hypothesis"
                )
                violations.append(violation)
                requiredApprovals.append(DoctrineCore.DoctrineDomain.statistics)  // Use fully qualified name
            }

            if let usesSingleSplit = experimentContext["uses_single_split"] as? Bool,
                usesSingleSplit {
                warnings.append("Experiment uses single train/test split")
                requiredApprovals.append(DoctrineCore.DoctrineDomain.statistics)  // Use fully qualified name
            }
        }

        // 7. Check for missing uncertainty estimates
        if proposedChange.contains("accuracy") || proposedChange.contains("precision")
            || proposedChange.contains("recall") || proposedChange.contains("f1") {
            if !proposedChange.contains("confidence") && !proposedChange.contains("interval")
                && !proposedChange.contains("std") && !proposedChange.contains("var") {
                warnings.append("Statistical metrics without uncertainty estimates")
                requiredApprovals.append(DoctrineCore.DoctrineDomain.statistics)  // Use fully qualified name
            }
        }

        return DoctrineGuardResult(
            allowed: violations.isEmpty || requiredApprovals.isEmpty,
            violations: violations,
            warnings: warnings,
            requiredApprovals: requiredApprovals
        )
    }

    private func createTempFile(content: String, filePath: String? = nil) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let fileExtension = (filePath?.hasSuffix(".py") ?? false) ? "py" : "swift"
        let tempFile = tempDir.appendingPathComponent(
            "stats_check_\(UUID().uuidString).\(fileExtension)")

        try? content.write(to: tempFile, atomically: true, encoding: .utf8)
        return tempFile.path
    }
}

/// Guard that checks law/compliance doctrine compliance.
public actor LawComplianceDoctrineGuard {
    private let violationStore: DoctrineCore.DoctrineViolationStore  // Use fully qualified name
    private let scoutRegistry: DoctrinalScoutRegistry
    private let activeProfiles: [ComplianceProfile]

    public init(
        violationStore: DoctrineCore.DoctrineViolationStore =
            try! DoctrineCore.DoctrineViolationStore(),  // Use fully qualified name
        scoutRegistry: DoctrinalScoutRegistry = DoctrinalScoutRegistry(),
        activeProfiles: [ComplianceProfile] = [.default]
    ) {
        self.violationStore = violationStore
        self.scoutRegistry = scoutRegistry
        self.activeProfiles = activeProfiles
    }

    /// Check if a proposed change complies with law/compliance doctrine.
    public func check(
        filePath: String,
        proposedChange: String,
        context: [String: Sendable] = [:]
    ) async throws -> DoctrineGuardResult {
        var violations: [DoctrineCore.DoctrineViolation] = []
        var warnings: [String] = []
        var requiredApprovals: [DoctrineCore.DoctrineDomain] = []

        // 1. Check existing violations
        let existingViolations = try violationStore.getViolations(inFile: filePath)
        let lawViolations = existingViolations.filter {
            if let rule = DoctrineCore.DoctrineRegistry.rule(withId: $0.ruleId) {  // Use fully qualified name
                return rule.domain == DoctrineCore.DoctrineDomain.lawCompliance
                    || rule.domain == DoctrineCore.DoctrineDomain.privacy
                    || rule.domain == DoctrineCore.DoctrineDomain.accessibility  // Use fully qualified name
            }
            return false
        }

        if !lawViolations.isEmpty {
            warnings.append("File has \(lawViolations.count) unresolved compliance violations")
            requiredApprovals.append(contentsOf: [
                DoctrineCore.DoctrineDomain.lawCompliance, DoctrineCore.DoctrineDomain.privacy,
                DoctrineCore.DoctrineDomain.accessibility
            ])  // Use fully qualified name
        }

        // 2. Scan the proposed change
        let tempFilePath = createTempFile(content: proposedChange, filePath: filePath)
        defer { try? FileManager.default.removeItem(atPath: tempFilePath) }

        let newViolations = try await scoutRegistry.scanFile(at: tempFilePath)
        let newLawViolations = newViolations.filter {
            if let rule = DoctrineCore.DoctrineRegistry.rule(withId: $0.ruleId) {  // Use fully qualified name
                return rule.domain == DoctrineCore.DoctrineDomain.lawCompliance
                    || rule.domain == DoctrineCore.DoctrineDomain.privacy
                    || rule.domain == DoctrineCore.DoctrineDomain.accessibility  // Use fully qualified name
            }
            return false
        }

        // 3. Check for critical violations
        let criticalViolations = newLawViolations.filter {
            $0.severity == DoctrineCore.DoctrineSeverity.critical
        }  // Use fully qualified name
        if !criticalViolations.isEmpty {
            violations.append(contentsOf: criticalViolations)
            return DoctrineGuardResult(
                allowed: false,
                violations: violations,
                warnings: warnings + ["Critical compliance violations found"],
                requiredApprovals: requiredApprovals
            )
        }

        // 4. Check for error violations
        let errorViolations = newLawViolations.filter {
            $0.severity == DoctrineCore.DoctrineSeverity.error
        }  // Use fully qualified name
        if !errorViolations.isEmpty {
            violations.append(contentsOf: errorViolations)
            warnings.append("\(errorViolations.count) compliance errors found")
            requiredApprovals.append(contentsOf: [
                DoctrineCore.DoctrineDomain.lawCompliance, DoctrineCore.DoctrineDomain.privacy,
                DoctrineCore.DoctrineDomain.accessibility
            ])  // Use fully qualified name
        }

        // 5. Check against active compliance profiles
        for profile in activeProfiles {
            let profileCheck = try await checkAgainstProfile(
                profile: profile,
                filePath: filePath,
                proposedChange: proposedChange,
                context: context
            )

            if !profileCheck.allowed {
                violations.append(contentsOf: profileCheck.violations)
                warnings.append(contentsOf: profileCheck.warnings)
                requiredApprovals.append(contentsOf: profileCheck.requiredApprovals)
            }
        }

        // 6. Check for privacy violations
        if proposedChange.contains("collect") || proposedChange.contains("store")
            || proposedChange.contains("process") || proposedChange.contains("share") {
            if !proposedChange.contains("consent") && !proposedChange.contains("Consent") {
                warnings.append("Data processing without explicit consent")
                requiredApprovals.append(DoctrineCore.DoctrineDomain.privacy)  // Use fully qualified name
            }
        }

        // 7. Check for accessibility violations
        if proposedChange.contains("timeout") || proposedChange.contains("Timeout") {
            if let timeout = extractTimeout(from: proposedChange), timeout < 5.0 {
                warnings.append("Timeout too short for accessibility: \(timeout) seconds")
                requiredApprovals.append(DoctrineCore.DoctrineDomain.accessibility)  // Use fully qualified name
            }
        }

        // 8. Check for licensing violations
        if proposedChange.contains("AGPL") || proposedChange.contains("GNU Affero") {
            if filePath.contains("Commercial") || filePath.contains("Pro") {
                let violation = DoctrineCore.DoctrineViolation(  // Use fully qualified name and add message
                    ruleId: "law.licensing.agpl_violation",
                    severity: DoctrineCore.DoctrineSeverity.critical,  // Use fully qualified name
                    message: "AGPL license in commercial module",
                    filePath: filePath,
                    context: "AGPL license in commercial module"
                )
                violations.append(violation)
                return DoctrineGuardResult(
                    allowed: false,
                    violations: violations,
                    warnings: warnings,
                    requiredApprovals: requiredApprovals
                )
            }
        }

        return DoctrineGuardResult(
            allowed: violations.isEmpty || requiredApprovals.isEmpty,
            violations: violations,
            warnings: warnings,
            requiredApprovals: requiredApprovals
        )
    }

    private func checkAgainstProfile(
        profile: ComplianceProfile,
        filePath: String,
        proposedChange: String,
        context: [String: Sendable]
    ) async throws -> DoctrineGuardResult {
        var warnings: [String] = []
        var requiredApprovals: [DoctrineCore.DoctrineDomain] = []

        // Check GDPR compliance
        if profile.contains(.gdpr) {
            if proposedChange.contains("personal") || proposedChange.contains("Personal")
                || proposedChange.contains("PII") || proposedChange.contains("pii") {
                if !proposedChange.contains("consent") && !proposedChange.contains("legal") {
                    warnings.append("Personal data processing may require GDPR compliance review")
                    requiredApprovals.append(DoctrineCore.DoctrineDomain.lawCompliance)  // Use fully qualified name
                }
            }
        }

        // Check accessibility compliance
        if profile.contains(.accessibility) {
            if filePath.contains("UI") || filePath.contains("View")
                || filePath.contains("Component") {
                warnings.append("UI changes may require accessibility review")
                requiredApprovals.append(DoctrineCore.DoctrineDomain.accessibility)  // Use fully qualified name
            }
            // Fix: ComplianceProfile.accessibility is already a value, no need to qualify with DoctrineCore.DoctrineDomain
        }

        // Check data retention
        if profile.contains(.dataRetention) {
            if proposedChange.contains("store") || proposedChange.contains("save")
                || proposedChange.contains("persist") || proposedChange.contains("cache") {
                warnings.append("Data storage may have retention requirements")
                requiredApprovals.append(DoctrineCore.DoctrineDomain.lawCompliance)  // Use fully qualified name
            }
        }

        return DoctrineGuardResult(
            allowed: true,
            violations: [],
            warnings: warnings,
            requiredApprovals: requiredApprovals
        )
    }

    private func extractTimeout(from text: String) -> Double? {
        let pattern = #"timeout\s*[:=]\s*([0-9]+(?:\.[0-9]+)?)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)

        if let match = regex?.firstMatch(
            in: text, options: [], range: NSRange(location: 0, length: text.count)) {
            if let range = Range(match.range(at: 1), in: text) {
                return Double(text[range])
            }
        }

        return nil
    }

    private func createTempFile(content: String, filePath: String? = nil) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("compliance_check_\(UUID().uuidString).txt")

        try? content.write(to: tempFile, atomically: true, encoding: .utf8)
        return tempFile.path
    }
}

/// Compliance profile for legal/regulatory requirements.
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
    public static let california: ComplianceProfile = [
        .ccpa, .accessibility, .dataRetention, .auditTrail
    ]  // Fix: removed redundant DoctrineCore.DoctrineDomain.
    public static let full: ComplianceProfile = [
        .gdpr, .ccpa, .accessibility, .dataRetention, .auditTrail, .licensing
    ]  // Fix: removed redundant DoctrineCore.DoctrineDomain.
}

/// Registry for all doctrine guards.
public actor DoctrineGuardRegistry {
    private let csGuard: CSDoctrineGuard
    private let statsGuard: StatisticsDoctrineGuard
    private let lawGuard: LawComplianceDoctrineGuard

    public init(
        csGuard: CSDoctrineGuard = CSDoctrineGuard(),
        statsGuard: StatisticsDoctrineGuard = StatisticsDoctrineGuard(),
        lawGuard: LawComplianceDoctrineGuard = LawComplianceDoctrineGuard()
    ) {
        self.csGuard = csGuard
        self.statsGuard = statsGuard
        self.lawGuard = lawGuard
    }

    /// Check all doctrine guards for a proposed change.
    public func checkAll(
        filePath: String,
        proposedChange: String,
        context: [String: Sendable] = [:]
    ) async throws -> DoctrineGuardResult {
        var allViolations: [DoctrineCore.DoctrineViolation] = []  // Use fully qualified name
        var allWarnings: [String] = []
        var allRequiredApprovals: [DoctrineCore.DoctrineDomain] = []  // Use fully qualified name

        // Check CS doctrine
        let csResult = try await csGuard.check(
            filePath: filePath,
            proposedChange: proposedChange,
            context: context
        )

        if !csResult.allowed {
            allViolations.append(contentsOf: csResult.violations)
        }
        allWarnings.append(contentsOf: csResult.warnings)
        allRequiredApprovals.append(contentsOf: csResult.requiredApprovals)

        // Check statistics doctrine
        let statsResult = try await statsGuard.check(
            filePath: filePath,
            proposedChange: proposedChange,
            context: context
        )

        if !statsResult.allowed {
            allViolations.append(contentsOf: statsResult.violations)
        }
        allWarnings.append(contentsOf: statsResult.warnings)
        allRequiredApprovals.append(contentsOf: statsResult.requiredApprovals)

        // Check law/compliance doctrine
        let lawResult = try await lawGuard.check(
            filePath: filePath,
            proposedChange: proposedChange,
            context: context
        )

        if !lawResult.allowed {
            allViolations.append(contentsOf: lawResult.violations)
        }
        allWarnings.append(contentsOf: lawResult.warnings)
        allRequiredApprovals.append(contentsOf: lawResult.requiredApprovals)

        // Determine overall result
        let allowed = csResult.allowed && statsResult.allowed && lawResult.allowed

        return DoctrineGuardResult(
            allowed: allowed,
            violations: allViolations,
            warnings: allWarnings,
            requiredApprovals: Array(Set(allRequiredApprovals))  // Remove duplicates
        )
    }

    /// Get a summary of doctrine compliance.
    public func getComplianceSummary(filePath: String) async throws -> [DoctrineCore.DoctrineDomain:
        Bool] {  // Use fully qualified name
        let violations = try DoctrineViolationStore().getViolations(inFile: filePath)  // Use fully qualified name

        var summary: [DoctrineCore.DoctrineDomain: Bool] = [:]  // Use fully qualified name

        for domain in DoctrineCore.DoctrineDomain.allCases {  // Use fully qualified name
            let domainViolations = violations.filter {
                if let rule = DoctrineCore.DoctrineRegistry.rule(withId: $0.ruleId) {  // Use fully qualified name
                    return rule.domain == domain
                }
                return false
            }

            let criticalOrError = domainViolations.filter {
                $0.severity == DoctrineCore.DoctrineSeverity.critical
                    || $0.severity == DoctrineCore.DoctrineSeverity.error  // Use fully qualified name
            }

            summary[domain] = criticalOrError.isEmpty
        }

        return summary
    }
}
