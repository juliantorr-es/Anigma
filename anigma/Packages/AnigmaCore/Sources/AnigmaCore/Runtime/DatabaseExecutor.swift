//
//  DatabaseExecutor.swift
//  AnigmaCore
//
//  Protocol defining the minimal database interface required by capability modules.
//  Enables gradual migration from DatabaseActor to DatabaseAuthorityAdapter.
//
//  See ADR-0006: Three-Tier Runtime Architecture
//

import Foundation
import DatabaseCore

/// Protocol defining the database operations required by legacy modules.
/// Both DatabaseActor and DatabaseAuthorityAdapter conform to this protocol,
/// enabling gradual migration to runtime authorities.
public protocol DatabaseExecutor: Actor, Sendable {
    /// Execute a SQL statement with parameters (mutation)
    /// - Parameters:
    ///   - sql: SQL statement to execute
    ///   - parameters: Optional parameters for the statement
    /// - Returns: Number of rows affected
    /// - Throws: DatabaseError if execution fails
    @discardableResult
    func execute(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int
    

    
    /// Execute a query and return rows
    /// - Parameters:
    ///   - sql: SQL query
    ///   - parameters: Optional parameters for the query
    /// - Returns: Array of database rows
    /// - Throws: DatabaseError if query fails
    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow]
    
    /// Execute a mutation asynchronously (legacy method)
    /// - Parameters:
    ///   - sql: SQL mutation statement
    ///   - parameters: Optional parameters for the statement
    /// - Returns: Number of rows affected
    /// - Throws: DatabaseError if execution fails
    func executeAsync(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int
    
    /// Execute operations in a transaction
    /// - Parameter block: Block containing database operations
    /// - Throws: DatabaseError if transaction fails
    func transaction(_ block: @Sendable () async throws -> Void) async throws
    
    /// Open database connection (required for DatabaseActor, no-op for adapter)
    func open() throws
    
    /// Close database connection (no-op for adapter, connection managed by runtime)
    func close()
    
    /// Get database path (returns placeholder for compatibility)
    var path: String { get }
}

// MARK: - Default Implementations

extension DatabaseExecutor {
    /// Convenience method with empty parameters array
    @discardableResult
    public func execute(_ sql: String) async throws -> Int {
        return try await execute(sql, parameters: [])
    }
    
    /// Convenience method with empty parameters array
    public func query(_ sql: String) async throws -> [DatabaseRow] {
        return try await query(sql, parameters: [])
    }
    
    /// Convenience method with empty parameters array
    public func executeAsync(_ sql: String) async throws -> Int {
        return try await executeAsync(sql, parameters: [])
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
}

// MARK: - DatabaseActor Conformance

extension DatabaseActor: DatabaseExecutor {
    // DatabaseActor already implements query and executeAsync methods
    // Need to provide async wrapper for synchronous execute
    public func execute(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int {
        // Call the synchronous execute method with await for actor isolation
        return try await execute(sql, parameters: parameters)
    }
}

// MARK: - DatabaseAuthorityAdapter Conformance

extension DatabaseAuthorityAdapter: DatabaseExecutor {
    // DatabaseAuthorityAdapter already implements all required methods
    // No additional implementation needed
}

// MARK: - Default Implementations for Optional Methods

extension DatabaseExecutor {
    /// Default implementation that does nothing (for DatabaseAuthorityAdapter)
    public func open() throws {
        // Connection is already open or managed by runtime
    }
    
    /// Default implementation that does nothing (for DatabaseAuthorityAdapter)
    public func close() {
        // Connection is managed by runtime
    }
}

// MARK: - Type Aliases for Migration

/// Typealias for modules that need to reference either DatabaseActor or DatabaseAuthorityAdapter
public typealias LegacyDatabaseExecutor = any DatabaseExecutor

/// Convenience method to create a DatabaseExecutor from a DatabaseAuthority
public func makeDatabaseExecutor(from authority: any DatabaseAuthority) -> any DatabaseExecutor {
    return DatabaseAuthorityAdapter(databaseAuthority: authority)
}