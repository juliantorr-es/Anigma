//
//  RetentionEventSchema.swift
//  DatabaseCore
//

import Foundation

/// Shared registration for the DatabaseCore retention events schema.
public enum RetentionEventSchema {
    public static func register(using db: any DatabaseExecutor) async throws {
        try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS retention_events (
                retention_id UUID PRIMARY KEY,
                policy_version_hash TEXT NOT NULL,
                started_at TIMESTAMPTZ NOT NULL,
                completed_at TIMESTAMPTZ NOT NULL,
                artifacts_deleted INTEGER,
                payload_bytes_freed INTEGER,
                deletion_reason TEXT,
                metadata JSONB
            );
            """
        )

        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_retention_events_timestamp
            ON retention_events(started_at);
            """
        )
    }
}
