//
//  TrustRecalcScheduler.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Hourly batch trust score recalculation scheduler.
//  Processes trust scores for all subjects in batches.
//

import Foundation
import SQLite3
import AnigmaCore
import SecurityEventsManager
import DoctrineCore
import HarmoniaModule

/// Scheduler for hourly trust score recalculation.
public actor TrustRecalcScheduler {

    private let trustScoreCalculator: TrustScoreCalculator
    private let trustTierManager: TrustTierManager
    private let securityEvents: SecurityEventsManager
    private let dbPath: String

    private var isRunning = false
    private var lastRun: Date?
    private var totalProcessed = 0
    private var totalErrors = 0

    public init(
        trustScoreCalculator: TrustScoreCalculator = TrustScoreCalculator(),
        trustTierManager: TrustTierManager = TrustTierManager(),
        securityEvents: SecurityEventsManager = SecurityEventsManager(),
        dbPath: String = "harmonia_harness.sqlite"
    ) {
        self.trustScoreCalculator = trustScoreCalculator
        self.trustTierManager = trustTierManager
        self.securityEvents = securityEvents
        self.dbPath = dbPath
    }

    /// Start the hourly recalculation scheduler.
    public func start() async {
        guard !isRunning else {
            logInfo("[TRUST] Scheduler already running", category: "TrustRecalcScheduler")
            return
        }

        isRunning = true
        logInfo("[TRUST] Starting hourly trust recalculation scheduler", category: "TrustRecalcScheduler")

        // Run initial calculation
        await runRecalculation()

        // Start hourly loop
        Task {
            while isRunning {
                // Sleep for 1 hour
                try? await Task.sleep(nanoseconds: 3_600_000_000_000) // 1 hour in nanoseconds

                if isRunning {
                    await runRecalculation()
                }
            }
        }
    }

    /// Stop the scheduler.
    public func stop() {
        isRunning = false
        logInfo("[TRUST] Stopping trust recalculation scheduler", category: "TrustRecalcScheduler")
    }

    /// Run a single recalculation cycle.
    public func runRecalculation() async {
        let startTime = Date()
        logInfo("[TRUST] Starting trust score recalculation cycle", category: "TrustRecalcScheduler")

        var cycleProcessed = 0
        var cycleErrors = 0

        // Get all subjects that need recalculation
        let subjects = await getSubjectsForRecalculation()

        logInfo("[TRUST] Found \(subjects.count) subjects for recalculation", category: "TrustRecalcScheduler")

        // Process in batches of 50
        for batch in subjects.chunked(into: 50) {
            let batchStart = Date()

            // Process batch concurrently
            await withTaskGroup(of: Bool.self) { group in
                for subject in batch {
                    group.addTask {
                        return await self.processSubject(subject)
                    }
                }

                // Collect results
                for await result in group {
                    if result {
                        cycleProcessed += 1
                    } else {
                        cycleErrors += 1
                    }
                }
            }

            let batchTime = Date().timeIntervalSince(batchStart)
            logInfo("[TRUST] Processed batch of \(batch.count) subjects in \(String(format: "%.2f", batchTime))s", category: "TrustRecalcScheduler")

            // Small delay between batches to prevent database contention
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        // Update statistics
        totalProcessed += cycleProcessed
        totalErrors += cycleErrors
        lastRun = Date()

        let totalTime = Date().timeIntervalSince(startTime)

        // Log completion
        logInfo("[TRUST] Recalculation completed: \(cycleProcessed) processed, \(cycleErrors) errors in \(String(format: "%.2f", totalTime))s", category: "TrustRecalcScheduler")

        // Log security event for audit trail
        let details = SecurityEventDetails(
            engineType: "system",
            engineId: nil,
            zone: "system",
            capability: "trust_recalculation",
            reason: "Hourly trust score recalculation completed",
            attemptedAction: "trust_recalculation",
            taskId: nil,
            metadata: [
                "processed": String(cycleProcessed),
                "errors": String(cycleErrors),
                "duration_seconds": String(format: "%.2f", totalTime),
                "total_processed": String(totalProcessed),
                "total_errors": String(totalErrors)
            ]
        )

        await securityEvents.logEvent(
            type: .trustRecalculation,
            severity: .low,
            engineId: "system",
            operation: "trust_recalculation",
            details: details
        )
    }

    /// Get subjects that need recalculation.
    private func getSubjectsForRecalculation() async -> [(subjectId: String, subjectKind: TrustSubjectKind)] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_close(db) }

        // Get subjects where:
        // 1. trust_calculated_at is NULL (never calculated), OR
        // 2. trust_calculated_at is more than 1 hour ago, OR
        // 3. There are new security events since last calculation
        let sql = """
        SELECT ts.subject_id, ts.subject_kind
        FROM trust_state ts
        WHERE ts.trust_calculated_at IS NULL
           OR ts.trust_calculated_at < datetime('now', '-1 hour')
           OR EXISTS (
               SELECT 1 FROM security_events se
               WHERE se.engine_id = ts.subject_id
                 AND se.created_at > COALESCE(ts.trust_calculated_at, '1970-01-01')
           )
        ORDER BY ts.trust_calculated_at ASC NULLS FIRST
        LIMIT 1000
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var subjects: [(String, TrustSubjectKind)] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let subjectId = sqlite3_column_text(stmt, 0),
                  let subjectKindStr = sqlite3_column_text(stmt, 1),
                  let subjectKind = TrustSubjectKind(rawValue: String(cString: subjectKindStr)) else {
                continue
            }

            subjects.append((String(cString: subjectId), subjectKind))
        }

        return subjects
    }

    /// Process a single subject.
    private func processSubject(_ subject: (subjectId: String, subjectKind: TrustSubjectKind)) async -> Bool {
        do {
            let result = try await trustScoreCalculator.calculateScore(
                for: subject.subjectId,
                subjectKind: subject.subjectKind
            )

            // Update trust state with new score
            let success = await trustTierManager.setTrustScore(
                subjectId: subject.subjectId,
                subjectKind: subject.subjectKind,
                score: result.score,
                reason: "Hourly recalculation: \(result.score)",
                changedBy: "system"
            )

            if success {
                // Update calculation timestamp
                updateCalculationTimestamp(
                    subjectId: subject.subjectId,
                    subjectKind: subject.subjectKind
                )

                logDebug("[TRUST] Recalculated \(subject.subjectKind.rawValue) '\(subject.subjectId)': \(result.score) (\(result.tier.rawValue))", category: "TrustRecalcScheduler")
                return true
            } else {
                logError("[TRUST] Failed to update trust score for \(subject.subjectId)", category: "TrustRecalcScheduler")
                return false
            }

        } catch {
            logError("[TRUST] Error calculating trust score for \(subject.subjectId): \(error)", category: "TrustRecalcScheduler")
            return false
        }
    }

    /// Update calculation timestamp for a subject.
    private func updateCalculationTimestamp(subjectId: String, subjectKind: TrustSubjectKind) {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return
        }
        defer { sqlite3_close(db) }

        let sql = "UPDATE trust_state SET trust_calculated_at = CURRENT_TIMESTAMP WHERE subject_id = ? AND subject_kind = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, subjectId, -1, nil)
        sqlite3_bind_text(stmt, 2, subjectKind.rawValue, -1, nil)

        _ = sqlite3_step(stmt)
    }

    /// Get scheduler statistics.
    public func getStats() -> SchedulerStats {
        return SchedulerStats(
            isRunning: isRunning,
            lastRun: lastRun,
            totalProcessed: totalProcessed,
            totalErrors: totalErrors
        )
    }
}

// MARK: - Supporting Types

/// Scheduler statistics.
public struct SchedulerStats: Sendable, Codable {
    public let isRunning: Bool
    public let lastRun: Date?
    public let totalProcessed: Int
    public let totalErrors: Int

    public var successRate: Double {
        guard totalProcessed + totalErrors > 0 else { return 0.0 }
        return Double(totalProcessed) / Double(totalProcessed + totalErrors) * 100.0
    }

    public var timeSinceLastRun: TimeInterval? {
        guard let lastRun = lastRun else { return nil }
        return Date().timeIntervalSince(lastRun)
    }
}

// MARK: - Array Extension for Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Logging Helper

private func logInfo(_ message: String, category: String) {
    print("[INFO][\(category)] \(message)")
}

private func logDebug(_ message: String, category: String) {
    #if DEBUG
    print("[DEBUG][\(category)] \(message)")
    #endif
}

private func logError(_ message: String, category: String) {
    print("[ERROR][\(category)] \(message)")
}
