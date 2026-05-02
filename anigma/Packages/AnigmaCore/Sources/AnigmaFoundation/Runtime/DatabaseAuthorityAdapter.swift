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

import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts
import Foundation
import DatabaseCore
import AnigmaPrimitives

/// Adapter that wraps DatabaseAuthority to provide DatabaseActor-like API
/// during migration to three-tier architecture.
public actor DatabaseAuthorityAdapter: DatabaseAuthority, DatabaseExecutor {
    private let databaseAuthority: any DatabaseAuthority
    private let systemContext: ExecutionContext
    
    /// Create adapter for a DatabaseAuthority
    /// - Parameter databaseAuthority: The authority to wrap
    public init(databaseAuthority: any DatabaseAuthority) {
        self.databaseAuthority = databaseAuthority
        self.systemContext = ExecutionContext(principal: .system)
    }
    
    // MARK: - DatabaseAuthority Protocol
    
    public func registerSchema(_ schema: ModuleSchema) async throws {
        try await databaseAuthority.registerSchema(schema)
    }
    
    public func query(_ sql: String, parameters: [String: String]) async throws -> [DatabaseRow] {
        try await databaseAuthority.query(sql, parameters: parameters)
    }
    
    public func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow] {
        try await databaseAuthority.query(sql, parameters: parameters)
    }
    
    public func mutate(_ mutation: DatabaseMutation, context: ExecutionContext) async throws -> MutationReceipt {
        try await databaseAuthority.mutate(mutation, context: context)
    }
    
    public func transaction(context: ExecutionContext, _ block: @escaping @Sendable () async throws -> Void) async throws {
        try await databaseAuthority.transaction(context: context, block)
    }
    
    public func isVectorAvailable() async -> Bool {
        await databaseAuthority.isVectorAvailable()
    }
    
    // MARK: - DatabaseExecutor Protocol (Legacy)
    
    @discardableResult
    public func execute(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int {
        let mutation = DatabaseMutation(
            sql: sql,
            parameters: parameters,
            componentType: "legacy_adapter"
        )
        
        let receipt = try await databaseAuthority.mutate(mutation, context: systemContext)
        return receipt.rowsAffected
    }
    
    @discardableResult
    public func executeAsync(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int {
        return try await execute(sql, parameters: parameters)
    }
    
    public func transaction(_ block: @escaping @Sendable () async throws -> Void) async throws {
        try await databaseAuthority.transaction(context: systemContext, block)
    }
    
    public func open() throws {
        // No-op for adapter
    }
    
    public func close() {
        // No-op for adapter
    }
    
    public nonisolated var path: String {
        "runtime://database-authority"
    }
}

// MARK: - Backward Compatibility Typealiases

/// Typealias for modules that reference DatabaseActor type
public typealias LegacyDatabaseActor = DatabaseAuthorityAdapter

/// Typealias for migration compatibility
public typealias MigrationDatabaseAdapter = DatabaseAuthorityAdapter
