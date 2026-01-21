//
//  DatabaseAuthorityAdapter.swift
//  AnigmaCore
//
//  Adapter that provides DatabaseActor-compatible API using DatabaseAuthority.
//  This enables gradual migration of capability modules from direct DatabaseActor
//  usage to runtime authorities while maintaining backward compatibility.
//
//  See ADR-0006: Three-Tier Runtime Architecture
//

import Foundation
import DatabaseCore
import AnigmaPrimitives

/// Adapter that wraps DatabaseAuthority to provide DatabaseActor-like API
/// during migration to three-tier architecture.
///
/// ## Usage
/// ```swift
/// // BEFORE (direct DatabaseActor usage):
/// let dbActor = DatabaseActor(dbPath: "...")
/// try await dbActor.execute("INSERT INTO ...", parameters: [...])
///
/// // AFTER (using adapter during migration):
/// let adapter = DatabaseAuthorityAdapter(database: runtime.database)
/// try await adapter.execute("INSERT INTO ...", parameters: [...])
///
/// // FINAL (using DatabaseAuthority directly):
/// let mutation = DatabaseMutation(sql: "INSERT INTO ...", parameters: [...])
/// let receipt = try await runtime.database.mutate(mutation, context: context)
/// ```
public actor DatabaseAuthorityAdapter {
    private let databaseAuthority: any DatabaseAuthority
    private let systemContext: ExecutionContext
    
    /// Create adapter for a DatabaseAuthority
    /// - Parameter databaseAuthority: The authority to wrap
    public init(databaseAuthority: any DatabaseAuthority) {
        self.databaseAuthority = databaseAuthority
        self.systemContext = ExecutionContext(principal: .system)
    }
    
    // MARK: - DatabaseActor-Compatible API
    
    /// Execute a SQL statement with parameters (mutation)
    /// - Parameters:
    ///   - sql: SQL statement to execute
    ///   - parameters: Optional parameters for the statement
    /// - Returns: Number of rows affected
    /// - Throws: DatabaseError or RuntimeError if governance blocks the mutation
    @discardableResult
    public func execute(_ sql: String, parameters: [DatabaseParameter] = []) async throws -> Int {
        let mutation = DatabaseMutation(
            sql: sql,
            parameters: parameters,
            componentType: "legacy_adapter"
        )
        
        let receipt = try await databaseAuthority.mutate(mutation, context: systemContext)
        return receipt.rowsAffected
    }
    
    /// Execute a SQL script (multiple statements)
    /// - Parameter sql: SQL script containing multiple statements
    /// - Returns: 0 (placeholder, scripts not directly supported via authority)
    /// - Throws: DatabaseError if execution fails
    @discardableResult
    public func executeScript(_ sql: String) async throws -> Int32 {
        // Note: DatabaseAuthority doesn't support scripts directly.
        // For migration purposes, we can execute each statement separately.
        // This is a simplified implementation - modules should migrate
        // to individual mutations for proper governance.
        let statements = sql.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        var totalRowsAffected: Int = 0
        
        for statement in statements where !statement.isEmpty {
            let rowsAffected = try await execute(statement)
            totalRowsAffected += rowsAffected
        }
        
        return Int32(totalRowsAffected)
    }
    
    /// Execute a query and return rows
    /// - Parameters:
    ///   - sql: SQL query
    ///   - parameters: Optional parameters for the query
    /// - Returns: Array of database rows
    /// - Throws: DatabaseError if query fails
    public func query(_ sql: String, parameters: [DatabaseParameter] = []) async throws -> [DatabaseRow] {
        return try await databaseAuthority.query(sql, parameters: parameters)
    }
    
    /// Execute a mutation asynchronously (legacy method)
    /// - Parameters:
    ///   - sql: SQL mutation statement
    ///   - parameters: Optional parameters for the statement
    /// - Returns: Number of rows affected
    /// - Throws: DatabaseError if execution fails
    public func executeAsync(_ sql: String, parameters: [DatabaseParameter] = []) async throws -> Int {
        // For compatibility with modules that use executeAsync for mutations
        return try await execute(sql, parameters: parameters)
    }
    
    /// Execute a query that returns a single value
    /// - Parameters:
    ///   - sql: SQL query
    ///   - parameters: Optional parameters for the query
    /// - Returns: Single database row or nil if no results
    /// - Throws: DatabaseError if query fails
    public func querySingle(_ sql: String, parameters: [DatabaseParameter] = []) async throws -> DatabaseRow? {
        let rows = try await query(sql, parameters: parameters)
        return rows.first
    }
    
    /// Execute a query with dictionary parameters (convenience method)
    /// - Parameters:
    ///   - sql: SQL query
    ///   - parameters: Dictionary of named parameters
    /// - Returns: Array of database rows
    /// - Throws: DatabaseError if query fails
    public func query(_ sql: String, parameters: [String: String]) async throws -> [DatabaseRow] {
        // Convert dictionary to ordered parameters
        // Note: This assumes named parameters like ":paramName"
        var orderedParams: [DatabaseParameter] = []
        var processedSQL = sql
        
        for (key, value) in parameters {
            let placeholder = ":\(key)"
            if processedSQL.contains(placeholder) {
                orderedParams.append(.text(value))
                // Simple replacement - for production use a proper SQL parser
                processedSQL = processedSQL.replacingOccurrences(of: placeholder, with: "?")
            }
        }
        
        return try await query(processedSQL, parameters: orderedParams)
    }
    
    // MARK: - Transaction Support
    
    /// Execute operations in a transaction
    /// - Parameter block: Block containing database operations
    /// - Throws: DatabaseError if transaction fails
    public func transaction(_ block: @Sendable () async throws -> Void) async throws {
        try await databaseAuthority.transaction(context: systemContext, block)
    }
    
    /// Open database connection (no-op for adapter, connection managed by runtime)
    public func open() throws {
        // Connection is already open or managed by runtime
    }
    
    /// Close database connection (no-op for adapter, connection managed by runtime)
    public func close() {
        // Connection is managed by the runtime, not the adapter
        // This method exists for API compatibility
    }
    
    /// Get database path (returns placeholder for compatibility)
    public nonisolated var path: String {
        // Return placeholder path for compatibility
        "runtime://database-authority"
    }
    
    // MARK: - Migration Utilities
    
    /// Create a migration context for schema setup
    /// - Returns: A DatabaseAuthorityAdapter configured for schema migrations
    public func forMigrations() -> DatabaseAuthorityAdapter {
        // For migrations, we might want different component type
        // but for now return self with system context
        return self
    }
}

