//
//  ContentAddressedMigration.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Migration for content-addressed artifact storage.
public enum ContentAddressedMigration {
    public static func migrate(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync("BEGIN TRANSACTION")
        do {
            try await createContentAddressedArtifacts(db)
            try await createArtifactReferences(db)
            try await createIndexes(db)
            try await db.executeAsync("COMMIT TRANSACTION")
        } catch {
            _ = try? await db.executeAsync("ROLLBACK TRANSACTION")
            throw error
        }
    }

    private static func createContentAddressedArtifacts(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS content_addressed_artifacts (
                content_hash TEXT PRIMARY KEY,
                hash_algorithm TEXT NOT NULL DEFAULT 'sha256:1',
                payload BYTEA NOT NULL,
                payload_size INTEGER NOT NULL,
                is_compressed INTEGER NOT NULL DEFAULT 0,
                first_seen_at TIMESTAMPTZ NOT NULL,
                reference_count INTEGER NOT NULL DEFAULT 1
            );
            """
        )
    }

    private static func createArtifactReferences(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS artifact_references (
                reference_id UUID PRIMARY KEY,
                content_hash TEXT NOT NULL,
                parent_key TEXT NOT NULL,
                parent_type TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL,
                metadata JSONB,
                FOREIGN KEY(content_hash) REFERENCES content_addressed_artifacts(content_hash) ON DELETE CASCADE
            );
            """
        )
    }

    private static func createIndexes(_ db: any DatabaseExecutor) async throws {
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

        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_content_artifacts_reference_count
            ON content_addressed_artifacts(reference_count);
            """
        )
    }
}
