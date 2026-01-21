//
//  ModelRegistryStore.swift
//  ModelRegistry
//
//  Durable SQLite-backed persistence for model registry with full provenance.
//

import Foundation
import SQLite3
import ContractsCore

/// SQLite-backed model registry with governance metadata
public actor ModelRegistryStore: ModelRegistryProtocol {
    private struct Connection: @unchecked Sendable {
        var pointer: OpaquePointer?
    }

    private var db = Connection(pointer: nil)
    private let dbPath: String

    public init(storagePath: String) async throws {
        self.dbPath = storagePath
        try await openDatabase()
        try await createSchema()
    }

    deinit {
        if let pointer = db.pointer {
            sqlite3_close(pointer)
        }
    }

    // MARK: - Database Setup

    private func openDatabase() async throws {
        var pointer: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(dbPath, &pointer, flags, nil) == SQLITE_OK else {
            throw RegistryError.databaseError("Failed to open database at \(dbPath)")
        }

        self.db = Connection(pointer: pointer)

        // Enable WAL mode for better concurrency
        try await execute("PRAGMA journal_mode=WAL")
        try await execute("PRAGMA synchronous=NORMAL")
        try await execute("PRAGMA foreign_keys=ON")
    }

    private func createSchema() async throws {
        let schema = """
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

        try await execute(schema)
    }

    private func execute(_ sql: String) async throws {
        var stmt: OpaquePointer?
        defer {
            if let stmt = stmt {
                sqlite3_finalize(stmt)
            }
        }

        guard sqlite3_prepare_v2(db.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Prepare failed: \(err)")
        }

        let result = sqlite3_step(stmt)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Execute failed: \(err)")
        }
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

        let sql = """
        INSERT OR REPLACE INTO models
        (id, spec_json, install_path, status, last_verified, usage_count, last_used, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        defer {
            if let stmt = stmt {
                sqlite3_finalize(stmt)
            }
        }

        guard sqlite3_prepare_v2(db.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Prepare failed: \(err)")
        }

        let now = Int64(Date().timeIntervalSince1970)

        sqlite3_bind_text(stmt, 1, (spec.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (String(data: specJSON, encoding: .utf8)! as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (installPath as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (entry.status.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 5, now)
        sqlite3_bind_int64(stmt, 6, 0)
        sqlite3_bind_null(stmt, 7)
        sqlite3_bind_int64(stmt, 8, now)
        sqlite3_bind_int64(stmt, 9, now)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Insert failed: \(err)")
        }

        // Store hashes
        for (filePath, hash) in spec.artifactHashes {
            try await storeHash(modelId: spec.id, filePath: filePath, hash: hash)
        }

        return entry
    }

    public func find(id: String) async throws -> ModelRegistryEntry? {
        let sql = "SELECT spec_json, install_path, status, last_verified, usage_count, last_used FROM models WHERE id = ?"

        var stmt: OpaquePointer?
        defer {
            if let stmt = stmt {
                sqlite3_finalize(stmt)
            }
        }

        guard sqlite3_prepare_v2(db.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Prepare failed: \(err)")
        }

        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        return try parseRow(stmt!, id: id)
    }

    public func query(_ filter: ModelQuery) async throws -> [ModelRegistryEntry] {
        var conditions: [String] = []
        var args: [String] = []

        if let task = filter.taskKind {
            conditions.append("json_extract(spec_json, '$.task') = ?")
            args.append(task.rawValue)
        }

        if let backend = filter.backend {
            conditions.append("json_extract(spec_json, '$.backend') = ?")
            args.append(backend.rawValue)
        }

        if let tier = filter.trustTier {
            conditions.append("json_extract(spec_json, '$.trustTier') = ?")
            args.append(tier.rawValue)
        }

        if filter.runnableOnly {
            conditions.append("json_extract(spec_json, '$.trustTier') IN ('first_class', 'compatible')")
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        let sql = "SELECT id, spec_json, install_path, status, last_verified, usage_count, last_used FROM models \(whereClause) ORDER BY last_used DESC"

        var stmt: OpaquePointer?
        defer {
            if let stmt = stmt {
                sqlite3_finalize(stmt)
            }
        }

        guard sqlite3_prepare_v2(db.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Prepare failed: \(err)")
        }

        for (idx, arg) in args.enumerated() {
            sqlite3_bind_text(stmt, Int32(idx + 1), (arg as NSString).utf8String, -1, nil)
        }

        var results: [ModelRegistryEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idCol = String(cString: sqlite3_column_text(stmt, 0))
            if let entry = try parseRow(stmt!, id: idCol) {
                results.append(entry)
            }
        }

        return results
    }

    public func update(_ id: String, status: ModelStatus) async throws {
        let sql = "UPDATE models SET status = ?, updated_at = ? WHERE id = ?"

        var stmt: OpaquePointer?
        defer {
            if let stmt = stmt {
                sqlite3_finalize(stmt)
            }
        }

        guard sqlite3_prepare_v2(db.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Prepare failed: \(err)")
        }

        sqlite3_bind_text(stmt, 1, (status.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 2, Int64(Date().timeIntervalSince1970))
        sqlite3_bind_text(stmt, 3, (id as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Update failed: \(err)")
        }
    }

    public func recordUsage(_ id: String) async throws {
        let sql = "UPDATE models SET usage_count = usage_count + 1, last_used = ?, updated_at = ? WHERE id = ?"

        var stmt: OpaquePointer?
        defer {
            if let stmt = stmt {
                sqlite3_finalize(stmt)
            }
        }

        guard sqlite3_prepare_v2(db.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Prepare failed: \(err)")
        }

        let now = Int64(Date().timeIntervalSince1970)
        sqlite3_bind_int64(stmt, 1, now)
        sqlite3_bind_int64(stmt, 2, now)
        sqlite3_bind_text(stmt, 3, (id as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Update failed: \(err)")
        }
    }

    public func verifyIntegrity(_ id: String) async throws -> Bool {
        guard let entry = try await find(id: id) else {
            return false
        }

        // Verify all artifact hashes match stored values
        for (filePath, expectedHash) in entry.spec.artifactHashes {
            let fullPath = entry.installPath + "/" + filePath
            guard let actualHash = try? await computeSHA256(path: fullPath) else {
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
        let sql = "DELETE FROM models WHERE id = ?"

        var stmt: OpaquePointer?
        defer {
            if let stmt = stmt {
                sqlite3_finalize(stmt)
            }
        }

        guard sqlite3_prepare_v2(db.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Prepare failed: \(err)")
        }

        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Delete failed: \(err)")
        }
    }

    public func listAll() async throws -> [ModelRegistryEntry] {
        return try await query(ModelQuery())
    }

    // MARK: - Run Receipt Storage

    public func storeRunReceipt(_ receipt: ModelRunReceipt, modelId: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let runSpecJSON = try encoder.encode(receipt.runSpec)
        let receiptJSON = try encoder.encode(receipt)

        let sql = """
        INSERT INTO model_runs (run_id, model_id, run_spec_json, receipt_json, created_at)
        VALUES (?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        defer {
            if let stmt = stmt {
                sqlite3_finalize(stmt)
            }
        }

        guard sqlite3_prepare_v2(db.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Prepare failed: \(err)")
        }

        sqlite3_bind_text(stmt, 1, (receipt.runSpec.requestId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (modelId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (String(data: runSpecJSON, encoding: .utf8)! as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (String(data: receiptJSON, encoding: .utf8)! as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 5, Int64(Date().timeIntervalSince1970))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Insert receipt failed: \(err)")
        }
    }

    // MARK: - Helpers

    private func storeHash(modelId: String, filePath: String, hash: String) async throws {
        let sql = """
        INSERT OR REPLACE INTO model_hashes (model_id, file_path, hash_sha256, verified_at)
        VALUES (?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        defer {
            if let stmt = stmt {
                sqlite3_finalize(stmt)
            }
        }

        guard sqlite3_prepare_v2(db.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Prepare failed: \(err)")
        }

        sqlite3_bind_text(stmt, 1, (modelId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (filePath as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (hash as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 4, Int64(Date().timeIntervalSince1970))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let err = String(cString: sqlite3_errmsg(db.pointer))
            throw RegistryError.databaseError("Store hash failed: \(err)")
        }
    }

    private func parseRow(_ stmt: OpaquePointer, id: String) throws -> ModelRegistryEntry? {
        guard let specJSONStr = sqlite3_column_text(stmt, 1) else { return nil }
        guard let installPathStr = sqlite3_column_text(stmt, 2) else { return nil }
        guard let statusStr = sqlite3_column_text(stmt, 3) else { return nil }

        let specJSON = Data(String(cString: specJSONStr).utf8)
        let installPath = String(cString: installPathStr)
        let status = ModelStatus(rawValue: String(cString: statusStr)) ?? .ready
        let lastVerified = Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 4)))
        let usageCount = sqlite3_column_int64(stmt, 5)
        let lastUsedTS = sqlite3_column_int64(stmt, 6)
        let lastUsed = lastUsedTS > 0 ? Date(timeIntervalSince1970: Double(lastUsedTS)) : nil

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let spec = try? decoder.decode(ModelSpec.self, from: specJSON) else {
            return nil
        }

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

    private func computeSHA256(path: String) async throws -> String {
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            throw RegistryError.fileNotFound(path)
        }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        fileData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(fileData.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

public enum RegistryError: Error {
    case databaseError(String)
    case fileNotFound(String)
    case invalidSpec
    case modelNotFound(String)
}

// MARK: - CommonCrypto Bridge

import CommonCrypto

private extension Data {
    func sha256() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
