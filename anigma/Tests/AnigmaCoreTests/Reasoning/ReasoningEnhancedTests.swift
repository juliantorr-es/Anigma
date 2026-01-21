//
//  ReasoningEnhancedTests.swift
//  AnigmaCoreTests
//
//  Tests for the enhanced reasoning kernel features:
//  - Multi-gremlin orchestrator
//  - Adversarial scenario library
//  - Meta-puzzles
//  - Continuous reasoning
//  - CI/CD integration
//

import Testing
import Foundation
@testable import AnigmaCore

@Suite("Reasoning Orchestrator Tests")
struct ReasoningOrchestratorTests {

    @Test("Orchestrator dispatches to appropriate kernel")
    func testKernelDispatch() async throws {
        let orchestrator = ReasoningOrchestrator()
        let auditLog = AuditLog()
        await orchestrator.configure(auditLog: auditLog)

        // Simple puzzle for access control domain
        let puzzle = ReasoningPuzzle(
            puzzleType: .verifyCompliance,
            domain: .accessControl,
            initialState: AbstractState(symbols: ["safe": .boolean(true)]),
            transitions: [],
            constraints: [],
            goal: .proveInvariant(),
            maxSteps: 10
        )

        let result = try await orchestrator.dispatch(puzzle)

        #expect(result.outcome == .provedInvariant || result.outcome == .notFound)
    }

    @Test("Ensemble analysis runs multiple kernels")
    func testEnsembleAnalysis() async throws {
        let orchestrator = ReasoningOrchestrator()
        let auditLog = AuditLog()
        await orchestrator.configure(auditLog: auditLog)

        let puzzle = ReasoningPuzzle(
            puzzleType: .verifyCompliance,
            domain: .accessControl,
            initialState: AbstractState(symbols: ["value": .integer(0)]),
            transitions: [
                AbstractTransition(
                    transitionId: "inc",
                    name: "Increment",
                    effects: [AbstractEffect(symbol: "value", effectType: .increment, value: .integer(1))]
                )
            ],
            constraints: [
                AbstractConstraint(
                    constraintId: "bounded",
                    name: "Value must be bounded",
                    condition: AbstractCondition(symbol: "value", operator_: .lessThan, value: .integer(5)),
                    severity: .violation
                )
            ],
            goal: .proveInvariant(),
            maxSteps: 10
        )

        let result = try await orchestrator.analyzeWithEnsemble(puzzle)

        #expect(!result.kernelResults.isEmpty)
        #expect(result.combinedConfidence >= 0)
    }

    @Test("Domain risk scores update correctly")
    func testDomainRiskScores() async throws {
        let orchestrator = ReasoningOrchestrator()

        // Initial priorities should exist
        let initialPriorities = await orchestrator.getDomainPriorities()
        #expect(!initialPriorities.isEmpty)

        // Update risk for access control
        await orchestrator.updateDomainRisk(.accessControl, factor: .recentCodeChange, magnitude: 0.8)

        let updatedPriorities = await orchestrator.getDomainPriorities()
        let accessControlPriority = updatedPriorities.first { $0.domain == .accessControl }?.priority ?? 0

        #expect(accessControlPriority > 0.5)
    }

    @Test("Orchestrator suggests next analyses based on risk")
    func testAnalysisSuggestions() async throws {
        let orchestrator = ReasoningOrchestrator()

        // Boost risk for specific domains
        await orchestrator.updateDomainRisk(.tenantIsolation, factor: .externalThreatIntel, magnitude: 1.0)
        await orchestrator.updateDomainRisk(.accessControl, factor: .recentProbeFailure, magnitude: 0.5)

        let suggestions = await orchestrator.suggestNextAnalyses(count: 3)

        #expect(suggestions.count <= 3)
        #expect(suggestions.contains(.tenantIsolation))
    }

    @Test("Orchestrator tracks statistics")
    func testOrchestratorStatistics() async throws {
        let orchestrator = ReasoningOrchestrator()
        let auditLog = AuditLog()
        await orchestrator.configure(auditLog: auditLog)

        // Run some analyses
        let puzzle = ReasoningPuzzle(
            puzzleType: .findPath,
            domain: .workflowStates,
            initialState: AbstractState(),
            transitions: [],
            goal: .reach([]),
            maxSteps: 5
        )

        _ = try await orchestrator.dispatch(puzzle)
        _ = try await orchestrator.analyzeWithEnsemble(puzzle)

        let stats = await orchestrator.getStatistics()

        #expect(stats.ensembleAnalysesRun == 1)
        #expect(!stats.kernelStatistics.isEmpty)
    }
}

@Suite("Adversarial Scenario Library Tests")
struct AdversarialScenarioLibraryTests {

