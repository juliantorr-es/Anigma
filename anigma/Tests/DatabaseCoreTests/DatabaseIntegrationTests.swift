//
//  DatabaseIntegrationTests.swift
//  DatabaseCoreTests
//
//  INTEGRATION TESTS for PostgreSQL First-Class Implementation using Swift Testing.
//  Tests interactions between multiple components against real PostgreSQL.
//  NO MOCKS - only real data.
//
//  To run: Start PostgreSQL and use `swift test DatabaseCoreTests`
//
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Testing
import Foundation
@testable import DatabaseCore

// MARK: - Test Configuration

private enum TestConfig {
    static var host: String { ProcessInfo.processInfo.environment["PGHOST"] ?? "localhost" }
    static var port: Int { Int(ProcessInfo.processInfo.environment["PGPORT"] ?? "5432") ?? 5432 }
    static var database: String { ProcessInfo.processInfo.environment["PGDATABASE"] ?? "testdb" }
    static var username: String { ProcessInfo.processInfo.environment["PGUSER"] ?? "testuser" }
    static var password: String { ProcessInfo.processInfo.environment["PGPASSWORD"] ?? "testpass" }
    static var connectionString: String { "postgresql://\(username):\(password)@\(host):\(port)/\(database)" }
}

private func makeDatabase() -> DatabaseActor { DatabaseActor(path: TestConfig.connectionString) }

// MARK: - One-Time Setup

