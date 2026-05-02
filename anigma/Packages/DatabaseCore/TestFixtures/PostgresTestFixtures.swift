//
//  PostgresTestFixtures.swift
//  DatabaseCore
//
//  Test fixtures for PostgreSQL testing.
//
//  See td-c9cb45: Add migration test fixtures
//  See td-d12908: Create fixture loader for test data
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Foundation
import AnigmaPrimitives

// MARK: - Test Fixture Protocol

/// Protocol for test fixtures
public protocol PostgresTestFixture: Sendable {
    /// Setup the fixture (create tables, insert data)
    func setup(database: any DatabaseExecutor) async throws
    
    /// Teardown the fixture (clean up)
    func teardown(database: any DatabaseExecutor) async throws
    
    /// Get the fixture name
    static var fixtureName: String { get }
}

// MARK: - Base Test Table

/// Base test table definition
public protocol TestTable: Sendable {
    static var name: String { get }
    static var schema: [RowTypeGenerator.ColumnDefinition] { get }
}

// MARK: - Fixture Loader

/// Fixture loader for loading test data from JSON or CSV files
public final class PostgresFixtureLoader: Sendable {
    private let database: any DatabaseExecutor
    private let fixturePath: URL?
    
    public init(database: any DatabaseExecutor, fixturePath: URL? = nil) {
        self.database = database
        self.fixturePath = fixturePath ?? 
            URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }
    
    /// Load a JSON fixture file
    public func loadJSONFixture(filename: String) throws -> [[String: String]] {
        let url = fixturePath!.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FixtureError.fileNotFound(filename)
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([[String: String]].self, from: data)
    }
    
    /// Load a CSV fixture file
    public func loadCSVFixture(filename: String, hasHeader: Bool = true) throws -> [[String: String]] {
        let url = fixturePath!.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FixtureError.fileNotFound(filename)
        }
        
        let data = try String(contentsOf: url, encoding: .utf8)
        let lines = data.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return [] }
        
        var headers: [String] = []
        var startIndex = 0
        
        if hasHeader, !lines[0].isEmpty {
            headers = lines[0].components(separatedBy: ",")
            startIndex = 1
        } else {
            headers = Array(0..<lines[0].components(separatedBy: ",").count).map { "column_\($0)" }
        }
        
        var rows: [[String: String]] = []
        for line in lines.dropFirst(startIndex) {
            guard !line.isEmpty else { continue }
            let values = line.components(separatedBy: ",")
            var row: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                row[header] = index < values.count ? values[index] : ""
            }
            rows.append(row)
        }
        
        return rows
    }
    
    /// Insert JSON fixture into a table
    public func insertFixture(
        _ data: [[String: String]],
        inTable table: String,
        columnMapping: [String: String]? = nil
    ) async throws {
        for row in data {
            // Determine target columns: use mapping values if provided, otherwise row keys
            let columns = columnMapping?.values.map { $0 } ?? Array(row.keys)
            let placeholders = columns.map { _ in "?" }.joined(separator: ", ")
            
            let columnList = columns.joined(separator: ", ")
            let sql = "INSERT INTO \(table) (\(columnList)) VALUES (\(placeholders))"
            
            var parameters: [DatabaseParameter] = []
            for column in columns {
                // Find the source key that maps to this target column
                let sourceKey = columnMapping?.first { $0.value == column }?.key ?? column
                let value = row[sourceKey] ?? ""
                parameters.append(.text(value))
            }
            
            _ = try await database.execute(sql, parameters: parameters)
        }
    }
    
    /// Clear all data from a table
    public func clearTable(_ table: String) async throws {
        // Use TRUNCATE for speed in tests
        let sql = "TRUNCATE TABLE \(table) RESTART IDENTITY CASCADE"
        _ = try await database.execute(sql)
    }
    
    /// Reset sequence for a table
    public func resetSequence(forTable table: String, sequenceName: String? = nil) async throws {
        let seq = sequenceName ?? "\(table)_id_seq"
        let sql = "ALTER SEQUENCE \(seq) RESTART WITH 1"
        _ = try? await database.execute(sql) // Ignore errors if sequence doesn't exist
    }
    
    /// Load a fixture by name
    public func loadFixture<T: PostgresTestFixture>(_ fixtureType: T.Type) async throws -> T {
        // In a real implementation, we'd instantiate the fixture
        // For now, this is a placeholder - concrete fixtures should provide their own mechanism
        fatalError("loadFixture is not implemented - use fixture-specific initialization")
    }
    
    // MARK: - Helper
    
    private func databaseValueToParameter(_ value: String) -> DatabaseParameter {
        return .text(value)
    }
}

// MARK: - Errors

public enum FixtureError: Error, CustomStringConvertible, Sendable {
    case fileNotFound(String)
    case invalidFormat(String)
    case insertFailed(String)
    case teardownFailed(String)
    
