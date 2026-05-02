//
//  DatabaseEndToEndTests.swift
//  DatabaseCoreTests
//
//  END-TO-END TESTS for PostgreSQL First-Class Implementation using Swift Testing.
//  Tests complete workflows from user action to database persistence.
//  NO MOCKS - only real data against real PostgreSQL.
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

private func isPostgreSQLAvailable() async -> Bool {
    do {
        let db = makeDatabase()
        _ = try await db.query("SELECT 1")
        return true
    } catch {
        return false
    }
}

// MARK: - DatabaseEndToEndTests

@Suite("Database End-to-End Tests")
struct DatabaseEndToEndTests {
    
    // MARK: User Management Workflow
    
    @Test("Complete user CRUD workflow")
    func testUserWorkflow() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_user_e2e_" + UUID().uuidString.prefix(8)
        try await database.query("""
            CREATE TABLE \(tableName) (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                username TEXT NOT NULL UNIQUE,
                email TEXT NOT NULL UNIQUE
            )
        """)
        try await database.query("CREATE INDEX idx_username ON \(tableName)(username)")
        let userId = UUID()
        try await database.query("""
            INSERT INTO \(tableName) (id, username, email) VALUES (?, ?, ?)
        """, parameters: [.text(userId.uuidString), .text("testuser"), .text("test@example.com")])
        let users = try await database.query("SELECT * FROM \(tableName) WHERE username = ?", parameters: [.text("testuser")])
        #expect(users.count == 1)
        try await database.query("UPDATE \(tableName) SET email = ? WHERE username = ?", parameters: [.text("updated@example.com"), .text("testuser")])
        let updated = try await database.query("SELECT email FROM \(tableName) WHERE username = ?", parameters: [.text("testuser")])
        #expect(updated[0].string(for: "email") == "updated@example.com")
        try await database.query("DELETE FROM \(tableName) WHERE username = ?", parameters: [.text("testuser")])
        let deleted = try await database.query("SELECT * FROM \(tableName)")
        #expect(deleted.count == 0)
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    // MARK: Job Queue Workflow
    
