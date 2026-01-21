//
//  ContinuousReasoning.swift
//  AnigmaCore
//
//  Continuous reasoning infrastructure.
//  Adaptive scheduling, CI/CD integration, and probe generation.
//
//  This is the "always running" layer that makes the gremlin proactive.
//

import Foundation
import ContractsCore

// MARK: - Continuous Reasoning Engine

/// Continuously runs reasoning analyses based on risk and events.
public actor ContinuousReasoningEngine {
    /// The reasoning orchestrator.
    private let orchestrator: ReasoningOrchestrator

    /// Scenario library for storing findings.
    private let scenarioLibrary: ScenarioLibrary

    /// Meta-puzzle runner for health checks.
    private let metaPuzzleRunner: MetaPuzzleRunner

    /// Reasoning service for high-level analyses.
    private let reasoningService: ReasoningService

    /// Configuration.
    private var config: ContinuousReasoningConfig

    /// Audit log.
    private var auditLog: (any AuditLogging)?

    /// Running state.
    private var isRunning: Bool = false

    /// Last run times per domain.
    private var lastRunTimes: [ReasoningDomain: Date] = [:]

    /// Pending events to process.
    private var pendingEvents: [ReasoningEvent] = []

    /// Statistics.
    private var stats = ContinuousReasoningStatistics()

    public init(config: ContinuousReasoningConfig = .default) {
        self.orchestrator = ReasoningOrchestrator()
        self.scenarioLibrary = ScenarioLibrary()
        self.metaPuzzleRunner = MetaPuzzleRunner()
        self.reasoningService = ReasoningService()
        self.config = config
    }

    /// Configures the engine with dependencies.
    public func configure(auditLog: any AuditLogging) async {
        self.auditLog = auditLog
        await orchestrator.configure(auditLog: auditLog)
        await scenarioLibrary.configure(auditLog: auditLog)
        await metaPuzzleRunner.configure(auditLog: auditLog)
        await reasoningService.configure(auditLog: auditLog)
    }

    /// Updates configuration.
    public func updateConfig(_ newConfig: ContinuousReasoningConfig) {
        self.config = newConfig
    }

    // MARK: - Event-Driven Analysis

    /// Queues an event that should trigger reasoning.
    public func queueEvent(_ event: ReasoningEvent) {
        pendingEvents.append(event)

        // Update domain risk based on event type
        Task {
            await updateRiskFromEvent(event)
        }
    }

    /// Processes pending events.
    public func processPendingEvents() async {
        guard !pendingEvents.isEmpty else { return }

        let eventsToProcess = pendingEvents
        pendingEvents.removeAll()

        for event in eventsToProcess {
            await processEvent(event)
        }
    }

    private func processEvent(_ event: ReasoningEvent) async {
        switch event {
        case .codeChange(let modules, _):
            // Run analyses for affected domains
            let domains = mapModulesToDomains(modules)
            for domain in domains {
                await runDomainAnalysis(domain, reason: "Code change in \(modules.joined(separator: ", "))")
            }

        case .complianceDeadline(let controlId, _):
            // Run focused analysis for the control
            await runControlAnalysis(controlId, reason: "Compliance deadline approaching")

        case .securityAlert(let domain, _):
            // Immediate analysis for the domain
            await orchestrator.updateDomainRisk(domain, factor: ReasoningRiskFactor.externalThreatIntel, magnitude: 0.8)
            await runDomainAnalysis(domain, reason: "Security alert")

        case .userReport(let domain, _):
            await orchestrator.updateDomainRisk(domain, factor: ReasoningRiskFactor.userReport, magnitude: 0.3)
            await runDomainAnalysis(domain, reason: "User report")

        case .probeFailure(let domain, _):
            await orchestrator.updateDomainRisk(domain, factor: ReasoningRiskFactor.recentProbeFailure, magnitude: 0.5)
            await runDomainAnalysis(domain, reason: "Probe failure")

        case .scheduledRun:
            // Run analyses for highest-risk domains
            let priorities = await orchestrator.suggestNextAnalyses(count: 3)
            for domain in priorities {
                await runDomainAnalysis(domain, reason: "Scheduled run")
            }
        }
    }

    private func updateRiskFromEvent(_ event: ReasoningEvent) async {
        switch event {
        case .codeChange(let modules, _):
            let domains = mapModulesToDomains(modules)
            for domain in domains {
                await orchestrator.updateDomainRisk(domain, factor: ReasoningRiskFactor.recentCodeChange, magnitude: 0.3)
            }
        case .complianceDeadline(_, let daysUntil):
            let magnitude = max(0.1, 1.0 - Double(daysUntil) / 30.0)
            await orchestrator.updateDomainRisk(.compliance, factor: ReasoningRiskFactor.complianceDeadline, magnitude: magnitude)
        default:
            break
        }
    }

    // MARK: - Domain Analysis

    /// Runs analysis for a specific domain.
    public func runDomainAnalysis(_ domain: ReasoningDomain, reason: String) async {
        guard config.isEnabled else { return }

        // Check if we've run recently enough
        if let lastRun = lastRunTimes[domain] {
            let elapsed = Date().timeIntervalSince(lastRun)
            if elapsed < config.minIntervalBetweenRuns {
                return
            }
        }

        try? await auditLog?.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.automationTriggered,
            principal: "continuous_reasoning",
            module: "ContinuousReasoning",
            description: "Domain analysis started: \(domain.rawValue) - \(reason)",
            metadata: ["domain": domain.rawValue, "reason": reason]
        )

        stats.totalAnalysesRun += 1
        lastRunTimes[domain] = Date()

        do {
            // Build domain-specific puzzle
            let puzzle = buildDomainPuzzle(domain)

            // Use ensemble for high-risk domains
            let risk = (await orchestrator.getDomainPriorities().first { $0.domain == domain })?.priority ?? 0.5

            if risk > 0.7 {
                let result = try await orchestrator.analyzeWithEnsemble(puzzle)
                await handleEnsembleResult(result, domain: domain, puzzle: puzzle)
            } else {
                let result = try await orchestrator.dispatch(puzzle)
                await handleResult(result, domain: domain, puzzle: puzzle)
            }

        } catch {
            stats.totalErrors += 1
            try? await auditLog?.recordEvent(
                id: UUID(),
                            type: ContractsCore.AuditEventType.custom,
                            principal: "continuous_reasoning",
                            module: "ContinuousReasoning",
                            description: "Domain analysis failed: \(error.localizedDescription)",
                            metadata: ["domain": domain.rawValue, "original_event_type": "systemError"]            )
        }
    }

    /// Runs analysis for a specific control.
    public func runControlAnalysis(_ controlId: String, reason: String) async {
        guard config.isEnabled else { return }

        try? await auditLog?.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.automationTriggered,
            principal: "continuous_reasoning",
            module: "ContinuousReasoning",
            description: "Control analysis started: \(controlId) - \(reason)",
            metadata: ["control_id": controlId, "reason": reason]
        )

        do {
            let result = try await reasoningService.analyzeControlBypass(
                controlId: controlId,
                protectedOperations: ["critical_operation"],
                bypassScenarios: [("direct_bypass", ["attempt"])]
            )

            if result.status == .nonCompliant {
                stats.issuesFound += 1
                for finding in result.findings {
                    await createScenarioFromControlFinding(finding, controlId: controlId)
                }
            }
        } catch {
            stats.totalErrors += 1
        }
    }

    private func handleResult(_ result: ReasoningResult, domain: ReasoningDomain, puzzle: ReasoningPuzzle) async {
        if result.outcome == .foundViolation {
            stats.issuesFound += 1

            // Create scenario
            if let scenario = await scenarioLibrary.createFromResult(
                result,
                puzzle: puzzle,
                kernelType: .generalPurpose,
                platformVersion: "1.0.0"
            ) {
                try? await auditLog?.recordEvent(
                    id: UUID(),
                    type: ContractsCore.AuditEventType.automationExecuted,
                    principal: "continuous_reasoning",
                    module: "ContinuousReasoning",
                    description: "Adversarial scenario discovered: \(scenario.title)",
                    metadata: [
                        "scenario_id": scenario.id.uuidString,
                        "domain": domain.rawValue,
                        "severity": scenario.severity.rawValue
                    ]
                )
            }
        }
    }

    private func handleEnsembleResult(_ result: EnsembleAnalysisResult, domain: ReasoningDomain, puzzle: ReasoningPuzzle) async {
        if result.hasDisagreement {
            stats.disagreementsDetected += 1

            try? await auditLog?.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.automationExecuted,
                principal: "continuous_reasoning",
                module: "ContinuousReasoning",
                description: "Ensemble disagreement: \(result.summary)",
                metadata: ["domain": domain.rawValue, "path_count": String(result.allViolationPaths.count)]
            )
        }

        // Create scenarios for all unique violation paths
        for (kernelType, kernelResult) in result.kernelResults {
            if kernelResult.outcome == .foundViolation {
                stats.issuesFound += 1

                _ = await scenarioLibrary.createFromResult(
                    kernelResult,
                    puzzle: puzzle,
                    kernelType: kernelType,
                    platformVersion: "1.0.0"
                )
            }
        }
    }

    // MARK: - Health Checks

    /// Runs a health check using meta-puzzles.
    public func runHealthCheck() async -> ReasoningHealthCheckResult {
        let suiteResult = await metaPuzzleRunner.runHealthCheck(count: 5)

        stats.healthChecksRun += 1

        if !suiteResult.allPassed {
            stats.healthCheckFailures += 1

            try? await auditLog?.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.custom,
                principal: "continuous_reasoning",
                module: "ContinuousReasoning",
                description: "Reasoning health check failed: \(suiteResult.totalFailed) of \(suiteResult.results.count) meta-puzzles failed",
                metadata: [
                    "pass_rate": String(suiteResult.passRate),
                    "total_passed": String(suiteResult.totalPassed),
                    "total_failed": String(suiteResult.totalFailed),
                    "original_event_type": "systemError"
                ]
            )
        }

        return ReasoningHealthCheckResult(
            timestamp: Date(),
            metaPuzzlesPassed: suiteResult.totalPassed,
            metaPuzzlesFailed: suiteResult.totalFailed,
            passRate: suiteResult.passRate,
            isHealthy: suiteResult.allPassed,
            failedPuzzles: suiteResult.results.filter { !$0.passed }.map { $0.metaPuzzleId }
        )
    }

    // MARK: - Statistics

    /// Gets current statistics.
    public func getStatistics() async -> ContinuousReasoningStatistics {
        var currentStats = stats
        currentStats.orchestratorStats = await orchestrator.getStatistics()
        currentStats.scenarioLibraryStats = await scenarioLibrary.getStatistics()
        return currentStats
    }

    // MARK: - Private Helpers

    private func mapModulesToDomains(_ modules: [String]) -> [ReasoningDomain] {
        var domains: [ReasoningDomain] = []

        for module in modules {
            switch module.lowercased() {
            case let m where m.contains("identity") || m.contains("access"):
                domains.append(.accessControl)
            case let m where m.contains("tenant"):
                domains.append(.tenantIsolation)
            case let m where m.contains("audit"):
                domains.append(.auditIntegrity)
            case let m where m.contains("update") || m.contains("migration"):
                domains.append(.updateSequence)
            case let m where m.contains("automation"):
                domains.append(.automationRules)
            case let m where m.contains("workflow") || m.contains("dsps") || m.contains("transcriptum"):
                domains.append(.workflowStates)
            case let m where m.contains("storage") || m.contains("lifecycle"):
                domains.append(.dataLifecycle)
            default:
                domains.append(.compliance)
            }
        }

        return Array(Set(domains))
    }

    private func buildDomainPuzzle(_ domain: ReasoningDomain) -> ReasoningPuzzle {
        // Build a generic puzzle for the domain
        // In practice, this would be more sophisticated
        switch domain {
        case .accessControl:
            return AccessControlPuzzleBuilder.buildUnauthorizedAccessPuzzle(
                principals: [("P1", ["user"], false), ("P2", ["admin"], false)],
                resources: [("R1", "restricted", ["admin"])],
                sessions: [("S1", "P1", true, true)]
            )
        case .tenantIsolation:
            return TenantIsolationPuzzleBuilder.buildCrossTenantPuzzle(
                tenants: ["T1", "T2"],
                entityTenantMap: [("E1", "T1"), ("E2", "T2")],
                operationContexts: [("C1", "T1")]
            )
        case .automationRules:
            return AutomationRulePuzzleBuilder.buildRuleLoopDetectionPuzzle(
                rules: [
                    (id: "R1", triggers: ["initial"], effects: ["step1"]),
                    (id: "R2", triggers: ["step1"], effects: ["step2"])
                ]
            )
        default:
            // Generic compliance puzzle
            return ReasoningPuzzle(
                puzzleType: .verifyCompliance,
                domain: domain,
                initialState: AbstractState(symbols: ["compliant": .boolean(true)]),
                transitions: [],
                constraints: [],
                goal: .proveInvariant(),
                maxSteps: 10
            )
        }
    }

    private func createScenarioFromControlFinding(_ finding: ComplianceFinding, controlId: String) async {
        let scenario = AdversarialScenario(
            domain: .compliance,
            affectedControls: [controlId],
            severity: finding.severity,
            violationPath: finding.bypassPath,
            initialState: AbstractState.empty,
            violatedConstraints: [finding.findingId.uuidString],
            title: "Control bypass: \(controlId)",
            description: finding.description,
            discoveredBy: .generalPurpose,
            platformVersion: "1.0.0",
            recommendation: finding.recommendation
        )

        await scenarioLibrary.add(scenario)
    }
}

