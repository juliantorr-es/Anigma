//
//  ReasoningIntegration.swift
//  AnigmaCore
//
//  Integration layer between the Reasoning Kernel and Anigma domains.
//  Provides high-level APIs for compliance, security, and automation analysis.
//
//  All real data is abstracted before reaching the kernel.
//  All kernel outputs go through governance before affecting state.
//

import Foundation
import ContractsCore

// MARK: - Reasoning Service

/// High-level service for reasoning operations.
/// This is the main entry point for other Anigma modules.
public actor ReasoningService {
    /// The underlying reasoning kernel.
    private let kernel: RecursiveReasoner

    /// State abstractor for anonymization.
    private let abstractor: StateAbstractor

    /// Audit log for recording all operations.
    private var auditLog: (any AuditLogging)?

    /// Compliance control registry for mapping results.
    private var controlRegistry: ControlRegistry?

    /// Automation containment for safety.
    private var containment: AutomationContainment?

    /// Whether the service is enabled.
    private var isEnabled: Bool = true

    /// Total analyses run.
    private var totalAnalyses: Int = 0

    /// Total issues found.
    private var totalIssuesFound: Int = 0

    public init(config: ReasonerConfig = ReasonerConfig()) {
        self.kernel = RecursiveReasoner(config: config)
        self.abstractor = StateAbstractor()
    }

    /// Configures the service with dependencies.
    public func configure(
        auditLog: any AuditLogging,
        controlRegistry: ControlRegistry? = nil,
        containment: AutomationContainment? = nil
    ) async {
        self.auditLog = auditLog
        self.controlRegistry = controlRegistry
        self.containment = containment
        await kernel.setAuditLog(auditLog)
    }

    /// Enables or disables the service.
    public func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }

    // MARK: - Access Control Analysis

    /// Analyzes access control for potential violations.
    public func analyzeAccessControl(
        context: AccessControlAnalysisContext
    ) async throws -> SecurityAnalysisResult {
        guard isEnabled else {
            throw ReasoningError.kernelUnavailable
        }

        await abstractor.reset()

        // Abstract principals
        var abstractPrincipals: [(symbol: String, roles: Set<String>, isDeprovisioned: Bool)] = []
        for principal in context.principals {
            let symbol = await abstractor.anonymize(principal.id, prefix: "P")
            abstractPrincipals.append((symbol, principal.roles, principal.isDeprovisioned))
        }

        // Abstract resources
        var abstractResources: [(symbol: String, sensitivity: String, requiredRoles: Set<String>)] = []
        for resource in context.resources {
            let symbol = await abstractor.anonymize(resource.id, prefix: "R")
            abstractResources.append((symbol, resource.sensitivity.label, resource.requiredRoles))
        }

        // Abstract sessions
        var abstractSessions: [(symbol: String, principalSymbol: String, isValid: Bool, mfaVerified: Bool)] = []
        for session in context.sessions {
            let sessionSymbol = await abstractor.anonymize(session.id, prefix: "S")
            let principalSymbol = await abstractor.anonymize(session.principalId, prefix: "P")
            abstractSessions.append((sessionSymbol, principalSymbol, session.isValid, session.mfaVerified))
        }

        // Build and solve puzzle
        let puzzle = AccessControlPuzzleBuilder.buildUnauthorizedAccessPuzzle(
            principals: abstractPrincipals,
            resources: abstractResources,
            sessions: abstractSessions
        )

        let result = try await kernel.solve(puzzle)
        totalAnalyses += 1

        // Interpret result
        var issues: [SecurityIssue] = []
        if result.outcome == .foundViolation {
            totalIssuesFound += 1
            issues.append(SecurityIssue(
                issueId: UUID(),
                severity: .high,
                category: .accessControl,
                title: "Potential Unauthorized Access Path Found",
                description: result.explanation,
                violationPath: result.transitionSequence,
                affectedControls: ["AC-2", "AC-3", "AC-6"],
                recommendation: "Review access control logic and session validation"
            ))
        }

        return SecurityAnalysisResult(
            analysisId: UUID(),
            analysisType: .accessControl,
            status: result.outcome == .provedInvariant ? .passed : (issues.isEmpty ? .inconclusive : .failed),
            issues: issues,
            stepsExplored: result.stepsExplored,
            durationMs: result.durationMs,
            confidence: result.confidence,
            explanation: result.explanation
        )
    }

    // MARK: - Tenant Isolation Analysis

    /// Analyzes tenant isolation for potential breaches.
    public func analyzeTenantIsolation(
        context: TenantIsolationAnalysisContext
    ) async throws -> SecurityAnalysisResult {
        guard isEnabled else {
            throw ReasoningError.kernelUnavailable
        }

        await abstractor.reset()

        // Abstract tenants
        var tenantSymbols: [String] = []
        for tenant in context.tenants {
            tenantSymbols.append(await abstractor.anonymize(tenant, prefix: "T"))
        }

        // Abstract entity-tenant mappings
        var entityTenantMap: [(entitySymbol: String, tenantSymbol: String)] = []
        for (entityId, tenantId) in context.entityTenantMap {
            let entitySymbol = await abstractor.anonymize(entityId, prefix: "E")
            let tenantSymbol = await abstractor.anonymize(tenantId, prefix: "T")
            entityTenantMap.append((entitySymbol, tenantSymbol))
        }

        // Abstract operation contexts
        var operationContexts: [(contextSymbol: String, tenantSymbol: String)] = []
        for (contextId, tenantId) in context.operationContexts {
            let contextSymbol = await abstractor.anonymize(contextId, prefix: "C")
            let tenantSymbol = await abstractor.anonymize(tenantId, prefix: "T")
            operationContexts.append((contextSymbol, tenantSymbol))
        }

        let puzzle = TenantIsolationPuzzleBuilder.buildCrossTenantPuzzle(
            tenants: tenantSymbols,
            entityTenantMap: entityTenantMap,
            operationContexts: operationContexts
        )

        let result = try await kernel.solve(puzzle)
        totalAnalyses += 1

        var issues: [SecurityIssue] = []
        if result.outcome == .foundViolation {
            totalIssuesFound += 1
            issues.append(SecurityIssue(
                issueId: UUID(),
                severity: .critical,
                category: .tenantIsolation,
                title: "Potential Cross-Tenant Access Path Found",
                description: result.explanation,
                violationPath: result.transitionSequence,
                affectedControls: ["AC-4", "SC-4"],
                recommendation: "Review tenant isolation enforcement and operation context handling"
            ))
        }

        return SecurityAnalysisResult(
            analysisId: UUID(),
            analysisType: .tenantIsolation,
            status: result.outcome == .provedInvariant ? .passed : (issues.isEmpty ? .inconclusive : .failed),
            issues: issues,
            stepsExplored: result.stepsExplored,
            durationMs: result.durationMs,
            confidence: result.confidence,
            explanation: result.explanation
        )
    }

    // MARK: - Automation Rule Analysis

    /// Analyzes automation rules for loops and conflicts.
    public func analyzeAutomationRules(
        rules: [(id: UUID, name: String, triggers: [String], effects: [String])]
    ) async throws -> AutomationAnalysisResult {
        guard isEnabled else {
            throw ReasoningError.kernelUnavailable
        }

        await abstractor.reset()

        // Abstract rules
        var abstractRules: [(id: String, triggers: [String], effects: [String])] = []
        for rule in rules {
            let ruleSymbol = await abstractor.anonymize(rule.id, prefix: "R")
            abstractRules.append((ruleSymbol, rule.triggers, rule.effects))
        }

        let puzzle = AutomationRulePuzzleBuilder.buildRuleLoopDetectionPuzzle(rules: abstractRules)
        let result = try await kernel.solve(puzzle)
        totalAnalyses += 1

        var issues: [AutomationIssue] = []
        if result.outcome == .foundViolation {
            totalIssuesFound += 1
            issues.append(AutomationIssue(
                issueId: UUID(),
                severity: .high,
                issueType: .infiniteLoop,
                description: "Potential infinite loop detected in rule chain",
                involvedRules: result.transitionSequence.compactMap { transition in
                    if transition.hasPrefix("execute_") {
                        return String(transition.dropFirst("execute_".count))
                    }
                    return nil
                },
                recommendation: "Add loop detection or rate limiting to the rule chain"
            ))
        }

        return AutomationAnalysisResult(
            analysisId: UUID(),
            rulesAnalyzed: rules.count,
            loopsDetected: issues.filter { $0.issueType == .infiniteLoop }.count,
            conflictsDetected: issues.filter { $0.issueType == .conflict }.count,
            issues: issues,
            stepsExplored: result.stepsExplored,
            durationMs: result.durationMs
        )
    }

    // MARK: - Compliance Control Analysis

    /// Analyzes a compliance control for bypass vulnerabilities.
    public func analyzeControlBypass(
        controlId: String,
        protectedOperations: [String],
        bypassScenarios: [(name: String, steps: [String])]
    ) async throws -> ComplianceAnalysisResult {
        guard isEnabled else {
            throw ReasoningError.kernelUnavailable
        }

        let puzzle = CompliancePuzzleBuilder.buildControlBypassPuzzle(
            controlId: controlId,
            protectedOperations: protectedOperations,
            bypassAttempts: bypassScenarios
        )

        let result = try await kernel.solve(puzzle)
        totalAnalyses += 1

        var findings: [ComplianceFinding] = []
        if result.outcome == .foundViolation {
            totalIssuesFound += 1
            findings.append(ComplianceFinding(
                findingId: UUID(),
                controlId: controlId,
                severity: .high,
                findingType: .controlBypass,
                description: "Potential bypass path found for control \(controlId)",
                bypassPath: result.transitionSequence,
                recommendation: "Review and strengthen control implementation"
            ))
        }

        return ComplianceAnalysisResult(
            analysisId: UUID(),
            controlsAnalyzed: [controlId],
            status: result.outcome == .provedInvariant ? .compliant : (findings.isEmpty ? .inconclusive : .nonCompliant),
            findings: findings,
            stepsExplored: result.stepsExplored,
            durationMs: result.durationMs,
            confidence: result.confidence
        )
    }

    // MARK: - Data Lifecycle Analysis

    /// Analyzes legal hold enforcement.
    public func analyzeLegalHoldEnforcement(
        entities: [UUID],
        entitiesUnderHold: Set<UUID>,
        deletionAttempts: [UUID]
    ) async throws -> DataLifecycleAnalysisResult {
        guard isEnabled else {
            throw ReasoningError.kernelUnavailable
        }

        await abstractor.reset()

        // Abstract entities
        var abstractEntities: [String] = []
        for entity in entities {
            abstractEntities.append(await abstractor.anonymize(entity, prefix: "E"))
        }

        var abstractUnderHold: Set<String> = []
        for entity in entitiesUnderHold {
            abstractUnderHold.insert(await abstractor.anonymize(entity, prefix: "E"))
        }

        var abstractDeletionAttempts: [String] = []
        for entity in deletionAttempts {
            abstractDeletionAttempts.append(await abstractor.anonymize(entity, prefix: "E"))
        }

        let puzzle = DataLifecyclePuzzleBuilder.buildLegalHoldPuzzle(
            entities: abstractEntities,
            entitiesUnderHold: abstractUnderHold,
            deletionAttempts: abstractDeletionAttempts
        )

        let result = try await kernel.solve(puzzle)
        totalAnalyses += 1

        var issues: [DataLifecycleIssue] = []
        if result.outcome == .foundViolation {
            totalIssuesFound += 1
            issues.append(DataLifecycleIssue(
                issueId: UUID(),
                severity: .critical,
                issueType: .legalHoldBreach,
                description: "Legal hold enforcement can be bypassed",
                affectedEntities: result.violatedConstraints.compactMap { constraint in
                    if constraint.hasPrefix("hold_") {
                        return String(constraint.dropFirst("hold_".count))
                    }
                    return nil
                },
                recommendation: "Strengthen legal hold checks in deletion workflow"
            ))
        }

        return DataLifecycleAnalysisResult(
            analysisId: UUID(),
            entitiesAnalyzed: entities.count,
            holdViolationsFound: issues.filter { $0.issueType == .legalHoldBreach }.count,
            issues: issues,
            stepsExplored: result.stepsExplored,
            durationMs: result.durationMs
        )
    }

    // MARK: - Statistics

    /// Gets service statistics.
    public func getStatistics() async -> ReasoningServiceStatistics {
        let kernelStats = await kernel.getStatistics()
        return ReasoningServiceStatistics(
            totalAnalyses: totalAnalyses,
            totalIssuesFound: totalIssuesFound,
            isEnabled: isEnabled,
            kernelStats: kernelStats
        )
    }
}