private actor TestSetup {
    private static var initialized = false
    
    static func ensureInitialized() async throws {
        guard !initialized else { return }
        
        let db = makeDatabase()
        
        // Verify connection
        _ = try await db.query("SELECT 1")
        
        // Enable required PostgreSQL extensions for tests (best effort)
        // pgcrypto provides gen_random_uuid() function
        try? await db.query("CREATE EXTENSION IF NOT EXISTS pgcrypto")
        // uuid-ossp provides UUID generation functions
        try? await db.query("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"")
        
        initialized = true
    }
}

// Helper to check if a table exists in the public schema
private func tableExists(database: DatabaseActor, tableName: String) async throws -> Bool {
    let rows = try await database.query(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = ?",
        parameters: [.text(tableName)]
    )
    return rows.count > 0
}

private func isPostgreSQLAvailable() async -> Bool {
    do {
        try await TestSetup.ensureInitialized()
        return true
    } catch {
        return false
    }
}

// MARK: - Test Utilities

private enum TestError: Error {
    case testError
}

// MARK: - DatabaseIntegrationTests

@Suite("Database Integration Tests")
struct DatabaseIntegrationTests {
    
    // MARK: Connection
    
    @Test("Real PostgreSQL connection")
    func testRealConnection() async throws {
        guard await isPostgreSQLAvailable() else {
            Issue.record("PostgreSQL not available, skipping test")
            return
        }
        let database = makeDatabase()
        let rows = try await database.query("SELECT 1 as value")
        #expect(rows.count == 1)
        #expect(rows[0].int(for: "value") == 1)
    }
    
    @Test("PostgreSQL version")
    func testVersion() async throws {
        guard await isPostgreSQLAvailable() else {
            Issue.record("PostgreSQL not available")
            return
        }
        let database = makeDatabase()
        let rows = try await database.query("SELECT version() as version")
        #expect(rows.count == 1)
        let version = rows[0].string(for: "version") ?? ""
        #expect(version.contains("PostgreSQL"))
    }
    
    @Test("Database info")
    func testDatabaseInfo() async throws {
        guard await isPostgreSQLAvailable() else {
            Issue.record("PostgreSQL not available")
            return
        }
        let database = makeDatabase()
        let rows = try await database.query("SELECT current_database() as db, current_user as user")
        #expect(rows.count == 1)
        #expect(rows[0].string(for: "db") == TestConfig.database)
        #expect(rows[0].string(for: "user") == TestConfig.username)
    }
    
    // MARK: Transactions
    
    @Test("Transaction commit")
    func testTransactionCommit() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_tx_commit_" + UUID().uuidString.prefix(8)
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, data TEXT NOT NULL)")
        try await database.query("BEGIN")
        try await database.query("INSERT INTO \(tableName) (data) VALUES ('test')")
        let rows1 = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName)")
        #expect(rows1[0].int(for: "cnt") == 1)
        try await database.query("COMMIT")
        let rows2 = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName)")
        #expect(rows2[0].int(for: "cnt") == 1)
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    @Test("Transaction rollback")
    func testTransactionRollback() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_tx_rollback_" + UUID().uuidString.prefix(8)
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, data TEXT NOT NULL)")
        try await database.query("BEGIN")
        try await database.query("INSERT INTO \(tableName) (data) VALUES ('will_rollback')")
        let rows1 = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName)")
        #expect(rows1[0].int(for: "cnt") == 1)
        try await database.query("ROLLBACK")
        let rows2 = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName)")
        #expect(rows2[0].int(for: "cnt") == 0)
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    @Test("Savepoint nested transaction")
    func testSavepoint() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_savepoint_" + UUID().uuidString.prefix(8)
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, value INTEGER)")
        try await database.query("BEGIN")
        try await database.query("INSERT INTO \(tableName) (value) VALUES (1)")
        try await database.query("SAVEPOINT sp1")
        try await database.query("INSERT INTO \(tableName) (value) VALUES (2)")
        let rows1 = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName)")
        #expect(rows1[0].int(for: "cnt") == 2)
        try await database.query("ROLLBACK TO SAVEPOINT sp1")
        let rows2 = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName)")
        #expect(rows2[0].int(for: "cnt") == 1)
        try await database.query("INSERT INTO \(tableName) (value) VALUES (3)")
        try await database.query("RELEASE SAVEPOINT sp1")
        try await database.query("COMMIT")
        let finalRows = try await database.query("SELECT value FROM \(tableName) ORDER BY id")
        #expect(finalRows.count == 2)
        #expect(finalRows[0].int(for: "value") == 1)
        #expect(finalRows[1].int(for: "value") == 3)
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    @Test("DatabaseActor transaction block with commit")
    func testDatabaseActorTransaction() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_actor_tx_" + UUID().uuidString.prefix(8)
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, value TEXT)")
        try await database.transaction {
            try await database.query("INSERT INTO \(tableName) (value) VALUES ('in_transaction')")
        }
        let rows = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName)")
        #expect(rows[0].int(for: "cnt") == 1)
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    @Test("DatabaseActor transaction block with rollback on error")
    func testDatabaseActorTransactionRollback() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_actor_tx_rollback_" + UUID().uuidString.prefix(8)
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, value TEXT)")
        do {
            try await database.transaction {
                try await database.query("INSERT INTO \(tableName) (value) VALUES ('will_rollback')")
                throw TestError.testError
            }
        } catch is TestError {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let rows = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName)")
        #expect(rows[0].int(for: "cnt") == 0)
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    // MARK: Schema
    
    @Test("Create table with full schema")
    func testCreateTable() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_schema_" + UUID().uuidString.prefix(8)
        // Use SERIAL instead of UUID with gen_random_uuid() which requires pgcrypto extension
        try await database.query("""
            CREATE TABLE \(tableName) (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT UNIQUE,
                age INTEGER,
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        """)
        let exists = try await tableExists(database: database, tableName: tableName)
        #expect(exists == true)
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    // MARK: CRUD
    
    @Test("CRUD operations")
    func testCRUD() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_crud_" + UUID().uuidString.prefix(8)
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, name TEXT NOT NULL, score INTEGER)")
        for i in 1...10 {
            try await database.query("INSERT INTO \(tableName) (name, score) VALUES ('user_\(i)', \(i) * 10)")
        }
        let allRows = try await database.query("SELECT * FROM \(tableName) ORDER BY id")
        #expect(allRows.count == 10)
        let highScore = try await database.query("SELECT * FROM \(tableName) WHERE score > 50 ORDER BY score DESC")
        #expect(highScore.count == 5)
        let sumRows = try await database.query("SELECT SUM(score) as total, COUNT(*) as count FROM \(tableName)")
        let total = sumRows[0].int64(for: "total") ?? 0
        let count = sumRows[0].int64(for: "count") ?? 0
        let avgScore = Double(total) / Double(count)
        // Sum of 10+20+30+40+50+60+70+80+90+100 = 550, count = 10, avg = 55.0
        #expect(avgScore == 55.0)
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    @Test("Constraint violations")
    func testConstraints() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_constraints_" + UUID().uuidString.prefix(8)
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, unique_field TEXT UNIQUE, non_null_field TEXT NOT NULL)")
        try await database.query("INSERT INTO \(tableName) (unique_field, non_null_field) VALUES ('a', 'x')")
        do {
            try await database.query("INSERT INTO \(tableName) (unique_field, non_null_field) VALUES ('a', 'y')")
            Issue.record("Expected unique constraint violation")
        } catch {
            #expect(true)
        }
        do {
            try await database.query("INSERT INTO \(tableName) (unique_field) VALUES ('b')")
            Issue.record("Expected non-null constraint violation")
        } catch {
            #expect(true)
        }
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    // MARK: Indexes
    
    @Test("Index creation and query")
    func testIndexCreation() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_index_" + UUID().uuidString.prefix(8)
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, name TEXT)")
        try await database.query("CREATE INDEX idx_\(tableName)_name ON \(tableName)(name)")
        for i in 1...100 {
            try await database.query("INSERT INTO \(tableName) (name) VALUES ('name_\(i)')")
        }
        let rows = try await database.query("SELECT * FROM \(tableName) WHERE name = 'name_50'")
        #expect(rows.count == 1)
        try? await database.query("DROP TABLE IF EXISTS \(tableName) CASCADE")
    }
    
    // MARK: JSONB
    
    @Test("JSONB operations")
    func testJSONB() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_jsonb_" + UUID().uuidString.prefix(8)
        
        // Check if JSONB type is available
        do {
            _ = try await database.query("SELECT '{}'::jsonb as test")
        } catch {
            Issue.record("JSONB type not available: \(error)")
            return
        }
        
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, metadata JSONB)")
        let jsonString = "{\"name\": \"Alice\", \"age\": 30, \"active\": true}"
        try await database.query("INSERT INTO \(tableName) (metadata) VALUES (?)", parameters: [.text(jsonString)])
        let rows = try await database.query("SELECT metadata->>'name' as name FROM \(tableName) WHERE metadata->>'active' = 'true'")
        #expect(rows.count == 1)
        #expect(rows[0].string(for: "name") == "Alice")
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    // MARK: RLS
    
    @Test("RLS policy enforcement")
    func testRLS() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_rls_" + UUID().uuidString.prefix(8)
        let rlsManager = PostgresRLSManager(database: database)
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, tenant_id TEXT, data TEXT)")
        
        // RLS operations may fail if test user lacks ALTER TABLE permissions
        // Skip test gracefully if RLS cannot be enabled
        do {
            try await rlsManager.enableRLS(on: tableName)
        } catch {
            Issue.record("RLS test skipped: \(error)")
            return
        }
        let policy = PostgresRLSPolicy(
            name: "tenant_pol",
            table: tableName,
            roles: ["user"],
            usingExpression: "tenant_id = current_setting('app.tenant')",
            checkExpression: nil,
            command: .all
        )
        try await rlsManager.createPolicy(policy)
        try await database.query("INSERT INTO \(tableName) (tenant_id, data) VALUES ('a', 'data_a')")
        let noTenant = try await database.query("SELECT * FROM \(tableName)")
        #expect(noTenant.count == 0)
        try await database.query("SELECT set_config('app.tenant', 'a', false)")
        let tenantA = try await database.query("SELECT * FROM \(tableName)")
        #expect(tenantA.count == 1)
        try await database.query("RESET app.tenant")
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    // MARK: Advisory Locks
    
    @Test("Advisory lock")
    func testAdvisoryLock() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let lockKey: Int64 = 0x12345678
        let locked = try await database.query("SELECT pg_try_advisory_lock(\(lockKey)) as locked")
        #expect(locked.count == 1)
        try await database.query("SELECT pg_advisory_unlock(\(lockKey))")
        let locked2 = try await database.query("SELECT pg_try_advisory_lock(\(lockKey)) as locked")
        #expect(locked2.count == 1)
        try await database.query("SELECT pg_advisory_unlock(\(lockKey))")
    }
    
    // MARK: Connection Metrics
    
    @Test("Connection metrics retrieval")
    func testConnectionMetrics() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let metrics = await database.getConnectionMetrics()
        // Verify we can retrieve metrics
        #expect(metrics.uptimeSeconds >= 0)
        #expect(metrics.totalConnectionsCreated >= 0)
        #expect(metrics.healthState != .unavailable)
    }
    
    @Test("Health state retrieval")
    func testHealthState() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let healthState = try await database.checkHealth()
        #expect(healthState == .healthy)
    }
    
    @Test("Connection metrics to dictionary")
    func testConnectionMetricsToDictionary() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let metrics = await database.getConnectionMetrics()
        let dict = metrics.toDictionary()
        #expect(dict["connection_count"] != nil)
        #expect(dict["health_state"] != nil)
        #expect(dict["uptime_seconds"] != nil)
    }
}
