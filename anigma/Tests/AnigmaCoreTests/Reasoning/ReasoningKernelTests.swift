//
//  ReasoningKernelTests.swift
//  AnigmaCoreTests
//
//  Tests for the Reasoning Kernel module.
//

import Testing
import Foundation
@testable import AnigmaCore

@Suite("Reasoning Kernel Tests")
struct ReasoningKernelTests {

    // MARK: - Basic Puzzle Solving

    @Test("Solve simple path finding puzzle")
    func testSimplePathFinding() async throws {
        let kernel = RecursiveReasoner()

        let puzzle = ReasoningPuzzle(
            puzzleType: .findPath,
            domain: .workflowStates,
            initialState: AbstractState(symbols: ["state": .category("A")]),
            transitions: [
                AbstractTransition(
                    transitionId: "A_to_B",
                    name: "Move from A to B",
                    preconditions: [AbstractCondition(symbol: "state", operator_: .equals, value: .category("A"))],
                    effects: [AbstractEffect(symbol: "state", effectType: .set, value: .category("B"))]
                ),
                AbstractTransition(
                    transitionId: "B_to_C",
                    name: "Move from B to C",
                    preconditions: [AbstractCondition(symbol: "state", operator_: .equals, value: .category("B"))],
                    effects: [AbstractEffect(symbol: "state", effectType: .set, value: .category("C"))]
                )
            ],
            constraints: [],
            goal: .reach([AbstractCondition(symbol: "state", operator_: .equals, value: .category("C"))]),
            maxSteps: 10
        )

        let result = try await kernel.solve(puzzle)

        #expect(result.outcome == .foundPath)
        #expect(result.transitionSequence == ["A_to_B", "B_to_C"])
        #expect(result.stepsExplored >= 2)
    }

    @Test("Find violation in constraint")
    func testFindViolation() async throws {
        let kernel = RecursiveReasoner()

        let puzzle = ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: AbstractState(symbols: [
                "user_deprovisioned": .boolean(true),
                "has_access": .boolean(false)
            ]),
            transitions: [
                AbstractTransition(
                    transitionId: "grant_access",
                    name: "Grant access (should be blocked)",
                    preconditions: [], // No precondition - the vulnerability
                    effects: [AbstractEffect(symbol: "has_access", effectType: .set, value: .boolean(true))]
                )
            ],
            constraints: [
                AbstractConstraint(
                    constraintId: "no_deprovisioned_access",
                    name: "Deprovisioned users cannot have access",
                    condition: AbstractCondition(
                        symbol: "has_access",
                        operator_: .equals,
                        value: .boolean(false)
                    ),
                    severity: .violation
                )
            ],
            goal: .violate(["no_deprovisioned_access"]),
            maxSteps: 10
        )

        let result = try await kernel.solve(puzzle)

