//
//  GovernanceEnforcementTests.swift
//  AnigmaCoreTests
//
//  Tests for governance enforcement in the Platform Runtime.
//  Verifies Phase 2 requirements:
//  1. DatabaseAuthority checks governance before mutations
//  2. KillSwitch blocks mutations
//  3. WriteGate blocks mutations
//

import XCTest
@testable import AnigmaCore
@testable import DatabaseCore

final class GovernanceEnforcementTests: XCTestCase {

    var runtime: PlatformRuntime!

    override func setUp() async throws {
        // Create a testing runtime (but we'll configure it to enforce governance manually)
        runtime = try await PlatformRuntime(config: .testing)
        try await runtime.initialize()

        // Ensure governance is initialized
        await runtime.governance.initialize()
    }

    override func tearDown() async throws {
        await runtime.shutdown()
        runtime = nil
    }

    // MARK: - Kill Switch Tests

    func testKillSwitchBlocksMutations() async throws {
        // Setup: Create a test context
        let context = ExecutionContext(
            principal: Principal(id: "user-1", displayName: "Test User"),
            metadata: ["test": "true"]
        )

        // Setup: Ensure we are in a writable mode
        await runtime.governance.setMode(.autopilot, by: "test")

        // 1. Verify mutation works initially
        let mutation = DatabaseMutation(
            sql: "CREATE TABLE IF NOT EXISTS test_table (id TEXT PRIMARY KEY)",
            parameters: [],
            componentType: nil,
            entityId: nil
        )

        let receipt1 = try await runtime.database.mutate(mutation, context: context)
        XCTAssertEqual(receipt1.evidence.outcome, .success)

        // 2. Activate Kill Switch
        await runtime.governance.killSwitch.activate(reason: "Emergency Test", by: "admin")

        // 3. Verify mutation is blocked
        do {
            _ = try await runtime.database.mutate(mutation, context: context)
            XCTFail("Mutation should have been blocked by Kill Switch")
        } catch RuntimeError.governanceViolation(let reason) {
            XCTAssertTrue(reason.contains("Kill switch active"))
            XCTAssertTrue(reason.contains("Emergency Test"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // 4. Deactivate Kill Switch
        await runtime.governance.killSwitch.deactivate(by: "admin")

        // 5. Verify mutation works again
        let receipt2 = try await runtime.database.mutate(mutation, context: context)
        XCTAssertEqual(receipt2.evidence.outcome, .success)
    }

    // MARK: - Operating Mode Tests

    func testReadOnlyModeBlocksMutations() async throws {
        // Setup: Create a test context
        let context = ExecutionContext(
            principal: Principal(id: "user-1", displayName: "Test User")
        )

        // 1. Set mode to Read Only
        await runtime.governance.setMode(.readOnly, by: "test")

        // 2. Verify mutation is blocked
        let mutation = DatabaseMutation(
            sql: "INSERT INTO test_table VALUES (?)",
            parameters: [.text("1")],
            componentType: nil,
            entityId: nil
        )

        do {
            _ = try await runtime.database.mutate(mutation, context: context)
            XCTFail("Mutation should have been blocked in Read Only mode")
        } catch RuntimeError.governanceViolation(let reason) {
            XCTAssertTrue(reason.contains("does not allow writes"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // 3. Set mode to Autopilot
        await runtime.governance.setMode(.autopilot, by: "test")

        // 4. Verify mutation works
        // (Note: We expect this to fail with SQL error because table might not exist, but NOT governance error)
        do {
            _ = try await runtime.database.mutate(mutation, context: context)
        } catch RuntimeError.governanceViolation {
            XCTFail("Should not fail with governance violation in Autopilot mode")
        } catch {
            // SQL error is expected and acceptable here
        }
    }

    // MARK: - Custom Write Check Tests

    func testCustomWriteCheckBlocksMutations() async throws {
        // Setup
        let context = ExecutionContext(
            principal: Principal(id: "user-1", displayName: "Test User")
        )
        await runtime.governance.setMode(.autopilot, by: "test")

        // 1. Register a blocking check that always fails
        struct AlwaysFailCheck: WriteCheck {
            let id = "always-fail"
            let name = "Always Fail"
            let isBlocking = true

            func appliesTo(_ proposal: WriteProposal) -> Bool { true }
            func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
                .fail(checkId: id, message: "Computer says no")
            }
        }

        await runtime.governance.writeGate.registerCheck(AlwaysFailCheck())

        // 2. Verify mutation is blocked
        let mutation = DatabaseMutation(
            sql: "SELECT 1", // SQL doesn't matter, check runs before execution
            parameters: [],
            componentType: nil,
            entityId: nil
        )

        do {
            _ = try await runtime.database.mutate(mutation, context: context)
            XCTFail("Mutation should have been blocked by custom check")
        } catch RuntimeError.governanceViolation(let reason) {
            XCTAssertTrue(reason.contains("Computer says no"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // 3. Remove the check
        await runtime.governance.writeGate.removeCheck(id: "always-fail")

        // 4. Verify mutation passes governance (ignoring SQL errors)
        do {
            _ = try await runtime.database.mutate(mutation, context: context)
        } catch RuntimeError.governanceViolation {
            XCTFail("Should not fail with governance violation after check removal")
        } catch {
            // Other errors ok
        }
    }
}
