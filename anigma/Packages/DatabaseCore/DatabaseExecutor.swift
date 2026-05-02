//
//  DatabaseExecutor.swift
//  DatabaseCore
//
//  Protocol defining the minimal database interface required by capability modules.
//

import Foundation

/// Protocol defining the database operations required by legacy modules.
public protocol DatabaseExecutor: Actor, Sendable {
    @discardableResult
    func execute(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int
    
    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow]
    
    @discardableResult
    func executeAsync(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int
    
    func transaction(_ block: @escaping @Sendable () async throws -> Void) async throws
    
    func open() throws
    
    func close()
    
    func isVectorAvailable() async -> Bool
    
    nonisolated var path: String { get }
}

extension DatabaseExecutor {
    @discardableResult
    public func execute(_ sql: String, parameters: [DatabaseParameter] = []) async throws -> Int {
        return try await executeAsync(sql, parameters: parameters)
    }
    
    public func querySingle(_ sql: String, parameters: [DatabaseParameter] = []) async throws -> DatabaseRow? {
        let rows = try await query(sql, parameters: parameters)
        return rows.first
    }

    // Convenience methods to avoid requiring 'parameters: []' at every call site
    public func query(_ sql: String) async throws -> [DatabaseRow] {
        return try await query(sql, parameters: [])
    }

    @discardableResult
    public func executeAsync(_ sql: String) async throws -> Int {
        return try await executeAsync(sql, parameters: [])
    }
}

extension DatabaseExecutor {
    public func open() throws {
        // Default no-op
    }
    
    public func close() {
        // Default no-op
    }
}
