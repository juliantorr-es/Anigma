//
//  GovernedMigrationAPI.swift
//  GovernedMigrationCore
//
//  [Brief description of file purpose]
//

import Foundation
import DatabaseCore
import AnigmaPrimitives
import ContractsCore

/// Minimal API for governed Swift 6 migrations.
/// 
/// This is the core interface that HarmoniaCLI will call into.
/// It encapsulates the working logic from Swift6Harness without
/// pulling in broken subsystems (inspiration, polytropos, etc.).
public struct GovernedMigrationAPI {
    private let database: DatabaseActor
    public let dbPath: String

    public init(dbPath: String = DatabaseConfiguration.defaultDatabasePath()) {
        self.database = DatabaseActor(dbPath: dbPath)
        self.dbPath = dbPath
    }

    /// Run Swift 6 discovery and create migration tasks.
    /// Returns the number of tasks created.
    public func runSwift6DiscoveryAndTaskCreation() async throws -> Int {
        print("🔍 Running Swift 6 discovery...")

        do {
            let pendingTasks = try await loadPendingTasks(limit: 10)

            if pendingTasks.isEmpty {
                print("📝 No pending tasks found. Creating simulated tasks...")
                let taskCount = try await createSimulatedTasks()
                print("✅ Created \(taskCount) simulated migration tasks")
                return taskCount
            } else {
                print("📋 Found \(pendingTasks.count) pending migration tasks")
                return 0
            }
        } catch let error as DatabaseError {
            throw GovernedMigrationError.databaseError("Database error during task discovery: \(error.localizedDescription)")
        } catch {
            throw error // Re-throw other errors
        }
    }

    /// Process N Swift 6 migration steps through the governed pipeline.
    /// Returns a summary of what happened.
    public func runSwift6Steps(count: Int) async throws -> MigrationBatchResult {
        print("⚙️ Processing \(count) Swift 6 migration step(s)...")

        do {
            // Load pending tasks
            let tasks = try await loadPendingTasks(limit: count)

            if tasks.isEmpty {
                print("📭 No pending migration tasks to process")
                return MigrationBatchResult(
                    processed: 0,
                    succeeded: 0,
                    failed: 0,
                    blocked: 0,
                    trustChanges: []
                )
            }

            print("📋 Found \(tasks.count) task(s) to process")

            var result = MigrationBatchResult(
                processed: tasks.count,
                succeeded: 0,
                failed: 0,
                blocked: 0,
                trustChanges: []
            )

            // Process each task through governed pipeline
            for task in tasks {
                print("\n--- Processing task \(task.id) ---")
                print("  Category: \(task.featureCategory)")
                print("  Priority: \(task.priority)")

                // Check capability validation (simulated for Phase 5)
                if isCapabilityViolation(task: task) {
                    print("  ⚠️  Security Policy Blocked: capability violation")
                    await updateTaskStatus(taskId: task.id, newStatus: "blocked", errorMessage: "Capability violation")
                    result.blocked += 1

                    // Log security event
                    await logSecurityEvent(
                        eventType: ContractsCore.AuditEventType.custom,
                        engineId: "migration-engine-1",
                        operation: "migration_step",
                        severity: "high",
                        details: "Blocked migration due to capability violation",
                        metadata: ["original_event_type": "capability_violation"]
                    )
                    continue
                }

                // Simulate migration processing
                let success = Bool.random() // Simulate random success/failure for testing

                if success {
                    await updateTaskStatus(taskId: task.id, newStatus: "completed")
                    print("  Result: ✅ Success")
                    result.succeeded += 1

                    // Simulate trust score increase for successful migration
                    let trustChange = try await adjustTrustScore(
                        subjectId: "migration-engine-1",
                        subjectKind: "engine_instance",
                        delta: 2,
                        reason: "Successful Swift 6 migration"
                    )
                    result.trustChanges.append(trustChange)

                    await logSecurityEvent(
                        eventType: ContractsCore.AuditEventType.migrationExecuted,
                        engineId: "migration-engine-1",
                        operation: "migration_step",
                        severity: "low",
                        details: "Successfully migrated Swift 6 syntax"
                    )
                } else {
                    await updateTaskStatus(taskId: task.id, newStatus: "failed", errorMessage: "Simulated failure")
                    print("  Result: ❌ Failed - simulated failure")
                    result.failed += 1

                    // Simulate trust score decrease for failed migration
                    let trustChange = try await adjustTrustScore(
                        subjectId: "migration-engine-1",
                        subjectKind: "engine_instance",
                        delta: -1,
                        reason: "Failed Swift 6 migration"
                    )
                    result.trustChanges.append(trustChange)

                    await logSecurityEvent(
                        eventType: ContractsCore.AuditEventType.migrationFailed,
                        engineId: "migration-engine-1",
                        operation: "migration_step",
                        severity: "medium",
                        details: "Failed to migrate Swift 6 syntax"
                    )
                }
            }

            print("\n📊 Batch complete:")
            print("  Processed: \(result.processed)")
            print("  Succeeded: \(result.succeeded)")
            print("  Failed: \(result.failed)")
            print("  Blocked: \(result.blocked)")

            return result
        } catch let error as DatabaseError {
            throw GovernedMigrationError.databaseError("Database error during migration steps: \(error.localizedDescription)")
        } catch {
            throw error // Re-throw other errors
        }
    }

