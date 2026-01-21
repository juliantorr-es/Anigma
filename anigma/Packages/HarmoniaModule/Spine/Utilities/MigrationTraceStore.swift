//
//  MigrationTraceStore.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import Foundation
import DatabaseCore
import AnigmaPrimitives

public final class SQLiteMigrationTraceSink: MigrationTraceSink {
    private let actor: DatabaseActor
    private let ready: Task<Void, Error>
    public let dbPath: String?
    public let isEnabled: Bool = true

public init(dbPath: String = DatabaseConfiguration.defaultDatabasePath()) {
        self.dbPath = dbPath
        let actor = DatabaseActor(dbPath: dbPath)
        self.actor = actor
        self.ready = Task {
            try await actor.open()
          try await actor.execute("""
                CREATE TABLE IF NOT EXISTS migration_trace_steps (
                    task_id TEXT NOT NULL,
                    recorded_at TEXT NOT NULL,
                    rewrite_path TEXT NOT NULL,
                    rule_id TEXT,
                    verify_status TEXT NOT NULL,
                    rollback_status TEXT NOT NULL,
                    rollback_reason TEXT,
                    backup_path TEXT,
                    diff_artifact_path TEXT,
                    detail TEXT,
                    circuit_state TEXT,
                    PRIMARY KEY(task_id, recorded_at)
                )
                """)

            try await actor.execute("""
                CREATE INDEX IF NOT EXISTS idx_migration_trace_task
                ON migration_trace_steps (task_id)
                """)

            try await actor.execute("""
                CREATE INDEX IF NOT EXISTS idx_migration_trace_recorded_at
                ON migration_trace_steps (recorded_at)
                """)

            // Add circuit_state column if it doesn't exist (for backwards compatibility)
            // Check if column already exists first
            let tableInfo = try await actor.query("PRAGMA table_info(migration_trace_steps)")
            let hasCircuitStateColumn = tableInfo.contains { row in
                row.string(for: "name") == "circuit_state"
            }

            if !hasCircuitStateColumn {
                try await actor.execute("""
                    ALTER TABLE migration_trace_steps
                    ADD COLUMN circuit_state TEXT
                    """)
            }

            try await actor.execute("""
                CREATE INDEX IF NOT EXISTS idx_migration_trace_task
                ON migration_trace_steps (task_id)
                """)
            try await actor.execute("""
                CREATE INDEX IF NOT EXISTS idx_migration_trace_recorded_at
                ON migration_trace_steps (recorded_at)
                """)
        }
    }

    public func waitUntilReady() async throws {
        try await ready.value
    }

    public func record(_ outcome: MigrationStepOutcome) {
        Task {
            do {
                try await ready.value
                let recordedAt = SQLiteMigrationTraceSink.isoTimestamp(Date())
                try await actor.execute("""
                    INSERT INTO migration_trace_steps (
                        task_id, recorded_at, rewrite_path, rule_id,
                        verify_status, rollback_status, rollback_reason,
                        backup_path, diff_artifact_path, detail, circuit_state
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    parameters: [
                        .text(outcome.taskId),
                        .text(recordedAt),
                        .text(outcome.rewritePath),
                        outcome.ruleId.map { .text($0) } ?? .null,
                        .text(outcome.verifyStatus),
                        .text(outcome.rollbackStatus),
                        outcome.rollbackReason.map { .text($0) } ?? .null,
                        outcome.backupPath.map { .text($0) } ?? .null,
                        outcome.diffArtifactPath.map { .text($0) } ?? .null,
                        outcome.detail.map { .text($0) } ?? .null,
                        outcome.circuitState.map { .text($0) } ?? .null
                    ]
                )
            } catch {
                print("MigrationTraceSink error: \(error)")
            }
        }
    }

    public func latestOutcome(for taskId: String) async throws -> MigrationStepOutcome? {
        try await ready.value
        let rows = try await actor.query("""
            SELECT rewrite_path, rule_id, verify_status, rollback_status,
                   rollback_reason, backup_path, diff_artifact_path, detail
            FROM migration_trace_steps
            WHERE task_id = ?
            ORDER BY recorded_at DESC
            LIMIT 1
            """,
            parameters: [.text(taskId)]
        )

        guard let row = rows.first else { return nil }
        return MigrationStepOutcome(
            taskId: taskId,
            rewritePath: row.string(for: "rewrite_path") ?? "none",
            ruleId: row.string(for: "rule_id"),
            verifyStatus: row.string(for: "verify_status") ?? "not_run",
            rollbackStatus: row.string(for: "rollback_status") ?? "not_needed",
            rollbackReason: row.string(for: "rollback_reason"),
            backupPath: row.string(for: "backup_path"),
            diffArtifactPath: row.string(for: "diff_artifact_path"),
            detail: row.string(for: "detail")
        )
    }

    private static func isoTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