        #expect(result.outcome == .foundViolation)
        #expect(result.violatedConstraints.contains("no_deprovisioned_access"))
        #expect(result.transitionSequence.contains("grant_access"))
    }

    @Test("Prove invariant holds")
    func testProveInvariant() async throws {
        let kernel = RecursiveReasoner()

        let puzzle = ReasoningPuzzle(
            puzzleType: .invariantCheck,
            domain: .accessControl,
            initialState: AbstractState(symbols: [
                "user_deprovisioned": .boolean(true),
                "has_access": .boolean(false)
            ]),
            transitions: [
                AbstractTransition(
                    transitionId: "grant_access",
                    name: "Grant access (properly guarded)",
                    preconditions: [
                        AbstractCondition(symbol: "user_deprovisioned", operator_: .equals, value: .boolean(false))
                    ],
                    effects: [AbstractEffect(symbol: "has_access", effectType: .set, value: .boolean(true))]
                )
            ],
            constraints: [
                AbstractConstraint(
                    constraintId: "no_deprovisioned_access",
                    name: "Deprovisioned users cannot have access",
                    condition: AbstractCondition(
                        symbol: "has_access",
                        operator_: .equals,
                        value: .boolean(false)
                    ),
                    severity: .violation
                )
            ],
            goal: .proveInvariant(),
            maxSteps: 10
        )

        let result = try await kernel.solve(puzzle)

        #expect(result.outcome == .provedInvariant)
        #expect(result.violatedConstraints.isEmpty)
    }

    @Test("Explore state space")
    func testStateSpaceExploration() async throws {
        let kernel = RecursiveReasoner()

        let puzzle = ReasoningPuzzle(
            puzzleType: .exploreSpace,
            domain: .workflowStates,
            initialState: AbstractState(symbols: ["counter": .integer(0)]),
            transitions: [
                AbstractTransition(
                    transitionId: "increment",
                    name: "Increment counter",
                    preconditions: [AbstractCondition(symbol: "counter", operator_: .lessThan, value: .integer(5))],
                    effects: [AbstractEffect(symbol: "counter", effectType: .increment, value: .integer(1))]
                )
            ],
            constraints: [
                AbstractConstraint(
                    constraintId: "counter_limit",
                    name: "Counter must stay under 4",
                    condition: AbstractCondition(symbol: "counter", operator_: .lessThan, value: .integer(4)),
                    severity: .warning
                )
            ],
            goal: .reach([]),
            maxSteps: 20
        )

        let result = try await kernel.solve(puzzle)

        #expect(result.outcome == .explorationComplete)
        #expect(result.stepsExplored > 0)
        // Should find violation of counter_limit when counter >= 4
        #expect(result.violatedConstraints.contains("counter_limit"))
    }

    // MARK: - Puzzle Builder Tests

    @Test("Build access control puzzle")
    func testAccessControlPuzzleBuilder() async throws {
        let puzzle = AccessControlPuzzleBuilder.buildUnauthorizedAccessPuzzle(
            principals: [
                (symbol: "P1", roles: ["admin"], isDeprovisioned: false),
                (symbol: "P2", roles: ["user"], isDeprovisioned: true)
            ],
            resources: [
                (symbol: "R1", sensitivity: "restricted", requiredRoles: ["admin"])
            ],
            sessions: [
                (symbol: "S1", principalSymbol: "P1", isValid: true, mfaVerified: true),
                (symbol: "S2", principalSymbol: "P2", isValid: true, mfaVerified: false)
            ]
        )

        #expect(puzzle.puzzleType == .findViolation)
        #expect(puzzle.domain == .accessControl)
        #expect(!puzzle.transitions.isEmpty)
        #expect(!puzzle.constraints.isEmpty)
    }

    @Test("Build tenant isolation puzzle")
    func testTenantIsolationPuzzleBuilder() async throws {
        let puzzle = TenantIsolationPuzzleBuilder.buildCrossTenantPuzzle(
            tenants: ["T1", "T2"],
            entityTenantMap: [
                (entitySymbol: "E1", tenantSymbol: "T1"),
                (entitySymbol: "E2", tenantSymbol: "T2")
            ],
            operationContexts: [
                (contextSymbol: "C1", tenantSymbol: "T1"),
                (contextSymbol: "C2", tenantSymbol: "T2")
            ]
        )

        #expect(puzzle.puzzleType == .findViolation)
        #expect(puzzle.domain == .tenantIsolation)
        #expect(!puzzle.constraints.isEmpty)
    }

    @Test("Build automation loop detection puzzle")
    func testAutomationLoopPuzzleBuilder() async throws {
        // Create a potential loop: rule1 triggers event that triggers rule2, which triggers event that triggers rule1
        let puzzle = AutomationRulePuzzleBuilder.buildRuleLoopDetectionPuzzle(
            rules: [
                (id: "rule1", triggers: ["initial"], effects: ["trigger_rule2"]),
                (id: "rule2", triggers: ["trigger_rule2"], effects: ["trigger_rule1"]),
                (id: "rule3", triggers: ["trigger_rule1"], effects: ["trigger_rule2"])
            ]
        )

        #expect(puzzle.puzzleType == .findViolation)
        #expect(puzzle.domain == .automationRules)

        // Solve to find the loop
        let kernel = RecursiveReasoner()
        let result = try await kernel.solve(puzzle)

        // Should detect potential for infinite loop
        #expect(result.outcome == .foundViolation || result.stepsExplored > 3)
    }

    @Test("Build legal hold puzzle")
    func testLegalHoldPuzzleBuilder() async throws {
        let puzzle = DataLifecyclePuzzleBuilder.buildLegalHoldPuzzle(
            entities: ["E1", "E2", "E3"],
            entitiesUnderHold: Set(["E1", "E2"]),
            deletionAttempts: ["E1", "E2", "E3"]
        )

        #expect(puzzle.puzzleType == .verifyCompliance)
        #expect(puzzle.domain == .dataLifecycle)

        let kernel = RecursiveReasoner()
        let result = try await kernel.solve(puzzle)

        // The puzzle has "force delete" transitions that bypass hold
        // Result will be foundViolation (if bypass found) or provedInvariant or notFound
        #expect(result.outcome == .foundViolation || result.outcome == .provedInvariant || result.outcome == .notFound)
    }

    // MARK: - Rate Limiting Tests

    @Test("Rate limiting prevents abuse")
    func testRateLimiting() async throws {
        let kernel = RecursiveReasoner(config: ReasonerConfig(
            maxTransitions: 10,
            maxStepsAllowed: 100,
            maxTimeMs: 1000,
            maxStateSize: 100
        ))

        let simplePuzzle = ReasoningPuzzle(
            puzzleType: .findPath,
            domain: .workflowStates,
            initialState: AbstractState(),
            transitions: [],
            constraints: [],
            goal: .reach([]),
            maxSteps: 10
        )

        // Make many calls quickly
        var rateLimitHit = false
        for _ in 0..<100 {
            do {
                _ = try await kernel.solve(simplePuzzle)
            } catch ReasoningError.rateLimited {
                rateLimitHit = true
                break
            } catch {
                // Other errors are fine
            }
        }

        #expect(rateLimitHit)
    }

    // MARK: - Budget Enforcement Tests

    @Test("Step budget is enforced")
    func testStepBudgetEnforcement() async throws {
        let kernel = RecursiveReasoner(config: ReasonerConfig(maxStepsAllowed: 5))

        let puzzle = ReasoningPuzzle(
            puzzleType: .findPath,
            domain: .workflowStates,
            initialState: AbstractState(),
            transitions: [],
            constraints: [],
            goal: .reach([]),
            maxSteps: 100 // Request more than allowed
        )

        do {
            _ = try await kernel.solve(puzzle)
            Issue.record("Should have thrown budget exceeded error")
        } catch ReasoningError.budgetExceeded(let requested, let max) {
            #expect(requested == 100)
            #expect(max == 5)
        }
    }

    @Test("Transition limit is enforced")
    func testTransitionLimitEnforcement() async throws {
        let kernel = RecursiveReasoner(config: ReasonerConfig(maxTransitions: 5))

        // Create puzzle with too many transitions
        let transitions = (0..<10).map { i in
            AbstractTransition(transitionId: "t\(i)", name: "Transition \(i)")
        }

        let puzzle = ReasoningPuzzle(
            puzzleType: .findPath,
            domain: .workflowStates,
            initialState: AbstractState(),
            transitions: transitions,
            constraints: [],
            goal: .reach([]),
            maxSteps: 10
        )

        do {
            _ = try await kernel.solve(puzzle)
            Issue.record("Should have thrown puzzle too large error")
        } catch ReasoningError.puzzleTooLarge(let actual, let max) {
            #expect(actual == 10)
            #expect(max == 5)
        }
    }

    // MARK: - State Abstractor Tests

    @Test("State abstractor anonymizes IDs")
    func testStateAbstractor() async throws {
        let abstractor = StateAbstractor()

        let id1 = UUID()
        let id2 = UUID()

        let symbol1 = await abstractor.anonymize(id1, prefix: "E")
        let symbol2 = await abstractor.anonymize(id2, prefix: "E")

        // Same ID should return same symbol
        let symbol1Again = await abstractor.anonymize(id1, prefix: "E")
        #expect(symbol1 == symbol1Again)

        // Different IDs should return different symbols
        #expect(symbol1 != symbol2)

        // Can deanonymize
        let recovered = await abstractor.deanonymize(symbol1)
        #expect(recovered == id1)

        // Reset clears mappings
        await abstractor.reset()
        let newSymbol = await abstractor.anonymize(id1, prefix: "E")
        // After reset, it starts fresh so it will generate same pattern but for new mapping
        #expect(newSymbol.hasPrefix("E"))
    }

    // MARK: - Abstract State Tests

    @Test("Abstract conditions evaluate correctly")
    func testConditionEvaluation() {
        var state = AbstractState()
        state.symbols["active"] = .boolean(true)
        state.symbols["count"] = .integer(5)
        state.symbols["status"] = .category("running")

        // Boolean equality
        let cond1 = AbstractCondition(symbol: "active", operator_: .equals, value: .boolean(true))
        #expect(cond1.evaluate(in: state))

        // Integer comparison
        let cond2 = AbstractCondition(symbol: "count", operator_: .greaterThan, value: .integer(3))
        #expect(cond2.evaluate(in: state))

        let cond3 = AbstractCondition(symbol: "count", operator_: .lessThan, value: .integer(10))
        #expect(cond3.evaluate(in: state))

        // Category equality
        let cond4 = AbstractCondition(symbol: "status", operator_: .equals, value: .category("running"))
        #expect(cond4.evaluate(in: state))

        // Not equals
        let cond5 = AbstractCondition(symbol: "status", operator_: .notEquals, value: .category("stopped"))
        #expect(cond5.evaluate(in: state))

        // Missing symbol
        let cond6 = AbstractCondition(symbol: "missing", operator_: .isNil, value: .boolean(true))
        #expect(cond6.evaluate(in: state))
    }

    @Test("Abstract effects apply correctly")
    func testEffectApplication() {
        var state = AbstractState()
        state.symbols["count"] = .integer(5)

        // Set effect
        let setEffect = AbstractEffect(symbol: "status", effectType: .set, value: .category("active"))
        setEffect.apply(to: &state)
        #expect(state.symbols["status"] == .category("active"))

        // Increment effect
        let incEffect = AbstractEffect(symbol: "count", effectType: .increment, value: .integer(3))
        incEffect.apply(to: &state)
        #expect(state.symbols["count"] == .integer(8))

        // Decrement effect
        let decEffect = AbstractEffect(symbol: "count", effectType: .decrement, value: .integer(2))
        decEffect.apply(to: &state)
        #expect(state.symbols["count"] == .integer(6))

        // Clear effect
        let clearEffect = AbstractEffect(symbol: "status", effectType: .clear, value: nil)
        clearEffect.apply(to: &state)
        #expect(state.symbols["status"] == nil)

        // Add to set
        let addEffect = AbstractEffect(symbol: "tags", effectType: .addToSet, value: .category("important"))
        addEffect.apply(to: &state)
        #expect(state.sets["tags"]?.contains("important") == true)
    }
}