// MARK: - Configuration

/// Configuration for continuous reasoning.
public struct ContinuousReasoningConfig: Sendable {
    /// Whether continuous reasoning is enabled.
    public var isEnabled: Bool

    /// Minimum interval between runs for the same domain (seconds).
    public var minIntervalBetweenRuns: TimeInterval

    /// Maximum concurrent analyses.
    public var maxConcurrentAnalyses: Int

    /// Whether to use ensemble for high-risk analyses.
    public var useEnsembleForHighRisk: Bool

    /// Health check interval (seconds).
    public var healthCheckInterval: TimeInterval

    public init(
        isEnabled: Bool = true,
        minIntervalBetweenRuns: TimeInterval = 300,
        maxConcurrentAnalyses: Int = 3,
        useEnsembleForHighRisk: Bool = true,
        healthCheckInterval: TimeInterval = 3600
    ) {
        self.isEnabled = isEnabled
        self.minIntervalBetweenRuns = minIntervalBetweenRuns
        self.maxConcurrentAnalyses = maxConcurrentAnalyses
        self.useEnsembleForHighRisk = useEnsembleForHighRisk
        self.healthCheckInterval = healthCheckInterval
    }

    public static let `default` = ContinuousReasoningConfig()

    public static let aggressive = ContinuousReasoningConfig(
        isEnabled: true,
        minIntervalBetweenRuns: 60,
        maxConcurrentAnalyses: 5,
        useEnsembleForHighRisk: true,
        healthCheckInterval: 900
    )

