import Foundation
import DatabaseCore
import CryptoKit

/// Centralized idempotency enforcement for Contextum operations
public actor IdempotencyGuard {
    private let database: ContextumDatabase

    public init(database: ContextumDatabase) {
        self.database = database
    }

    // MARK: - State Key Generation

    public func makeIngestStateKey(
        artifactID: String,
        contentHash: String
    ) -> String {
        return "ingest:\(artifactID):\(contentHash)"
    }

    public func makeChunkStateKey(
        contentHash: String,
        chunkerVersion: Int
    ) -> String {
        return "chunk:\(contentHash):v\(chunkerVersion)"
    }

    public func makeEmbedStateKey(
        chunkHash: String,
        modelID: String,
        modelHash: String
    ) -> String {
        return "embed:\(chunkHash):\(modelID):\(modelHash)"
    }

    public func makeIndexStateKey(
        contentHash: String,
        chunkerVersion: Int,
        embeddingModelID: String?
    ) -> String {
        let modelPart = embeddingModelID ?? "none"
        return "index:\(contentHash):v\(chunkerVersion):\(modelPart)"
    }

    // MARK: - Idempotency Checks

    public func checkIngestIdempotency(
        artifactID: String,
        contentHash: String
    ) async throws -> IngestIdempotencyResult {
        let stateKey = makeIngestStateKey(artifactID: artifactID, contentHash: contentHash)

        if let existing = try await database.queryIndexState(stateKey: stateKey) {
            return .alreadyIngested(
                sourceID: existing.artifactID,
                ingestedAt: existing.lastUpdated
            )
        }

        return .shouldIngest(stateKey: stateKey)
    }

    public func checkChunkIdempotency(
        contentHash: String,
        chunkerVersion: Int
    ) async throws -> ChunkIdempotencyResult {
        let stateKey = makeChunkStateKey(contentHash: contentHash, chunkerVersion: chunkerVersion)

        if let existing = try await database.queryIndexState(stateKey: stateKey),
           existing.chunkingNeeded == false {
            // Chunking already complete, return existing chunk IDs
            let chunks = try await database.queryChunksByContentHash(contentHash: contentHash)
            return .alreadyChunked(chunkIDs: chunks.map { $0.chunkId })
        }

        return .shouldChunk(stateKey: stateKey)
    }

    public func checkEmbedIdempotency(
        chunkHash: String,
        modelID: String,
        modelHash: String
    ) async throws -> EmbedIdempotencyResult {
        // Check if embedding already exists
        if let existing = try await database.queryEmbedding(
            chunkHash: chunkHash,
            modelHash: modelHash
        ) {
            return .alreadyEmbedded(
                embeddingID: existing.embeddingID,
                receiptID: existing.receiptID,
                evidenceHeadHash: existing.evidenceHeadHash
            )
        }

        return .shouldEmbed(
            stateKey: makeEmbedStateKey(chunkHash: chunkHash, modelID: modelID, modelHash: modelHash)
        )
    }
    
    public func recordIngestState(
        stateKey: String,
        artifactID: String,
        contentHash: String,
        chunkerVersion: String,
        embeddingModelID: String,
        chunkingNeeded: Bool,
        embeddingNeeded: Bool
    ) async throws {
        let config = RecordIngestStateConfiguration(
            stateKey: stateKey,
            artifactID: artifactID,
            contentHash: contentHash,
            chunkerVersion: chunkerVersion,
            embeddingModelID: embeddingModelID,
            chunkingNeeded: chunkingNeeded,
            embeddingNeeded: embeddingNeeded
        )
        try await recordIngestState(config: config)
    }
    
    public func recordIngestState(config: RecordIngestStateConfiguration) async throws {
        let dbConfig = ContextumDatabase.InsertIndexStateConfiguration(
            id: UUID().uuidString,
            stateKey: config.stateKey,
            artifactID: config.artifactID,
            contentHash: config.contentHash,
            chunkerVersion: Int(config.chunkerVersion) ?? 1,
            embeddingModelID: config.embeddingModelID,
            status: "pending",
            chunkingNeeded: config.chunkingNeeded,
            embeddingNeeded: config.embeddingNeeded
        )
        try await database.insertIndexState(config: dbConfig)
    }
    
    public struct RecordIngestStateConfiguration: Sendable {
        let stateKey: String
        let artifactID: String
        let contentHash: String
        let chunkerVersion: String
        let embeddingModelID: String
        let chunkingNeeded: Bool
        let embeddingNeeded: Bool
        
        public init(
            stateKey: String,
            artifactID: String,
            contentHash: String,
            chunkerVersion: String,
            embeddingModelID: String,
            chunkingNeeded: Bool,
            embeddingNeeded: Bool
        ) {
            self.stateKey = stateKey
            self.artifactID = artifactID
            self.contentHash = contentHash
            self.chunkerVersion = chunkerVersion
            self.embeddingModelID = embeddingModelID
            self.chunkingNeeded = chunkingNeeded
            self.embeddingNeeded = embeddingNeeded
        }
    }



    public func recordChunkCompletion(
        stateKey: String
    ) async throws {
        try await database.updateIndexState(
            stateKey: stateKey,
            updates: [
                "chunking_needed": .int(0),
                "status": .text("chunked"),
                "last_updated": .int(Int(Date().timeIntervalSince1970))
            ]
        )
    }

    public func recordEmbedCompletion(
        stateKey: String
    ) async throws {
        try await database.updateIndexState(
            stateKey: stateKey,
            updates: [
                "embedding_needed": .int(0),
                "status": .text("embedded"),
                "last_updated": .int(Int(Date().timeIntervalSince1970))
            ]
        )
    }

    // MARK: - Result Types

    public enum IngestIdempotencyResult: Sendable {
        case shouldIngest(stateKey: String)
        case alreadyIngested(sourceID: String, ingestedAt: Date)
    }

    public enum ChunkIdempotencyResult {
        case shouldChunk(stateKey: String)
        case alreadyChunked(chunkIDs: [String])
    }

    public enum EmbedIdempotencyResult {
        case shouldEmbed(stateKey: String)
        case alreadyEmbedded(embeddingID: String, receiptID: String, evidenceHeadHash: String?)
    }
}

