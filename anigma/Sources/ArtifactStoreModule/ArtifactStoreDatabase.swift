import Foundation
import DatabaseCore
import AnigmaCore

/// Database layer for artifact metadata
/// Backed by DatabaseActor for governed, court-safe persistence
public actor ArtifactStoreDatabase {
    private let dbActor: any DatabaseCore.DatabaseExecutor

    public init(dbActor: any DatabaseCore.DatabaseExecutor) async throws {
        self.dbActor = dbActor
        try await executeMigrations()
    }

    private func executeMigrations() async throws {
        _ = try await dbActor.executeAsync("""
            CREATE TABLE IF NOT EXISTS artifacts (
                artifact_id TEXT PRIMARY KEY,
                content_hash TEXT NOT NULL,
                source_hash TEXT NOT NULL,
                media_type TEXT NOT NULL,
                size_bytes INTEGER NOT NULL,
                source_type TEXT NOT NULL,
                source_identifier TEXT NOT NULL,
                metadata TEXT NOT NULL,
                receipt_id TEXT NOT NULL,
                evidence_head_hash TEXT,
                committed_at REAL NOT NULL,
                trust_tier TEXT NOT NULL,
                created_at REAL NOT NULL DEFAULT (julianday('now'))
            );
            """, parameters: [])

        _ = try await dbActor.executeAsync("CREATE INDEX IF NOT EXISTS idx_artifacts_content_hash ON artifacts(content_hash);", parameters: [])
        _ = try await dbActor.executeAsync("CREATE INDEX IF NOT EXISTS idx_artifacts_media_type ON artifacts(media_type);", parameters: [])
        _ = try await dbActor.executeAsync("CREATE INDEX IF NOT EXISTS idx_artifacts_trust_tier ON artifacts(trust_tier);", parameters: [])
    }

    // MARK: - Insert

    public func insertArtifact(_ artifact: StoredArtifact) async throws {
        let metadataJSON = try JSONEncoder().encode(artifact.metadata)
        let metadataString = String(data: metadataJSON, encoding: .utf8) ?? "{}"

        _ = try await dbActor.executeAsync(
            """
            INSERT INTO artifacts (
                artifact_id, content_hash, source_hash, media_type, size_bytes,
                source_type, source_identifier, metadata, receipt_id, evidence_head_hash,
                committed_at, trust_tier
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                DatabaseCore.DatabaseParameter.text(artifact.artifactID),
                DatabaseCore.DatabaseParameter.text(artifact.contentHash),
                DatabaseCore.DatabaseParameter.text(artifact.sourceHash),
                DatabaseCore.DatabaseParameter.text(artifact.mediaType),
                DatabaseCore.DatabaseParameter.int(Int(artifact.sizeBytes)),
                DatabaseCore.DatabaseParameter.text(artifact.source.type),
                DatabaseCore.DatabaseParameter.text(artifact.source.identifier),
                DatabaseCore.DatabaseParameter.text(metadataString),
                DatabaseCore.DatabaseParameter.text(artifact.receiptID),
                artifact.evidenceHeadHash.map { DatabaseCore.DatabaseParameter.text($0) } ?? DatabaseCore.DatabaseParameter.null,
                DatabaseCore.DatabaseParameter.double(artifact.committedAt.timeIntervalSince1970),
                DatabaseCore.DatabaseParameter.text(artifact.trustTier.rawValue)
            ]
        )
    }

    // MARK: - Fetch

    public func fetchArtifact(artifactID: String) async throws -> StoredArtifact? {
        let rows = try await dbActor.query(
            """
            SELECT artifact_id, content_hash, source_hash, media_type, size_bytes,
                   source_type, source_identifier, metadata, receipt_id, evidence_head_hash,
                   committed_at, trust_tier
            FROM artifacts
            WHERE artifact_id = ?
            LIMIT 1
            """,
            parameters: [DatabaseCore.DatabaseParameter.text(artifactID)]
        )

        guard let row = rows.first else { return nil }
        return try parseArtifact(row: row)
    }

    public func fetchArtifactByHash(contentHash: String) async throws -> StoredArtifact? {
        let rows = try await dbActor.query(
            """
            SELECT artifact_id, content_hash, source_hash, media_type, size_bytes,
                   source_type, source_identifier, metadata, receipt_id, evidence_head_hash,
                   committed_at, trust_tier
            FROM artifacts
            WHERE content_hash = ?
            LIMIT 1
            """,
            parameters: [DatabaseCore.DatabaseParameter.text(contentHash)]
        )

        guard let row = rows.first else { return nil }
        return try parseArtifact(row: row)
    }

    public func listArtifacts(
        mediaType: String? = nil,
        trustTier: TrustTier? = nil,
        limit: Int = 100
    ) async throws -> [StoredArtifact] {
        var sql = """
            SELECT artifact_id, content_hash, source_hash, media_type, size_bytes,
                   source_type, source_identifier, metadata, receipt_id, evidence_head_hash,
                   committed_at, trust_tier
            FROM artifacts
            WHERE 1=1
            """

        var parameters: [DatabaseCore.DatabaseParameter] = []

        if let mt = mediaType {
            sql += " AND media_type = ?"
            parameters.append(DatabaseCore.DatabaseParameter.text(mt))
        }

        if let tt = trustTier {
            sql += " AND trust_tier = ?"
            parameters.append(DatabaseCore.DatabaseParameter.text(tt.rawValue))
        }

        sql += " ORDER BY committed_at DESC LIMIT ?"
        parameters.append(DatabaseCore.DatabaseParameter.int(limit))

        let rows = try await dbActor.query(sql, parameters: parameters)
        return try rows.map { try parseArtifact(row: $0) }
    }

    // MARK: - Helpers

    private func parseArtifact(row: DatabaseRow) throws -> StoredArtifact {
        guard
            let artifactID = row.string(for: "artifact_id"),
            let contentHash = row.string(for: "content_hash"),
            let sourceHash = row.string(for: "source_hash"),
            let mediaType = row.string(for: "media_type"),
            let sizeBytes = row.int(for: "size_bytes"),
            let sourceType = row.string(for: "source_type"),
            let sourceIdentifier = row.string(for: "source_identifier"),
            let metadataString = row.string(for: "metadata"),
            let receiptID = row.string(for: "receipt_id"),
            let committedAt = row.double(for: "committed_at"),
            let trustTierString = row.string(for: "trust_tier")
        else {
            throw ArtifactStoreError.parseError("Failed to parse artifact from database row")
        }

        let metadataData = metadataString.data(using: .utf8) ?? Data()
        let metadata = (try? JSONDecoder().decode([String: String].self, from: metadataData)) ?? [:]

        let evidenceHeadHash = row.string(for: "evidence_head_hash")

        return StoredArtifact(
            artifactID: artifactID,
            contentHash: contentHash,
            sourceHash: sourceHash,
            mediaType: mediaType,
            sizeBytes: Int64(sizeBytes),
            source: ArtifactSource(type: sourceType, identifier: sourceIdentifier),
            metadata: metadata,
            receiptID: receiptID,
            evidenceHeadHash: evidenceHeadHash,
            committedAt: Date(timeIntervalSince1970: committedAt),
            trustTier: TrustTier(rawValue: trustTierString) ?? .standard
        )
    }
}
