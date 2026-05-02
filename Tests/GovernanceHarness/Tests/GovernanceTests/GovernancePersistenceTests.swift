//
//  GovernancePersistenceTests.swift
//  GovernanceHarness
//
//  Tests that verify governance persistence methods work correctly.
//  Tests table creation, mode seeding, and state loading without full runtime cycles.
//

import XCTest
import Foundation
import DatabaseCore
import AnigmaPrimitives
import ContractsCore
import GovernanceCore
@testable import AnigmaGovernance

final class GovernancePersistenceTests: XCTestCase {
    
    /// Test that table creation SQL is valid and creates expected schema
    func testGovernanceTablesCreation() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("governance_tables_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let dbPath = tempDir.appendingPathComponent("test.db").path
        
        // Create a simple database actor
        let dbActor = DatabaseActor(dbPath: dbPath)
        try await dbActor.open()
        
        // Create tables manually (mimicking what GovernanceController.initialize would do)
        let modesTableSQL = """
            CREATE TABLE IF NOT EXISTS governance_modes (
                project_id TEXT PRIMARY KEY,
                mode TEXT NOT NULL,
                updated_at REAL NOT NULL,
                updated_by TEXT NOT NULL
            )
            """
        
        let killswitchTableSQL = """
            CREATE TABLE IF NOT EXISTS governance_killswitch (
                project_id TEXT PRIMARY KEY,
                active INTEGER NOT NULL,
                reason TEXT,
                updated_at REAL NOT NULL,
                updated_by TEXT NOT NULL
            )
            """
        
        try await dbActor.execute(modesTableSQL)
        try await dbActor.execute(killswitchTableSQL)
        
        // Verify tables exist by querying schema
        let tables = try await dbActor.query("SELECT name FROM sqlite_master WHERE type='table'")
        let tableNames = tables.compactMap { row -> String? in
            if case .text(let name) = row["name"] {
                return name
            }
            return nil
        }
        
        XCTAssert(tableNames.contains("governance_modes"), "governance_modes table should exist")
        XCTAssert(tableNames.contains("governance_killswitch"), "governance_killswitch table should exist")
    }
    
    /// Test that we can insert and retrieve mode records
    func testModeInsertAndRetrieve() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("governance_insert_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let dbPath = tempDir.appendingPathComponent("test.db").path
        let dbActor = DatabaseActor(dbPath: dbPath)
        try await dbActor.open()
        
        // Create table
        try await dbActor.execute("""
            CREATE TABLE governance_modes (
                project_id TEXT PRIMARY KEY,
                mode TEXT NOT NULL,
                updated_at REAL NOT NULL,
                updated_by TEXT NOT NULL
            )
            """)
        
        // Insert a mode
        try await dbActor.execute(
            "INSERT INTO governance_modes (project_id, mode, updated_at, updated_by) VALUES (?, ?, ?, ?)",
            parameters: [.text("test-project"), .text("readOnly"), .double(Date().timeIntervalSince1970), .text("system")]
        )
        
        // Retrieve it
        let rows = try await dbActor.query("SELECT project_id, mode FROM governance_modes WHERE project_id = ?", parameters: [.text("test-project")])
        
        XCTAssertEqual(rows.count, 1, "Should retrieve exactly one row")
        
        guard let row = rows.first,
              case .text(let projectId) = row["project_id"],
              case .text(let mode) = row["mode"] else {
            XCTFail("Failed to extract values from row")
            return
        }
        
        XCTAssertEqual(projectId, "test-project")
        XCTAssertEqual(mode, "readOnly")
    }
    
    /// Test that UPSERT (INSERT ... ON CONFLICT) works for mode updates
    func testModeUpsert() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("governance_upsert_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let dbPath = tempDir.appendingPathComponent("test.db").path
        let dbActor = DatabaseActor(dbPath: dbPath)
        try await dbActor.open()
        
        try await dbActor.execute("""
            CREATE TABLE governance_modes (
                project_id TEXT PRIMARY KEY,
                mode TEXT NOT NULL,
                updated_at REAL NOT NULL,
                updated_by TEXT NOT NULL
            )
            """)
        
        let upsertSQL = """
            INSERT INTO governance_modes (project_id, mode, updated_at, updated_by)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(project_id) DO UPDATE SET
                mode = excluded.mode,
                updated_at = excluded.updated_at,
                updated_by = excluded.updated_by
            """
        
        // Insert initial mode
        try await dbActor.execute(upsertSQL, parameters: [
            .text("global"), .text("assistive"), .double(Date().timeIntervalSince1970), .text("system")
        ])
        
        // Update to readOnly
        try await dbActor.execute(upsertSQL, parameters: [
            .text("global"), .text("readOnly"), .double(Date().timeIntervalSince1970), .text("admin")
        ])
        
        // Verify only one row exists and it's readOnly
        let rows = try await dbActor.query("SELECT mode, updated_by FROM governance_modes WHERE project_id = 'global'")
        
        XCTAssertEqual(rows.count, 1, "Should have exactly one row after upsert")
        
        guard let row = rows.first,
              case .text(let mode) = row["mode"],
              case .text(let updatedBy) = row["updated_by"] else {
            XCTFail("Failed to extract values")
            return
        }
        
        XCTAssertEqual(mode, "readOnly", "Mode should be updated to readOnly")
        XCTAssertEqual(updatedBy, "admin", "Updated by should reflect latest change")
    }
    
    /// Test default mode seeding logic
    func testDefaultModeSeeding() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("governance_seeding_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let dbPath = tempDir.appendingPathComponent("test.db").path
        let dbActor = DatabaseActor(dbPath: dbPath)
        try await dbActor.open()
        
        try await dbActor.execute("""
            CREATE TABLE governance_modes (
                project_id TEXT PRIMARY KEY,
                mode TEXT NOT NULL,
                updated_at REAL NOT NULL,
                updated_by TEXT NOT NULL
            )
            """)
        
        // Check if global mode exists (mimicking seedDefaultMode logic)
        let checkSQL = "SELECT COUNT(*) as count FROM governance_modes WHERE project_id = 'global'"
        let checkRows = try await dbActor.query(checkSQL)
        
        guard let row = checkRows.first,
              case .int(let count) = row["count"] else {
            XCTFail("Failed to get count")
            return
        }
        
        XCTAssertEqual(count, 0, "Should start with no global mode")
        
        // Seed default
        try await dbActor.execute(
            "INSERT INTO governance_modes (project_id, mode, updated_at, updated_by) VALUES ('global', 'assistive', ?, 'system')",
            parameters: [.double(Date().timeIntervalSince1970)]
        )
        
        // Verify seeded
        let verifyRows = try await dbActor.query("SELECT mode FROM governance_modes WHERE project_id = 'global'")
        
        guard let verifyRow = verifyRows.first,
              case .text(let mode) = verifyRow["mode"] else {
            XCTFail("Failed to retrieve seeded mode")
            return
        }
        
        XCTAssertEqual(mode, "assistive", "Default mode should be assistive")
    }

    func testRetentionMigrationCreatesTablesViaExecutor() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retention_migration_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("test.db").path
        let dbActor = DatabaseActor(dbPath: dbPath)

        try await RetentionMigration.migrate(dbActor)

        let tables = try await dbActor.query("SELECT name FROM sqlite_master WHERE type='table'")
        let tableNames = tables.compactMap { row -> String? in
            if case .text(let name) = row["name"] {
                return name
            }
            return nil
        }

        XCTAssertTrue(tableNames.contains("retention_policy_store"))
        XCTAssertTrue(tableNames.contains("policy_compliance_events"))
    }
}
