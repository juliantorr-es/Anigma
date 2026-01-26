//
//  DevelopumAuthorities.swift
//  AnigmaAppMac
//
//  Real authorities for DevelopumModule backed by DatabaseCore and StorageCore.
//

import AnigmaCore
import DatabaseCore
import DevelopumModule
import Foundation
import StorageCore

actor AppDatabaseAuthority: DatabaseAuthority {
    private let database: DatabaseActor
    private var schemas: [String: ModuleSchema] = [:]
    private var prepareTask: Task<Void, Error>?

    init(database: DatabaseActor) {
        self.database = database
    }

    func prepare() async throws {
        if let task = prepareTask {
            try await task.value
            return
        }

        let task = Task {
            try database.open()
            try await MigrationRegistry.applyMigrations(using: database)
            try await DevelopumMigration.migrate(database)
            try await ensureSchemaRegistry()
        }
        prepareTask = task
        try await task.value
    }

    func databaseActor() async throws -> DatabaseActor {
        try await prepare()
        return database
    }

    func registerSchema(_ schema: ModuleSchema) async throws {
        try await prepare()

        let rows = try await database.query(
            "SELECT version FROM schema_registry WHERE name = ?",
            parameters: [.text(schema.name)]
        )

        let currentVersion = rows.first?.int(for: "version") ?? 0
        if currentVersion >= schema.version {
            return
        }

        for version in (currentVersion + 1)...schema.version {
            guard let migrationSQL = schema.migrations[version] else {
                throw RuntimeError.configurationError(
                    "Missing migration for schema '\(schema.name)' version \(version)"
                )
            }

            _ = try await database.executeAsync(migrationSQL)

            if currentVersion == 0 && version == 1 {
                _ = try await database.executeAsync(
                    "INSERT INTO schema_registry (name, module, version, migrated_at) VALUES (?, ?, ?, ?)",
                    parameters: [
                        .text(schema.name),
                        .text(schema.module),
                        .int(version),
                        .int(Int(Date().timeIntervalSince1970))
                    ]
                )
            } else {
                _ = try await database.executeAsync(
                    "UPDATE schema_registry SET version = ?, migrated_at = ? WHERE name = ?",
                    parameters: [
                        .int(version),
                        .int(Int(Date().timeIntervalSince1970)),
                        .text(schema.name)
                    ]
                )
            }
        }

        schemas[schema.name] = schema
    }

    func query(_ sql: String, parameters: [String: String]) async throws -> [DatabaseRow] {
        try await prepare()
        let dbParams = parameters
            .sorted { $0.key < $1.key }
            .map { DatabaseParameter.text($0.value) }
        return try await database.query(sql, parameters: dbParams)
    }

    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow] {
        try await prepare()
        return try await database.query(sql, parameters: parameters)
    }

    func mutate(
        _ mutation: DatabaseMutation,
        context: ExecutionContext
    ) async throws -> MutationReceipt {
        try await prepare()

        let rowsAffected = try await database.executeAsync(
            mutation.sql,
            parameters: mutation.parameters
        )

        let receipt = Receipt(
            operationType: "database_mutation",
            principal: context.principal,
            outcome: .success,
            summary: "Rows affected: \(rowsAffected)",
            contentHash: UUID().uuidString
        )

        return MutationReceipt(rowsAffected: rowsAffected, evidence: receipt)
    }

    func transaction(
        context: ExecutionContext,
        _ block: @Sendable () async throws -> Void
    ) async throws {
        try await prepare()
        try await database.transaction {
            try await block()
        }
    }

    private func ensureSchemaRegistry() async throws {
        _ = try await database.executeAsync(
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
}

actor AppArtifactAuthority: ArtifactAuthority {
    private let databaseAuthority: AppDatabaseAuthority
    private let vaultRoot: URL
    private var vault: VaultAuthority?

    init(databaseAuthority: AppDatabaseAuthority, vaultRoot: URL) {
        self.databaseAuthority = databaseAuthority
        self.vaultRoot = vaultRoot
    }

    func prepare() async throws {
        _ = try await resolveVault()
    }

    func store(
        _ artifact: Artifact,
        context: ExecutionContext
    ) async throws -> (id: ArtifactID, receipt: Receipt) {
        guard let content = artifact.content else {
            throw RuntimeError.configurationError("Artifact content missing")
        }

        let vault = try await resolveVault()
        let ref = try await vault.ingest(
            data: content,
            kind: .original,
            mime: artifact.mimeType,
            actorId: context.principal.id
        )

        let receipt = Receipt(
            operationType: "artifact_store",
            principal: context.principal,
            outcome: .success,
            summary: "Stored artifact \(ref.sha256Hex.prefix(12))",
            contentHash: ref.sha256Hex
        )

        return (ArtifactID(hash: ref.sha256Hex), receipt)
    }

    func retrieve(
        _ id: ArtifactID,
        principal: Principal
    ) async throws -> Artifact {
        let vault = try await resolveVault()
        let data = try await vault.open(hash: id.hash, actorId: principal.id)
        let refs = try await vault.listArtifacts(actorId: principal.id)
        let ref = refs.first { $0.sha256Hex == id.hash }

        return Artifact(
            id: id,
            mimeType: ref?.mime ?? "application/octet-stream",
            size: Int64(ref?.byteLen ?? data.count),
            createdAt: ref?.createdAt ?? Date(),
            tags: [],
            metadata: [:],
            content: data
        )
    }

    func list(
        filter: ArtifactFilter,
        principal: Principal
    ) async throws -> [ArtifactMetadata] {
        let vault = try await resolveVault()
        let refs = try await vault.listArtifacts(actorId: principal.id)
        let candidates = refs.map { ref in
            ArtifactMetadata(
                id: ArtifactID(hash: ref.sha256Hex),
                mimeType: ref.mime,
                size: Int64(ref.byteLen),
                createdAt: ref.createdAt,
                tags: [],
                metadata: [:]
            )
        }

        return candidates.filter { metadata in
            if let mimeTypes = filter.mimeTypes, !mimeTypes.contains(metadata.mimeType) {
                return false
            }
            if let createdAfter = filter.createdAfter, metadata.createdAt < createdAfter {
                return false
            }
            if let createdBefore = filter.createdBefore, metadata.createdAt > createdBefore {
                return false
            }
            return true
        }
    }

    func delete(
        _ id: ArtifactID,
        context: ExecutionContext
    ) async throws -> Receipt {
        throw RuntimeError.configurationError("Vault deletion is not supported")
    }

    private func resolveVault() async throws -> VaultAuthority {
        if let vault = vault {
            return vault
        }

        let database = try await databaseAuthority.databaseActor()
        let vault = try await VaultAuthority(
            rootURL: vaultRoot,
            database: database,
            keyProvider: DefaultVaultKeyProvider.make()
        )
        self.vault = vault
        return vault
    }
}
