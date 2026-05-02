//
//  DatabaseUnitTests.swift
//  DatabaseCoreTests
//
//  UNIT TESTS for PostgreSQL First-Class Implementation using Swift Testing.
//  Tests individual components in isolation with real data structures.
//  NO MOCKS - only real data.
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

// MARK: - DatabaseUnitTests

@Suite("Database Unit Tests")
struct DatabaseUnitTests {
    
    // MARK: Database Configuration
    
    @Test("Connection string formatting")
    func testConnectionString() {
        let config = TestConfig.connectionString
        #expect(config.contains("postgresql://"))
        #expect(config.contains("localhost"))
        #expect(config.contains("testdb"))
    }
    
    // MARK: DatabaseParameter
    
    @Test("Text parameter")
    func testParameterText() {
        let param = DatabaseParameter.text("hello")
        if case .text(let value) = param {
            #expect(value == "hello")
        }
    }
    
    @Test("Integer parameter")
    func testParameterInt() {
        let param = DatabaseParameter.int(42)
        if case .int(let value) = param {
            #expect(value == 42)
        }
    }
    
    @Test("Double parameter")
    func testParameterDouble() {
        let param = DatabaseParameter.double(3.14)
        if case .double(let value) = param {
            #expect(value == 3.14)
        }
    }
    
    @Test("Null parameter")
    func testParameterNull() {
        let param = DatabaseParameter.null
        if case .null = param {
            #expect(true)
        }
    }
    
    @Test("Date parameter")
    func testParameterDate() {
        let date = Date()
        let param = DatabaseParameter.date(date)
        if case .date(let value) = param {
            #expect(value == date)
        }
    }
    
    // MARK: AnyCodable
    
    @Test("String encoding")
    func testAnyCodableString() {
        let value = AnyCodable.string("test")
        let json = value.jsonString()
        #expect(json == "\"test\"")
    }
    
    @Test("Integer encoding")
    func testAnyCodableInt() {
        let value = AnyCodable.int(42)
        let json = value.jsonString()
        #expect(json == "42")
    }
    
    @Test("Boolean encoding")
    func testAnyCodableBool() {
        let value = AnyCodable.bool(true)
        let json = value.jsonString()
        #expect(json == "true")
    }
    
    @Test("Array encoding")
    func testAnyCodableArray() {
        let value = AnyCodable.array([.string("a"), .int(1)])
        let json = value.jsonString()
        #expect(json.contains("\"a\""))
        #expect(json.contains("1"))
    }
    
    @Test("Dictionary encoding")
    func testAnyCodableDictionary() {
        let value = AnyCodable.dictionary([
            "name": .string("Alice"),
            "age": .int(30)
        ])
        let json = value.jsonString()
        #expect(json.contains("\"name\":\"Alice\""))
        #expect(json.contains("\"age\":30"))
    }
    
    // MARK: Container Configuration
    
    @Test("Container config defaults")
    func testContainerConfigDefaults() {
        let config = PostgresContainerConfig.default
        #expect(config.image == "postgres")
        #expect(config.tag == "16-alpine")
        #expect(config.username == "testuser")
        #expect(config.database == "testdb")
        #expect(config.port == 5432)
    }
    
    @Test("Container config connection string")
    func testContainerConfigConnectionString() {
        let config = PostgresContainerConfig(
            image: "postgres", tag: "16", username: "user", password: "pass", database: "db", port: 5433
        )
        let connString = config.connectionString
        #expect(connString == "postgresql://user:pass@localhost:5433/db")
    }
    
    // MARK: Migration Types
    
    @Test("Migration step creation")
    func testMigrationStep() {
        let step = PostgresMigrationStep(
            version: 1, identifier: "create_users", module: "Auth",
            requiredTables: ["users"],
            applySQL: "CREATE TABLE users (id SERIAL PRIMARY KEY)",
            rollbackSQL: "DROP TABLE users",
            rollbackExpectation: "Safe to rollback"
        )
        #expect(step.version == 1)
        #expect(step.identifier == "create_users")
        #expect(step.module == "Auth")
        #expect(step.requiredTables == ["users"])
    }
    
    // MARK: RLS Types
    
    @Test("RLS policy creation")
    func testRLSPolicy() {
        let policy = PostgresRLSPolicy(
            name: "tenant_isolation",
            table: "data",
            roles: ["user", "admin"],
            usingExpression: "tenant_id = current_setting('app.tenant')",
            checkExpression: nil,
            command: .all
        )
        #expect(policy.name == "tenant_isolation")
        #expect(policy.table == "data")
        #expect(policy.command == .all)
    }
    
    // MARK: Index Types
    
    @Test("Index definition")
    func testIndexDefinition() {
        let columns = [PostgresIndexColumn(column: "name")]
        let index = PostgresIndexDefinition(
            name: "idx_users_name",
            table: "users",
            type: .btree,
            columns: columns,
            options: PostgresIndexOptions()
        )
        #expect(index.table == "users")
        #expect(index.name == "idx_users_name")
        #expect(index.columns.count == 1)
        #expect(index.type == .btree)
    }
    
    // MARK: JSONB Coders
    
    @Test("JSONB encoding")
    func testJSONBEncoder() {
        struct TestData: Codable, Equatable, Sendable { let name: String; let value: Int }
        let encoder = JSONBEncoder()
        let data = TestData(name: "Test", value: 42)
        let encoded = encoder.encode(data)
        if case let .blob(buttonData) = encoded {
            #expect(buttonData.count > 0)
        } else {
            Issue.record("Expected blob DatabaseValue")
        }
    }
    
    @Test("JSONB decoding")
    func testJSONBDecoder() throws {
        struct TestData: Codable, Equatable, Sendable { let name: String; let value: Int }
        let decoder = JSONBDecoder()
        let json = "{\"name\":\"Test\",\"value\":42}".data(using: .utf8)!
        let dbValue = DatabaseValue.blob(json)
        let decoded = try decoder.decode(TestData.self, from: dbValue)
        #expect(decoded.name == "Test")
        #expect(decoded.value == 42)
    }
    
    // MARK: Backup Types
    
    @Test("Backup manifest creation")
    func testBackupManifest() {
        let manifest = PostgresBackupManifest(
            version: "1.0",
            backups: [],
            retentionPolicyDays: 30,
            maxBackups: 100
        )
        #expect(manifest.version == "1.0")
        #expect(manifest.backups.count == 0)
        #expect(manifest.retentionPolicyDays == 30)
        #expect(manifest.maxBackups == 100)
    }
    
    @Test("Backup result creation")
    func testBackupResult() {
        let url = URL(fileURLWithPath: "/backups/base.tar")
        let result = PostgresBackupResult(
            id: UUID(),
            path: url,
            sizeBytes: 512,
            backupType: .sql,
            compression: .none,
            databaseName: "testdb",
            startedAt: Date(),
            completedAt: Date(),
            durationSeconds: 1.5,
            success: true,
            error: nil,
            checksum: "abc123"
        )
        #expect(result.databaseName == "testdb")
        #expect(result.sizeBytes == 512)
        #expect(result.success == true)
        #expect(result.checksum == "abc123")
    }
}