// MARK: - DatabaseActor Protocol Conformance

extension DatabaseAuthorityAdapter: @unchecked Sendable {
    // The actor is already Sendable, but we need to expose it for compatibility
}

// MARK: - Convenience Extensions for Legacy Code

extension DatabaseAuthorityAdapter {
    /// Convenience method for modules that expect DatabaseActor directly
    /// - Returns: Self (adapter acts as DatabaseActor replacement)
    public func asDatabaseActor() -> DatabaseAuthorityAdapter {
        return self
    }
    
    /// Check if a table exists (migration utility)
    /// - Parameter tableName: Name of the table to check
    /// - Returns: true if table exists
    public func tableExists(_ tableName: String) async throws -> Bool {
        let sql = """
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name=?
        """
        let rows = try await query(sql, parameters: [.text(tableName)])
        return !rows.isEmpty
    }
    
    /// Get schema version for a module (migration utility)
    /// - Parameter moduleName: Name of the module
    /// - Returns: Current schema version or 0 if not registered
    public func getSchemaVersion(_ moduleName: String) async throws -> Int {
        let sql = """
            SELECT version FROM schema_registry 
            WHERE name = ?
        """
        let rows = try await query(sql, parameters: [.text(moduleName)])
        return rows.first?.int(for: "version") ?? 0
    }
}

// MARK: - Backward Compatibility Typealiases

/// Typealias for modules that reference DatabaseActor type
public typealias LegacyDatabaseActor = DatabaseAuthorityAdapter

/// Typealias for migration compatibility
public typealias MigrationDatabaseAdapter = DatabaseAuthorityAdapter

