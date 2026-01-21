//
//  MigrationTraceReporter.swift
//  AccessumFlow
//
//  [Brief description of file purpose]
//

import Foundation
import DatabaseCore

public struct MigrationTraceRecord: Codable, Sendable, Equatable {
    public let taskId: String
    public let rewritePath: String
    public let ruleId: String?
    public let verifyStatus: String
    public let rollbackStatus: String
    public let rollbackReason: String?
    public let backupPath: String?
    public let diffArtifactPath: String?
    public let detail: String?
    public let recordedAt: String
}

public final class MigrationTraceReporter {
    private let actor: DatabaseActor
    private let ready: Task<Void, Error>

    public init(dbPath: String = DatabaseConfiguration.defaultDatabasePath()) {
        let actor = DatabaseActor(dbPath: dbPath)
        self.actor = actor
        self.ready = Task {
            try await actor.open()
        }
    }

    public func fetchLatest(taskId: String) async throws -> MigrationTraceRecord? {
        try await ready.value
        let rows = try await actor.query("""
            SELECT rewrite_path, rule_id, verify_status, rollback_status,
                   rollback_reason, backup_path, diff_artifact_path, detail, recorded_at
            FROM migration_trace_steps
            WHERE task_id = ?
            ORDER BY recorded_at DESC
            LIMIT 1
            """,
            parameters: [.text(taskId)]
        )
        guard let row = rows.first else { return nil }
        return MigrationTraceRecord(
            taskId: taskId,
            rewritePath: row.string(for: "rewrite_path") ?? "none",
            ruleId: row.string(for: "rule_id"),
            verifyStatus: row.string(for: "verify_status") ?? "not_run",
            rollbackStatus: row.string(for: "rollback_status") ?? "not_needed",
            rollbackReason: row.string(for: "rollback_reason"),
            backupPath: row.string(for: "backup_path"),
            diffArtifactPath: row.string(for: "diff_artifact_path"),
            detail: row.string(for: "detail"),
            recordedAt: row.string(for: "recorded_at") ?? ""
        )
    }
}