// MARK: - Analysis Contexts

/// Context for access control analysis.
public struct AccessControlAnalysisContext: Sendable {
    public let principals: [PrincipalSnapshot]
    public let resources: [ResourceSnapshot]
    public let sessions: [SessionSnapshot]

    public init(
        principals: [PrincipalSnapshot],
        resources: [ResourceSnapshot],
        sessions: [SessionSnapshot]
    ) {
        self.principals = principals
        self.resources = resources
        self.sessions = sessions
    }
}

/// Snapshot of a principal for analysis.
public struct PrincipalSnapshot: Sendable {
    public let id: UUID
    public let roles: Set<String>
    public let isDeprovisioned: Bool

    public init(id: UUID, roles: Set<String>, isDeprovisioned: Bool) {
        self.id = id
        self.roles = roles
        self.isDeprovisioned = isDeprovisioned
    }
}

/// Snapshot of a resource for analysis.
public struct ResourceSnapshot: Sendable {
    public let id: UUID
    public let sensitivity: DataSensitivity
    public let requiredRoles: Set<String>

    public init(id: UUID, sensitivity: DataSensitivity, requiredRoles: Set<String>) {
        self.id = id
        self.sensitivity = sensitivity
        self.requiredRoles = requiredRoles
    }
}

/// Snapshot of a session for analysis.
public struct SessionSnapshot: Sendable {
    public let id: UUID
    public let principalId: UUID
    public let isValid: Bool
    public let mfaVerified: Bool

