import XCTest
import AnigmaCLICore
import AnigmaCLIEventing
import AnigmaCLIProviders
import AnigmaCLIRouter
import AnigmaCLIGovernance
@testable import AnigmaCLIOrchestrator

final class CLIOrchestratorTests: XCTestCase {

    func testOrchestratorPlanning() async throws {
        let registry = ProviderRegistry()
        let eventStream = CLIEventStream()
        let orchestrator = AnigmaCLIOrchestrator(
            registry: registry,
            eventStream: eventStream
        )

        let task = TaskIntent(summary: "Test Task")
        let context = TaskContext(
            repoRoot: URL(fileURLWithPath: "/tmp"),
            worktreeRoot: URL(fileURLWithPath: "/tmp/worktree")
        )

        let outcome = try await orchestrator.plan(task: task, context: context)

        XCTAssertEqual(outcome.contract.objective, "Test Task")
        // Default router might fail to find a provider if none registered, 
        // but it should still return a 'none' decision.
        XCTAssertNil(outcome.route.selected)
    }

    func testOrchestratorRunDeniedByGovernance() async throws {
        let registry = ProviderRegistry()
        let orchestrator = AnigmaCLIOrchestrator(registry: registry)

        let task = TaskIntent(summary: "Blocked Task")
        let context = TaskContext(
            repoRoot: URL(fileURLWithPath: "/tmp"),
            worktreeRoot: URL(fileURLWithPath: "/tmp/worktree")
        )

        // Mock a governance engine that denies everything
        class DenyGovernance: GovernanceEngine {
            override func evaluate(task: TaskIntent, contract: TaskContract, provider: Provider?, requiredCapabilities: Set<ProviderCapability>) -> GovernanceDecision {
                return GovernanceDecision(allowed: false, issues: ["Polished Denial"])
            }
        }

        let outcome = try await orchestrator.run(
            task: task,
            context: context,
            dryRun: false,
            governance: DenyGovernance()
        )

        XCTAssertFalse(outcome.governance.allowed)
        XCTAssertEqual(outcome.status, .failed)
    }
}