    @Test("Add and retrieve scenario")
    func testAddAndRetrieve() async throws {
        let library = ScenarioLibrary()

        let scenario = AdversarialScenario(
            domain: .accessControl,
            affectedControls: ["AC-2", "AC-3"],
            severity: .high,
            violationPath: ["step1", "step2"],
            initialState: AbstractState(symbols: ["x": .integer(0)]),
            violatedConstraints: ["constraint1"],
            title: "Test Scenario",
            description: "A test adversarial scenario",
            discoveredBy: .controlAttacker,
            platformVersion: "1.0.0",
            recommendation: "Fix the issue"
        )

        await library.add(scenario)

        let retrieved = await library.get(scenario.id)
        #expect(retrieved != nil)
        #expect(retrieved?.title == "Test Scenario")
    }

    @Test("Query scenarios by domain")
    func testQueryByDomain() async throws {
        let library = ScenarioLibrary()

        let scenario1 = AdversarialScenario(
            domain: .accessControl,
            affectedControls: ["AC-2"],
            severity: .high,
            violationPath: [],
            initialState: AbstractState.empty,
            violatedConstraints: [],
            title: "Access Control Scenario",
            description: "",
            discoveredBy: .controlAttacker,
            platformVersion: "1.0.0",
            recommendation: ""
        )

        let scenario2 = AdversarialScenario(
            domain: .tenantIsolation,
            affectedControls: ["SC-4"],
            severity: .critical,
            violationPath: [],
            initialState: AbstractState.empty,
            violatedConstraints: [],
            title: "Tenant Isolation Scenario",
            description: "",
            discoveredBy: .tenantProber,
            platformVersion: "1.0.0",
            recommendation: ""
        )

        await library.add(scenario1)
        await library.add(scenario2)

        let accessScenarios = await library.getByDomain(.accessControl)
        let tenantScenarios = await library.getByDomain(.tenantIsolation)

        #expect(accessScenarios.count == 1)
        #expect(tenantScenarios.count == 1)
        #expect(accessScenarios[0].title == "Access Control Scenario")
    }

    @Test("Update scenario status")
    func testStatusUpdate() async throws {
        let library = ScenarioLibrary()
        let auditLog = AuditLog()
        await library.configure(auditLog: auditLog)

        let scenario = AdversarialScenario(
            domain: .accessControl,
            affectedControls: [],
            severity: .medium,
            violationPath: [],
            initialState: AbstractState.empty,
            violatedConstraints: [],
            title: "Test",
            description: "",
            discoveredBy: .generalPurpose,
            platformVersion: "1.0.0",
            status: .open,
            recommendation: ""
        )

        await library.add(scenario)

        let resolution = ScenarioResolution(
            resolutionType: .codeFix,
            description: "Fixed the bug",
            fixedInVersion: "1.0.1",
            resolvedBy: "developer"
        )

        let updated = await library.updateStatus(scenario.id, newStatus: .resolved, resolution: resolution)
        #expect(updated)

        let retrieved = await library.get(scenario.id)
        #expect(retrieved?.status == .resolved)
        #expect(retrieved?.resolution?.fixedInVersion == "1.0.1")
    }

    @Test("Get regression test candidates")
    func testRegressionCandidates() async throws {
        let library = ScenarioLibrary()

        // Add open scenario
        let openScenario = AdversarialScenario(
            domain: .accessControl,
            affectedControls: [],
            severity: .high,
            violationPath: ["path1"],
            initialState: AbstractState.empty,
            violatedConstraints: [],
            title: "Open Issue",
            description: "",
            discoveredBy: .generalPurpose,
            platformVersion: "1.0.0",
            status: .open,
            recommendation: ""
        )

        // Add resolved scenario
        let resolvedScenario = AdversarialScenario(
            domain: .tenantIsolation,
            affectedControls: [],
            severity: .critical,
            violationPath: ["path2"],
            initialState: AbstractState.empty,
            violatedConstraints: [],
            title: "Resolved Issue",
            description: "",
            discoveredBy: .tenantProber,
            platformVersion: "1.0.0",
            status: .resolved,
            recommendation: ""
        )

        await library.add(openScenario)
        await library.add(resolvedScenario)

        let candidates = await library.getRegressionTestCandidates()

        #expect(candidates.count == 1)
        #expect(candidates[0].title == "Resolved Issue")
    }

