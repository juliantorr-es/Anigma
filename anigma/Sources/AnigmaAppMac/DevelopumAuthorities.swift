//
//  DevelopumAuthorities.swift
//  AnigmaAppMac
//
//  Real authorities for DevelopumModule backed by DatabaseCore and StorageCore.
//

import AnigmaCore
import DatabaseCore
import Foundation
import StorageCore

// MARK: - Stub: DevelopumMigration
// DevelopumModule is not available; migration is a no-op for now.
enum DevelopumMigration {
    static func migrate(_ database: any DatabaseExecutor) async throws {
        // Migration stub - no-op when DevelopumModule is unavailable
    }
}

actor AppDatabaseAuthority: AnigmaFoundation.DatabaseAuthority {
    private let database: any DatabaseExecutor
    private var schemas: [String: AnigmaFoundation.ModuleSchema] = [:]
    private var prepareTask: Task<Void, Error>?

    init(database: any DatabaseExecutor) {
        self.database = database
    }

    func prepare() async throws {
        if let task = prepareTask {
            try await task.value
            return
        }

        let task = Task {
            // database is any DatabaseExecutor, open() may be async
            if let databaseActor = database as? DatabaseActor {
                try await databaseActor.open()
            } else {
                try await database.open()
            }
            try await MigrationRegistry.applyMigrations(using: database)
            try await DevelopumMigration.migrate(database)
            if let databaseActor = database as? DatabaseActor {
                _ = try await databaseActor.validateBootstrap()
            }
        }
        prepareTask = task
        try await task.value
    }

    func databaseActor() async throws -> DatabaseActor {
        try await prepare()
        guard let actor = database as? DatabaseActor else {
            throw GenericCoreError.configuration("AppDatabaseAuthority requires a DatabaseActor-backed executor")
        }
        return actor
    }

    func registerSchema(_ schema: AnigmaFoundation.ModuleSchema) async throws {
        try await prepare()
        do {
            try await SchemaRegistry.apply(
                name: schema.name,
                module: schema.module,
                targetVersion: schema.version,
                migrations: schema.migrations,
                using: database
            )
        } catch let error as SchemaRegistryError {
            throw GenericCoreError(
                error.description,
                category: .configuration,
                isRecoverable: false,
                underlyingError: error
            )
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
        _ mutation: AnigmaFoundation.DatabaseMutation,
        context: AnigmaFoundation.ExecutionContext
    ) async throws -> AnigmaFoundation.MutationReceipt {
        try await prepare()

        let rowsAffected = try await database.executeAsync(
            mutation.sql,
            parameters: mutation.parameters
        )

        let receipt = AnigmaFoundation.CoreReceipt(
            operationType: "database_mutation",
            principal: context.principal,
            outcome: .success,
            summary: "Rows affected: \(rowsAffected)",
            contentHash: UUID().uuidString
        )

        return AnigmaFoundation.MutationReceipt(rowsAffected: rowsAffected, evidence: receipt)
    }

    func transaction(
        context: AnigmaFoundation.ExecutionContext,
        _ block: @escaping @Sendable () async throws -> Void
    ) async throws {
        try await prepare()
        try await database.transaction {
            try await block()
        }
    }

    func isVectorAvailable() async -> Bool {
        if let databaseActor = database as? DatabaseActor {
            return await databaseActor.isVectorAvailable()
        }
        return false
    }

}

actor AppArtifactAuthority: AnigmaFoundation.ArtifactAuthority {
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
    ) async throws -> (id: ArtifactID, receipt: CoreReceipt) {
        guard let content = artifact.content else {
            throw GenericCoreError(
                "Artifact content missing",
                category: .configuration,
                isRecoverable: true,
                suggestedAction: "Provide artifact content before ingestion"
            )
        }

        let vault = try await resolveVault()
        let ref = try await vault.ingest(
            data: content,
            kind: .original,
            mime: artifact.mimeType,
            actorId: context.principal.id
        )

        let receipt = CoreReceipt(
            operationType: "artifact_store",
            principal: context.principal,
            outcome: .success,
            summary: "Stored artifact \(ref.hashHex.prefix(12))",
            contentHash: ref.hashHex
        )

        return (ArtifactID(hash: ref.hashHex), receipt)
    }

    func retrieve(
        _ id: ArtifactID,
        principal: Principal
    ) async throws -> Artifact {
        let vault = try await resolveVault()
        let data = try await vault.open(hash: id.hash, actorId: principal.id)
        let refs = try await vault.listArtifacts(actorId: principal.id)
        let ref = refs.first { $0.hashHex == id.hash }

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
                id: ArtifactID(hash: ref.hashHex),
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
    ) async throws -> CoreReceipt {
        throw GenericCoreError(
            "Vault deletion is not supported",
            category: .configuration,
            isRecoverable: false,
            suggestedAction: "Use archive or deprecation instead of deletion"
        )
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