    public static let conservative = ContinuousReasoningConfig(
        isEnabled: true,
        minIntervalBetweenRuns: 3600,
        maxConcurrentAnalyses: 1,
        useEnsembleForHighRisk: false,
        healthCheckInterval: 86400
    )
}

// MARK: - Events

/// Events that trigger reasoning analyses.
public enum ReasoningEvent: Sendable {
    /// Code change in specific modules.
    case codeChange(modules: [String], commitId: String)

    /// Compliance deadline approaching.
    case complianceDeadline(controlId: String, daysUntil: Int)

    /// Security alert for a domain.
    case securityAlert(domain: ReasoningDomain, severity: ReasoningIssueSeverity)

    /// User-reported issue.
    case userReport(domain: ReasoningDomain, description: String)

    /// Probe failure detected.
    case probeFailure(domain: ReasoningDomain, probeId: String)

    /// Scheduled periodic run.
    case scheduledRun
}

// MARK: - Results

/// Result from a reasoning health check.
public struct ReasoningHealthCheckResult: Sendable {
    public let timestamp: Date
    public let metaPuzzlesPassed: Int
    public let metaPuzzlesFailed: Int
    public let passRate: Double
    public let isHealthy: Bool
    public let failedPuzzles: [UUID]
}

/// Statistics for continuous reasoning.
public struct ContinuousReasoningStatistics: Sendable {
    public var totalAnalysesRun: Int = 0
    public var issuesFound: Int = 0
    public var disagreementsDetected: Int = 0
    public var healthChecksRun: Int = 0
    public var healthCheckFailures: Int = 0
    public var totalErrors: Int = 0
    public var orchestratorStats: OrchestratorStatistics?
    public var scenarioLibraryStats: ScenarioLibraryStatistics?
}

