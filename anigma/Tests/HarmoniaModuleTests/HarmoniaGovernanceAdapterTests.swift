//
//  HarmoniaGovernanceAdapterTests.swift
//  HarmoniaModuleTests
//
//  Tests for HarmoniaGovernanceAdapter.
//

import XCTest
@testable import HarmoniaModule
import AnigmaCore
import DatabaseCore

final class HarmoniaGovernanceAdapterTests: XCTestCase {

    var runtime: PlatformRuntime!
    var adapter: HarmoniaGovernanceAdapter!

    override func setUp() async throws {
        // Create a testing runtime
        runtime = try await PlatformRuntime(config: .testing)
        try await runtime.initialize()

        // Initialize adapter
        let db = await runtime.database
        adapter = HarmoniaGovernanceAdapter(database: db)
        try await adapter.initialize()

        // Allow writes for testing
        await runtime.governance.setMode(.autopilot, by: "test")
    }

    override func tearDown() async throws {
        await runtime?.shutdown()
        runtime = nil
        adapter = nil
    }

    func testRecordSessionLifecycle() async throws {
        let context = ExecutionContext(
            principal: Principal(id: "test-user", displayName: "Test User")
        )
        let sessionId = UUID().uuidString

        // Record event
        let receipt = try await adapter.recordSessionLifecycle(
            sessionId: sessionId,
            event: "start",
            context: context
        )

        XCTAssertEqual(receipt.evidence.outcome, .success)

        // Verify it was written to DB
        let db = await runtime.database
        let rows = try await db.query(
            "SELECT * FROM session_lifecycle_events WHERE session_id = ?",
            parameters: [.text(sessionId)]
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.string(for: "event"), "start")
    }
}
