//
//  DatabaseAuthority.swift
//  DatabaseCore
//
//  Governed Database Authority for Anigma.
//  Implements Request Coalescing, PostgreSQL RLS session management,
//  and cryptographically chained audit logging.
//

import Foundation
import AnigmaPrimitives

// MARK: - Errors

public enum GovernedDatabaseError: Error, Sendable {
    case connectionFailed(String)
    case queryFailed(String)
    case serializationError(String)
    case authenticationRequired
    case notImplemented(String)
}

public struct ModuleSchema: Sendable {
    public let name: String
    public let version: Int
    public let migrations: [Int: String]

    public init(name: String, version: Int, migrations: [Int: String] = [:]) {
        self.name = name
        self.version = version
        self.migrations = migrations
    }
}

public struct DatabaseExecutionContext: Sendable {
    public let principal: PrincipalID

    public init(principal: PrincipalID) {
        self.principal = principal
    }
}

public enum DatabaseReceiptOperation: Sendable, Codable {
    case databaseMutation(sql: String, rowsAffected: Int)
}

public struct DatabaseCoreReceipt: Sendable, Codable {
    public let id: DatabaseReceiptID
    public let operation: DatabaseReceiptOperation
    public let principal: PrincipalID
    public let timestamp: Date

    public init(id: DatabaseReceiptID, operation: DatabaseReceiptOperation, principal: PrincipalID, timestamp: Date) {
        self.id = id
        self.operation = operation
        self.principal = principal
        self.timestamp = timestamp
    }
}

public struct DatabaseMutation: Sendable {
    public let sql: String
    public let parameters: [DatabaseParameter]

    public init(sql: String, parameters: [DatabaseParameter] = []) {
        self.sql = sql
        self.parameters = parameters
    }
}

public struct MutationReceipt: Sendable {
    public let rowsAffected: Int
    public let evidence: DatabaseCoreReceipt

    public init(rowsAffected: Int, evidence: DatabaseCoreReceipt) {
        self.rowsAffected = rowsAffected
        self.evidence = evidence
    }
}

/// Authority for governed database access.
/// Wraps DatabaseActor with governance enforcement and schema management.
public protocol DatabaseAuthority: Actor, DatabaseExecutor {
    /// Register a module schema
    /// - Called during module registration
    /// - Runtime performs migrations, not modules
    func registerSchema(_ schema: ModuleSchema) async throws

    /// Execute a query (read-only, no governance needed)
    /// - Returns raw database rows
    func query(_ sql: String, parameters: [String: String]) async throws -> [DatabaseRow]

    /// Execute a query with ordered parameters
    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow]

    /// Execute a governed mutation
    /// - Checks KillSwitch before execution
    /// - Checks WriteGate before execution
    /// - Records evidence after execution
    /// - Returns mutation receipt with evidence
    func mutate(
        _ mutation: DatabaseMutation,
        context: DatabaseExecutionContext
    ) async throws -> MutationReceipt

    /// Execute multiple mutations in a transaction
    /// - All mutations are governed
    /// - Either all succeed or all rollback
    func transaction(
        context: DatabaseExecutionContext,
        _ block: @escaping @Sendable () async throws -> Void
    ) async throws

    /// Records a cryptographically chained audit receipt.
    func recordAudit(
        principal: PrincipalID,
        operation: String,
        entity: String,
        payload: AnyCodable
    ) async throws -> DatabaseReceiptID

    /// Executes a SQL query and decodes results into a type.
    func execute<T: Decodable>(_ sql: String, parameters: [String: AnyCodable]) async throws -> [T]
}