    public init(id: UUID, principalId: UUID, isValid: Bool, mfaVerified: Bool) {
        self.id = id
        self.principalId = principalId
        self.isValid = isValid
        self.mfaVerified = mfaVerified
    }
}

/// Context for tenant isolation analysis.
public struct TenantIsolationAnalysisContext: Sendable {
    public let tenants: [UUID]
    public let entityTenantMap: [(entityId: UUID, tenantId: UUID)]
    public let operationContexts: [(contextId: UUID, tenantId: UUID)]

    public init(
        tenants: [UUID],
        entityTenantMap: [(entityId: UUID, tenantId: UUID)],
        operationContexts: [(contextId: UUID, tenantId: UUID)]
    ) {
        self.tenants = tenants
        self.entityTenantMap = entityTenantMap
        self.operationContexts = operationContexts
    }
}

// MARK: - Analysis Results

/// Result of security analysis.
public struct SecurityAnalysisResult: Sendable {
    public let analysisId: UUID
    public let analysisType: SecurityAnalysisType
    public let status: AnalysisStatus
    public let issues: [SecurityIssue]
    public let stepsExplored: Int
    public let durationMs: Int
    public let confidence: Double
    public let explanation: String
}

/// Types of security analysis.
public enum SecurityAnalysisType: String, Sendable {
    case accessControl = "access_control"
    case tenantIsolation = "tenant_isolation"
    case sessionSecurity = "session_security"
    case auditIntegrity = "audit_integrity"
}

