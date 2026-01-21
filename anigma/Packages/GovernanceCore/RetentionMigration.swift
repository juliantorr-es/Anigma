//
//  RetentionMigration.swift
//  GovernanceCore
//
//  [Brief description of file purpose]
//

import DatabaseCore
import Foundation

/// Migration for retention policy storage and compliance events.
public enum RetentionMigration {
    public static func migrate(_ db: DatabaseActor) async throws {
        try await db.execute("BEGIN TRANSACTION")

        do {
            try await createPolicyStorage(db)
            try await createComplianceEvents(db)
            try await createIndexes(db)
            try await db.execute("COMMIT TRANSACTION")
        } catch {
            _ = try? await db.execute("ROLLBACK TRANSACTION")
            throw error
        }
    }

    private static func createPolicyStorage(_ db: DatabaseActor) async throws {
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS retention_policy_store (
                policy_id TEXT PRIMARY KEY,
                policy_version TEXT NOT NULL,
                policy_content BLOB NOT NULL,
                policy_hash TEXT NOT NULL,
                created_at REAL NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1
            );
            """
        )
    }

    private static func createComplianceEvents(_ db: DatabaseActor) async throws {
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS policy_compliance_events (
                event_id TEXT PRIMARY KEY,
                policy_version_hash TEXT NOT NULL,
                action TEXT NOT NULL,
                effected_artifacts INTEGER,
                bytes_freed INTEGER,
                created_at REAL NOT NULL,
                metadata BLOB
            );
            """
        )
    }

    private static func createIndexes(_ db: DatabaseActor) async throws {
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_retention_policy_active
            ON retention_policy_store(is_active);
            """
        )

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_policy_compliance_hash
            ON policy_compliance_events(policy_version_hash);
            """
        )

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_policy_compliance_timestamp
            ON policy_compliance_events(created_at);
            """
        )
    }
}
