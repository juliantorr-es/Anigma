//
//  AdversarialScenarios.swift
//  AnigmaCore
//
//  Adversarial scenario library and management.
//  Stores discovered attack paths as durable knowledge objects.
//
//  Scenarios are:
//  - Indexed by domain, control, and version
//  - Linked to Compliance, Codex, and Pragma
//  - Used for regression testing
//  - Used for training data (anonymized abstractions only)
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import Foundation
import ContractsCore

// MARK: - Adversarial Scenario

/// A discovered adversarial scenario (attack path).
public struct AdversarialScenario: Sendable, Codable, Identifiable {
    /// Unique scenario identifier.
    public let id: UUID

    /// When this scenario was discovered.
    public let discoveredAt: Date

    /// Domain this scenario relates to.
    public let domain: ReasoningDomain

    /// Control IDs affected.
    public let affectedControls: [String]

    /// Severity of this scenario.
    public let severity: ReasoningIssueSeverity

    /// The abstract violation path.
    public let violationPath: [String]

    /// The abstract initial state.
    public let initialState: AbstractState

    /// The abstract final state.
    public let finalState: AbstractState?

    /// Constraints violated.
    public let violatedConstraints: [String]

    /// Human-readable title.
    public let title: String

    /// Human-readable description.
    public let description: String

    /// Kernel that discovered this.
    public let discoveredBy: SpecializedKernelType

    /// Platform version when discovered.
    public let platformVersion: String

    /// Current status.
    public var status: ScenarioStatus

    /// Resolution details (if resolved).
    public var resolution: ScenarioResolution?

    /// Tags for categorization.
    public var tags: Set<String>

    /// Link to Pragma issue (if created).
    public var pragmaIssueId: UUID?

    /// Link to Codex page (if documented).
    public var codexPageId: UUID?

    /// Recommendation for remediation.
    public let recommendation: String

    public init(
        id: UUID = UUID(),
        discoveredAt: Date = Date(),
        domain: ReasoningDomain,
        affectedControls: [String],
        severity: ReasoningIssueSeverity,
        violationPath: [String],
        initialState: AbstractState,
        finalState: AbstractState? = nil,
        violatedConstraints: [String],
        title: String,
        description: String,
        discoveredBy: SpecializedKernelType,
        platformVersion: String,
        status: ScenarioStatus = .open,
        resolution: ScenarioResolution? = nil,
        tags: Set<String> = [],
        pragmaIssueId: UUID? = nil,
        codexPageId: UUID? = nil,
        recommendation: String
    ) {
        self.id = id
        self.discoveredAt = discoveredAt
        self.domain = domain
        self.affectedControls = affectedControls
        self.severity = severity
        self.violationPath = violationPath
        self.initialState = initialState
        self.finalState = finalState
        self.violatedConstraints = violatedConstraints
        self.title = title
        self.description = description
        self.discoveredBy = discoveredBy
        self.platformVersion = platformVersion
        self.status = status
        self.resolution = resolution
        self.tags = tags
        self.pragmaIssueId = pragmaIssueId
        self.codexPageId = codexPageId
        self.recommendation = recommendation
    }
}

/// Status of an adversarial scenario.
public enum ScenarioStatus: String, Sendable, Codable {
    /// Newly discovered, not yet triaged.
    case open = "open"

    /// Being investigated.
    case investigating = "investigating"

    /// Fix in progress.
    case remediating = "remediating"

    /// Fixed and verified.
    case resolved = "resolved"

    /// Accepted risk (documented).
    case acceptedRisk = "accepted_risk"

    /// False positive (scenario invalid).
    case falsePositive = "false_positive"

    /// Deferred to future release.
    case deferred = "deferred"
}

/// Resolution details for a scenario.
public struct ScenarioResolution: Sendable, Codable {
    /// When resolved.
    public let resolvedAt: Date

    /// How it was resolved.
    public let resolutionType: ResolutionType