    @Test("Library statistics are accurate")
    func testLibraryStatistics() async throws {
        let library = ScenarioLibrary()

        await library.add(AdversarialScenario(
            domain: .accessControl,
            affectedControls: [],
            severity: .high,
            violationPath: [],
            initialState: AbstractState.empty,
            violatedConstraints: [],
            title: "1",
            description: "",
            discoveredBy: .generalPurpose,
            platformVersion: "1.0.0",
            status: .open,
            recommendation: ""
        ))

        await library.add(AdversarialScenario(
            domain: .accessControl,
            affectedControls: [],
            severity: .critical,
            violationPath: [],
            initialState: AbstractState.empty,
            violatedConstraints: [],
            title: "2",
            description: "",
            discoveredBy: .generalPurpose,
            platformVersion: "1.0.0",
            status: .resolved,
            recommendation: ""
        ))

        let stats = await library.getStatistics()

        #expect(stats.totalScenarios == 2)
        #expect(stats.openCount == 1)
        #expect(stats.resolvedCount == 1)
        #expect(stats.bySeverity[.high] == 1)
        #expect(stats.bySeverity[.critical] == 1)
    }
}

@Suite("Meta-Puzzle Tests")
struct MetaPuzzleTests {

    @Test("Standard meta-puzzles are defined")
    func testStandardMetaPuzzles() {
        let allPuzzles = StandardMetaPuzzles.all

        #expect(allPuzzles.count >= 10)

        // Check all categories are represented
        let categories = Set(allPuzzles.map { $0.category })
        #expect(categories.contains(.provablyUnbreakable))
        #expect(categories.contains(.knownCounterexample))
        #expect(categories.contains(.unsatisfiable))
    }

    @Test("Trivially unbreakable puzzle proves invariant")
    func testTriviallyUnbreakable() async throws {
        let runner = MetaPuzzleRunner()
        let metaPuzzle = StandardMetaPuzzles.triviallyUnbreakable()

        let result = await runner.run(metaPuzzle)

        #expect(result.passed)
        #expect(result.outcomeMatched)
        #expect(result.actualResult.outcome == .provedInvariant)
    }

    @Test("Trivial violation puzzle finds violation")
    func testTrivialViolation() async throws {
        let runner = MetaPuzzleRunner()
        let metaPuzzle = StandardMetaPuzzles.trivialViolation()

        let result = await runner.run(metaPuzzle)

        #expect(result.passed)
        #expect(result.outcomeMatched)
        #expect(result.actualResult.outcome == .foundViolation)
    }

    @Test("Two-step violation puzzle finds correct path")
    func testTwoStepViolation() async throws {
        let runner = MetaPuzzleRunner()
        let metaPuzzle = StandardMetaPuzzles.twoStepViolation()

        let result = await runner.run(metaPuzzle)

        #expect(result.passed)
        #expect(result.actualResult.outcome == .foundViolation)
        #expect(result.actualResult.transitionSequence == ["step1", "step2"])
    }

    @Test("Impossible goal puzzle returns not found")
    func testImpossibleGoal() async throws {
        let runner = MetaPuzzleRunner()
        let metaPuzzle = StandardMetaPuzzles.impossibleGoal()

        let result = await runner.run(metaPuzzle)

        #expect(result.passed)
        #expect(result.actualResult.outcome == .notFound)
    }

    @Test("Run all meta-puzzles")
    func testRunAllMetaPuzzles() async throws {
        let runner = MetaPuzzleRunner()

        let suiteResult = await runner.runAll()

        #expect(suiteResult.results.count == StandardMetaPuzzles.all.count)
        // Most should pass
        #expect(suiteResult.passRate > 0.8)
    }

    @Test("Health check runs subset")
    func testHealthCheck() async throws {
        let runner = MetaPuzzleRunner()

        let result = await runner.runHealthCheck(count: 3)

        #expect(result.results.count == 3)
    }

    @Test("Runner tracks pass rate")
    func testPassRateTracking() async throws {
        let runner = MetaPuzzleRunner()

        // Get the puzzle once and reuse it (same ID)
        let metaPuzzle = StandardMetaPuzzles.triviallyUnbreakable()

        // Run same puzzle multiple times
        var lastResult: MetaPuzzleResult?
        for _ in 0..<3 {
            lastResult = await runner.run(metaPuzzle)
        }

        // Check the pass rate for the puzzle we actually ran
        let passRate = await runner.getPassRate(for: metaPuzzle.id)

        // Pass rate should be non-nil and should reflect results
        #expect(passRate != nil)
        if lastResult?.passed == true {
            #expect(passRate == 1.0)
        }
    }
}

@Suite("Continuous Reasoning Tests")
struct ContinuousReasoningTests {

    @Test("Engine processes events")
    func testEventProcessing() async throws {
        let engine = ContinuousReasoningEngine(config: .aggressive)
        let auditLog = AuditLog()
        await engine.configure(auditLog: auditLog)

        // Queue some events
        await engine.queueEvent(.codeChange(modules: ["Identity"], commitId: "abc123"))
        await engine.queueEvent(.scheduledRun)

        // Process them
        await engine.processPendingEvents()

        let stats = await engine.getStatistics()
        #expect(stats.totalAnalysesRun > 0)
    }

