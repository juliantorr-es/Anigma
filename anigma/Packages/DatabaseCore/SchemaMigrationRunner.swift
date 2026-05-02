//
//  SchemaMigrationRunner.swift
//  DatabaseCore
//
//  PostgreSQL schema migration runner actor.
//

import Foundation

public enum SchemaMigrationError: Error, CustomStringConvertible, Equatable {
    case extensionCreationFailed(extension: String, error: String)
    case migrationApplicationFailed(version: Int, error: String)
    case rollbackFailed(version: Int, error: String)
    case validationFailed(message: String)

    public var description: String {
        switch self {
        case let .extensionCreationFailed(extensionName, error):
            return "Failed to create extension \(extensionName): \(error)"
        case let .migrationApplicationFailed(version, error):
            return "Migration v\(version) failed: \(error)"
        case let .rollbackFailed(version, error):
            return "Rollback to v\(version) failed: \(error)"
        case let .validationFailed(message):
            return "Validation failed: \(message)"
        }
    }
}

public struct MigrationRunResult: Sendable, Equatable {
    public let appliedCount: Int
    public let skippedCount: Int
    public let failedCount: Int
    public let currentVersion: Int
    public let targetVersion: Int
    public let missingExtensions: [String]
    public let validationReport: PostgresSchemaValidationReport?

    public init(
        appliedCount: Int = 0,
        skippedCount: Int = 0,
        failedCount: Int = 0,
        currentVersion: Int,
        targetVersion: Int,
        missingExtensions: [String] = [],
        validationReport: PostgresSchemaValidationReport? = nil
    ) {
        self.appliedCount = appliedCount
        self.skippedCount = skippedCount
        self.failedCount = failedCount
        self.currentVersion = currentVersion
        self.targetVersion = targetVersion
        self.missingExtensions = missingExtensions
        self.validationReport = validationReport
    }

    public var isSuccessful: Bool {
        failedCount == 0 && missingExtensions.isEmpty && validationReport?.isSatisfied == true
    }
}

public struct MigrationRollbackResult: Sendable, Codable, Equatable {
    public let rolledBackToVersion: Int
    public let rolledBackCount: Int
    public let success: Bool
    public let error: String?

    public init(
        rolledBackToVersion: Int,
        rolledBackCount: Int,
        success: Bool,
        error: String? = nil
    ) {
        self.rolledBackToVersion = rolledBackToVersion
        self.rolledBackCount = rolledBackCount
        self.success = success
        self.error = error
    }
}

public enum RequiredPostgresExtension: String, CaseIterable, Sendable, Codable {
    case pgvector = "vector"
    case pgTrgm = "pg_trgm"
    case pgCrypto = "pgcrypto"
    case uuidOsp = "uuid-ossp"

    public var createStatement: String {
        "CREATE EXTENSION IF NOT EXISTS \"\(rawValue)\""
    }
}

