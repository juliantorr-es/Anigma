//
//  ModelRegistryStore.swift
//  AnigmaAppMac
//
//  Persistent storage for enhanced model registry with full metadata tracking.
//

import Foundation
import DatabaseCore

/// Persistent model registry backed by DatabaseActor
public actor ModelRegistryStore {
    private let dbActor: DatabaseActor
    private let schemaVersion = 2  // Incremented for enhanced schema

    public init(storagePath: String) async throws {
        self.dbActor = DatabaseActor(dbPath: storagePath)
        try await createTables()
        try await migrateIfNeeded()
    }

    private func createTables() async throws {
        let schema = """
        CREATE TABLE IF NOT EXISTS model_registry (
            model_id TEXT PRIMARY KEY,
            source_type TEXT NOT NULL,
            source_location TEXT NOT NULL,
            source_revision TEXT,

            -- Runtime status
            status TEXT NOT NULL DEFAULT 'ready',
            is_runnable INTEGER NOT NULL DEFAULT 1,

            -- Storage tracking
            install_path TEXT,
            storage_bytes INTEGER NOT NULL DEFAULT 0,
            artifact_hash TEXT NOT NULL,
            tokenizer_hash TEXT,
            artifact_hashes TEXT,  -- JSON: {"model": "hash1", "tokenizer": "hash2"}

            -- Timestamps
            registered_at INTEGER NOT NULL,
            last_verified INTEGER NOT NULL,
            last_used INTEGER,

            -- Usage analytics
            usage_count INTEGER NOT NULL DEFAULT 0,

            -- License (structured as JSON)
            license_info TEXT NOT NULL,  -- LicenseInfo as JSON

            -- Backend compatibility
            backend_compat TEXT NOT NULL,

            -- Trust tier
            trust_tier TEXT NOT NULL,

            -- Conversion receipt
            conversion_receipt_id TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_model_registry_source ON model_registry(source_type, source_location);
        CREATE INDEX IF NOT EXISTS idx_model_registry_tier ON model_registry(trust_tier);
        CREATE INDEX IF NOT EXISTS idx_model_registry_status ON model_registry(status);
        CREATE INDEX IF NOT EXISTS idx_model_registry_runnable ON model_registry(is_runnable);

        -- Schema version tracking
        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER PRIMARY KEY
        );
        """

        _ = try await dbActor.executeAsync(schema, parameters: [])
    }

    private func migrateIfNeeded() async throws {
        // Check current schema version
        let versionRows = try? await dbActor.query("SELECT version FROM schema_version LIMIT 1;", parameters: [])
        let currentVersion = versionRows?.first?.int(for: "version") ?? 1

        if currentVersion < schemaVersion {
            print("📦 Migrating model registry schema from v\(currentVersion) to v\(schemaVersion)")
            try await migrateFromV1ToV2()

            // Update version
            _ = try? await dbActor.executeAsync("DELETE FROM schema_version;", parameters: [])
            _ = try await dbActor.executeAsync("INSERT INTO schema_version (version) VALUES (?);", parameters: [.int(schemaVersion)])
        }
    }

    private func migrateFromV1ToV2() async throws {
        // Add new columns if they don't exist (SQLite doesn't have ADD COLUMN IF NOT EXISTS)
        let alterStatements = [
            "ALTER TABLE model_registry ADD COLUMN status TEXT NOT NULL DEFAULT 'ready';",
            "ALTER TABLE model_registry ADD COLUMN is_runnable INTEGER NOT NULL DEFAULT 1;",
            "ALTER TABLE model_registry ADD COLUMN install_path TEXT;",
            "ALTER TABLE model_registry ADD COLUMN storage_bytes INTEGER NOT NULL DEFAULT 0;",
            "ALTER TABLE model_registry ADD COLUMN artifact_hashes TEXT;",
            "ALTER TABLE model_registry ADD COLUMN last_verified INTEGER;",
            "ALTER TABLE model_registry ADD COLUMN last_used INTEGER;",
            "ALTER TABLE model_registry ADD COLUMN usage_count INTEGER NOT NULL DEFAULT 0;",
            "ALTER TABLE model_registry ADD COLUMN license_info TEXT;"
        ]

        for statement in alterStatements {
            // Ignore errors if column already exists
            _ = try? await dbActor.executeAsync(statement, parameters: [])
        }

        // Migrate license data from old format to new LicenseInfo struct
        let rows = try await dbActor.query("SELECT model_id, license, license_decision, imported_at FROM model_registry;", parameters: [])

        for row in rows {
            guard let modelId = row.string(for: "model_id"),
                  let licenseDecision = row.string(for: "license_decision"),
                  let importedAtInt = row.int(for: "imported_at") else {
                continue
            }

            let licenseDeclared = row.string(for: "license")
            let licenseAllowed = licenseDecision.lowercased() == "allowed"
            let licenseInfo = LicenseInfo(
                declared: licenseDeclared,
                allowed: licenseAllowed,
                reason: licenseDecision,
                reviewedAt: Date(timeIntervalSince1970: TimeInterval(importedAtInt))
            )

            let licenseJson = try JSONEncoder().encode(licenseInfo)
            let licenseStr = String(data: licenseJson, encoding: .utf8) ?? "{}"

            _ = try? await dbActor.executeAsync(
                "UPDATE model_registry SET license_info = ?, last_verified = imported_at WHERE model_id = ?;",
                parameters: [.text(licenseStr), .text(modelId)]
            )
        }
    }

    public func insertModel(_ entry: ModelRegistryEntry) async throws {
        let backendJson = try JSONEncoder().encode(entry.backendCompatibility)
        let backendStr = String(data: backendJson, encoding: .utf8) ?? "{}"

        let licenseJson = try JSONEncoder().encode(entry.license)
        let licenseStr = String(data: licenseJson, encoding: .utf8) ?? "{}"

        let artifactHashesJson = try JSONEncoder().encode(entry.artifactHashes)
        let artifactHashesStr = String(data: artifactHashesJson, encoding: .utf8) ?? "{}"

        _ = try await dbActor.executeAsync(
            """
            INSERT OR REPLACE INTO model_registry (
                model_id, source_type, source_location, source_revision,
                status, is_runnable,
                install_path, storage_bytes, artifact_hash, tokenizer_hash, artifact_hashes,
                registered_at, last_verified, last_used,
                usage_count,
                license_info,
                backend_compat, trust_tier, conversion_receipt_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            parameters: [
                .text(entry.modelId),
                .text(entry.sourceType),
                .text(entry.sourceLocation),
                .text(entry.sourceRevision ?? ""),
                .text(entry.status.rawValue),
                .int(entry.isRunnable ? 1 : 0),
                .text(entry.installPath ?? ""),
                .int(Int(entry.storageBytes)),
                .text(entry.artifactHash),
                .text(entry.tokenizerHash ?? ""),
                .text(artifactHashesStr),
                .int(Int(entry.registeredAt.timeIntervalSince1970)),
                .int(Int(entry.lastVerified.timeIntervalSince1970)),
                entry.lastUsed.map { .int(Int($0.timeIntervalSince1970)) } ?? .null,
                .int(entry.usageCount),
                .text(licenseStr),
                .text(backendStr),
                .text(entry.trustTier),
                .text(entry.conversionReceiptId ?? "")
            ]
        )
    }

    public func getAllModels() async throws -> [ModelRegistryEntry] {
        let rows = try await dbActor.query("SELECT * FROM model_registry ORDER BY registered_at DESC;", parameters: [])
        return try rows.compactMap { try parseEntry(from: $0) }
    }

    public func getModel(id: String) async throws -> ModelRegistryEntry? {
        let rows = try await dbActor.query("SELECT * FROM model_registry WHERE model_id = ?;", parameters: [.text(id)])
        guard let row = rows.first else { return nil }
        return try parseEntry(from: row)
    }

    private func parseEntry(from row: DatabaseCore.DatabaseRow) throws -> ModelRegistryEntry? {
        guard let modelId = row.string(for: "model_id"),
              let sourceType = row.string(for: "source_type"),
              let sourceLocation = row.string(for: "source_location"),
              let statusStr = row.string(for: "status"),
              let status = ModelStatus(rawValue: statusStr),
              let isRunnableInt = row.int(for: "is_runnable"),
              let artifactHash = row.string(for: "artifact_hash"),
              let licenseInfoStr = row.string(for: "license_info"),
              let backendStr = row.string(for: "backend_compat"),
              let registeredAtInt = row.int(for: "registered_at"),
              let lastVerifiedInt = row.int(for: "last_verified"),
              let trustTier = row.string(for: "trust_tier") else {
            return nil
        }

        let isRunnable = isRunnableInt != 0
        let storageBytes = Int64(row.int(for: "storage_bytes") ?? 0)
        let usageCount = row.int(for: "usage_count") ?? 0

        // Decode JSON fields
        let licenseData = Data(licenseInfoStr.utf8)
        let license = (try? JSONDecoder().decode(LicenseInfo.self, from: licenseData)) ?? LicenseInfo(declared: nil, allowed: false)

        let backendData = Data(backendStr.utf8)
        let backendCompat = (try? JSONDecoder().decode(ModelBackendCompatibility.self, from: backendData)) ?? ModelBackendCompatibility(supportedBackends: [], preferredBackend: nil)

        let artifactHashesStr = row.string(for: "artifact_hashes") ?? "{}"
        let artifactHashesData = Data(artifactHashesStr.utf8)
        let artifactHashes = (try? JSONDecoder().decode([String: String].self, from: artifactHashesData)) ?? [:]

        let lastUsed = row.int(for: "last_used").map { Date(timeIntervalSince1970: TimeInterval($0)) }

        return ModelRegistryEntry(
            modelId: modelId,
            sourceType: sourceType,
            sourceLocation: sourceLocation,
            sourceRevision: row.string(for: "source_revision"),
            status: status,
            isRunnable: isRunnable,
            taskKind: row.string(for: "task_kind") ?? "unknown",
            backendFormat: row.string(for: "backend_format") ?? "mlx",
            dimension: row.int(for: "dimension"),
            installPath: row.string(for: "install_path"),
            storageBytes: storageBytes,
            artifactHash: artifactHash,
            tokenizerHash: row.string(for: "tokenizer_hash"),
            artifactHashes: artifactHashes,
            registeredAt: Date(timeIntervalSince1970: TimeInterval(registeredAtInt)),
            lastVerified: Date(timeIntervalSince1970: TimeInterval(lastVerifiedInt)),
            lastUsed: lastUsed,
            usageCount: usageCount,
            license: license,
            backendCompatibility: backendCompat,
            trustTier: trustTier,
            conversionReceiptId: row.string(for: "conversion_receipt_id")
        )
    }

    public func deleteModel(id: String) async throws {
        _ = try await dbActor.executeAsync("DELETE FROM model_registry WHERE model_id = ?;", parameters: [.text(id)])
    }

    // MARK: - Status and Usage Helpers

    /// Update model status
    public func updateModelStatus(_ modelId: String, status: ModelStatus) async throws {
        _ = try await dbActor.executeAsync(
            "UPDATE model_registry SET status = ?, last_verified = ? WHERE model_id = ?;",
            parameters: [
                .text(status.rawValue),
                .int(Int(Date().timeIntervalSince1970)),
                .text(modelId)
            ]
        )
    }

    /// Record model usage (increment count, update lastUsed)
    public func recordModelUsage(_ modelId: String) async throws {
        _ = try await dbActor.executeAsync(
            """
            UPDATE model_registry
            SET usage_count = usage_count + 1, last_used = ?
            WHERE model_id = ?;
            """,
            parameters: [
                .int(Int(Date().timeIntervalSince1970)),
                .text(modelId)
            ]
        )
    }

    /// Update storage information after model download/conversion
    public func updateStorageInfo(_ modelId: String, installPath: String, storageBytes: Int64, artifactHashes: [String: String]) async throws {
        let artifactHashesJson = try JSONEncoder().encode(artifactHashes)
        let artifactHashesStr = String(data: artifactHashesJson, encoding: .utf8) ?? "{}"

        _ = try await dbActor.executeAsync(
            """
            UPDATE model_registry
            SET install_path = ?, storage_bytes = ?, artifact_hashes = ?, last_verified = ?
            WHERE model_id = ?;
            """,
            parameters: [
                .text(installPath),
                .int(Int(storageBytes)),
                .text(artifactHashesStr),
                .int(Int(Date().timeIntervalSince1970)),
                .text(modelId)
            ]
        )
    }
}