// MARK: - Database Extensions

extension ContextumDatabase {
    func queryIndexState(stateKey: String) async throws -> IndexStateRecord? {
        let rows = try await dbActor.query(
            """
            SELECT id, state_key, artifact_id, content_hash, chunker_version,
                   embedding_model_id, status, chunking_needed, embedding_needed,
                   plan_recorded_at, last_updated
            FROM contextum_index_states
            WHERE state_key = ?
            LIMIT 1;
            """,
            parameters: [DatabaseParameter.text(stateKey)]
        )

        guard let row = rows.first,
              let id = row.string(for: "id"),
              let artifactID = row.string(for: "artifact_id"),
              let contentHash = row.string(for: "content_hash"),
              let status = row.string(for: "status") else {
            return nil
        }

        let chunkerVersion = row.int(for: "chunker_version") ?? 1
        let embeddingModelID = row.string(for: "embedding_model_id")
        let chunkingNeeded = (row.int(for: "chunking_needed") ?? 1) != 0
        let embeddingNeeded = (row.int(for: "embedding_needed") ?? 1) != 0
        let planRecordedAtInt = row.int(for: "plan_recorded_at") ?? 0
        let lastUpdatedInt = row.int(for: "last_updated") ?? 0
        let planRecordedAt = Date(timeIntervalSince1970: TimeInterval(planRecordedAtInt))
        let lastUpdated = Date(timeIntervalSince1970: TimeInterval(lastUpdatedInt))

        return IndexStateRecord(
            id: id,
            stateKey: stateKey,
            artifactID: artifactID,
            contentHash: contentHash,
            chunkerVersion: chunkerVersion,
            embeddingModelID: embeddingModelID,
            status: status,
            chunkingNeeded: chunkingNeeded,
            embeddingNeeded: embeddingNeeded,
            planRecordedAt: planRecordedAt,
            lastUpdated: lastUpdated
        )
    }

    func queryChunksByContentHash(contentHash: String) async throws -> [ChunkRecord] {
        let rows = try await dbActor.query(
            """
            SELECT chunk_id, source_id, content_hash, chunk_index
            FROM contextum_chunks
            WHERE content_hash = ?
            ORDER BY chunk_index ASC;
            """,
            parameters: [DatabaseParameter.text(contentHash)]
        )

        return rows.compactMap { row in
            guard let chunkID = row.string(for: "chunk_id"),
                  let sourceID = row.string(for: "source_id"),
                  let hash = row.string(for: "content_hash") else {
                return nil
            }
            let index = row.int(for: "chunk_index") ?? 0
            return ChunkRecord(chunkId: chunkID, sourceId: sourceID, contentHash: hash, chunkIndex: index)
        }
    }

