//
//  ModelRegistryStore.swift
//  ModelRegistry
//
//  PostgreSQL-backed persistence for model registry with full provenance.
//

import Foundation
import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts
import AnigmaPrimitives
import DatabaseCore
import CommonCrypto

/// PostgreSQL-backed model registry with governance metadata.
/// 
/// IMPORTANT: This class should receive a `DatabaseExecutor` via dependency injection.
/// Only composition roots (AnigmaDaemon, AnigmaApp, CLI tools) should create DatabaseActor directly.
/// See ADR-0018 and td-317bbb for details.
public actor ModelRegistryStore: ModelRegistryProtocol {
    private let database: any DatabaseExecutor

    /// Preferred initializer - receives DatabaseExecutor via dependency injection.
    /// Use this when ModelRegistryStore is created by feature modules.
    public init(database: any DatabaseExecutor) async throws {
        self.database = database
        try await openDatabase()
        try await createSchema()
    }



    // MARK: - Database Setup

    private func openDatabase() async throws {
        _ = try await database.execute("SELECT 1")
    }

    private func createSchema() async throws {
        let schema = """
        CREATE TABLE IF NOT EXISTS models (
            id TEXT PRIMARY KEY,
            spec_json JSONB NOT NULL,
            install_path TEXT NOT NULL,
            status TEXT NOT NULL,
            last_verified BIGINT NOT NULL,
            usage_count BIGINT NOT NULL DEFAULT 0,
            last_used BIGINT,
            created_at BIGINT NOT NULL,
            updated_at BIGINT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_models_task ON models(((spec_json::jsonb ->> 'task')));
        CREATE INDEX IF NOT EXISTS idx_models_backend ON models(((spec_json::jsonb ->> 'backend')));
        CREATE INDEX IF NOT EXISTS idx_models_trust_tier ON models(((spec_json::jsonb ->> 'trustTier')));
        CREATE INDEX IF NOT EXISTS idx_models_status ON models(status);

        CREATE TABLE IF NOT EXISTS model_hashes (
            model_id TEXT NOT NULL,
            file_path TEXT NOT NULL,
            artifact_hash TEXT NOT NULL,
            verified_at BIGINT NOT NULL,
            PRIMARY KEY (model_id, file_path),
            FOREIGN KEY (model_id) REFERENCES models(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS model_runs (
            run_id TEXT PRIMARY KEY,
            model_id TEXT NOT NULL,
            run_spec_json JSONB NOT NULL,
            receipt_json JSONB NOT NULL,
            created_at BIGINT NOT NULL,
            FOREIGN KEY (model_id) REFERENCES models(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_runs_model ON model_runs(model_id);
        CREATE INDEX IF NOT EXISTS idx_runs_created ON model_runs(created_at DESC);
        """

        _ = try await database.execute(schema)
    }

    // MARK: - ModelRegistryProtocol

    public func register(_ spec: ModelSpec, installPath: String) async throws -> ModelRegistryEntry {
        let entry = ModelRegistryEntry(
            id: spec.id,
            spec: spec,
            installPath: installPath,
            status: .ready,
            lastVerified: Date(),
            usageCount: 0,
            lastUsed: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let specJSON = try encoder.encode(spec)
        let now = Int64(Date().timeIntervalSince1970)

        let sql = """
        INSERT INTO models
        (id, spec_json, install_path, status, last_verified, usage_count, last_used, created_at, updated_at)
        VALUES (?, ?::jsonb, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (id) DO UPDATE SET
            spec_json = EXCLUDED.spec_json,
            install_path = EXCLUDED.install_path,
            status = EXCLUDED.status,
            last_verified = EXCLUDED.last_verified,
            usage_count = EXCLUDED.usage_count,
            last_used = EXCLUDED.last_used,
            updated_at = EXCLUDED.updated_at
        """

        _ = try await database.execute(sql, parameters: [
            .text(spec.id),
            .text(String(decoding: specJSON, as: UTF8.self)),
            .text(installPath),
            .text(entry.status.rawValue),
            .int(Int(now)),
            .int(0),
            .null,
            .int(Int(now)),
            .int(Int(now))
        ])

        for (filePath, hash) in spec.artifactHashes {
            try await storeHash(modelId: spec.id, filePath: filePath, hash: hash)
        }

        return entry
    }

    public func find(id: String) async throws -> ModelRegistryEntry? {
        let sql = """
        SELECT id, spec_json, install_path, status, last_verified, usage_count, last_used
        FROM models
        WHERE id = ?
        """

        guard let row = try await database.querySingle(sql, parameters: [.text(id)]) else {
            return nil
        }

        return try decodeEntry(from: row)
    }

    public func query(_ filter: ModelQuery) async throws -> [ModelRegistryEntry] {
        var sql = """
        SELECT id, spec_json, install_path, status, last_verified, usage_count, last_used
        FROM models
        WHERE 1=1
        """
        var parameters: [DatabaseParameter] = []

        if let task = filter.taskKind {
            sql += " AND (spec_json::jsonb ->> 'task') = ?"
            parameters.append(.text(task.rawValue))
        }

        if let backend = filter.backend {
            sql += " AND (spec_json::jsonb ->> 'backend') = ?"
            parameters.append(.text(backend.rawValue))
        }

        if let tier = filter.trustTier {
            sql += " AND (spec_json::jsonb ->> 'trustTier') = ?"
            parameters.append(.text(tier.rawValue))
        }

        if filter.runnableOnly {
            sql += " AND (spec_json::jsonb ->> 'trustTier') IN ('first_class', 'compatible')"
        }

        if let sourcePattern = filter.sourcePattern, !sourcePattern.isEmpty {
            sql += " AND (spec_json::jsonb ->> 'source') ILIKE ?"
            parameters.append(.text("%\(sourcePattern)%"))
        }

        sql += " ORDER BY last_used DESC NULLS LAST, updated_at DESC"

        let rows = try await database.query(sql, parameters: parameters)
        return rows.compactMap { try? decodeEntry(from: $0) }
    }

    public func update(_ id: String, status: ModelStatus) async throws {
        let sql = """
        UPDATE models
        SET status = ?, updated_at = ?, last_verified = COALESCE(last_verified, ?)
        WHERE id = ?
        """

        _ = try await database.execute(sql, parameters: [
            .text(status.rawValue),
            .int(Int(Date().timeIntervalSince1970)),
            .int(Int(Date().timeIntervalSince1970)),
            .text(id)
        ])
    }

    public func recordUsage(_ id: String) async throws {
        let now = Int64(Date().timeIntervalSince1970)
        let sql = """
        UPDATE models
        SET usage_count = usage_count + 1,
            last_used = ?,
            updated_at = ?
        WHERE id = ?
        """

        _ = try await database.execute(sql, parameters: [
            .int(Int(now)),
            .int(Int(now)),
            .text(id)
        ])
    }

    public func verifyIntegrity(_ id: String) async throws -> Bool {
        guard let entry = try await find(id: id) else {
            return false
        }

        for (filePath, expectedHash) in entry.spec.artifactHashes {
            let fullPath = entry.installPath + "/" + filePath
            guard let actualHash = computeBlake3(path: fullPath) else {
                return false
            }

            if actualHash != expectedHash {
                try await update(id, status: .degraded)
                return false
            }
        }

        try await update(id, status: .ready)
        return true
    }

    public func delete(_ id: String) async throws {
        _ = try await database.execute("DELETE FROM models WHERE id = ?", parameters: [.text(id)])
    }

    public func listAll() async throws -> [ModelRegistryEntry] {
        try await query(ModelQuery())
    }

    // MARK: - Run CoreReceipt Storage

    public func storeRunReceipt(_ receipt: ModelRunReceipt, modelId: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let runSpecJSON = try encoder.encode(receipt.runSpec)
        let receiptJSON = try encoder.encode(receipt)
        let now = Int64(Date().timeIntervalSince1970)

        let sql = """
        INSERT INTO model_runs (run_id, model_id, run_spec_json, receipt_json, created_at)
        VALUES (?, ? , ?::jsonb, ?::jsonb, ?)
        ON CONFLICT (run_id) DO UPDATE SET
            model_id = EXCLUDED.model_id,
            run_spec_json = EXCLUDED.run_spec_json,
            receipt_json = EXCLUDED.receipt_json,
            created_at = EXCLUDED.created_at
        """

        _ = try await database.execute(sql, parameters: [
            .text(receipt.runSpec.requestId),
            .text(modelId),
            .text(String(decoding: runSpecJSON, as: UTF8.self)),
            .text(String(decoding: receiptJSON, as: UTF8.self)),
            .int(Int(now))
        ])
    }

    // MARK: - Helpers

    private func storeHash(modelId: String, filePath: String, hash: String) async throws {
        let sql = """
        INSERT INTO model_hashes (model_id, file_path, artifact_hash, verified_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT (model_id, file_path) DO UPDATE SET
            artifact_hash = EXCLUDED.artifact_hash,
            verified_at = EXCLUDED.verified_at
        """

        _ = try await database.execute(sql, parameters: [
            .text(modelId),
            .text(filePath),
            .text(hash),
            .int(Int(Date().timeIntervalSince1970))
        ])
    }

    private func decodeEntry(from row: DatabaseRow) throws -> ModelRegistryEntry? {
        guard
            let id = row.string(for: "id"),
            let specJSON = row.string(for: "spec_json"),
            let installPath = row.string(for: "install_path"),
            let statusRaw = row.string(for: "status")
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let specData = specJSON.data(using: .utf8),
              let spec = try? decoder.decode(ModelSpec.self, from: specData) else {
            return nil
        }

        let lastVerified = Date(timeIntervalSince1970: Double(row.int(for: "last_verified") ?? 0))
        let usageCount = row.int64(for: "usage_count") ?? 0
        let lastUsedTS = row.int64(for: "last_used") ?? 0
        let lastUsed = lastUsedTS > 0 ? Date(timeIntervalSince1970: Double(lastUsedTS)) : nil
        let status = ModelStatus(rawValue: statusRaw) ?? .ready

        return ModelRegistryEntry(
            id: id,
            spec: spec,
            installPath: installPath,
            status: status,
            lastVerified: lastVerified,
            usageCount: usageCount,
            lastUsed: lastUsed
        )
    }

    private func computeBlake3(path: String) -> String? {
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return BLAKE3Digest.hex(of: fileData)
    }
}