/// Status of analysis.
public enum AnalysisStatus: String, Sendable {
    case passed = "passed"
    case failed = "failed"
    case inconclusive = "inconclusive"
    case error = "error"
}

/// A security issue found.
public struct SecurityIssue: Sendable {
    public let issueId: UUID
    public let severity: ReasoningIssueSeverity
    public let category: SecurityIssueCategory
    public let title: String
    public let description: String
    public let violationPath: [String]
    public let affectedControls: [String]
    public let recommendation: String
}

/// Reasoning issue severity levels.
public enum ReasoningIssueSeverity: String, Sendable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// Security issue categories.
public enum SecurityIssueCategory: String, Sendable {
    case accessControl = "access_control"
    case tenantIsolation = "tenant_isolation"
    case auditIntegrity = "audit_integrity"
    case dataProtection = "data_protection"
}

/// Result of automation analysis.
public struct AutomationAnalysisResult: Sendable {
    public let analysisId: UUID
    public let rulesAnalyzed: Int
    public let loopsDetected: Int
    public let conflictsDetected: Int
    public let issues: [AutomationIssue]
    public let stepsExplored: Int
    public let durationMs: Int
}

/// An automation issue found.
public struct AutomationIssue: Sendable {
    public let issueId: UUID
    public let severity: ReasoningIssueSeverity
    public let issueType: AutomationIssueType
    public let description: String
    public let involvedRules: [String]
    public let recommendation: String
}

