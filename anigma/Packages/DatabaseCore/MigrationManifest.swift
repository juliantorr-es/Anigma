//
//  MigrationManifest.swift
//  DatabaseCore
//
//  JSON-based migration manifest format for external module definitions.
//
//  See td-16f76f: Define migration manifest format
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Foundation

/// JSON representation of a migration step for external manifest files
public struct MigrationManifestStep: Codable, Sendable, Equatable {
    public let version: Int
    public let identifier: String
    public let module: String
    public let description: String
    public let requiredExtensions: [String]?
    public let requiredTables: [String]?
    public let applySQL: String
    public let rollbackSQL: String?
    public let rollbackExpectation: String
    
    public init(
        version: Int,
        identifier: String,
        module: String,
        description: String,
        requiredExtensions: [String]? = nil,
        requiredTables: [String]? = nil,
        applySQL: String,
        rollbackSQL: String? = nil,
        rollbackExpectation: String
    ) {
        self.version = version
        self.identifier = identifier
        self.module = module
        self.description = description
        self.requiredExtensions = requiredExtensions
        self.requiredTables = requiredTables
        self.applySQL = applySQL
        self.rollbackSQL = rollbackSQL
        self.rollbackExpectation = rollbackExpectation
    }
    
    /// Convert to PostgresMigrationStep for use with existing contract infrastructure
    public func toPostgresMigrationStep() -> PostgresMigrationStep {
        PostgresMigrationStep(
            version: version,
            identifier: identifier,
            module: module,
            requiredExtensions: requiredExtensions ?? [],
            requiredTables: requiredTables ?? [],
            applySQL: applySQL,
            rollbackSQL: rollbackSQL,
            rollbackExpectation: rollbackExpectation
        )
    }
}

/// JSON representation of a complete migration manifest for a module
public struct MigrationManifest: Codable, Sendable {
    public let contractID: String
    public let module: String
    public let description: String?
    public let migrations: [MigrationManifestStep]
    
    public init(
        contractID: String,
        module: String,
        description: String? = nil,
        migrations: [MigrationManifestStep]
    ) {
        self.contractID = contractID
        self.module = module
        self.description = description
        self.migrations = migrations
    }
    
    /// Load a migration manifest from a JSON file
    public static func load(from url: URL) async throws -> MigrationManifest {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(MigrationManifest.self, from: data)
    }
    
    /// Convert to PostgresSchemaBootstrapContract for use with SchemaMigrationRunner
    public func toBootstrapContract() throws -> PostgresSchemaBootstrapContract {
        let steps = migrations.map { $0.toPostgresMigrationStep() }
        return try PostgresSchemaBootstrapContract(
            contractID: contractID,
            migrations: steps
        )
    }
}