public actor SchemaMigrationRunner {
    private let database: any DatabaseExecutor
    private let contract: PostgresSchemaBootstrapContract
    private let requiredExtensions: [RequiredPostgresExtension]

    public init(
        database: any DatabaseExecutor,
        contract: PostgresSchemaBootstrapContract? = nil,
        requiredExtensions: [RequiredPostgresExtension]? = nil
    ) async throws {
        self.database = database
        self.contract = try contract ?? .canonical()
        self.requiredExtensions = requiredExtensions ?? [.pgvector, .pgTrgm, .pgCrypto]
    }

    public func getCurrentVersion() async throws -> Int {
        do {
            let rows = try await database.query(
                "SELECT version FROM schema_registry WHERE name = ?",
                parameters: [.text(contract.contractID)]
            )
            return rows.first?.int(for: "version") ?? 0
        } catch {
            guard Self.isMissingSchemaRegistry(error) else {
                throw error
            }
            return 0
        }
    }

    public func verifyExtensions() async throws -> [String] {
        let installedRows = try await database.query("SELECT extname FROM pg_extension")
        let installedExtensions = Set(installedRows.compactMap { $0.string(for: "extname") })
        return requiredExtensions.compactMap { extensionName in
            installedExtensions.contains(extensionName.rawValue) ? nil : extensionName.rawValue
        }
    }

    @discardableResult
    public func ensureExtensions() async throws -> [String] {
        let missing = try await verifyExtensions()
        var created: [String] = []

        for extensionName in missing {
            guard let requiredExtension = RequiredPostgresExtension(rawValue: extensionName) else {
                continue
            }

            do {
                try await database.executeAsync(requiredExtension.createStatement)
                created.append(extensionName)
            } catch {
                throw SchemaMigrationError.extensionCreationFailed(
                    extension: extensionName,
                    error: error.localizedDescription
                )
            }
        }

        return created
    }

    public func validateLiveSchema() async throws -> PostgresSchemaValidationReport {
        do {
            return try await contract.validateLiveCatalog(using: database)
        } catch {
            guard Self.isMissingSchemaRegistry(error) else {
                throw error
            }
            let report = PostgresSchemaValidationReport(
                expectedVersion: contract.expectedVersion,
                appliedVersion: 0,
                missingExtensions: contract.requiredExtensions,
                missingTables: contract.requiredTables
            )
            throw PostgresSchemaBootstrapError.liveValidationFailed(report)
        }
    }

    public func checkSchemaDrift() async throws -> Bool {
        do {
            _ = try await validateLiveSchema()
            return false
        } catch let PostgresSchemaBootstrapError.liveValidationFailed(report) {
            return !report.isSatisfied
        }
    }

    public func runMigrations() async throws -> MigrationRunResult {
        try await SchemaRegistry.ensureRegistryTable(using: database)

        let currentVersion = try await getCurrentVersion()
        let missingExtensionsBefore = try await verifyExtensions()
        if !missingExtensionsBefore.isEmpty {
            try await ensureExtensions()
        }

        var appliedCount = 0
        var skippedCount = 0
        var failedCount = 0

        for migration in contract.migrations {
            guard migration.version > currentVersion else {
                skippedCount += 1
                continue
            }

            let shouldInsertRegistry = currentVersion == 0 && appliedCount == 0
            let database = database
            let contractID = contract.contractID

            do {
                try await database.transaction {
                    try await database.executeAsync(migration.applySQL)
                    let timestamp = Int(Date().timeIntervalSince1970)
                    if shouldInsertRegistry {
                        try await database.executeAsync(
                            "INSERT INTO schema_registry (name, module, version, migrated_at) VALUES (?, ?, ?, ?)",
                            parameters: [
                                .text(contractID),
                                .text(migration.module),
                                .int(migration.version),
                                .int(timestamp)
                            ]
                        )
                    } else {
                        try await database.executeAsync(
                            "UPDATE schema_registry SET version = ?, module = ?, migrated_at = ? WHERE name = ?",
                            parameters: [
                                .int(migration.version),
                                .text(migration.module),
                                .int(timestamp),
                                .text(contractID)
                            ]
                        )
                    }
                }
                appliedCount += 1
            } catch {
                failedCount += 1
                throw SchemaMigrationError.migrationApplicationFailed(
                    version: migration.version,
                    error: error.localizedDescription
                )
            }
        }

        let validationReport = try await validateLiveSchema()
        let missingExtensionsAfter = try await verifyExtensions()

        return MigrationRunResult(
            appliedCount: appliedCount,
            skippedCount: skippedCount,
            failedCount: failedCount,
            currentVersion: currentVersion,
            targetVersion: contract.expectedVersion,
            missingExtensions: missingExtensionsAfter,
            validationReport: validationReport
        )
    }

    public func rollback(to version: Int) async throws -> MigrationRollbackResult {
        guard version >= 0 else {
            throw SchemaMigrationError.rollbackFailed(
                version: version,
                error: "Target version must be >= 0"
            )
        }

        try await SchemaRegistry.ensureRegistryTable(using: database)
        let currentVersion = try await getCurrentVersion()

        guard version < currentVersion else {
            return MigrationRollbackResult(
                rolledBackToVersion: currentVersion,
                rolledBackCount: 0,
                success: true,
                error: "Already at or before target version"
            )
        }

        let rollbackSQLs = contract.migrations
            .filter { $0.version > version }
            .sorted { $0.version > $1.version }
            .compactMap(\.rollbackSQL)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let database = database
        let contractID = contract.contractID
        try await database.transaction {
            for rollbackSQL in rollbackSQLs {
                try await database.executeAsync(rollbackSQL)
            }
            try await database.executeAsync(
                "UPDATE schema_registry SET version = ? WHERE name = ?",
                parameters: [.int(version), .text(contractID)]
            )
        }

        return MigrationRollbackResult(
            rolledBackToVersion: version,
            rolledBackCount: rollbackSQLs.count,
            success: true
        )
    }

    private static func isMissingSchemaRegistry(_ error: any Error) -> Bool {
        if case let DatabaseError.queryError(message) = error {
            return message.localizedCaseInsensitiveContains("schema_registry")
                && (
                    message.localizedCaseInsensitiveContains("does not exist")
                    || message.localizedCaseInsensitiveContains("no such table")
                    || message.localizedCaseInsensitiveContains("undefined_table")
                    || message.localizedCaseInsensitiveContains("42p01")
                )
        }
        return false
    }
}