    public var description: String {
        switch self {
        case let .fileNotFound(f): return "Fixture file not found: \(f)"
        case let .invalidFormat(f): return "Invalid fixture format: \(f)"
        case let .insertFailed(e): return "Insert failed: \(e)"
        case let .teardownFailed(e): return "Teardown failed: \(e)"
        }
    }
}

// MARK: - Common Test Fixtures

/// Fixture for basic database schema
public struct BasicSchemaFixture: PostgresTestFixture {
    public static var fixtureName: String { "basic_schema" }
    
    public func setup(database: any DatabaseExecutor) async throws {
        let schema = """
        CREATE TABLE IF NOT EXISTS test_entities (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            value INTEGER DEFAULT 0,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        );
        
        CREATE TABLE IF NOT EXISTS test_relations (
            id SERIAL PRIMARY KEY,
            entity_id INTEGER REFERENCES test_entities(id),
            related_id INTEGER REFERENCES test_entities(id),
            relation_type TEXT NOT NULL,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
        
        CREATE INDEX IF NOT EXISTS idx_test_entities_name ON test_entities(name);
        CREATE INDEX IF NOT EXISTS idx_test_relations_entity ON test_relations(entity_id);
        CREATE INDEX IF NOT EXISTS idx_test_relations_related ON test_relations(related_id);
        """
        _ = try await database.execute(schema)
    }
    
    public func teardown(database: any DatabaseExecutor) async throws {
        _ = try await database.execute("DROP TABLE IF EXISTS test_relations CASCADE")
        _ = try await database.execute("DROP TABLE IF EXISTS test_entities CASCADE")
    }
}

/// Fixture with sample data
public struct SampleDataFixture: PostgresTestFixture {
    public static var fixtureName: String { "sample_data" }
    
    public func setup(database: any DatabaseExecutor) async throws {
        let fixtureLoader = PostgresFixtureLoader(database: database)
        
        // Create tables
        try await BasicSchemaFixture().setup(database: database)
        
        // Insert sample data
        let sampleData = [
            ["name": "entity1", "value": "100"],
            ["name": "entity2", "value": "200"],
            ["name": "entity3", "value": "300"]
        ]
        
        // In production: try await fixtureLoader.insertFixture(sampleData, inTable: "test_entities")
        // For now, use direct inserts
        for row in sampleData {
            let name = row["name"] ?? ""
            let value = Int(row["value"] ?? "0") ?? 0
            let sql = "INSERT INTO test_entities (name, value) VALUES (?, ?)"
            _ = try await database.execute(sql, parameters: [.text(name), .int(value)])
        }
    }
    
    public func teardown(database: any DatabaseExecutor) async throws {
        let fixtureLoader = PostgresFixtureLoader(database: database)
        try await fixtureLoader.clearTable("test_relations")
        try await fixtureLoader.clearTable("test_entities")
    }
}

/// Fixture for RLS testing
public struct RLSFixture: PostgresTestFixture {
    public static var fixtureName: String { "rls" }
    
    public func setup(database: any DatabaseExecutor) async throws {
        let schema = """
        CREATE TABLE IF NOT EXISTS multi_tenant_data (
            id SERIAL PRIMARY KEY,
            tenant_id UUID NOT NULL,
            principal_id UUID NOT NULL,
            data JSONB NOT NULL,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
        
        -- Create RLS policy
        ALTER TABLE multi_tenant_data ENABLE ROW LEVEL SECURITY;
        
        -- This would normally be created with proper tenant isolation
        -- For testing, we create a permissive policy
        CREATE POLICY IF NOT EXISTS tenant_isolation_policy ON multi_tenant_data
            USING (true);
        """
        _ = try await database.execute(schema)
    }
    
    public func teardown(database: any DatabaseExecutor) async throws {
        _ = try await database.execute("DROP TABLE IF EXISTS multi_tenant_data CASCADE")
    }
}

/// Fixture for migration testing
public struct MigrationTestFixture: PostgresTestFixture {
    public static var fixtureName: String { "migration_test" }
    
    public func setup(database: any DatabaseExecutor) async throws {
        // Create a migrations tracking table
        let schema = """
        CREATE TABLE IF NOT EXISTS schema_migrations_test (
            version INTEGER PRIMARY KEY,
            description TEXT NOT NULL,
            applied_at TIMESTAMPTZ DEFAULT NOW(),
            checksum TEXT
        );
        
        CREATE TABLE IF NOT EXISTS test_migrations_applied (
            id SERIAL PRIMARY KEY,
            migration_name TEXT NOT NULL,
            applied_at TIMESTAMPTZ DEFAULT NOW(),
            success BOOLEAN DEFAULT true,
            error TEXT
        );
        """
        _ = try await database.execute(schema)
    }
    
    public func teardown(database: any DatabaseExecutor) async throws {
        _ = try await database.execute("DROP TABLE IF EXISTS test_migrations_applied CASCADE")
        _ = try await database.execute("DROP TABLE IF EXISTS schema_migrations_test CASCADE")
    }
}
