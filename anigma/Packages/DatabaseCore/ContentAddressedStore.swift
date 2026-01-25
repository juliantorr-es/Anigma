//
//  ContentAddressedStore.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Content-addressed blob storage with deduplication via strong hash keys.
public struct ContentAddressedArtifact: Sendable {
    /// SHA256 hash of the payload content.
    public let contentHash: String

    /// Algorithm and version used for hashing (e.g., "sha256:1").
    public let hashAlgorithm: String

    /// Raw blob payload.
    public let payload: Data

    /// Byte length of the payload (denormalized for efficiency).
    public let payloadSize: Int

    /// Optional compression flag (for future use).
    public let isCompressed: Bool

    /// Timestamp when artifact was first stored.
    public let firstSeenAt: Date

    /// Number of current references to this artifact.
    public let referenceCount: Int

    public init(
        contentHash: String,
        hashAlgorithm: String,
        payload: Data,
        payloadSize: Int,
        isCompressed: Bool,
        firstSeenAt: Date,
        referenceCount: Int
    ) {
        self.contentHash = contentHash
        self.hashAlgorithm = hashAlgorithm
        self.payload = payload
        self.payloadSize = payloadSize
        self.isCompressed = isCompressed
        self.firstSeenAt = firstSeenAt
        self.referenceCount = referenceCount
    }
}

/// Reference to a content-addressed artifact, without storing the payload.
public struct ArtifactReference: Sendable {
    /// Unique identifier for this reference.
    public let referenceID: String

    /// SHA256 hash of the artifact this references.
    public let contentHash: String

    /// Parent artifact key (e.g., tool name, session ID, operation).
    public let parentKey: String

    /// Type of parent (e.g., "tool_output", "build_log", "embedding").
    public let parentType: String

    /// When this reference was created.
    public let createdAt: Date

    /// Optional metadata about this reference (JSON).
    public let metadata: Data?