// MARK: - CI/CD Integration

/// Integration point for CI/CD pipelines.
public struct CICDReasoningGate: Sendable {
    /// Minimum pass rate for meta-puzzles.
    public let minMetaPuzzlePassRate: Double

    /// Maximum allowed high-severity issues.
    public let maxHighSeverityIssues: Int

    /// Maximum allowed critical issues (blocks merge).
    public let maxCriticalIssues: Int

    /// Domains that must pass verification.
    public let requiredDomains: [ReasoningDomain]

    public init(
        minMetaPuzzlePassRate: Double = 1.0,
        maxHighSeverityIssues: Int = 0,
        maxCriticalIssues: Int = 0,
        requiredDomains: [ReasoningDomain] = [.accessControl, .tenantIsolation]
    ) {
        self.minMetaPuzzlePassRate = minMetaPuzzlePassRate
        self.maxHighSeverityIssues = maxHighSeverityIssues
        self.maxCriticalIssues = maxCriticalIssues
        self.requiredDomains = requiredDomains
    }

    public static let strict = CICDReasoningGate(
        minMetaPuzzlePassRate: 1.0,
        maxHighSeverityIssues: 0,
        maxCriticalIssues: 0,
        requiredDomains: ReasoningDomain.allCases
    )

    public static let standard = CICDReasoningGate(
        minMetaPuzzlePassRate: 0.9,
        maxHighSeverityIssues: 2,
        maxCriticalIssues: 0,
        requiredDomains: [.accessControl, .tenantIsolation, .auditIntegrity]
    )
}