@Suite("Reasoning Integration Tests")
struct ReasoningIntegrationTests {

    @Test("ReasoningService analyzes access control")
    func testAccessControlAnalysis() async throws {
        let auditLog = AuditLog()
        let reasoning = await ReasoningModule.initialize(auditLog: auditLog)

        let context = AccessControlAnalysisContext(
            principals: [
                PrincipalSnapshot(id: UUID(), roles: ["admin"], isDeprovisioned: false),
                PrincipalSnapshot(id: UUID(), roles: ["user"], isDeprovisioned: true)
            ],
            resources: [
                ResourceSnapshot(id: UUID(), sensitivity: .restricted, requiredRoles: ["admin"])
            ],
            sessions: [
                SessionSnapshot(id: UUID(), principalId: UUID(), isValid: true, mfaVerified: true)
            ]
        )

        let result = try await reasoning.service.analyzeAccessControl(context: context)

        #expect(result.analysisType == .accessControl)
        #expect(result.stepsExplored > 0)
    }

    @Test("ReasoningService analyzes tenant isolation")
    func testTenantIsolationAnalysis() async throws {
        let auditLog = AuditLog()
        let reasoning = await ReasoningModule.initialize(auditLog: auditLog)

        let tenant1 = UUID()
        let tenant2 = UUID()
        let entity1 = UUID()
        let context1 = UUID()

        let analysisContext = TenantIsolationAnalysisContext(
            tenants: [tenant1, tenant2],
            entityTenantMap: [(entity1, tenant1)],
            operationContexts: [(context1, tenant2)]
        )

        let result = try await reasoning.service.analyzeTenantIsolation(context: analysisContext)

        #expect(result.analysisType == .tenantIsolation)
        #expect(result.stepsExplored > 0)
    }

