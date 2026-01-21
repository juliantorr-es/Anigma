import Foundation
import DatabaseCore
import AnigmaCore
import SQLite3

/// SQLite-backed model registry storage with migrations
public actor ModelRegistryDatabase {
    private let dbActor: any DatabaseExecutor

    public init(dbActor: any DatabaseExecutor) async throws {
        self.dbActor = dbActor
        try await createTables()
    }

    private func createTables() async throws {
        try await dbActor.open()

        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS registered_models (
                model_id TEXT NOT NULL,
                model_hash TEXT NOT NULL,
                task_contract TEXT NOT NULL,
                backend_kind TEXT NOT NULL,
                source_type TEXT NOT NULL,
                source_identifier TEXT NOT NULL,
                source_revision TEXT,
                license TEXT NOT NULL,
                license_decision TEXT NOT NULL,
                artifact_hashes_json TEXT NOT NULL,
                tokenizer_hash TEXT,
                conversion_receipts_json TEXT,
                metadata_json TEXT NOT NULL,
                trust_tier TEXT NOT NULL,
                dimensions INTEGER,
                registered_at REAL NOT NULL,
                PRIMARY KEY (model_id, model_hash)
            );
            """)

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_models_task ON registered_models(task_contract);
            """)
        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_models_backend ON registered_models(backend_kind);
            """)
        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_models_tier ON registered_models(trust_tier);
            """)
        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_models_id ON registered_models(model_id);
            """)
    }

    public func insertModel(_ model: RegisteredModelRecord) async throws {
        let artifactHashesJSON = try JSONEncoder().encode(model.artifactHashes)
        guard let artifactHashesStr = String(data: artifactHashesJSON, encoding: .utf8) else {
            fatalError("Failed to unwrap artifactHashesStr")
        }

        let conversionReceiptsStr: String?
        if let receipts = model.conversionReceipts {
            let data = try JSONEncoder().encode(receipts)
            conversionReceiptsStr = String(data: data, encoding: .utf8)
        } else {
            conversionReceiptsStr = nil
        }

        let metadataJSON = try JSONEncoder().encode(model.metadata)
        guard let metadataStr = String(data: metadataJSON, encoding: .utf8) else {
            fatalError("Failed to unwrap metadataStr")
        }

        let sql = """
        INSERT INTO registered_models (
            model_id, model_hash, task_contract, backend_kind,
            source_type, source_identifier, source_revision,
            license, license_decision,
            artifact_hashes_json, tokenizer_hash, conversion_receipts_json,
            metadata_json, trust_tier, dimensions, registered_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        _ = try await dbActor.executeAsync(sql, parameters: [
            dbp(model.modelID),
            dbp(model.modelHash),
            dbp(model.taskContract.rawValue),
            dbp(model.backendKind.rawValue),
            dbp(model.source.type),
            dbp(model.source.identifier),
            dbp(model.source.revision),
            dbp(model.license),
            dbp(model.licenseDecision),
            dbp(artifactHashesStr),
            dbp(model.tokenizerHash),
            dbp(conversionReceiptsStr),
            dbp(metadataStr),
            dbp(model.trustTier.rawValue),
            dbp(model.dimensions),
            dbp(model.registeredAt.timeIntervalSince1970)
        ])
    }

    public func fetchModel(modelID: String, modelHash: String) async throws -> RegisteredModelRecord? {
        let sql = """
        SELECT model_id, model_hash, task_contract, backend_kind,
               source_type, source_identifier, source_revision,
               license, license_decision,
               artifact_hashes_json, tokenizer_hash, conversion_receipts_json,
               metadata_json, trust_tier, dimensions, registered_at
        FROM registered_models
        WHERE model_id = ? AND model_hash = ?
        """

        let rows = try await dbActor.query(sql, parameters: [dbp(modelID), dbp(modelHash)])
        return rows.first.flatMap { try? decodeModelRecord($0) }
    }

    public func fetchLatestModel(modelID: String) async throws -> RegisteredModelRecord? {
        let sql = """
        SELECT model_id, model_hash, task_contract, backend_kind,
               source_type, source_identifier, source_revision,
               license, license_decision,
               artifact_hashes_json, tokenizer_hash, conversion_receipts_json,
               metadata_json, trust_tier, dimensions, registered_at
        FROM registered_models
        WHERE model_id = ?
        ORDER BY registered_at DESC
        LIMIT 1
        """

        let rows = try await dbActor.query(sql, parameters: [dbp(modelID)])
        return rows.first.flatMap { try? decodeModelRecord($0) }
    }

    public func listModels(
        taskContract: TaskContract?,
        backendKind: BackendKind?,
        trustTier: TrustTier?
    ) async throws -> [RegisteredModelRecord] {
        var sql = """
        SELECT model_id, model_hash, task_contract, backend_kind,
               source_type, source_identifier, source_revision,
               license, license_decision,
               artifact_hashes_json, tokenizer_hash, conversion_receipts_json,
               metadata_json, trust_tier, dimensions, registered_at
        FROM registered_models
        WHERE 1=1
        """

        var params: [DatabaseParameter] = []

        if let taskContract = taskContract {
            sql += " AND task_contract = ?"
            params.append(dbp(taskContract.rawValue))
        }

        if let backendKind = backendKind {
            sql += " AND backend_kind = ?"
            params.append(dbp(backendKind.rawValue))
        }

        if let trustTier = trustTier {
            sql += " AND trust_tier = ?"
            params.append(dbp(trustTier.rawValue))
        }

        sql += " ORDER BY registered_at DESC"

        let rows = try await dbActor.query(sql, parameters: params)
        return rows.compactMap { try? decodeModelRecord($0) }
    }

    private func decodeModelRecord(_ row: DatabaseRow) throws -> RegisteredModelRecord {
        guard case .text(let modelID) = row.values["model_id"],
              case .text(let modelHash) = row.values["model_hash"],
              case .text(let taskContractRaw) = row.values["task_contract"],
              case .text(let backendKindRaw) = row.values["backend_kind"],
              case .text(let sourceType) = row.values["source_type"],
              case .text(let sourceIdentifier) = row.values["source_identifier"],
              case .text(let license) = row.values["license"],
              case .text(let licenseDecision) = row.values["license_decision"],
              case .text(let artifactHashesStr) = row.values["artifact_hashes_json"],
              case .text(let metadataStr) = row.values["metadata_json"],
              case .text(let trustTierRaw) = row.values["trust_tier"],
              case .double(let registeredAtTimestamp) = row.values["registered_at"],
              let taskContract = TaskContract(rawValue: taskContractRaw),
              let backendKind = BackendKind(rawValue: backendKindRaw),
              let trustTier = TrustTier(rawValue: trustTierRaw) else {
            throw DatabaseError.invalidRow
        }

        let sourceRevision: String?
        if case .text(let rev) = row.values["source_revision"] {
            sourceRevision = rev
        } else {
            sourceRevision = nil
        }

        let tokenizerHash: String?
        if case .text(let hash) = row.values["tokenizer_hash"] {
            tokenizerHash = hash
        } else {
            tokenizerHash = nil
        }

        let conversionReceipts: [String]?
        if case .text(let jsonStr) = row.values["conversion_receipts_json"],
           let data = jsonStr.data(using: .utf8) {
            conversionReceipts = try? JSONDecoder().decode([String].self, from: data)
        } else {
            conversionReceipts = nil
        }

        let dimensions: Int?
        if case .int(let dim) = row.values["dimensions"] {
            dimensions = dim
        } else {
            dimensions = nil
        }

        guard let artifactHashesData = artifactHashesStr.data(using: .utf8) else {
            fatalError("Failed to unwrap artifactHashesData")
        }
        let artifactHashes = try JSONDecoder().decode([String: String].self, from: artifactHashesData)

        guard let metadataData = metadataStr.data(using: .utf8) else {
            fatalError("Failed to unwrap metadataData")
        }
        let metadata = try JSONDecoder().decode([String: String].self, from: metadataData)

        let source = ModelSource(
            type: sourceType,
            identifier: sourceIdentifier,
            revision: sourceRevision
        )

        return RegisteredModelRecord(
            modelID: modelID,
            modelHash: modelHash,
            taskContract: taskContract,
            backendKind: backendKind,
            source: source,
            license: license,
            licenseDecision: licenseDecision,
            artifactHashes: artifactHashes,
            tokenizerHash: tokenizerHash,
            conversionReceipts: conversionReceipts,
            metadata: metadata,
            trustTier: trustTier,
            dimensions: dimensions,
            registeredAt: Date(timeIntervalSince1970: registeredAtTimestamp)
        )
    }
}

enum DatabaseError: Error {
    case invalidRow
}
