//
//  ToolRouterMigration.swift
//  DatabaseCore
//
//  Schema migrations for tool router evidence recording using DatabaseActor.
//  Tables: loop_events, tool_calls, tool_call_artifacts
//

import Foundation

/// Migration for tool router evidence recording.
public enum ToolRouterMigration {
    public static func migrate(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync("BEGIN TRANSACTION")
        do {
            try await createToolCallsTable(db)
            try await createLoopEventsTable(db)
            try await createArtifactsTable(db)
            try await applyAlterations(db)
            try await db.executeAsync("COMMIT TRANSACTION")
        } catch {
            _ = try? await db.executeAsync("ROLLBACK TRANSACTION")
            throw error
        }
    }

    private static func createToolCallsTable(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS tool_calls (
                id UUID PRIMARY KEY NOT NULL,
                session_id UUID NOT NULL,
                tool_name TEXT NOT NULL,
                started_at TIMESTAMPTZ NOT NULL,
                completed_at TIMESTAMPTZ,
                status TEXT NOT NULL,
                input_hash TEXT NOT NULL,
                output_hash TEXT,
                error_signature TEXT,
                parameters TEXT DEFAULT '',
                file_path TEXT,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            );
            """
        )
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_tool_calls_session ON tool_calls(session_id, started_at DESC);")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_tool_calls_tool ON tool_calls(tool_name, started_at DESC);")
    }

    private static func createLoopEventsTable(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS loop_events (
                id UUID PRIMARY KEY NOT NULL,
                tool_call_id UUID NOT NULL,
                event_type TEXT NOT NULL,
                signature_hash TEXT NOT NULL,
                threshold INTEGER NOT NULL,
                window_seconds INTEGER NOT NULL,
                recovery_strategy TEXT,
                context TEXT,
                manual_justification TEXT,
                unblocked_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                FOREIGN KEY (tool_call_id) REFERENCES tool_calls(id)
            );
            """
        )
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_loop_events_tool_call ON loop_events(tool_call_id);")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_loop_events_signature ON loop_events(signature_hash);")
    }

    private static func createArtifactsTable(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS tool_call_artifacts (
                id UUID PRIMARY KEY NOT NULL,
                tool_call_id UUID NOT NULL,
                artifact_type TEXT NOT NULL,
                artifact_path TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                size_bytes INTEGER NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                FOREIGN KEY (tool_call_id) REFERENCES tool_calls(id)
            );
            """
        )
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_tool_call_artifacts_call ON tool_call_artifacts(tool_call_id);")
    }

    private static func applyAlterations(_ db: any DatabaseExecutor) async throws {
        // Handle legacy schema updates if needed
        // Since we include them in CREATE TABLE IF NOT EXISTS, this is mainly for existing DBs
        _ = try? await db.executeAsync("ALTER TABLE loop_events ADD COLUMN manual_justification TEXT;")
        _ = try? await db.executeAsync("ALTER TABLE loop_events ADD COLUMN unblocked_at TIMESTAMPTZ;")
        _ = try? await db.executeAsync("ALTER TABLE tool_calls ADD COLUMN parameters TEXT DEFAULT '';")
        _ = try? await db.executeAsync("ALTER TABLE tool_calls ADD COLUMN file_path TEXT;")
    }
}