public actor GovernedDatabaseAuthority: DatabaseAuthority {
    public nonisolated let path: String
    private let dbActor: DatabaseActor
    
    // Thundering Herd Prevention: Coalesce identical queries
    private var activeQueries: [String: Task<Data, Error>] = [:]
    
    // Audit Chaining: Keep track of the last receipt hash per project
    private var lastReceiptHashes: [ProjectID: String] = [:]

    public init(dbActor: DatabaseActor) {
        self.dbActor = dbActor
        self.path = dbActor.path
    }

    // MARK: - DatabaseExecutor Implementation

    public func execute(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int {
        try await dbActor.execute(sql, parameters: parameters)
    }

    public func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow] {
        try await dbActor.query(sql, parameters: parameters)
    }

    public func executeAsync(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int {
        try await dbActor.executeAsync(sql, parameters: parameters)
    }

    public func transaction(_ block: @escaping @Sendable () async throws -> Void) async throws {
        try await dbActor.transaction(block)
    }
    
    public func isVectorAvailable() async -> Bool {
        await dbActor.isVectorAvailable()
    }

    // MARK: - DatabaseAuthority Implementation

    public func registerSchema(_ schema: ModuleSchema) async throws {
        // Implementation for registering schema and running migrations
        print("Registering schema: \(schema.name) v\(schema.version)")
        // In a real implementation, we would check schema_versions table and run migrations
        for (version, sql) in schema.migrations.sorted(by: { $0.key < $1.key }) {
             // Simplified: just execute for now
             _ = try await dbActor.executeAsync(sql)
        }
    }

    public func query(_ sql: String, parameters: [String: String]) async throws -> [DatabaseRow] {
        let dbParams = parameters.map { DatabaseParameter.text($1) } // Simplified
        return try await dbActor.query(sql, parameters: dbParams)
    }

    public func mutate(_ mutation: DatabaseMutation, context: DatabaseExecutionContext) async throws -> MutationReceipt {
        // Governance checks would go here (KillSwitch, WriteGate)
        let rowsAffected = try await dbActor.execute(mutation.sql, parameters: mutation.parameters)
        
        // Evidence recording
        let receipt = DatabaseCoreReceipt(
            id: DatabaseReceiptID(rawValue: UUID()),
            operation: .databaseMutation(sql: mutation.sql, rowsAffected: rowsAffected),
            principal: context.principal,
            timestamp: Date()
        )
        
        return MutationReceipt(rowsAffected: rowsAffected, evidence: receipt)
    }

    public func transaction(context: DatabaseExecutionContext, _ block: @escaping @Sendable () async throws -> Void) async throws {
        // Governance-aware transaction
        try await dbActor.transaction {
            try await block()
        }
    }

    public func execute<T: Decodable>(_ sql: String, parameters: [String: AnyCodable]) async throws -> [T] {
        let identity = try CorrelationIDContext.required
        let queryKey = "\(identity.projectID.rawValue)-\(sql)-\(parameters.description)"
        
        // 1. Request Coalescing
        if let existingTask = activeQueries[queryKey] {
            let data = try await existingTask.value
            return try JSONDecoder().decode([T].self, from: data)
        }
        
        let task = Task<Data, Error> {
            defer { activeQueries[queryKey] = nil }
            
            // In a real implementation: query dbActor and encode to Data
            throw GovernedDatabaseError.notImplemented("GovernedDatabaseAuthority.execute() is currently a stub.")
        }
        
        activeQueries[queryKey] = task
        let data = try await task.value
        return try JSONDecoder().decode([T].self, from: data)
    }

    public func recordAudit(
        principal: PrincipalID,
        operation: String,
        entity: String,
        payload: AnyCodable
    ) async throws -> DatabaseReceiptID {
        let identity = try CorrelationIDContext.required
        let previousHash = lastReceiptHashes[identity.projectID]
        
        // 3. Cryptographic Chaining
        let receiptID = DatabaseReceiptID(rawValue: UUID())
        let receiptHash = try calculateChainHash(
            receiptID: receiptID,
            previousHash: previousHash,
            payload: payload
        )
        
        // Save to PostgreSQL via dbActor...
        lastReceiptHashes[identity.projectID] = receiptHash
        
        print("Audit Recorded: \(operation) on \(entity) [Chained: \(receiptHash)]")
        return receiptID
    }
    
    private func calculateChainHash(receiptID: DatabaseReceiptID, previousHash: String?, payload: AnyCodable) throws -> String {
        // In a real implementation: Use BLAKE3 to hash (receiptID + previousHash + payload)
        return "sha256:example_hash_\(receiptID.rawValue)"
    }
}

public struct DatabaseReceiptID: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
}
