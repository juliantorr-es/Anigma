//
//  HarmoniaScenarioLibrary.swift
//  HarmoniaModule
//
//  Harmonia-specific adversarial scenario library.
//  Stores and manages scenarios found by the reasoning kernel.
//
//  Scenarios are durable knowledge objects that:
//  - Become regression tests
//  - Generate documentation in Codex
//  - Feed into Pragma as tracked issues
//  - Provide inline hints in the IDE
//

import Foundation
import AnigmaCore
import ContractsCore

// MARK: - Harmonia Adversarial Scenario

/// An adversarial scenario discovered by Harmonia reasoning.
public struct HarmoniaAdversarialScenario: Sendable, Codable, Identifiable {
    /// Unique scenario ID.
    public let id: UUID

    /// When this scenario was discovered.
    public let discoveredAt: Date

    /// Harmonia domain this scenario belongs to.
    public let domain: HarmoniaReasoningDomain

    /// Title for the scenario.
    public let title: String

    /// Detailed description.
    public let description: String

    /// The violation path (sequence of transitions).
    public let violationPath: [String]

    /// Violated constraints.
    public let violatedConstraints: [String]

    /// Severity level.
    public let severity: ScenarioSeverity

    /// Current status.
    public var status: ScenarioStatus

    /// Associated module(s).
    public let affectedModules: [String]

    /// Version when discovered.
    public let discoveryVersion: String

    /// Version when fixed (if fixed).
    public var fixedInVersion: String?

    /// Linked Pragma task ID (if any).
    public var linkedTaskId: UUID?

    /// Linked Codex page ID (if any).
    public var linkedCodexPageId: UUID?

    /// Tags for categorization.
    public var tags: Set<String>

    /// Metadata.
    public var metadata: [String: String]

    public enum ScenarioSeverity: String, Sendable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }

    public enum ScenarioStatus: String, Sendable, Codable {
        case new = "new"
        case triaged = "triaged"
        case inProgress = "in_progress"
        case fixed = "fixed"
        case wontFix = "wont_fix"
        case falsePositive = "false_positive"
    }

    public init(
        id: UUID = UUID(),
        discoveredAt: Date = Date(),
        domain: HarmoniaReasoningDomain,
        title: String,
        description: String,
        violationPath: [String],
        violatedConstraints: [String],
        severity: ScenarioSeverity,
        status: ScenarioStatus = .new,
        affectedModules: [String],
        discoveryVersion: String,
        fixedInVersion: String? = nil,
        linkedTaskId: UUID? = nil,
        linkedCodexPageId: UUID? = nil,
        tags: Set<String> = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.discoveredAt = discoveredAt
        self.domain = domain
        self.title = title
        self.description = description
        self.violationPath = violationPath
        self.violatedConstraints = violatedConstraints
        self.severity = severity
        self.status = status
        self.affectedModules = affectedModules
        self.discoveryVersion = discoveryVersion
        self.fixedInVersion = fixedInVersion
        self.linkedTaskId = linkedTaskId
        self.linkedCodexPageId = linkedCodexPageId
        self.tags = tags
        self.metadata = metadata
    }

    /// Creates a scenario from a Harmonia reasoning result.
    public static func fromReasoningResult(
        _ result: HarmoniaReasoningResult,
        affectedModules: [String],
        version: String
    ) -> HarmoniaAdversarialScenario? {
        guard result.baseResult.outcome == .foundViolation else {
            return nil
        }

        let severity: ScenarioSeverity
        switch result.riskLevel {
        case .critical:
            severity = .critical
        case .high:
            severity = .high
        case .moderate:
            severity = .medium
        default:
            severity = .low
        }

        return HarmoniaAdversarialScenario(
            domain: result.harmoniaDomain,
            title: "[\(result.harmoniaDomain.rawValue.uppercased())] Violation in \(affectedModules.joined(separator: ", "))",
            description: result.diagnosis,
            violationPath: result.baseResult.transitionSequence,
            violatedConstraints: result.baseResult.violatedConstraints,
            severity: severity,
            affectedModules: affectedModules,
            discoveryVersion: version
        )
    }
}

// MARK: - Scenario Library

