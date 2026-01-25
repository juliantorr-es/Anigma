import Foundation
import DatabaseCore
import AnigmaCore
import SQLite3

/// SQLite-backed model registry storage with migrations
public actor ModelRegistryDatabase {
    private let dbActor: any DatabaseCore.DatabaseExecutor

    public init(dbActor: any DatabaseCore.DatabaseExecutor) async throws {
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
            """, parameters: [])

        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_models_task ON registered_models(task_contract);
            """, parameters: [])
        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_models_backend ON registered_models(backend_kind);
            """, parameters: [])
        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_models_tier ON registered_models(trust_tier);
            """, parameters: [])
        _ = try await dbActor.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_models_id ON registered_models(model_id);
            """, parameters: [])
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
            DatabaseCore.dbp(model.modelID),
            DatabaseCore.dbp(model.modelHash),
            DatabaseCore.dbp(model.taskContract.rawValue),
            DatabaseCore.dbp(model.backendKind.rawValue),
            DatabaseCore.dbp(model.source.type),
            DatabaseCore.dbp(model.source.identifier),
            DatabaseCore.dbp(model.source.revision),
            DatabaseCore.dbp(model.license),
            DatabaseCore.dbp(model.licenseDecision),
            DatabaseCore.dbp(artifactHashesStr),
            DatabaseCore.dbp(model.tokenizerHash),
            DatabaseCore.dbp(conversionReceiptsStr),
            DatabaseCore.dbp(metadataStr),
            DatabaseCore.dbp(model.trustTier.rawValue),
            DatabaseCore.dbp(model.dimensions),
            DatabaseCore.dbp(model.registeredAt.timeIntervalSince1970)
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

        let rows = try await dbActor.query(sql, parameters: [DatabaseCore.dbp(modelID), DatabaseCore.dbp(modelHash)])
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

        let rows = try await dbActor.query(sql, parameters: [DatabaseCore.dbp(modelID)])
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

        var params: [DatabaseCore.DatabaseParameter] = []

        if let taskContract = taskContract {
            sql += " AND task_contract = ?"
            params.append(DatabaseCore.dbp(taskContract.rawValue))
        }

        if let backendKind = backendKind {
            sql += " AND backend_kind = ?"
            params.append(DatabaseCore.dbp(backendKind.rawValue))
        }

        if let trustTier = trustTier {
            sql += " AND trust_tier = ?"
            params.append(DatabaseCore.dbp(trustTier.rawValue))
        }

        sql += " ORDER BY registered_at DESC"

        let rows = try await dbActor.query(sql, parameters: params)
        return rows.compactMap { try? decodeModelRecord($0) }
    }

    private func decodeModelRecord(_ row: DatabaseRow) throws -> RegisteredModelRecord {
        guard let modelID = row.string(for: "model_id"),
              let modelHash = row.string(for: "model_hash"),
              let taskContractRaw = row.string(for: "task_contract"),
              let backendKindRaw = row.string(for: "backend_kind"),
              let sourceType = row.string(for: "source_type"),
              let sourceIdentifier = row.string(for: "source_identifier"),
              let license = row.string(for: "license"),
              let licenseDecision = row.string(for: "license_decision"),
              let artifactHashesStr = row.string(for: "artifact_hashes_json"),
              let metadataStr = row.string(for: "metadata_json"),
              let trustTierRaw = row.string(for: "trust_tier"),
              let registeredAtTimestamp = row.double(for: "registered_at"),
              let taskContract = TaskContract(rawValue: taskContractRaw),
              let backendKind = BackendKind(rawValue: backendKindRaw),
              let trustTier = TrustTier(rawValue: trustTierRaw) else {
            throw ModelRegistryDatabaseError.invalidRow
        }

        let sourceRevision: String?
        if let rev = row.string(for: "source_revision") {
            sourceRevision = rev
        } else {
            sourceRevision = nil
        }

        let tokenizerHash: String?
        if let hash = row.string(for: "tokenizer_hash") {
            tokenizerHash = hash
        } else {
            tokenizerHash = nil
        }

        let conversionReceipts: [String]?
        if let jsonStr = row.string(for: "conversion_receipts_json"),
           let data = jsonStr.data(using: .utf8) {
            conversionReceipts = try? JSONDecoder().decode([String].self, from: data)
        } else {
            conversionReceipts = nil
        }

        let dimensions: Int?
        if let dim = row.int(for: "dimensions") {
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

enum ModelRegistryDatabaseError: Error {
    case invalidRow
}