    /// Description of the fix.
    public let description: String

    /// Version where fix was applied.
    public let fixedInVersion: String?

    /// Who resolved it.
    public let resolvedBy: String

    public init(
        resolvedAt: Date = Date(),
        resolutionType: ResolutionType,
        description: String,
        fixedInVersion: String? = nil,
        resolvedBy: String
    ) {
        self.resolvedAt = resolvedAt
        self.resolutionType = resolutionType
        self.description = description
        self.fixedInVersion = fixedInVersion
        self.resolvedBy = resolvedBy
    }
}

/// Types of resolution.
public enum ResolutionType: String, Sendable, Codable {
    case codeFix = "code_fix"
    case configurationChange = "configuration_change"
    case policyChange = "policy_change"
    case acceptedRisk = "accepted_risk"
    case falsePositive = "false_positive"
    case cannotReproduce = "cannot_reproduce"
}

// MARK: - Scenario Library

/// Library of adversarial scenarios.
public actor ScenarioLibrary {
    /// All stored scenarios.
    private var scenarios: [UUID: AdversarialScenario] = [:]

    /// Index by domain.
    private var byDomain: [ReasoningDomain: Set<UUID>] = [:]

    /// Index by control.
    private var byControl: [String: Set<UUID>] = [:]

    /// Index by status.
    private var byStatus: [ScenarioStatus: Set<UUID>] = [:]

    /// Audit log.
    private var auditLog: (any AuditLogging)?

    public init() {}

    /// Configures the library.
    public func configure(auditLog: any AuditLogging) {
        self.auditLog = auditLog
    }

    // MARK: - CRUD Operations

    /// Adds a new scenario to the library.
    public func add(_ scenario: AdversarialScenario) async {
        scenarios[scenario.id] = scenario

        // Update indices
        byDomain[scenario.domain, default: []].insert(scenario.id)
        for control in scenario.affectedControls {
            byControl[control, default: []].insert(scenario.id)
        }
        byStatus[scenario.status, default: []].insert(scenario.id)

        try? await auditLog?.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.dataCreated,
            principal: "scenario_library",
            module: "ScenarioLibrary",
            description: "Adversarial scenario added: \(scenario.title)",
            metadata: [
                "scenario_id": scenario.id.uuidString,
                "domain": scenario.domain.rawValue,
                "severity": scenario.severity.rawValue
            ]
        )
    }

    /// Creates a scenario from a reasoning result.
    public func createFromResult(
        _ result: ReasoningResult,
        puzzle: ReasoningPuzzle,
        kernelType: SpecializedKernelType,
        platformVersion: String,
        additionalContext: [String: String] = [:]
    ) async -> AdversarialScenario? {
        guard result.outcome == .foundViolation else { return nil }

        let title = generateTitle(domain: puzzle.domain, constraints: result.violatedConstraints)
        let description = generateDescription(result: result, puzzle: puzzle)
        let severity = determineSeverity(puzzle: puzzle, constraints: result.violatedConstraints)

        let scenario = AdversarialScenario(
            domain: puzzle.domain,
            affectedControls: mapToControls(domain: puzzle.domain),
            severity: severity,
            violationPath: result.transitionSequence,
            initialState: puzzle.initialState,
            finalState: result.finalState,
            violatedConstraints: result.violatedConstraints,
            title: title,
            description: description,
            discoveredBy: kernelType,
            platformVersion: platformVersion,
            tags: Set(additionalContext.keys),
            recommendation: generateRecommendation(domain: puzzle.domain, severity: severity)
        )

        await add(scenario)
        return scenario
    }

    /// Updates a scenario's status.
    public func updateStatus(
        _ scenarioId: UUID,
        newStatus: ScenarioStatus,
        resolution: ScenarioResolution? = nil
    ) async -> Bool {
        guard var scenario = scenarios[scenarioId] else { return false }

        let oldStatus = scenario.status

        // Update status index
        byStatus[oldStatus]?.remove(scenarioId)
        byStatus[newStatus, default: []].insert(scenarioId)

        scenario.status = newStatus
        if let resolution = resolution {
            scenario.resolution = resolution
        }

        scenarios[scenarioId] = scenario

        try? await auditLog?.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.dataModified,
            principal: "scenario_library",
            module: "ScenarioLibrary",
            description: "Scenario status changed: \(oldStatus.rawValue) → \(newStatus.rawValue)",
            metadata: [
                "scenario_id": scenarioId.uuidString,
                "old_status": oldStatus.rawValue,
                "new_status": newStatus.rawValue
            ]
        )

        return true
    }

    /// Links a scenario to a Pragma issue.
    public func linkToPragma(_ scenarioId: UUID, issueId: UUID) async -> Bool {
        guard var scenario = scenarios[scenarioId] else { return false }
        scenario.pragmaIssueId = issueId
        scenarios[scenarioId] = scenario
        return true
    }

    /// Links a scenario to a Codex page.
    public func linkToCodex(_ scenarioId: UUID, pageId: UUID) async -> Bool {
        guard var scenario = scenarios[scenarioId] else { return false }
        scenario.codexPageId = pageId
        scenarios[scenarioId] = scenario
        return true
    }

    // MARK: - Queries

    /// Gets a scenario by ID.
    public func get(_ id: UUID) -> AdversarialScenario? {
        scenarios[id]
    }

    /// Gets all scenarios for a domain.
    public func getByDomain(_ domain: ReasoningDomain) -> [AdversarialScenario] {
        (byDomain[domain] ?? []).compactMap { scenarios[$0] }
    }

    /// Gets all scenarios for a control.
    public func getByControl(_ controlId: String) -> [AdversarialScenario] {
        (byControl[controlId] ?? []).compactMap { scenarios[$0] }
    }

    /// Gets all scenarios with a specific status.
    public func getByStatus(_ status: ScenarioStatus) -> [AdversarialScenario] {
        (byStatus[status] ?? []).compactMap { scenarios[$0] }
    }

    /// Gets all open scenarios sorted by severity.
    public func getOpenScenariosBySeverity() -> [AdversarialScenario] {
        getByStatus(.open)
            .sorted { $0.severity.priority > $1.severity.priority }
    }

    /// Gets scenarios that can be used as regression tests.
    public func getRegressionTestCandidates() -> [AdversarialScenario] {
        scenarios.values.filter { scenario in
            scenario.status == .resolved || scenario.status == .acceptedRisk
        }
    }

    /// Gets library statistics.
    public func getStatistics() -> ScenarioLibraryStatistics {
        var bySeverity: [ReasoningIssueSeverity: Int] = [:]
        var byStatusCounts: [ScenarioStatus: Int] = [:]
        var byDomainCounts: [ReasoningDomain: Int] = [:]

        for scenario in scenarios.values {
            bySeverity[scenario.severity, default: 0] += 1
            byStatusCounts[scenario.status, default: 0] += 1
            byDomainCounts[scenario.domain, default: 0] += 1
        }

        return ScenarioLibraryStatistics(
            totalScenarios: scenarios.count,
            openCount: byStatus[.open]?.count ?? 0,
            resolvedCount: byStatus[.resolved]?.count ?? 0,
            bySeverity: bySeverity,
            byStatus: byStatusCounts,
            byDomain: byDomainCounts
        )
    }

    // MARK: - Export

    /// Exports scenarios for a given filter.
    public func export(
        domain: ReasoningDomain? = nil,
        status: ScenarioStatus? = nil,
        since: Date? = nil
    ) -> [AdversarialScenario] {
        var result = Array(scenarios.values)

        if let domain = domain {
            result = result.filter { $0.domain == domain }
        }
        if let status = status {
            result = result.filter { $0.status == status }
        }
        if let since = since {
            result = result.filter { $0.discoveredAt >= since }
        }

        return result.sorted { $0.discoveredAt > $1.discoveredAt }
    }

    /// Exports as JSON for external consumption.
    public func exportAsJSON(scenarios: [AdversarialScenario]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(scenarios)
    }

    // MARK: - Private Helpers

    private func generateTitle(domain: ReasoningDomain, constraints: [String]) -> String {
        let constraintPart = constraints.first ?? "unknown"
        return "\(domain.rawValue.capitalized) violation: \(constraintPart)"
    }

    private func generateDescription(result: ReasoningResult, puzzle: ReasoningPuzzle) -> String {
        var lines: [String] = []
        lines.append("Domain: \(puzzle.domain.rawValue)")
        lines.append("Puzzle type: \(puzzle.puzzleType.rawValue)")
        lines.append("Violation path: \(result.transitionSequence.joined(separator: " → "))")
        lines.append("Steps explored: \(result.stepsExplored)")
        lines.append("Constraints violated: \(result.violatedConstraints.joined(separator: ", "))")
        if !result.explanation.isEmpty {
            lines.append("Explanation: \(result.explanation)")
        }
        return lines.joined(separator: "\n")
    }

    private func determineSeverity(puzzle: ReasoningPuzzle, constraints: [String]) -> ReasoningIssueSeverity {
        // Check puzzle constraints for severity
        for constraintId in constraints {
            if let constraint = puzzle.constraints.first(where: { $0.constraintId == constraintId }) {
                switch constraint.severity {
                case .critical: return .critical
                case .violation: return .high
                case .warning: return .medium
                }
            }
        }
        return .medium
    }

    private func mapToControls(domain: ReasoningDomain) -> [String] {
        switch domain {
        case .accessControl:
            return ["AC-2", "AC-3", "AC-6"]
        case .tenantIsolation:
            return ["AC-4", "SC-4"]
        case .auditIntegrity:
            return ["AU-9", "AU-10"]
        case .updateSequence:
            return ["CM-3", "CM-4"]
        case .automationRules:
            return ["SI-4", "SI-7"]
        case .workflowStates:
            return ["CM-4"]
        case .dataLifecycle:
            return ["AU-11", "SI-12"]
        case .compliance:
            return ["CA-2", "CA-7"]
        }
    }

    private func generateRecommendation(domain: ReasoningDomain, severity: ReasoningIssueSeverity) -> String {
        let urgency = severity == .critical ? "immediately" : (severity == .high ? "promptly" : "as scheduled")

        switch domain {
        case .accessControl:
            return "Review access control logic and session validation \(urgency). Consider adding additional checks or tightening role requirements."
        case .tenantIsolation:
            return "Review tenant isolation enforcement \(urgency). Ensure all queries and operations include tenant context validation."
        case .auditIntegrity:
            return "Review audit log protection \(urgency). Consider additional integrity checks or separate audit storage."
        case .updateSequence:
            return "Review migration safety checks \(urgency). Add additional validation or rollback capabilities."
        case .automationRules:
            return "Review automation rule interactions \(urgency). Consider adding loop detection or rate limiting."
        case .workflowStates:
            return "Review workflow state machine \(urgency). Ensure all transitions are properly guarded."
        case .dataLifecycle:
            return "Review data lifecycle enforcement \(urgency). Strengthen legal hold and retention checks."
        case .compliance:
            return "Review control implementation \(urgency). Ensure all bypass paths are blocked."
        }
    }
}

extension ReasoningIssueSeverity {
    /// Priority for sorting (higher = more urgent).
    var priority: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

/// Statistics for the scenario library.
public struct ScenarioLibraryStatistics: Sendable {
    public let totalScenarios: Int
    public let openCount: Int
    public let resolvedCount: Int
    public let bySeverity: [ReasoningIssueSeverity: Int]
    public let byStatus: [ScenarioStatus: Int]
    public let byDomain: [ReasoningDomain: Int]
}