/// Result from CI/CD gate evaluation.
public struct CICDGateResult: Sendable {
    /// Whether the gate passed.
    public let passed: Bool

    /// Detailed results.
    public let metaPuzzlePassRate: Double
    public let highSeverityCount: Int
    public let criticalCount: Int
    public let domainResults: [ReasoningDomain: Bool]

    /// Failure reasons (if any).
    public let failureReasons: [String]

    public init(
        passed: Bool,
        metaPuzzlePassRate: Double,
        highSeverityCount: Int,
        criticalCount: Int,
        domainResults: [ReasoningDomain: Bool],
        failureReasons: [String]
    ) {
        self.passed = passed
        self.metaPuzzlePassRate = metaPuzzlePassRate
        self.highSeverityCount = highSeverityCount
        self.criticalCount = criticalCount
        self.domainResults = domainResults
        self.failureReasons = failureReasons
    }
}

/// Evaluates CI/CD reasoning gate for a set of changes.
public actor CICDReasoningEvaluator {
    private let engine: ContinuousReasoningEngine
    private let metaPuzzleRunner: MetaPuzzleRunner
    private let scenarioLibrary: ScenarioLibrary

    public init() {
        self.engine = ContinuousReasoningEngine()
        self.metaPuzzleRunner = MetaPuzzleRunner()
        self.scenarioLibrary = ScenarioLibrary()
    }

    /// Configures the evaluator.
    public func configure(auditLog: any AuditLogging) async {
        await engine.configure(auditLog: auditLog)
        await metaPuzzleRunner.configure(auditLog: auditLog)
        await scenarioLibrary.configure(auditLog: auditLog)
    }

    /// Evaluates whether changes pass the gate.
    public func evaluate(
        changedModules: [String],
        gate: CICDReasoningGate
    ) async -> CICDGateResult {
        var failureReasons: [String] = []

        // 1. Run meta-puzzles
        let metaResult = await metaPuzzleRunner.runAll()
        let metaPassRate = metaResult.passRate

        if metaPassRate < gate.minMetaPuzzlePassRate {
            failureReasons.append("Meta-puzzle pass rate \(metaPassRate) below threshold \(gate.minMetaPuzzlePassRate)")
        }

        // 2. Run domain analyses for affected domains
        let affectedDomains = mapModulesToDomains(changedModules)
        var domainResults: [ReasoningDomain: Bool] = [:]

        for domain in gate.requiredDomains {
            if affectedDomains.contains(domain) {
                await engine.runDomainAnalysis(domain, reason: "CI/CD gate check")
            }
            // For now, mark as passed (would check scenario library)
            domainResults[domain] = true
        }

        // 3. Check scenario library for new issues
        let stats = await scenarioLibrary.getStatistics()
        let highSeverityCount = (stats.bySeverity[.high] ?? 0) + (stats.bySeverity[.critical] ?? 0)
        let criticalCount = stats.bySeverity[.critical] ?? 0

        if highSeverityCount > gate.maxHighSeverityIssues {
            failureReasons.append("High severity issues (\(highSeverityCount)) exceed threshold (\(gate.maxHighSeverityIssues))")
        }

        if criticalCount > gate.maxCriticalIssues {
            failureReasons.append("Critical issues (\(criticalCount)) exceed threshold (\(gate.maxCriticalIssues))")
        }

        let passed = failureReasons.isEmpty

        return CICDGateResult(
            passed: passed,
            metaPuzzlePassRate: metaPassRate,
            highSeverityCount: highSeverityCount,
            criticalCount: criticalCount,
            domainResults: domainResults,
            failureReasons: failureReasons
        )
    }

    private func mapModulesToDomains(_ modules: [String]) -> [ReasoningDomain] {
        var domains: [ReasoningDomain] = []

        for module in modules {
            switch module.lowercased() {
            case let m where m.contains("identity") || m.contains("access"):
                domains.append(.accessControl)
            case let m where m.contains("tenant"):
                domains.append(.tenantIsolation)
            case let m where m.contains("audit"):
                domains.append(.auditIntegrity)
            case let m where m.contains("update") || m.contains("migration"):
                domains.append(.updateSequence)
            case let m where m.contains("automation"):
                domains.append(.automationRules)
            case let m where m.contains("workflow"):
                domains.append(.workflowStates)
            case let m where m.contains("storage") || m.contains("lifecycle"):
                domains.append(.dataLifecycle)
            default:
                domains.append(.compliance)
            }
        }

        return Array(Set(domains))
    }
}

