//
//  SchemaRegistry.swift
//  DatabaseCore
//

import Foundation

/// Centralized schema registry helpers shared by runtime database authorities.
public enum SchemaRegistry {
    /// Ensures the schema registry table exists.
    public static func ensureRegistryTable(using db: any DatabaseExecutor) async throws {
        _ = try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS schema_registry (
                name TEXT PRIMARY KEY,
                module TEXT NOT NULL,
                version INTEGER NOT NULL,
                migrated_at INTEGER NOT NULL
            )
            """
        )
    }

    /// Applies ordered migrations for a module schema and records progress in `schema_registry`.
    public static func apply(
        name: String,
        module: String,
        targetVersion: Int,
        migrations: [Int: String],
        using db: any DatabaseExecutor
    ) async throws {
        guard targetVersion > 0 else { return }
        try await ensureRegistryTable(using: db)

        let rows = try await db.query(
            "SELECT version FROM schema_registry WHERE name = ?",
            parameters: [.text(name)]
        )
        let currentVersion = rows.first?.int(for: "version") ?? 0
        if currentVersion >= targetVersion { return }

        for version in (currentVersion + 1)...targetVersion {
            guard let migrationSQL = migrations[version] else {
                throw SchemaRegistryError.missingMigration(name: name, version: version)
            }

            _ = try await db.executeAsync(migrationSQL)

            let timestamp = Int(Date().timeIntervalSince1970)
            if currentVersion == 0 && version == 1 {
                _ = try await db.executeAsync(
                    "INSERT INTO schema_registry (name, module, version, migrated_at) VALUES (?, ?, ?, ?)",
                    parameters: [
                        .text(name),
                        .text(module),
                        .int(version),
                        .int(timestamp)
                    ]
                )
            } else {
                _ = try await db.executeAsync(
                    "UPDATE schema_registry SET version = ?, migrated_at = ? WHERE name = ?",
                    parameters: [
                        .int(version),
                        .int(timestamp),
                        .text(name)
                    ]
                )
            }
        }
    }
}

public enum SchemaRegistryError: Error, CustomStringConvertible {
    case missingMigration(name: String, version: Int)

    public var description: String {
        switch self {
        case let .missingMigration(name, version):
            return "Missing migration for schema '\(name)' version \(version)"
        }
    }
}