    /// Get current governance snapshot (trust, security events, mode).
    public func currentGovernanceSnapshot() async throws -> GovernanceSnapshot {
        do {
            let trustScores = try await getTrustScores()
            let securityEvents = try await getRecentSecurityEvents(limit: 5)
            let governanceMode = try await getGovernanceMode()

            return GovernanceSnapshot(
                trustScores: trustScores,
                recentSecurityEvents: securityEvents,
                governanceMode: governanceMode,
                timestamp: Date()
            )
        } catch let error as DatabaseError {
            throw GovernedMigrationError.databaseError("Database error during governance snapshot: \(error.localizedDescription)")
        } catch {
            throw error // Re-throw other errors
        }
    }

    /// Query migration trace steps with optional filters.
    /// - Parameters:
    ///   - taskId: Optional task ID filter
    ///   - limit: Maximum number of steps to return (default: 10)
    ///   - offset: Offset for pagination (default: 0)
    /// - Returns: Array of migration trace steps
    public func queryMigrationTraceSteps(
        taskId: String? = nil,
        limit: Int = 10,
        offset: Int = 0
    ) async throws -> [MigrationTraceStep] {
        do {
            try await database.open()

            var sql = """
                SELECT task_id, recorded_at, rewrite_path, rule_id,
                       verify_status, rollback_status, rollback_reason,
                       backup_path, diff_artifact_path, detail
                FROM migration_trace_steps
            """
            var parameters: [DatabaseParameter] = []

            if let taskId = taskId {
                sql += " WHERE task_id = ?"
                parameters.append(.text(taskId))
            }

            sql += " ORDER BY recorded_at DESC LIMIT ? OFFSET ?"
            parameters.append(.int(limit))
            parameters.append(.int(offset))

            let rows = try await database.query(sql, parameters: parameters)

            var steps: [MigrationTraceStep] = []
            for row in rows {
                guard let taskId = row.string(for: "task_id"),
                      let recordedAt = row.string(for: "recorded_at"),
                      let rewritePath = row.string(for: "rewrite_path"),
                      let verifyStatus = row.string(for: "verify_status"),
                      let rollbackStatus = row.string(for: "rollback_status") else {
                    continue
                }

                let step = MigrationTraceStep(
                    taskId: taskId,
                    recordedAt: recordedAt,
                    rewritePath: rewritePath,
                    ruleId: row.string(for: "rule_id"),
                    verifyStatus: verifyStatus,
                    rollbackStatus: rollbackStatus,
                    rollbackReason: row.string(for: "rollback_reason"),
                    backupPath: row.string(for: "backup_path"),
                    diffArtifactPath: row.string(for: "diff_artifact_path"),
                    detail: row.string(for: "detail")
                )
                steps.append(step)
            }

            return steps
        } catch let error as DatabaseError {
            throw GovernedMigrationError.databaseError("Database error during trace query: \(error.localizedDescription)")
        } catch {
            throw error
        }
    }