    func queryEmbedding(chunkHash: String, modelHash: String) async throws -> EmbeddingRecord? {
        let rows = try await dbActor.query(
            """
            SELECT embedding_id, receipt_id, evidence_head_hash
            FROM contextum_embeddings
            WHERE chunk_hash = ? AND model_hash = ?
            LIMIT 1;
            """,
            parameters: [DatabaseParameter.text(chunkHash), DatabaseParameter.text(modelHash)]
        )
        guard let row = rows.first,
              let embeddingID = row.string(for: "embedding_id"),
              let receiptID = row.string(for: "receipt_id") else {
            return nil
        }
        let evidenceHeadHash = row.string(for: "evidence_head_hash")
        return EmbeddingRecord(
            embeddingID: embeddingID,
            receiptID: receiptID,
            evidenceHeadHash: evidenceHeadHash
        )
    }
    
    public struct InsertIndexStateConfiguration: Sendable {
        let id: String
        let stateKey: String
        let artifactID: String
        let contentHash: String
        let chunkerVersion: Int
        let embeddingModelID: String?
        let status: String
        let chunkingNeeded: Bool
        let embeddingNeeded: Bool
        
        init(
            id: String,
            stateKey: String,
            artifactID: String,
            contentHash: String,
            chunkerVersion: Int,
            embeddingModelID: String?,
            status: String,
            chunkingNeeded: Bool,
            embeddingNeeded: Bool
        ) {
            self.id = id
            self.stateKey = stateKey
            self.artifactID = artifactID
            self.contentHash = contentHash
            self.chunkerVersion = chunkerVersion
            self.embeddingModelID = embeddingModelID
            self.status = status
            self.chunkingNeeded = chunkingNeeded
            self.embeddingNeeded = embeddingNeeded
        }
    }
    
    public func insertIndexState(config: InsertIndexStateConfiguration) async throws {
        let now = Int(Date().timeIntervalSince1970)
        _ = try await dbActor.executeAsync(
            """
            INSERT OR IGNORE INTO contextum_index_states (
                id, state_key, artifact_id, content_hash, chunker_version,
                embedding_model_id, status, chunking_needed, embedding_needed,
                plan_recorded_at, last_updated
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            parameters: [
                DatabaseParameter.text(config.id),
                DatabaseParameter.text(config.stateKey),
                DatabaseParameter.text(config.artifactID),
                DatabaseParameter.text(config.contentHash),
                DatabaseParameter.int(config.chunkerVersion),
                config.embeddingModelID.map { DatabaseParameter.text($0) } ?? DatabaseParameter.null,
                DatabaseParameter.text(config.status),
                DatabaseParameter.int(config.chunkingNeeded ? 1 : 0),
                DatabaseParameter.int(config.embeddingNeeded ? 1 : 0),
                DatabaseParameter.int(now),
                DatabaseParameter.int(now)
            ]
        )
    }

    func updateIndexState(stateKey: String, updates: [String: DatabaseParameter]) async throws {
        var setClauses: [String] = []
        var params: [DatabaseParameter] = []

        for (key, value) in updates {
            setClauses.append("\(key) = ?")
            params.append(value)
        }

        params.append(DatabaseParameter.text(stateKey))

        let sql = """
            UPDATE contextum_index_states
            SET \(setClauses.joined(separator: ", "))
            WHERE state_key = ?;
            """

        _ = try await dbActor.executeAsync(sql, parameters: params)
    }
}

// MARK: - Supporting Record Types

public struct IndexStateRecord: Sendable {
    let id: String
    let stateKey: String
    let artifactID: String
    let contentHash: String
    let chunkerVersion: Int
    let embeddingModelID: String?
    let status: String
    let chunkingNeeded: Bool
    let embeddingNeeded: Bool
    let planRecordedAt: Date
    let lastUpdated: Date
}

public struct ChunkRecord: Sendable {
    let chunkId: String
    let sourceId: String
    let contentHash: String
    let chunkIndex: Int
}

public struct EmbeddingRecord: Sendable {
    let embeddingID: String
    let receiptID: String
    let evidenceHeadHash: String?
}