    @Test("Health check works")
    func testHealthCheck() async throws {
        let engine = ContinuousReasoningEngine()
        let auditLog = AuditLog()
        await engine.configure(auditLog: auditLog)

        let result = await engine.runHealthCheck()

        #expect(result.metaPuzzlesPassed + result.metaPuzzlesFailed == 5)
    }

    @Test("Domain analysis runs")
    func testDomainAnalysis() async throws {
        let engine = ContinuousReasoningEngine(config: ContinuousReasoningConfig(
            isEnabled: true,
            minIntervalBetweenRuns: 0  // No cooldown for testing
        ))
        let auditLog = AuditLog()
        await engine.configure(auditLog: auditLog)

        await engine.runDomainAnalysis(.accessControl, reason: "Test")

        let stats = await engine.getStatistics()
        #expect(stats.totalAnalysesRun >= 1)
    }

    @Test("Configuration modes work")
    func testConfigurationModes() {
        let defaultConfig = ContinuousReasoningConfig.default
        let aggressive = ContinuousReasoningConfig.aggressive
        let conservative = ContinuousReasoningConfig.conservative

        #expect(aggressive.minIntervalBetweenRuns < defaultConfig.minIntervalBetweenRuns)
        #expect(conservative.minIntervalBetweenRuns > defaultConfig.minIntervalBetweenRuns)
        #expect(aggressive.maxConcurrentAnalyses > conservative.maxConcurrentAnalyses)
    }
}

@Suite("CI/CD Reasoning Gate Tests")
struct CICDReasoningGateTests {

    @Test("Gate configurations exist")
    func testGateConfigurations() {
        let strict = CICDReasoningGate.strict
        let standard = CICDReasoningGate.standard

        #expect(strict.minMetaPuzzlePassRate == 1.0)
        #expect(strict.maxCriticalIssues == 0)
        #expect(standard.minMetaPuzzlePassRate < strict.minMetaPuzzlePassRate)
    }

    @Test("Evaluator runs gate check")
    func testEvaluatorRuns() async throws {
        let evaluator = CICDReasoningEvaluator()
        let auditLog = AuditLog()
        await evaluator.configure(auditLog: auditLog)

        let result = await evaluator.evaluate(
            changedModules: ["Identity", "Tenant"],
            gate: .standard
        )

        #expect(result.metaPuzzlePassRate >= 0)
        #expect(!result.domainResults.isEmpty)
    }
}

@Suite("Probe Suggestion Tests")
struct ProbeSuggestionTests {

    @Test("Generator creates suggestions from violations")
    func testSuggestionGeneration() async throws {
        let generator = SuggestedProbeGenerator()

        let puzzle = ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: AbstractState(),
            transitions: [],
            constraints: [
                AbstractConstraint(
                    constraintId: "access_check",
                    name: "Access must be validated",
                    condition: AbstractCondition(symbol: "validated", operator_: .equals, value: .boolean(true)),
                    severity: .critical
                )
            ],
            goal: .violate(["access_check"]),
            maxSteps: 10
        )

        let result = ReasoningResult(
            puzzleId: puzzle.puzzleId,
            outcome: .foundViolation,
            transitionSequence: ["bypass_access"],
            violatedConstraints: ["access_check"],
            stepsExplored: 5,
            durationMs: 100,
            explanation: "Found bypass"
        )

        let suggestions = await generator.generateSuggestions(from: result, puzzle: puzzle)

        #expect(!suggestions.isEmpty)
        #expect(suggestions[0].domain == .accessControl)
        #expect(suggestions[0].severity == .high)
    }

    @Test("Suggestions can be accepted or rejected")
    func testSuggestionManagement() async throws {
        let generator = SuggestedProbeGenerator()

        let puzzle = ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: AbstractState(),
            transitions: [],
            constraints: [
                AbstractConstraint(
                    constraintId: "test",
                    name: "Test",
                    condition: AbstractCondition(symbol: "x", operator_: .equals, value: .boolean(true)),
                    severity: .violation
                )
            ],
            goal: .violate(["test"]),
            maxSteps: 5
        )

        let result = ReasoningResult(
            puzzleId: puzzle.puzzleId,
            outcome: .foundViolation,
            violatedConstraints: ["test"],
            stepsExplored: 1,
            durationMs: 10
        )

        let suggestions = await generator.generateSuggestions(from: result, puzzle: puzzle)
        let pending = await generator.getPendingSuggestions()

        #expect(pending.count == suggestions.count)

        if let first = suggestions.first {
            await generator.acceptSuggestion(first.id)
            let remaining = await generator.getPendingSuggestions()
            #expect(remaining.count == suggestions.count - 1)
        }
    }
}
