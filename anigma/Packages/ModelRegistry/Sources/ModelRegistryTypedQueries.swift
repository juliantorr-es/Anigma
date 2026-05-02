//
//  ModelRegistryTypedQueries.swift
//  ModelRegistry
//
//  Type-safe query builder definitions for ModelRegistry tables.
//  Demonstrates migration from string-based SQL to TypedQueryBuilder.
//
//  See td-8e5529: Migrate ModelRegistryStore to typed queries
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Foundation
import DatabaseCore
import IntelligenceContracts

// MARK: - Table Type Definitions

/// Table definition for models table
public enum ModelsTable: TableType {
    public static var tableName: String { "models" }
}

/// Table definition for model_hashes table
public enum ModelHashesTable: TableType {
    public static var tableName: String { "model_hashes" }
}

/// Table definition for model_runs table
public enum ModelRunsTable: TableType {
    public static var tableName: String { "model_runs" }
}

// MARK: - Column References

public extension ColumnReference where T == ModelsTable {
    /// Models.id column
    static var id: ColumnReference<ModelsTable> {
        ColumnReference(table: ModelsTable.self, name: "id")
    }
    
    /// Models.spec_json column
    static var specJSON: ColumnReference<ModelsTable> {
        ColumnReference(table: ModelsTable.self, name: "spec_json")
    }
    
    /// Models.install_path column
    static var installPath: ColumnReference<ModelsTable> {
        ColumnReference(table: ModelsTable.self, name: "install_path")
    }
    
    /// Models.status column
    static var status: ColumnReference<ModelsTable> {
        ColumnReference(table: ModelsTable.self, name: "status")
    }
    
    /// Models.last_verified column
    static var lastVerified: ColumnReference<ModelsTable> {
        ColumnReference(table: ModelsTable.self, name: "last_verified")
    }
    
    /// Models.usage_count column
    static var usageCount: ColumnReference<ModelsTable> {
        ColumnReference(table: ModelsTable.self, name: "usage_count")
    }
    
    /// Models.last_used column
    static var lastUsed: ColumnReference<ModelsTable> {
        ColumnReference(table: ModelsTable.self, name: "last_used")
    }
    
    /// Models.created_at column
    static var createdAt: ColumnReference<ModelsTable> {
        ColumnReference(table: ModelsTable.self, name: "created_at")
    }
    
    /// Models.updated_at column
    static var updatedAt: ColumnReference<ModelsTable> {
        ColumnReference(table: ModelsTable.self, name: "updated_at")
    }
}

// MARK: - Typed Query Extensions for ModelRegistryStore

public extension ModelRegistryStore {
    /// Example of using TypedQueryBuilder for the find(id:) method
    /// This demonstrates the migration pattern without breaking existing functionality
    func findTyped(id: String) async throws -> ModelRegistryEntry? {
        var query = TypedQueryBuilder<ModelsTable>()
        query.select(.id)
        query.select(.specJSON)
        query.select(.installPath)
        query.select(.status)
        query.select(.lastVerified)
        query.select(.usageCount)
        query.select(.lastUsed)
        query.from(ModelsTable.self)
        query.whereEqual(.id, id)
        
        let (sql, parameters) = query.build()
        
        guard let row = try await database.querySingle(sql, parameters: parameters) else {
            return nil
        }
        
        return try decodeEntry(from: row)
    }
    
    /// Example of using TypedQueryBuilder for the update(status:) method
    func updateTyped(_ id: String, status: ModelStatus) async throws {
        let now = Int64(Date().timeIntervalSince1970)
        let sql = """
        UPDATE models
        SET status = ?, updated_at = ?, last_verified = COALESCE(last_verified, ?)
        WHERE id = ?
        """
        
        _ = try await database.execute(sql, parameters: [
            DatabaseParameter.text(status.rawValue),
            DatabaseParameter.int(Int(now)),
            DatabaseParameter.int(Int(now)),
            DatabaseParameter.text(id)
        ])
    }
}