// MARK: - Suggested Probe Generator

/// Generates probe suggestions based on reasoning results.
public actor SuggestedProbeGenerator {
    /// Pending suggestions.
    private var pendingSuggestions: [ProbeSuggestion] = []

    /// Processes a reasoning result and generates probe suggestions.
    public func generateSuggestions(
        from result: ReasoningResult,
        puzzle: ReasoningPuzzle
    ) -> [ProbeSuggestion] {
        var suggestions: [ProbeSuggestion] = []

        // If violation found, suggest monitoring the violation condition
        if result.outcome == .foundViolation {
            for constraintId in result.violatedConstraints {
                if let constraint = puzzle.constraints.first(where: { $0.constraintId == constraintId }) {
                    suggestions.append(ProbeSuggestion(
                        domain: puzzle.domain,
                        name: "Monitor \(constraint.name)",
                        description: "Continuously check that \(constraint.condition.symbol) satisfies \(constraint.condition.operator_.rawValue) condition",
                        monitoredSymbol: constraint.condition.symbol,
                        threshold: describeThreshold(constraint.condition),
                        frequency: .hourly,
                        severity: constraint.severity == .critical ? .high : .medium,
                        rationale: "Discovered via adversarial analysis that this constraint can be violated via path: \(result.transitionSequence.joined(separator: " → "))"
                    ))
                }
            }
        }

        // If exploration found multiple paths to similar states, suggest monitoring state distribution
        if result.stepsExplored > 50 {
            suggestions.append(ProbeSuggestion(
                domain: puzzle.domain,
                name: "State distribution monitor for \(puzzle.domain.rawValue)",
                description: "Track distribution of states reached in this domain",
                monitoredSymbol: "state_distribution",
                threshold: "Unusual state distribution",
                frequency: .daily,
                severity: .low,
                rationale: "Large state space (\(result.stepsExplored) states) suggests value in distribution monitoring"
            ))
        }

        for suggestion in suggestions {
            pendingSuggestions.append(suggestion)
        }

        return suggestions
    }

    /// Gets pending suggestions.
    public func getPendingSuggestions() -> [ProbeSuggestion] {
        pendingSuggestions
    }

    /// Marks a suggestion as accepted.
    public func acceptSuggestion(_ id: UUID) {
        pendingSuggestions.removeAll { $0.id == id }
    }

    /// Marks a suggestion as rejected.
    public func rejectSuggestion(_ id: UUID) {
        pendingSuggestions.removeAll { $0.id == id }
    }

    private func describeThreshold(_ condition: AbstractCondition) -> String {
        switch condition.operator_ {
        case .equals:
            return "Must equal \(describeValue(condition.value))"
        case .notEquals:
            return "Must not equal \(describeValue(condition.value))"
        case .greaterThan:
            return "Must be greater than \(describeValue(condition.value))"
        case .lessThan:
            return "Must be less than \(describeValue(condition.value))"
        case .contains:
            return "Must contain \(describeValue(condition.value))"
        case .isNil:
            return "Must be nil"
        case .isNotNil:
            return "Must not be nil"
        }
    }

    private func describeValue(_ value: SymbolValue) -> String {
        switch value {
        case .boolean(let v): return String(v)
        case .integer(let v): return String(v)
        case .category(let v): return v
        case .set(let v): return "{\(v.joined(separator: ", "))}"
        }
    }
}

/// A suggested probe based on reasoning analysis.
public struct ProbeSuggestion: Sendable, Identifiable {
    public let id: UUID
    public let domain: ReasoningDomain
    public let name: String
    public let description: String
    public let monitoredSymbol: String
    public let threshold: String
    public let frequency: ReasoningProbeFrequency
    public let severity: ReasoningIssueSeverity
    public let rationale: String
    public let suggestedAt: Date

    public init(
        id: UUID = UUID(),
        domain: ReasoningDomain,
        name: String,
        description: String,
        monitoredSymbol: String,
        threshold: String,
        frequency: ReasoningProbeFrequency,
        severity: ReasoningIssueSeverity,
        rationale: String,
        suggestedAt: Date = Date()
    ) {
        self.id = id
        self.domain = domain
        self.name = name
        self.description = description
        self.monitoredSymbol = monitoredSymbol
        self.threshold = threshold
        self.frequency = frequency
        self.severity = severity
        self.rationale = rationale
        self.suggestedAt = suggestedAt
    }
}

/// Probe check frequency for reasoning.
public enum ReasoningProbeFrequency: String, Sendable, Codable {
    case realtime = "realtime"
    case minutely = "minutely"
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
}