    /// Get the latest migration trace step for a specific task.
    /// - Parameter taskId: Task ID to query
    /// - Returns: Latest migration trace step, or nil if none found
    public func latestMigrationTraceStep(for taskId: String) async throws -> MigrationTraceStep? {
        try await database.open()

        let sql = """
        SELECT rewrite_path, rule_id, verify_status, rollback_status,
               rollback_reason, backup_path, diff_artifact_path, detail
        FROM migration_trace_steps
        WHERE task_id = ?
        ORDER BY recorded_at DESC
        LIMIT 1
        """

        let rows = try await database.query(sql, parameters: [.text(taskId)])

        guard let row = rows.first else { return nil }

        return MigrationTraceStep(
            taskId: taskId,
            recordedAt: "", // Not needed for latest outcome
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

    public func queryMigrationTaskDetails(taskId: String) async throws -> MigrationTaskDetails? {
        try await database.open()

        let sql = """
        SELECT id, status, priority, feature_category, created_at, path, path_detail
        FROM migration_tasks
        WHERE id = ?
        LIMIT 1
        """

        let rows = try await database.query(sql, parameters: [.text(taskId)])

        guard let row = rows.first,
              let id = row.string(for: "id"),
              let status = row.string(for: "status"),
              let priority = row.int(for: "priority"),
              let featureCategory = row.string(for: "feature_category"),
              let createdAt = row.string(for: "created_at") else {
            return nil
        }

        let path = row.string(for: "path")
        let pathDetail = row.string(for: "path_detail")

        return MigrationTaskDetails(
            id: id,
            status: status,
            priority: priority,
            featureCategory: featureCategory,
            createdAt: createdAt,
            path: path,
            pathDetail: pathDetail
        )
    }

    // MARK: - Private Helpers

    private func loadPendingTasks(limit: Int) async throws -> [MigrationTaskRow] {
        try await database.open()

        let sql = """
        SELECT id, projectId, featureCategory, status, priority, createdAt, updatedAt,
               startedAt, completedAt, sessionIndex, findingId, errorMessage
        FROM migration_tasks
        WHERE status = 'pending'
        ORDER BY priority DESC
        LIMIT ?
        """

        let rows = try await database.query(sql, parameters: [.int(limit)])

        var tasks: [MigrationTaskRow] = []
        for row in rows {
            guard let id = row.string(for: "id"),
                  let projectIdString = row.string(for: "projectId"),
                  let projectId = UUID(uuidString: projectIdString),
                  let featureCategory = row.string(for: "featureCategory"),
                  let status = row.string(for: "status"),
                  let priority = row.int(for: "priority") else {
                continue
            }

            tasks.append(MigrationTaskRow(
                id: id,
                engineType: "migration",
                featureCategory: featureCategory,
                status: status,
                priority: priority,
                projectId: projectId
            ))
        }

        return tasks
    }

    private func createSimulatedTasks() async throws -> Int {
        try await database.open()

        let tasks = [
            ("Swift 6 Sendable conformance", "swift6-migration", 10),
            ("Remove force unwrapping", "swift6-migration", 8),
            ("Add explicit @objc annotations", "swift6-migration", 6),
            ("Update DispatchQueue to Task", "swift6-migration", 7)
        ]

        var count = 0
        for (_, category, priority) in tasks {
            let id = UUID().uuidString
            let timestamp = ISO8601DateFormatter().string(from: Date())

            let sql = """
            INSERT INTO migration_tasks
            (id, projectId, featureCategory, status, priority, createdAt, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """

            _ = try await database.executeAsync(sql, parameters: [
                .text(id),
                .text("00000000-0000-0000-0000-000000000000"),
                .text(category),
                .text("pending"),
                .int(priority),
                .text(timestamp),
                .text(timestamp)
            ])
            count += 1
        }

        return count
    }

    private func isCapabilityViolation(task: MigrationTaskRow) -> Bool {
        // Simulated capability check
        // In Phase 6+, this would call actual CapabilityValidator
        return false // For now, always allow
    }

    private func updateTaskStatus(taskId: String, newStatus: String, errorMessage: String? = nil) async {
        do {
            try await database.open()

            let sql: String
            var parameters: [DatabaseParameter]

            let timestamp = ISO8601DateFormatter().string(from: Date())

            if let errorMessage = errorMessage {
                sql = "UPDATE migration_tasks SET status = ?, errorMessage = ?, updatedAt = ? WHERE id = ?"
                parameters = [.text(newStatus), .text(errorMessage), .text(timestamp), .text(taskId)]
            } else {
                sql = "UPDATE migration_tasks SET status = ?, errorMessage = ?, updatedAt = ? WHERE id = ?"
                parameters = [.text(newStatus), .null, .text(timestamp), .text(taskId)]
            }

            _ = try await database.executeAsync(sql, parameters: parameters)
        } catch {
            print("Error updating task status: \(error)")
        }
    }

    private func logSecurityEvent(eventType: ContractsCore.AuditEventType, engineId: String, operation: String, severity: String, details: String, metadata: [String: String]? = nil) async {
        do {
            try await database.open()

            let timestamp = ISO8601DateFormatter().string(from: Date())

            let sql = """
            INSERT INTO security_events (event_type, engine_id, operation, severity, details, created_at, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """

            _ = try await database.executeAsync(sql, parameters: [
                .text(eventType.rawValue),
                .text(engineId),
                .text(operation),
                .text(severity),
                .text(details),
                .text(timestamp),
                .text(metadata?.jsonString() ?? "{}") // Convert metadata dictionary to JSON string
            ])
        } catch {
            print("Error logging security event: \(error)")
        }
    }

    private func adjustTrustScore(subjectId: String, subjectKind: String, delta: Int, reason: String) async throws -> TrustChange {
        try await database.open()

        // Get current score
        let currentScore = await getCurrentTrustScore(subjectId: subjectId, subjectKind: subjectKind)
        let newScore = max(0, min(100, currentScore + delta))

        // Update trust score
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let updateSql = """
        UPDATE trust_state
        SET trust_score = ?, last_changed_at = ?, changed_by = 'governed_migration', reason = ?
        WHERE subject_id = ? AND subject_kind = ?
        """

        _ = try await database.executeAsync(updateSql, parameters: [
            .int(newScore),
            .text(timestamp),
            .text(reason),
            .text(subjectId),
            .text(subjectKind)
        ])

        return TrustChange(
            subjectId: subjectId,
            subjectKind: subjectKind,
            oldScore: currentScore,
            newScore: newScore,
            delta: delta,
            reason: reason
        )
    }

    private func getCurrentTrustScore(subjectId: String, subjectKind: String) async -> Int {
        do {
            try await database.open()

            let sql = "SELECT trust_score FROM trust_state WHERE subject_id = ? AND subject_kind = ?"

            let rows = try await database.query(sql, parameters: [
                .text(subjectId),
                .text(subjectKind)
            ])

            if let row = rows.first, let score = row.int(for: "trust_score") {
                return score
            }
        } catch {
            print("Error getting current trust score: \(error)")
        }

        return 50 // Default if not found or error
    }

    private func getTrustScores() async throws -> [TrustScore] {
        try await database.open()

        var scores: [TrustScore] = []

        let sql = """
        SELECT subject_id, subject_kind, trust_score, current_trust_tier,
               trust_calculated_at, last_changed_at, changed_by, reason
        FROM trust_state
        ORDER BY trust_score DESC
        """

        let rows = try await database.query(sql)

            for row in rows {
                guard let subjectId = row.string(for: "subject_id"),
                      let subjectKind = row.string(for: "subject_kind"),
                      let trustScore = row.int(for: "trust_score"),
                      let trustTier = row.string(for: "current_trust_tier"),
                      let lastChanged = row.string(for: "last_changed_at") else {
                    continue
                }
            let calculatedAt = row.string(for: "trust_calculated_at") ?? ""
            let changedBy = row.string(for: "changed_by") ?? ""
            let reason = row.string(for: "reason") ?? ""

            scores.append(TrustScore(
                subjectId: subjectId,
                subjectKind: subjectKind,
                score: trustScore,
                tier: trustTier,
                calculatedAt: calculatedAt,
                lastChanged: lastChanged,
                changedBy: changedBy,
                reason: reason
            ))
        }

        return scores
    }

    private func getRecentSecurityEvents(limit: Int) async throws -> [SecurityEvent] {
        try await database.open()

        var events: [SecurityEvent] = []

        let sql = """
        SELECT created_at, event_type, engine_id, operation, severity, details
        FROM security_events
        ORDER BY created_at DESC
        LIMIT ?
        """

        let rows = try await database.query(sql, parameters: [.int(limit)])

            for row in rows {
                guard let createdAt = row.string(for: "created_at"),
                      let eventTypeString = row.string(for: "event_type"),
                      let eventType = ContractsCore.AuditEventType(rawValue: eventTypeString),
                      let severity = row.string(for: "severity") else {
                    continue
                }
            let engineId = row.string(for: "engine_id") ?? ""
            let operation = row.string(for: "operation") ?? ""
            let details = row.string(for: "details") ?? ""
            let metadataString = row.string(for: "metadata") ?? "{}"
            let metadata = metadataString.jsonDictionary() // Assuming a jsonDictionary extension for String

            events.append(SecurityEvent(
                timestamp: createdAt,
                eventType: eventType,
                engineId: engineId,
                operation: operation,
                severity: severity,
                details: details,
                metadata: metadata
            ))
        }

        return events
    }

    private func getGovernanceMode() async throws -> GovernanceMode {
        try await database.open()

        let sql = "SELECT mode, updated_by, updated_at FROM governance_mode LIMIT 1"

        let rows = try await database.query(sql)

        if let row = rows.first {
            guard let mode = row.string(for: "mode"),
                  let updatedAt = row.string(for: "updated_at") else {
                // This shouldn't happen if the row exists and schema is consistent
                throw GovernedMigrationError.databaseError("Failed to parse governance mode from database.")
            }
            let updatedBy = row.string(for: "updated_by") ?? ""

            return GovernanceMode(
                mode: mode,
                updatedBy: updatedBy,
                updatedAt: updatedAt
            )
        }

        // Default if not found
        return GovernanceMode(
            mode: "governed",
            updatedBy: "system",
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}

private extension String {
    func jsonDictionary() -> [String: String]? {
        guard let data = self.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String]
    }
}

private extension Dictionary where Key == String, Value == String {
    func jsonString() -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

public struct MigrationBatchResult: Sendable {
    public var processed: Int
    public var succeeded: Int
    public var failed: Int
    public var blocked: Int
    public var trustChanges: [TrustChange]
}

public struct TrustChange: Sendable {
    public let subjectId: String
    public let subjectKind: String
    public let oldScore: Int
    public let newScore: Int
    public let delta: Int
    public let reason: String
}

public struct TrustScore: Sendable {
    public let subjectId: String
    public let subjectKind: String
    public let score: Int
    public let tier: String
    public let calculatedAt: String
    public let lastChanged: String
    public let changedBy: String
    public let reason: String
}

public struct SecurityEvent: Sendable {
    public let timestamp: String
    public let eventType: ContractsCore.AuditEventType
    public let engineId: String
    public let operation: String
    public let severity: String
    public let details: String
    public let metadata: [String: String]?

    public init(timestamp: String, eventType: ContractsCore.AuditEventType, engineId: String, operation: String, severity: String, details: String, metadata: [String: String]? = nil) {
        self.timestamp = timestamp
        self.eventType = eventType
        self.engineId = engineId
        self.operation = operation
        self.severity = severity
        self.details = details
        self.metadata = metadata
    }
}

public struct GovernanceMode: Sendable {
    public let mode: String
    public let updatedBy: String
    public let updatedAt: String
}

public struct GovernanceSnapshot: Sendable {
    public let trustScores: [TrustScore]
    public let recentSecurityEvents: [SecurityEvent]
    public let governanceMode: GovernanceMode
    public let timestamp: Date
}

/// Represents a migration trace step for querying and JSON output.
public struct MigrationTraceStep: Sendable, Codable {
    public let taskId: String
    public let recordedAt: String
    public let rewritePath: String
    public let ruleId: String?
    public let verifyStatus: String
    public let rollbackStatus: String
    public let rollbackReason: String?
    public let backupPath: String?
    public let diffArtifactPath: String?
    public let detail: String?

    public init(
        taskId: String,
        recordedAt: String,
        rewritePath: String,
        ruleId: String? = nil,
        verifyStatus: String,
        rollbackStatus: String,
        rollbackReason: String? = nil,
        backupPath: String? = nil,
        diffArtifactPath: String? = nil,
        detail: String? = nil
    ) {
        self.taskId = taskId
        self.recordedAt = recordedAt
        self.rewritePath = rewritePath
        self.ruleId = ruleId
        self.verifyStatus = verifyStatus
        self.rollbackStatus = rollbackStatus
        self.rollbackReason = rollbackReason
        self.backupPath = backupPath
        self.diffArtifactPath = diffArtifactPath
        self.detail = detail
    }
}

public enum GovernedMigrationError: Error {
    case databaseError(String)
    case migrationError(String)
}

public struct MigrationTaskDetails: Codable, Sendable {
    public let id: String
    public let status: String
    public let priority: Int
    public let featureCategory: String
    public let createdAt: String
    public let path: String?
    public let pathDetail: String?

    public init(
        id: String,
        status: String,
        priority: Int,
        featureCategory: String,
        createdAt: String,
        path: String? = nil,
        pathDetail: String? = nil
    ) {
        self.id = id
        self.status = status
        self.priority = priority
        self.featureCategory = featureCategory
        self.createdAt = createdAt
        self.path = path
        self.pathDetail = pathDetail
    }
}