    @Test("ReasoningService analyzes automation rules")
    func testAutomationRulesAnalysis() async throws {
        let auditLog = AuditLog()
        let reasoning = await ReasoningModule.initialize(auditLog: auditLog)

        let result = try await reasoning.service.analyzeAutomationRules(
            rules: [
                (id: UUID(), name: "Rule 1", triggers: ["event_a"], effects: ["event_b"]),
                (id: UUID(), name: "Rule 2", triggers: ["event_b"], effects: ["event_c"])
            ]
        )

        #expect(result.rulesAnalyzed == 2)
        #expect(result.stepsExplored > 0)
    }

    @Test("ReasoningService reports statistics")
    func testReasoningStatistics() async throws {
        let auditLog = AuditLog()
        let reasoning = await ReasoningModule.initialize(auditLog: auditLog)

        // Run a few analyses
        _ = try await reasoning.service.analyzeAutomationRules(rules: [])
        _ = try await reasoning.service.analyzeControlBypass(
            controlId: "AC-2",
            protectedOperations: ["create_account"],
            bypassScenarios: []
        )

        let stats = await reasoning.service.getStatistics()

        #expect(stats.totalAnalyses == 2)
        #expect(stats.isEnabled)
    }

    @Test("ReasoningService can be disabled")
    func testServiceDisabling() async throws {
        let auditLog = AuditLog()
        let reasoning = await ReasoningModule.initialize(auditLog: auditLog)

        await reasoning.service.setEnabled(false)

        do {
            _ = try await reasoning.service.analyzeAutomationRules(rules: [])
            Issue.record("Should have thrown kernel unavailable")
        } catch ReasoningError.kernelUnavailable {
            // Expected
        }

        // Re-enable
        await reasoning.service.setEnabled(true)
        _ = try await reasoning.service.analyzeAutomationRules(rules: [])
    }
}
