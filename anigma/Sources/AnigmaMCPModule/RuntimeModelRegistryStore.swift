import Foundation
import ContractsCore
import CryptoKit
import DatabaseCore

actor RuntimeModelRegistryStore: ModelRegistryProtocol {
    private let dbActor: DatabaseActor

    init(dbActor: DatabaseActor) async throws {
        self.dbActor = dbActor
        try await createSchema()
    }

    private func createSchema() async throws {
        try await dbActor.open()

        let schemaSQL = """
        PRAGMA foreign_keys=ON;

        CREATE TABLE IF NOT EXISTS models (
            id TEXT PRIMARY KEY,
            spec_json TEXT NOT NULL,
            install_path TEXT NOT NULL,
            status TEXT NOT NULL,
            last_verified INTEGER NOT NULL,
            usage_count INTEGER NOT NULL DEFAULT 0,
            last_used INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_models_task ON models(json_extract(spec_json, '$.task'));
        CREATE INDEX IF NOT EXISTS idx_models_backend ON models(json_extract(spec_json, '$.backend'));
        CREATE INDEX IF NOT EXISTS idx_models_trust_tier ON models(json_extract(spec_json, '$.trustTier'));
        CREATE INDEX IF NOT EXISTS idx_models_status ON models(status);

        CREATE TABLE IF NOT EXISTS model_hashes (
            model_id TEXT NOT NULL,
            file_path TEXT NOT NULL,
            hash_sha256 TEXT NOT NULL,
            verified_at INTEGER NOT NULL,
            PRIMARY KEY (model_id, file_path),
            FOREIGN KEY (model_id) REFERENCES models(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS model_runs (
            run_id TEXT PRIMARY KEY,
            model_id TEXT NOT NULL,
            run_spec_json TEXT NOT NULL,
            receipt_json TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (model_id) REFERENCES models(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_runs_model ON model_runs(model_id);
        CREATE INDEX IF NOT EXISTS idx_runs_created ON model_runs(created_at DESC);
        """

        _ = try await dbActor.executeScript(schemaSQL)
    }

    func register(_ spec: ModelSpec, installPath: String) async throws -> ModelRegistryEntry {
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
        let specString = String(data: specJSON, encoding: .utf8) ?? "{}"
        let now = Int(Date().timeIntervalSince1970)

        _ = try await dbActor.executeAsync(
            """
            INSERT OR REPLACE INTO models
            (id, spec_json, install_path, status, last_verified, usage_count, last_used, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                dbp(spec.id),
                dbp(specString),
                dbp(installPath),
                dbp(entry.status.rawValue),
                dbp(now),
                dbp(0),
                .null,
                dbp(now),
                dbp(now)
            ]
        )

        for (filePath, hash) in spec.artifactHashes {
            try await storeHash(modelId: spec.id, filePath: filePath, hash: hash)
        }

        return entry
    }

    func find(id: String) async throws -> ModelRegistryEntry? {
        let sql = """
        SELECT id, spec_json, install_path, status, last_verified, usage_count, last_used
        FROM models
        WHERE id = ?
        """

        let rows = try await dbActor.query(sql, parameters: [dbp(id)])
        return try rows.first.flatMap { try parseRow($0) }
    }

    func query(_ filter: ModelQuery) async throws -> [ModelRegistryEntry] {
        var conditions: [String] = []
        var params: [DatabaseParameter] = []

        if let task = filter.taskKind {
            conditions.append("json_extract(spec_json, '$.task') = ?")
            params.append(dbp(task.rawValue))
        }

        if let backend = filter.backend {
            conditions.append("json_extract(spec_json, '$.backend') = ?")
            params.append(dbp(backend.rawValue))
        }

        if let tier = filter.trustTier {
            conditions.append("json_extract(spec_json, '$.trustTier') = ?")
            params.append(dbp(tier.rawValue))
        }

        if filter.runnableOnly {
            conditions.append("json_extract(spec_json, '$.trustTier') IN ('first_class', 'compatible')")
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        let sql = """
        SELECT id, spec_json, install_path, status, last_verified, usage_count, last_used
        FROM models
        \(whereClause)
        ORDER BY last_used DESC
        """

        let rows = try await dbActor.query(sql, parameters: params)
        return try rows.compactMap { try parseRow($0) }
    }

    func update(_ id: String, status: ModelStatus) async throws {
        let sql = "UPDATE models SET status = ?, updated_at = ? WHERE id = ?"
        _ = try await dbActor.executeAsync(
            sql,
            parameters: [dbp(status.rawValue), dbp(Int(Date().timeIntervalSince1970)), dbp(id)]
        )
    }

    func recordUsage(_ id: String) async throws {
        let now = Int(Date().timeIntervalSince1970)
        let sql = "UPDATE models SET usage_count = usage_count + 1, last_used = ?, updated_at = ? WHERE id = ?"
        _ = try await dbActor.executeAsync(sql, parameters: [dbp(now), dbp(now), dbp(id)])
    }

    func verifyIntegrity(_ id: String) async throws -> Bool {
        guard let entry = try await find(id: id) else {
            return false
        }

        for (filePath, expectedHash) in entry.spec.artifactHashes {
            let fullPath = entry.installPath + "/" + filePath
            guard let actualHash = try? computeSHA256(path: fullPath) else {
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

    func delete(_ id: String) async throws {
        _ = try await dbActor.executeAsync("DELETE FROM models WHERE id = ?", parameters: [dbp(id)])
    }

    func listAll() async throws -> [ModelRegistryEntry] {
        return try await query(ModelQuery())
    }

    private func storeHash(modelId: String, filePath: String, hash: String) async throws {
        let sql = """
        INSERT OR REPLACE INTO model_hashes (model_id, file_path, hash_sha256, verified_at)
        VALUES (?, ?, ?, ?)
        """
        _ = try await dbActor.executeAsync(
            sql,
            parameters: [
                dbp(modelId),
                dbp(filePath),
                dbp(hash),
                dbp(Int(Date().timeIntervalSince1970))
            ]
        )
    }

    private func parseRow(_ row: DatabaseRow) throws -> ModelRegistryEntry? {
        guard case .text(let id) = row.values["id"],
              case .text(let specJSON) = row.values["spec_json"],
              case .text(let installPath) = row.values["install_path"],
              case .text(let statusRaw) = row.values["status"],
              case .int(let lastVerified) = row.values["last_verified"],
              case .int(let usageCount) = row.values["usage_count"] else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let spec = try? decoder.decode(ModelSpec.self, from: Data(specJSON.utf8)) else {
            return nil
        }

        let status = ModelStatus(rawValue: statusRaw) ?? .ready
        let lastVerifiedDate = Date(timeIntervalSince1970: Double(lastVerified))

        let lastUsed: Date?
        if case .int(let lastUsedValue) = row.values["last_used"] {
            lastUsed = Date(timeIntervalSince1970: Double(lastUsedValue))
        } else {
            lastUsed = nil
        }

        return ModelRegistryEntry(
            id: id,
            spec: spec,
            installPath: installPath,
            status: status,
            lastVerified: lastVerifiedDate,
            usageCount: Int64(usageCount),
            lastUsed: lastUsed
        )
    }

    private func computeSHA256(path: String) throws -> String {
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
