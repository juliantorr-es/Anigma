//
//  ToolRouterMigration.swift
//  DatabaseCore
//
//  Schema migrations for tool router evidence recording.
//  Tables: loop_events, tool_calls, tool_call_artifacts
//

import Foundation
import GRDB

extension DatabaseMigrator {
    static func toolRouterMigrations() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // Migration 1: Tool calls table (primary evidence)
        migrator.registerMigration("v1_tool_router_tool_calls") { db in
            try db.execute(
                sql: """
                    CREATE TABLE IF NOT EXISTS tool_calls (
                        id TEXT PRIMARY KEY NOT NULL,
                        session_id TEXT NOT NULL,
                        tool_name TEXT NOT NULL,
                        started_at INTEGER NOT NULL,
                        completed_at INTEGER,
                        status TEXT NOT NULL,
                        input_hash TEXT NOT NULL,
                        output_hash TEXT,
                        error_signature TEXT,
                        created_at INTEGER NOT NULL DEFAULT (unixepoch('now'))
                    )
                    """)

            try db.execute(
                sql: """
                    CREATE INDEX IF NOT EXISTS idx_tool_calls_session
                    ON tool_calls(session_id, started_at DESC)
                    """)

            try db.execute(
                sql: """
                    CREATE INDEX IF NOT EXISTS idx_tool_calls_tool
                    ON tool_calls(tool_name, started_at DESC)
                    """)
        }

        // Migration 2: Loop events table (attachment to tool_calls)
        migrator.registerMigration("v2_tool_router_loop_events") { db in
            try db.execute(
                sql: """
                    CREATE TABLE IF NOT EXISTS loop_events (
                        id TEXT PRIMARY KEY NOT NULL,
                        tool_call_id TEXT NOT NULL,
                        event_type TEXT NOT NULL,
                        signature_hash TEXT NOT NULL,
                        threshold INTEGER NOT NULL,
                        window_seconds INTEGER NOT NULL,
                        recovery_strategy TEXT,
                        context TEXT,
                        created_at INTEGER NOT NULL DEFAULT (unixepoch('now')),
                        FOREIGN KEY (tool_call_id) REFERENCES tool_calls(id)
                    )
                    """)

            try db.execute(
                sql: """
                    CREATE INDEX IF NOT EXISTS idx_loop_events_tool_call
                    ON loop_events(tool_call_id)
                    """)

            try db.execute(
                sql: """
                    CREATE INDEX IF NOT EXISTS idx_loop_events_signature
                    ON loop_events(signature_hash)
                    """)
        }

        // Migration 3: Tool call artifacts table
        migrator.registerMigration("v3_tool_router_artifacts") { db in
            try db.execute(
                sql: """
                    CREATE TABLE IF NOT EXISTS tool_call_artifacts (
                        id TEXT PRIMARY KEY NOT NULL,
                        tool_call_id TEXT NOT NULL,
                        artifact_type TEXT NOT NULL,
                        artifact_path TEXT NOT NULL,
                        content_hash TEXT NOT NULL,
                        size_bytes INTEGER NOT NULL,
                        created_at INTEGER NOT NULL DEFAULT (unixepoch('now')),
                        FOREIGN KEY (tool_call_id) REFERENCES tool_calls(id)
                    )
                    """)

            try db.execute(
                sql: """
                    CREATE INDEX IF NOT EXISTS idx_tool_call_artifacts_call
                    ON tool_call_artifacts(tool_call_id)
                    """)
        }

        // Migration 4: Manual unblocking for loop events
        migrator.registerMigration("v4_loop_manual_unblock") { db in
            try db.execute(
                sql: """
                    ALTER TABLE loop_events ADD COLUMN manual_justification TEXT
                    """)
            try db.execute(
                sql: """
                    ALTER TABLE loop_events ADD COLUMN unblocked_at INTEGER
                    """)
        }

        // Migration 5: Add metadata to tool_calls
        migrator.registerMigration("v5_tool_calls_metadata") { db in
            try db.execute(
                sql: """
                    ALTER TABLE tool_calls ADD COLUMN parameters TEXT DEFAULT ''
                    """)
            try db.execute(
                sql: """
                    ALTER TABLE tool_calls ADD COLUMN file_path TEXT
                    """)
        }

        return migrator
    }
}