/// Library of Harmonia adversarial scenarios.
public actor HarmoniaScenarioLibrary {
    /// All scenarios.
    private var scenarios: [UUID: HarmoniaAdversarialScenario] = [:]

    /// Index by domain.
    private var byDomain: [HarmoniaReasoningDomain: Set<UUID>] = [:]

    /// Index by module.
    private var byModule: [String: Set<UUID>] = [:]

    /// Index by status.
    private var byStatus: [HarmoniaAdversarialScenario.ScenarioStatus: Set<UUID>] = [:]

    /// Audit log.
    private var auditLog: AuditLog?

    public init() {}

    /// Configures the library.
    public func configure(auditLog: AuditLog) {
        self.auditLog = auditLog
    }

    // MARK: - CRUD Operations

    /// Adds a new scenario.
    public func add(_ scenario: HarmoniaAdversarialScenario) async {
        scenarios[scenario.id] = scenario

        // Update indices
        byDomain[scenario.domain, default: []].insert(scenario.id)
        for module in scenario.affectedModules {
            byModule[module, default: []].insert(scenario.id)
        }
        byStatus[scenario.status, default: []].insert(scenario.id)

        if let log = auditLog {
            try? await log.record(
                eventType: .dataCreated,
                principal: "scenario_library",
                module: "reasoning.scenario_library",
                description: "Added scenario: \(scenario.title)",
                metadata: [
                    "scenario_id": scenario.id.uuidString,
                    "domain": scenario.domain.rawValue,
                    "severity": scenario.severity.rawValue
                ]
            )
        }
    }

    /// Gets a scenario by ID.
    public func get(_ id: UUID) -> HarmoniaAdversarialScenario? {
        scenarios[id]
    }

    /// Updates a scenario's status.
    public func updateStatus(_ id: UUID, to newStatus: HarmoniaAdversarialScenario.ScenarioStatus, fixedInVersion: String? = nil) async {
        guard var scenario = scenarios[id] else { return }

        let oldStatus = scenario.status
        byStatus[oldStatus]?.remove(id)

        scenario.status = newStatus
        if let version = fixedInVersion {
            scenario.fixedInVersion = version
        }

        scenarios[id] = scenario
        byStatus[newStatus, default: []].insert(id)

        if let log = auditLog {
            try? await log.record(
                eventType: .dataModified,
                principal: "scenario_library",
                module: "reasoning.scenario_library",
                description: "Updated scenario \(id.uuidString.prefix(8)) status: \(oldStatus.rawValue) → \(newStatus.rawValue)",
                metadata: [
                    "scenario_id": id.uuidString,
                    "old_status": oldStatus.rawValue,
                    "new_status": newStatus.rawValue
                ]
            )
        }
    }

    /// Links a scenario to a Pragma task.
    public func linkToTask(_ scenarioId: UUID, taskId: UUID) async {
        guard var scenario = scenarios[scenarioId] else { return }
        scenario.linkedTaskId = taskId
        scenarios[scenarioId] = scenario
    }

    /// Links a scenario to a Codex page.
    public func linkToCodexPage(_ scenarioId: UUID, pageId: UUID) async {
        guard var scenario = scenarios[scenarioId] else { return }
        scenario.linkedCodexPageId = pageId
        scenarios[scenarioId] = scenario
    }

    // MARK: - Queries

    /// Gets all scenarios.
    public func all() -> [HarmoniaAdversarialScenario] {
        Array(scenarios.values)
    }

    /// Gets scenarios by domain.
    public func forDomain(_ domain: HarmoniaReasoningDomain) -> [HarmoniaAdversarialScenario] {
        guard let ids = byDomain[domain] else { return [] }
        return ids.compactMap { scenarios[$0] }
    }

    /// Gets scenarios by module.
    public func forModule(_ module: String) -> [HarmoniaAdversarialScenario] {
        guard let ids = byModule[module] else { return [] }
        return ids.compactMap { scenarios[$0] }
    }

    /// Gets scenarios by status.
    public func withStatus(_ status: HarmoniaAdversarialScenario.ScenarioStatus) -> [HarmoniaAdversarialScenario] {
        guard let ids = byStatus[status] else { return [] }
        return ids.compactMap { scenarios[$0] }
    }

    /// Gets open (unresolved) scenarios.
    public func openScenarios() -> [HarmoniaAdversarialScenario] {
        let openStatuses: Set<HarmoniaAdversarialScenario.ScenarioStatus> = [.new, .triaged, .inProgress]
        return scenarios.values.filter { openStatuses.contains($0.status) }
    }

    /// Gets critical open scenarios.
    public func criticalOpenScenarios() -> [HarmoniaAdversarialScenario] {
        openScenarios().filter { $0.severity == .critical }
    }

    /// Searches scenarios by text.
    public func search(query: String) -> [HarmoniaAdversarialScenario] {
        let lowercased = query.lowercased()
        return scenarios.values.filter { scenario in
            scenario.title.lowercased().contains(lowercased) ||
            scenario.description.lowercased().contains(lowercased) ||
            scenario.affectedModules.contains { $0.lowercased().contains(lowercased) } ||
            scenario.tags.contains { $0.lowercased().contains(lowercased) }
        }
    }

    // MARK: - Statistics

    /// Gets library statistics.
    public func statistics() -> ScenarioLibraryStatistics {
        var bySeverity: [HarmoniaAdversarialScenario.ScenarioSeverity: Int] = [:]
        var byDomainCount: [HarmoniaReasoningDomain: Int] = [:]
        var byStatusCount: [HarmoniaAdversarialScenario.ScenarioStatus: Int] = [:]

        for scenario in scenarios.values {
            bySeverity[scenario.severity, default: 0] += 1
            byDomainCount[scenario.domain, default: 0] += 1
            byStatusCount[scenario.status, default: 0] += 1
        }

        return ScenarioLibraryStatistics(
            totalScenarios: scenarios.count,
            openCount: openScenarios().count,
            criticalOpenCount: criticalOpenScenarios().count,
            bySeverity: bySeverity,
            byDomain: byDomainCount,
            byStatus: byStatusCount
        )
    }

    // MARK: - Export

    /// Exports scenarios as test fixtures.
    public func exportAsTestFixtures() -> [ScenarioTestFixture] {
        scenarios.values.map { scenario in
            ScenarioTestFixture(
                scenarioId: scenario.id,
                domain: scenario.domain.rawValue,
                title: scenario.title,
                violationPath: scenario.violationPath,
                violatedConstraints: scenario.violatedConstraints,
                expectedToFail: scenario.status != .fixed && scenario.status != .falsePositive
            )
        }
    }

    /// Generates a Codex page for a scenario.
    public func generateCodexContent(for scenarioId: UUID) -> String? {
        guard let scenario = scenarios[scenarioId] else { return nil }

        var lines: [String] = []

        lines.append("# Adversarial Scenario: \(scenario.title)")
        lines.append("")
        lines.append("**ID:** `\(scenario.id.uuidString)`")
        lines.append("**Domain:** \(scenario.domain.rawValue)")
        lines.append("**Severity:** \(scenario.severity.rawValue.uppercased())")
        lines.append("**Status:** \(scenario.status.rawValue)")
        lines.append("**Discovered:** \(scenario.discoveredAt)")
        lines.append("**Version:** \(scenario.discoveryVersion)")
        if let fixed = scenario.fixedInVersion {
            lines.append("**Fixed in:** \(fixed)")
        }
        lines.append("")

        lines.append("## Description")
        lines.append("")
        lines.append(scenario.description)
        lines.append("")

        lines.append("## Affected Modules")
        lines.append("")
        for module in scenario.affectedModules {
            lines.append("- \(module)")
        }
        lines.append("")

        lines.append("## Violation Path")
        lines.append("")
        lines.append("```")
        for (index, step) in scenario.violationPath.enumerated() {
            lines.append("\(index + 1). \(step)")
        }
        lines.append("```")
        lines.append("")

        lines.append("## Violated Constraints")
        lines.append("")
        for constraint in scenario.violatedConstraints {
            lines.append("- `\(constraint)`")
        }
        lines.append("")

        if !scenario.tags.isEmpty {
            lines.append("## Tags")
            lines.append("")
            lines.append(scenario.tags.map { "`\($0)`" }.joined(separator: " "))
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Supporting Types

/// Statistics for the scenario library.
public struct ScenarioLibraryStatistics: Sendable {
    public let totalScenarios: Int
    public let openCount: Int
    public let criticalOpenCount: Int
    public let bySeverity: [HarmoniaAdversarialScenario.ScenarioSeverity: Int]
    public let byDomain: [HarmoniaReasoningDomain: Int]
    public let byStatus: [HarmoniaAdversarialScenario.ScenarioStatus: Int]
}

/// A test fixture generated from a scenario.
public struct ScenarioTestFixture: Sendable, Codable {
    public let scenarioId: UUID
    public let domain: String
    public let title: String
    public let violationPath: [String]
    public let violatedConstraints: [String]
    public let expectedToFail: Bool
}
