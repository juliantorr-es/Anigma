import XCTest
import ContractsCore
@testable import GovernanceCore

final class GovernanceInvariantsTests: XCTestCase {

    func testKillSwitchBlocksWritesGlobally() async {
        let killSwitch = KillSwitch()

        // Initially allowed
        XCTAssertTrue(await killSwitch.isWriteAllowed())

        // Activate
        await killSwitch.activate(reason: "Emergency halt", by: "security-service")

        // Now blocked
        XCTAssertFalse(await killSwitch.isWriteAllowed())
        XCTAssertFalse(await killSwitch.isWriteAllowed(forProject: "any-project"))
    }

    func testKillSwitchBlocksPerProject() async {
        let killSwitch = KillSwitch()
        let projectId = "sensitive-project"

        // Activate for project
        await killSwitch.activateForProject(projectId, by: "admin")

        // Blocked for that project
        XCTAssertFalse(await killSwitch.isWriteAllowed(forProject: projectId))

        // Allowed for other projects
        XCTAssertTrue(await killSwitch.isWriteAllowed(forProject: "other-project"))
    }

    func testWriteGateEvaluatesBlockingChecks() async {
        let gate = WriteGate()

        // Register a check that always fails
        struct FailingCheck: WriteCheck {
            let id = "fail-check"
            let name = "Always Fails"
            let isBlocking = true
            func appliesTo(_ proposal: WriteProposal) -> Bool { true }
            func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
                .fail(checkId: id, message: "Planned failure")
            }
        }

        await gate.registerCheck(FailingCheck())

        let proposal = WriteProposal(principal: "test", module: "test", operation: "test")
        let decision = await gate.evaluate(proposal)

        XCTAssertFalse(decision.allowed)
        XCTAssertEqual(decision.failedChecks.count, 1)
    }

    func testWriteGateAllowsNonBlockingFailures() async {
        let gate = WriteGate()

        // Register a check that fails but is NOT blocking
        struct WarningCheck: WriteCheck {
            let id = "warn-check"
            let name = "Warning Only"
            let isBlocking = false
            func appliesTo(_ proposal: WriteProposal) -> Bool { true }
            func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
                .fail(checkId: id, message: "Warning")
            }
        }

        await gate.registerCheck(WarningCheck())

        let proposal = WriteProposal(principal: "test", module: "test", operation: "test")
        let decision = await gate.evaluate(proposal)

        XCTAssertTrue(decision.allowed) // Still allowed because it's not blocking
        XCTAssertEqual(decision.failedChecks.count, 1)
    }

    func testWriteGateInterdependentRules() async {
        let gate = WriteGate()

        // Rule 1: Must be from 'admin' module
        struct AdminModuleCheck: WriteCheck {
            let id = "admin-module"
            let name = "Admin Module"
            let isBlocking = true
            func appliesTo(_ proposal: WriteProposal) -> Bool { true }
            func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
                proposal.module == "admin" ? .pass(checkId: id) : .fail(checkId: id, message: "External module")
            }
        }

        // Rule 2: Must not be 'delete' operation
        struct NoDeleteCheck: WriteCheck {
            let id = "no-delete"
            let name = "No Deletion"
            let isBlocking = true
            func appliesTo(_ proposal: WriteProposal) -> Bool { true }
            func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
                proposal.operation != "delete" ? .pass(checkId: id) : .fail(checkId: id, message: "Deletion forbidden")
            }
        }

        await gate.registerCheck(AdminModuleCheck())
        await gate.registerCheck(NoDeleteCheck())

        // Scenario A: Fails Rule 1
        let proposalA = WriteProposal(principal: "user", module: "guest", operation: "write")
        let decisionA = await gate.evaluate(proposalA)
        XCTAssertFalse(decisionA.allowed)

        // Scenario B: Fails Rule 2
        let proposalB = WriteProposal(principal: "admin", module: "admin", operation: "delete")
        let decisionB = await gate.evaluate(proposalB)
        XCTAssertFalse(decisionB.allowed)

        // Scenario C: Both Pass
        let proposalC = WriteProposal(principal: "admin", module: "admin", operation: "update")
        let decisionC = await gate.evaluate(proposalC)
        XCTAssertTrue(decisionC.allowed)
    }
}