/// Automation issue types.
public enum AutomationIssueType: String, Sendable {
    case infiniteLoop = "infinite_loop"
    case conflict = "conflict"
    case deadlock = "deadlock"
    case unreachable = "unreachable"
}

/// Result of compliance analysis.
public struct ComplianceAnalysisResult: Sendable {
    public let analysisId: UUID
    public let controlsAnalyzed: [String]
    public let status: ComplianceAnalysisStatus
    public let findings: [ComplianceFinding]
    public let stepsExplored: Int
    public let durationMs: Int
    public let confidence: Double
}

/// Compliance analysis status.
public enum ComplianceAnalysisStatus: String, Sendable {
    case compliant = "compliant"
    case nonCompliant = "non_compliant"
    case inconclusive = "inconclusive"
}

/// A compliance finding.
public struct ComplianceFinding: Sendable {
    public let findingId: UUID
    public let controlId: String
    public let severity: ReasoningIssueSeverity
    public let findingType: ComplianceFindingType
    public let description: String
    public let bypassPath: [String]
    public let recommendation: String
}

/// Compliance finding types.
public enum ComplianceFindingType: String, Sendable {
    case controlBypass = "control_bypass"
    case insufficientImplementation = "insufficient_implementation"
    case configurationWeakness = "configuration_weakness"
}

/// Result of data lifecycle analysis.
public struct DataLifecycleAnalysisResult: Sendable {
    public let analysisId: UUID
    public let entitiesAnalyzed: Int
    public let holdViolationsFound: Int
    public let issues: [DataLifecycleIssue]
    public let stepsExplored: Int
    public let durationMs: Int
}

/// A data lifecycle issue.
public struct DataLifecycleIssue: Sendable {
    public let issueId: UUID
    public let severity: ReasoningIssueSeverity
    public let issueType: DataLifecycleIssueType
    public let description: String
    public let affectedEntities: [String]
    public let recommendation: String
}

/// Data lifecycle issue types.
public enum DataLifecycleIssueType: String, Sendable {
    case legalHoldBreach = "legal_hold_breach"
    case retentionViolation = "retention_violation"
    case prematureDeletion = "premature_deletion"
}

/// Statistics about the reasoning service.
public struct ReasoningServiceStatistics: Sendable {
    public let totalAnalyses: Int
    public let totalIssuesFound: Int
    public let isEnabled: Bool
    public let kernelStats: ReasonerStatistics
}

// MARK: - Reasoning Module

/// The Reasoning module provides adversarial analysis capabilities.
public enum ReasoningModule {
    /// Version of the reasoning module.
    public static let version = "1.0.0"

    /// Initializes the reasoning infrastructure.
    public static func initialize(
        config: ReasonerConfig = ReasonerConfig(),
        auditLog: any AuditLogging
    ) async -> ReasoningInfrastructure {
        let service = ReasoningService(config: config)
        await service.configure(auditLog: auditLog)
        return ReasoningInfrastructure(service: service)
    }
}

/// Container for reasoning infrastructure.
public struct ReasoningInfrastructure: Sendable {
    /// The main reasoning service.
    public let service: ReasoningService
}
