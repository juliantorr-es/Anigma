import Foundation
import DatabaseCore
import AnigmaCore
import AnigmaEvents
import AnigmaPrimitives
import TelemetryCore

extension ContextumDatabase {
    public func insertArtifactCommit(_ commit: ArtifactCommitComponent) async throws {
        let sql = """
            INSERT INTO contextum_artifact_commits (
                id, artifact_id, content_hash, source_hash, media_type,
                commit_receipt_id, chunker_version, embedding_model_id,
                indexed, committed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

        let id = DatabaseParameter.text(commit.commitReceiptID)
        let artifactId = DatabaseParameter.text(commit.artifactID)
        let contentHash = DatabaseParameter.text(commit.contentHash)
        let sourceHash = DatabaseParameter.text(commit.sourceHash)
        let mediaType = DatabaseParameter.text(commit.mediaType)
        let commitReceiptId = DatabaseParameter.text(commit.commitReceiptID)
        let chunkerVersion = DatabaseParameter.int(Int(commit.chunkerVersion))
        let embeddingModelId = commit.embeddingModelID.map { DatabaseParameter.text($0) } ?? .null
        let indexed = DatabaseParameter.int(commit.indexed ? 1 : 0)
        let committedAt = DatabaseParameter.int(Int(commit.committedAt.timeIntervalSince1970))

        let parameters: [DatabaseParameter] = [
            id, artifactId, contentHash, sourceHash, mediaType,
            commitReceiptId, chunkerVersion, embeddingModelId,
            indexed, committedAt
        ]

        _ = try await database.executeAsync(sql, parameters: parameters)

        let event = AgentEvidenceEvent.artifactWrite(
            source: "ContextumModule",
            action: "artifact.commit",
            outcome: "allowed",
            traceID: TelemetryHash(
                input: "\(commit.commitReceiptID)|\(commit.artifactID)|\(commit.contentHash)"
            ).hex,
            runID: commit.commitReceiptID,
            receiptID: commit.commitReceiptID,
            payloadArtifactReferences: [
                AgentEvidenceArtifactReference(
                    artifactID: commit.artifactID,
                    role: "committed_artifact",
                    contentHash: commit.contentHash,
                    metadata: [
                        "source_hash": commit.sourceHash,
                        "media_type": commit.mediaType,
                        "chunker_version": String(commit.chunkerVersion)
                    ]
                )
            ],
            metadata: [
                "indexed": String(commit.indexed),
                "embedding_model": commit.embeddingModelID ?? ""
            ]
        )
        _ = await sharedEventBus.publishWithLogging(event, source: event.source)
    }

    public func insertIndexStatus(_ status: IndexStatusComponent) async throws {
        _ = try await database.executeAsync(
            """
            INSERT INTO contextum_index_status (
                source_id, index_type, status, last_updated, document_count, error_message
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT (source_id, index_type) DO UPDATE SET
                status = EXCLUDED.status,
                last_updated = EXCLUDED.last_updated,
                document_count = EXCLUDED.document_count,
                error_message = EXCLUDED.error_message;
            """,
            parameters: [
                .text(status.sourceId),
                .text(status.indexType.rawValue),
                .text(status.status.rawValue),
                .int(Int(status.lastUpdated.timeIntervalSince1970)),
                .int(Int(status.documentCount)),
                status.errorMessage.map { .text($0) } ?? .null
            ]
        )
    }
}