    @Test("Job queue workflow with SKIP LOCKED")
    func testJobQueueWorkflow() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_job_e2e_" + UUID().uuidString.prefix(8)
        try await database.query("""
            CREATE TABLE \(tableName) (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                queue_name TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                priority INTEGER NOT NULL DEFAULT 1,
                payload JSONB NOT NULL DEFAULT '{}'
            )
        """)
        try await database.query("CREATE INDEX idx_\(tableName)_status ON \(tableName)(status)")
        for i in 1...10 {
            try await database.query("""
                INSERT INTO \(tableName) (queue_name, priority, payload) 
                VALUES (?, ?, ?)
            """, parameters: [.text("email"), .int(i), .text("{\"to\":\"user\(i)@example.com\"}")])
        }
        var processed = 0
        for _ in 0..<10 {
            let jobs = try await database.query("""
                SELECT * FROM \(tableName) 
                WHERE status = 'pending' AND queue_name = ?
                ORDER BY priority DESC
                LIMIT 1
                FOR UPDATE SKIP LOCKED
            """, parameters: [.text("email")])
            if let job = jobs.first {
                processed += 1
                #expect(job.string(for: "queue_name") == "email")
                try await database.query("UPDATE \(tableName) SET status = 'completed' WHERE id = ?", parameters: [.text(job.string(for: "id") ?? "")])
            }
        }
        #expect(processed == 10)
        let completed = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName) WHERE status = 'completed'")
        #expect(completed[0].int(for: "cnt") == 10)
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    // MARK: Migration Workflow
    
    @Test("Migration workflow")
    func testMigrationWorkflow() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        try? await database.query("DROP TABLE IF EXISTS test_mig_users CASCADE")
        try? await database.query("DROP TABLE IF EXISTS schema_registry CASCADE")
        let contract = try PostgresSchemaBootstrapContract(migrations: [
            PostgresMigrationStep(
                version: 1, identifier: "create_users", module: "TestE2E",
                requiredTables: ["test_mig_users"],
                applySQL: "CREATE TABLE test_mig_users (id TEXT PRIMARY KEY, name TEXT)",
                rollbackSQL: "DROP TABLE test_mig_users CASCADE",
                rollbackExpectation: "Test table"
            )]
        )
        let runner = try await SchemaMigrationRunner(database: database, contract: contract)
        let result = try await runner.runMigrations()
        #expect(result.appliedCount == 1)
        let tables = try await database.query("SELECT table_name FROM information_schema.tables WHERE table_name = 'test_mig_users'")
        #expect(tables.count == 1)
        try await database.query("INSERT INTO test_mig_users (id, name) VALUES (?, ?)", parameters: [.text("1"), .text("Test")])
        let users = try await database.query("SELECT * FROM test_mig_users")
        #expect(users.count == 1)
        try? await database.query("DROP TABLE IF EXISTS test_mig_users CASCADE")
        try? await database.query("DROP TABLE IF EXISTS schema_registry CASCADE")
    }
    
    // MARK: RLS Multi-tenant Workflow
    
    @Test("RLS multi-tenant workflow")
    func testRLSWorkflow() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_rls_e2e_" + UUID().uuidString.prefix(8)
        let rls = PostgresRLSManager(database: database)
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, tenant_id TEXT, user_id TEXT, data JSONB)")
        try await rls.enableRLS(on: tableName)
        let policy = PostgresRLSPolicy(
            name: "multi_tenant",
            table: tableName,
            roles: ["app_user"],
            usingExpression: "tenant_id = current_setting('app.current_tenant')",
            checkExpression: nil,
            command: .all
        )
        try await rls.createPolicy(policy)
        for tenantId in ["tenant_a", "tenant_b"] {
            for i in 1...3 {
                let json = AnyCodable.dictionary(["name": .string("User \(i)")])
                try await database.query("INSERT INTO \(tableName) (tenant_id, user_id, data) VALUES (?, ?, ?)", parameters: [.text(tenantId), .text("user_\(i)"), .text(json.jsonString())])
            }
        }
        try await database.query("SELECT set_config('app.current_tenant', 'tenant_a', false)")
        let tenantA = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName)")
        #expect(tenantA[0].int(for: "cnt") == 3)
        try await database.query("SELECT set_config('app.current_tenant', 'tenant_b', false)")
        let tenantB = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName)")
        #expect(tenantB[0].int(for: "cnt") == 3)
        try await database.query("RESET app.current_tenant")
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
    
    // MARK: JSONB Indexing Workflow
    
    @Test("JSONB indexing workflow")
    func testJSONBWorkflow() async throws {
        guard await isPostgreSQLAvailable() else { return }
        let database = makeDatabase()
        let tableName = "test_jsonb_e2e_" + UUID().uuidString.prefix(8)
        try await database.query("CREATE TABLE \(tableName) (id SERIAL PRIMARY KEY, properties JSONB)")
        try await database.query("CREATE INDEX idx_props ON \(tableName) USING GIN (properties)")
        for category in ["electronics", "books"] {
            for i in 1...5 {
                let doc = AnyCodable.dictionary(["category": .string(category), "price": .double(Double(i * 10))])
                try await database.query("INSERT INTO \(tableName) (properties) VALUES (?)", parameters: [.text(doc.jsonString())])
            }
        }
        let electronics = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName) WHERE properties->>'category' = 'electronics'")
        #expect(electronics[0].int(for: "cnt") == 5)
        let books = try await database.query("SELECT COUNT(*) as cnt FROM \(tableName) WHERE properties @> '{\"category\": \"books\"}'")
        #expect(books[0].int(for: "cnt") == 5)
        try? await database.query("DROP TABLE IF EXISTS \(tableName)")
    }
}
