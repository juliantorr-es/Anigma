//
//  GovernedMigrationAPITests.swift
//  GovernedMigrationCoreTests
//
//  Unit tests for GovernedMigrationCoreTests.
//

import XCTest
import GovernedMigrationCore
import DatabaseCore

final class GovernedMigrationAPITests: XCTestCase {
    var databaseActor: DatabaseActor!
    var api: GovernedMigrationAPI!

    override func setUp() async throws {
        try await super.setUp()
        // Use an in-memory database for testing
        databaseActor = DatabaseActor(dbPath: ":memory:")
        api = GovernedMigrationAPI(dbPath: ":memory:")

        // Ensure the database is initialized with the schema
        try await setupTestDatabase()
    }

    override func tearDown() async throws {
        // Close the database connection after each test
        await databaseActor.close()
        databaseActor = nil
        api = nil
        try await super.tearDown()
    }

    private func setupTestDatabase() async throws {
        try await databaseActor.open()
        let schema = """
        CREATE TABLE IF NOT EXISTS migration_tasks (
            id TEXT PRIMARY KEY,
            projectId TEXT,
            featureCategory TEXT,
            status TEXT,
            priority INTEGER,
            createdAt TEXT,
            updatedAt TEXT,
            startedAt TEXT NULL,
            completedAt TEXT NULL,
            sessionIndex INTEGER NULL,
            findingId TEXT NULL,
            errorMessage TEXT NULL,
            path TEXT NULL,
            pathDetail TEXT NULL
        );

        CREATE TABLE IF NOT EXISTS trust_state (
            subject_id TEXT PRIMARY KEY,
            subject_kind TEXT,
            trust_score INTEGER,
            current_trust_tier TEXT,
            trust_calculated_at TEXT,
            last_changed_at TEXT,
            changed_by TEXT,
            reason TEXT
        );

        CREATE TABLE IF NOT EXISTS security_events (
            id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
            event_type TEXT,
            engine_id TEXT,
            operation TEXT,
            severity TEXT,
            details TEXT,
            created_at TEXT
        );

        CREATE TABLE IF NOT EXISTS governance_mode (
            mode TEXT PRIMARY KEY,
            updated_by TEXT,
            updated_at TEXT
        );

        INSERT OR IGNORE INTO governance_mode (mode, updated_by, updated_at) VALUES ('governed', 'system', datetime('now'));
        """
        _ = try await databaseActor.execute(schema)
    }

    func testRunSwift6DiscoveryAndTaskCreation() async throws {
        let taskCount = try await api.runSwift6DiscoveryAndTaskCreation()
        XCTAssertEqual(taskCount, 4, "Expected 4 simulated tasks to be created.")

        // Verify tasks are in the database
        let tasks = try await databaseActor.query("SELECT * FROM migration_tasks")
        XCTAssertEqual(tasks.count, 4, "Expected 4 tasks in the database.")

        for task in tasks {
            XCTAssertEqual(task["status"] as? String, "pending")
        }
    }

    func testRunSwift6Steps_success() async throws {
        _ = try await api.runSwift6DiscoveryAndTaskCreation() // Create 4 tasks

        let result = try await api.runSwift6Steps(count: 2)

        XCTAssertEqual(result.processed, 2, "Expected 2 tasks to be processed.")
        // Since success is random, we can't assert succeeded/failed directly,
        // but we can check if trustChanges were recorded for each.
        XCTAssertEqual(result.trustChanges.count, 2, "Expected 2 trust changes.")

        let tasks = try await databaseActor.query("SELECT * FROM migration_tasks WHERE status = 'completed'")
        XCTAssertGreaterThan(tasks.count, 0, "Expected at least some tasks to be completed.")

        let securityEvents = try await databaseActor.query("SELECT * FROM security_events")
        XCTAssertGreaterThan(securityEvents.count, 0, "Expected security events to be logged.")
    }

    func testCurrentGovernanceSnapshot() async throws {
        // Ensure some data exists
        _ = try await api.runSwift6DiscoveryAndTaskCreation()
        _ = try await api.runSwift6Steps(count: 1)

        let snapshot = try await api.currentGovernanceSnapshot()

        XCTAssertGreaterThan(snapshot.trustScores.count, 0, "Expected trust scores in snapshot.")
        XCTAssertGreaterThan(snapshot.recentSecurityEvents.count, 0, "Expected security events in snapshot.")
        XCTAssertEqual(snapshot.governanceMode.mode, "governed", "Expected governance mode to be 'governed'.")
        XCTAssertNotNil(snapshot.timestamp, "Expected a timestamp for the snapshot.")
    }
}