    public init(
        referenceID: String,
        contentHash: String,
        parentKey: String,
        parentType: String,
        createdAt: Date,
        metadata: Data?
    ) {
        self.referenceID = referenceID
        self.contentHash = contentHash
        self.parentKey = parentKey
        self.parentType = parentType
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

/// Actor managing content-addressed artifact store with deduplication.
public actor ContentAddressedStore {
    private let db: DatabaseActor

    public init(database: DatabaseActor) async throws {
        self.db = database
        try await setupSchema()
    }

    /// Set up content-addressed storage tables.
    private func setupSchema() async throws {
        // Content-addressed artifact blobs table.
        try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS content_addressed_artifacts (
                content_hash TEXT PRIMARY KEY,
                hash_algorithm TEXT NOT NULL,
                payload BLOB NOT NULL,
                payload_size INTEGER NOT NULL,
                is_compressed INTEGER NOT NULL DEFAULT 0,
                first_seen_at REAL NOT NULL,
                reference_count INTEGER NOT NULL DEFAULT 1
            );
            """
        )

        // Artifact references table (pointing to content-addressed artifacts).
        try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS artifact_references (
                reference_id TEXT PRIMARY KEY,
                content_hash TEXT NOT NULL,
                parent_key TEXT NOT NULL,
                parent_type TEXT NOT NULL,
                created_at REAL NOT NULL,
                metadata BLOB,
                deleted_at REAL,
                FOREIGN KEY(content_hash) REFERENCES content_addressed_artifacts(content_hash) ON DELETE CASCADE,
                UNIQUE(reference_id)
            );
            """
        )

        // Indexes for efficient querying.
        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_artifact_refs_parent
            ON artifact_references(parent_key, parent_type);
            """
        )

        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_artifact_refs_hash
            ON artifact_references(content_hash);
            """
        )

        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_artifact_refs_created
            ON artifact_references(created_at);
            """
        )
    }

    /// Store or retrieve a content-addressed artifact. Returns the stored artifact (idempotent).
    public func storeArtifact(
        _ artifact: ContentAddressedArtifact
    ) async throws -> ContentAddressedArtifact {
        let inserted = try await db.executeAsync(
            """
            INSERT OR IGNORE INTO content_addressed_artifacts
            (content_hash, hash_algorithm, payload, payload_size, is_compressed, first_seen_at, reference_count)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(artifact.contentHash),
                .text(artifact.hashAlgorithm),
                .blob(artifact.payload),
                .int(artifact.payloadSize),
                .int(artifact.isCompressed ? 1 : 0),
                .double(artifact.firstSeenAt.timeIntervalSince1970),
                .int(artifact.referenceCount)
            ]
        )

        // If inserted, return the artifact as-is.
        if inserted > 0 {
            return artifact
        }

        // Otherwise, fetch the existing artifact.
        guard let existing = try await getArtifact(byHash: artifact.contentHash) else {
            return artifact // Fallback to input if fetch fails.
        }
        return existing
    }

    /// Fetch a content-addressed artifact by its content hash.
    public func getArtifact(byHash hash: String) async throws -> ContentAddressedArtifact? {
        let rows = try await db.query(
            """
            SELECT content_hash, hash_algorithm, payload, payload_size, is_compressed, first_seen_at, reference_count
            FROM content_addressed_artifacts
            WHERE content_hash = ?
            """,
            parameters: [.text(hash)]
        )

        guard let row = rows.first else { return nil }

        return ContentAddressedArtifact(
            contentHash: row.string(for: "content_hash") ?? hash,
            hashAlgorithm: row.string(for: "hash_algorithm") ?? "sha256:1",
            payload: row.data(for: "payload") ?? Data(),
            payloadSize: row.int(for: "payload_size") ?? 0,
            isCompressed: (row.int(for: "is_compressed") ?? 0) != 0,
            firstSeenAt: Date(timeIntervalSince1970: row.double(for: "first_seen_at") ?? 0),
            referenceCount: row.int(for: "reference_count") ?? 0
        )
    }

    /// Create a reference to a content-addressed artifact.
    public func createReference(
        _ reference: ArtifactReference
    ) async throws -> ArtifactReference {
        try await db.executeAsync(
            """
            INSERT OR IGNORE INTO artifact_references
            (reference_id, content_hash, parent_key, parent_type, created_at, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(reference.referenceID),
                .text(reference.contentHash),
                .text(reference.parentKey),
                .text(reference.parentType),
                .double(reference.createdAt.timeIntervalSince1970),
                reference.metadata.map { .blob($0) } ?? .null
            ]
        )

        // Increment reference count in the artifact.
        _ = try await db.executeAsync(
            """
            UPDATE content_addressed_artifacts
            SET reference_count = reference_count + 1
            WHERE content_hash = ?
            """,
            parameters: [.text(reference.contentHash)]
        )

        return reference
    }

    /// Fetch all references for a given parent.
    public func getReferences(
        byParentKey parentKey: String,
        parentType: String
    ) async throws -> [ArtifactReference] {
        let rows = try await db.query(
            """
            SELECT reference_id, content_hash, parent_key, parent_type, created_at, metadata
            FROM artifact_references
            WHERE parent_key = ? AND parent_type = ?
            """,
            parameters: [.text(parentKey), .text(parentType)]
        )

        return rows.compactMap { row in
            guard let refID = row.string(for: "reference_id"),
                  let hash = row.string(for: "content_hash"),
                  let pKey = row.string(for: "parent_key"),
                  let pType = row.string(for: "parent_type"),
                  let createdDouble = row.double(for: "created_at") else {
                return nil
            }

            return ArtifactReference(
                referenceID: refID,
                contentHash: hash,
                parentKey: pKey,
                parentType: pType,
                createdAt: Date(timeIntervalSince1970: createdDouble),
                metadata: row.data(for: "metadata")
            )
        }
    }

    /// Get deduplication statistics.
    public func getDeduplicationStats() async throws -> (totalArtifacts: Int, totalReferences: Int, averageRefsPerArtifact: Double) {
        let statRows = try await db.query(
            """
            SELECT
                COUNT(*) as artifact_count,
                SUM(reference_count) as total_refs,
                AVG(reference_count) as avg_refs
            FROM content_addressed_artifacts
            """
        )

        guard let row = statRows.first else {
            return (0, 0, 0.0)
        }

        let artifactCount = row.int(for: "artifact_count") ?? 0
        let totalRefs = row.int(for: "total_refs") ?? 0
        let avgRefs = row.double(for: "avg_refs") ?? 0.0

        return (artifactCount, totalRefs, avgRefs)
    }
}
