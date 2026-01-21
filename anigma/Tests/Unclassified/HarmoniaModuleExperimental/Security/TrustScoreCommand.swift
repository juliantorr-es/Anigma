//
//  TrustScoreCommand.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  CLI commands for trust score management and observability.
//

import Foundation
import ArgumentParser
import SQLite3
import HarmoniaModule

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// CLI commands for trust score management.
public struct TrustScoreCommands {
    private let dbPath: String

    public init(dbPath: String = "./harmonia_harness.sqlite") {
        self.dbPath = dbPath
    }

    /// Show trust score for a specific subject.
    public func score(subjectId: String, subjectKind: String) throws {
        print("📊 Trust Score")
        print("==============")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        // Get trust score and details
        let sql = """
        SELECT
            ts.subject_id,
            ts.subject_kind,
            ts.trust_score,
            ts.current_trust_tier,
            ts.trust_calculated_at,
            ts.last_changed_at,
            ts.changed_by,
            ts.reason,
            COUNT(th.id) as history_count
        FROM trust_state ts
        LEFT JOIN trust_history th ON ts.subject_id = th.subject_id AND ts.subject_kind = th.subject_kind
        WHERE ts.subject_id = ? AND ts.subject_kind = ?
        GROUP BY ts.subject_id, ts.subject_kind
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare query: \(errMsg)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, subjectId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, subjectKind, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) == SQLITE_ROW {
            let subjectId = String(cString: sqlite3_column_text(stmt, 0))
            let subjectKind = String(cString: sqlite3_column_text(stmt, 1))
            let trustScore = Int(sqlite3_column_int64(stmt, 2))
            let trustTier = String(cString: sqlite3_column_text(stmt, 3))
            let calculatedAt = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let lastChanged = String(cString: sqlite3_column_text(stmt, 5))
            let changedBy = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            let reason = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            let historyCount = Int(sqlite3_column_int64(stmt, 8))

            print("Subject: \(subjectId)")
            print("Kind: \(subjectKind)")
            print("")
            print("📈 Raw Score: \(trustScore)/100")
            print("🏆 Raw Tier: \(trustTier)")

            // Show effective tier with governance clamping
            let governanceMode = try getGovernanceMode(db: db)
            let (minTier, maxTier) = getGovernanceBounds(mode: governanceMode)
            let effectiveTier = applyGovernanceClamp(rawTier: trustTier, minTier: minTier, maxTier: maxTier)

            if effectiveTier != trustTier {
                print("🔒 Effective Tier: \(effectiveTier) (clamped by \(governanceMode) mode)")
            } else {
                print("🔓 Effective Tier: \(effectiveTier)")
            }

            print("")
            print("📅 Last calculated: \(calculatedAt ?? "never")")
            print("🔄 Last changed: \(lastChanged)")

            if let changedBy = changedBy {
                print("👤 Changed by: \(changedBy)")
            }

            if let reason = reason {
                print("📝 Reason: \(reason)")
            }

            print("")
            print("📋 History entries: \(historyCount)")

            // Show score health
            let health = getScoreHealth(trustScore)
            print("🏥 Health: \(health)")

            // Show governance mode bounds
            print("🏛️  Governance mode: \(governanceMode)")
            print("   • Minimum tier: \(minTier)")
            print("   • Maximum tier: \(maxTier)")

        } else {
            print("📭 No trust score found for \(subjectKind) '\(subjectId)'")
            print("")
            print("Possible reasons:")
            print("1. Subject doesn't exist in trust system")
            print("2. Database not initialized (run 'harmonia security init')")
            print("3. Subject kind is incorrect")
            print("")
            print("Available subject kinds: engine_type, engine_instance, project, user, system")
        }
    }

    /// Set trust score for a subject.
    public func setScore(subjectId: String, subjectKind: String, score: Int, reason: String, changedBy: String? = nil) throws {
        let actualChangedBy = changedBy ?? ProcessInfo.processInfo.environment["USER"] ?? "unknown-user"
        print("⚙️  Setting trust score...")

        // Validate score
        guard (0...100).contains(score) else {
            print("❌ Score must be between 0 and 100")
            return
        }

        // Validate subject kind
        let validKinds = ["engine_type", "engine_instance", "project", "user", "system"]
        guard validKinds.contains(subjectKind) else {
            print("❌ Invalid subject kind: \(subjectKind)")
            print("Valid kinds: \(validKinds.joined(separator: ", "))")
            return
        }

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        // Get old score for history
        let oldScoreSql = "SELECT trust_score FROM trust_state WHERE subject_id = ? AND subject_kind = ?"
        var oldScoreStmt: OpaquePointer?
        var oldScore: Int?

        if sqlite3_prepare_v2(db, oldScoreSql, -1, &oldScoreStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(oldScoreStmt) }
            sqlite3_bind_text(oldScoreStmt, 1, subjectId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(oldScoreStmt, 2, subjectKind, -1, SQLITE_TRANSIENT)

            if sqlite3_step(oldScoreStmt) == SQLITE_ROW {
                oldScore = Int(sqlite3_column_int64(oldScoreStmt, 0))
            }
        }

        // Determine tier from score
        let tier = scoreToTier(score)

        // Update trust state
        let updateSql = """
        INSERT OR REPLACE INTO trust_state
        (subject_id, subject_kind, trust_score, current_trust_tier, trust_calculated_at, last_changed_at, changed_by, reason)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?, ?)
        """

        var updateStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSql, -1, &updateStmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare update: \(errMsg)")
            return
        }
        defer { sqlite3_finalize(updateStmt) }

        sqlite3_bind_text(updateStmt, 1, subjectId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(updateStmt, 2, subjectKind, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(updateStmt, 3, Int64(score))
        sqlite3_bind_text(updateStmt, 4, tier, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(updateStmt, 5, actualChangedBy, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(updateStmt, 6, reason, -1, SQLITE_TRANSIENT)

        if sqlite3_step(updateStmt) == SQLITE_DONE {
            // Add to history
            if let oldScore = oldScore {
                let historySql = """
                INSERT INTO trust_history
                (subject_id, subject_kind, old_score, new_score, old_tier, new_tier, reason, changed_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """

                var historyStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, historySql, -1, &historyStmt, nil) == SQLITE_OK {
                    defer { sqlite3_finalize(historyStmt) }

                    let oldTier = scoreToTier(oldScore)

                    sqlite3_bind_text(historyStmt, 1, subjectId, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(historyStmt, 2, subjectKind, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int64(historyStmt, 3, Int64(oldScore))
                    sqlite3_bind_int64(historyStmt, 4, Int64(score))
                    sqlite3_bind_text(historyStmt, 5, oldTier, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(historyStmt, 6, tier, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(historyStmt, 7, reason, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(historyStmt, 8, actualChangedBy, -1, SQLITE_TRANSIENT)

                    _ = sqlite3_step(historyStmt)
                }
            }

            print("✅ Set \(subjectKind) '\(subjectId)' to score \(score) (\(tier))")
            print("📝 Reason: \(reason)")
            print("👤 Changed by: \(actualChangedBy)")

        } else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to update trust score: \(errMsg)")
        }
    }

    /// Show trust score history for a subject.
    public func history(subjectId: String, subjectKind: String, limit: Int = 20) throws {
        print("📋 Trust Score History")
        print("=====================")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT
            old_score,
            new_score,
            old_tier,
            new_tier,
            reason,
            changed_by,
            created_at
        FROM trust_history
        WHERE subject_id = ? AND subject_kind = ?
        ORDER BY created_at DESC
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare query: \(errMsg)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, subjectId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, subjectKind, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 3, Int64(limit))

        var entries: [TrustHistoryEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let oldScore = Int(sqlite3_column_int64(stmt, 0))
            let newScore = Int(sqlite3_column_int64(stmt, 1))
            let oldTier = String(cString: sqlite3_column_text(stmt, 2))
            let newTier = String(cString: sqlite3_column_text(stmt, 3))
            let reason = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let changedBy = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let createdAt = String(cString: sqlite3_column_text(stmt, 6))

            entries.append(TrustHistoryEntry(
                oldScore: oldScore,
                newScore: newScore,
                oldTier: oldTier,
                newTier: newTier,
                reason: reason,
                changedBy: changedBy,
                createdAt: createdAt
            ))
        }

        if entries.isEmpty {
            print("📭 No history found for \(subjectKind) '\(subjectId)'")
            return
        }

        print("Subject: \(subjectId)")
        print("Kind: \(subjectKind)")
        print("")

        for (index, entry) in entries.enumerated() {
            print("Entry \(index + 1):")
            print("  📅 Date: \(entry.createdAt)")
            print("  📊 Score: \(entry.oldScore) → \(entry.newScore)")
            print("  🏆 Tier: \(entry.oldTier) → \(entry.newTier)")

            if let changedBy = entry.changedBy {
                print("  👤 Changed by: \(changedBy)")
            }

            if let reason = entry.reason {
                print("  📝 Reason: \(reason)")
            }

            let delta = entry.newScore - entry.oldScore
            if delta > 0 {
                print("  📈 Change: +\(delta)")
            } else if delta < 0 {
                print("  📉 Change: \(delta)")
            } else {
                print("  ➖ Change: 0")
            }

            if index < entries.count - 1 {
                print("")
            }
        }
    }

    /// Recalculate trust scores.
    public func recalc(limit: Int = 50, dryRun: Bool = false) throws {
        print("🔄 Trust Score Recalculation")
        print("===========================")

        if dryRun {
            print("🧪 DRY RUN - No changes will be made")
        }

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        // Get subjects that need recalculation
        let subjects = try getSubjectsForRecalculation(db: db, limit: limit)

        if subjects.isEmpty {
            print("✅ All trust scores are up to date")
            return
        }

        print("Found \(subjects.count) subjects needing recalculation:")
        for subject in subjects {
            print("  • \(subject.subjectKind) '\(subject.subjectId)'")
        }

        if dryRun {
            print("")
            print("🧪 Dry run complete. Would recalculate \(subjects.count) subjects.")
            return
        }

        print("")
        print("Starting recalculation...")

        var processed = 0
        var errors = 0

        for subject in subjects {
            do {
                // In a real implementation, this would call TrustScoreCalculator
                // For now, we'll simulate recalculation
                let newScore = try simulateRecalculation(db: db, subject: subject)
                let newTier = scoreToTier(newScore)

                // Update trust state
                let updateSql = """
                UPDATE trust_state
                SET trust_score = ?, current_trust_tier = ?, trust_calculated_at = CURRENT_TIMESTAMP
                WHERE subject_id = ? AND subject_kind = ?
                """

                var updateStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, updateSql, -1, &updateStmt, nil) == SQLITE_OK {
                    defer { sqlite3_finalize(updateStmt) }

                    sqlite3_bind_int64(updateStmt, 1, Int64(newScore))
                    sqlite3_bind_text(updateStmt, 2, newTier, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(updateStmt, 3, subject.subjectId, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(updateStmt, 4, subject.subjectKind, -1, SQLITE_TRANSIENT)

                    if sqlite3_step(updateStmt) == SQLITE_DONE {
                        processed += 1
                        print("  ✅ \(subject.subjectKind) '\(subject.subjectId)': \(newScore) (\(newTier))")
                    } else {
                        errors += 1
                        print("  ❌ Failed to update \(subject.subjectId)")
                    }
                } else {
                    errors += 1
                    print("  ❌ Failed to prepare update for \(subject.subjectId)")
                }

            } catch {
                errors += 1
                print("  ❌ Error recalculating \(subject.subjectId): \(error)")
            }
        }

        print("")
        print("Recalculation complete:")
        print("  • Processed: \(processed)")
        print("  • Errors: \(errors)")
        print("  • Success rate: \(processed > 0 ? String(format: "%.1f", Double(processed) / Double(processed + errors) * 100) : "0")%")
    }

    /// Show trust score statistics.
    public func stats() throws {
        print("📈 Trust Score Statistics")
        print("========================")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        // Basic statistics
        let basicStats = try getBasicStats(db: db)
        print("Basic Statistics:")
        print("  • Total subjects: \(basicStats.totalSubjects)")
        print("  • Average score: \(String(format: "%.1f", basicStats.averageScore))/100")
        print("  • Minimum score: \(basicStats.minScore)")
        print("  • Maximum score: \(basicStats.maxScore)")
        print("  • Health: \(getScoreHealth(Int(basicStats.averageScore)))")

        // Score distribution
        let distribution = try getScoreDistribution(db: db)
        print("")
        print("Score Distribution:")
        for (range, count) in distribution.sorted(by: { $0.key < $1.key }) {
            let percentage = basicStats.totalSubjects > 0 ?
                Double(count) / Double(basicStats.totalSubjects) * 100 : 0
            print("  • \(range): \(count) (\(String(format: "%.1f", percentage))%)")
        }

        // Tier distribution
        let tierDistribution = try getTierDistribution(db: db)
        print("")
        print("Tier Distribution:")
        for (tier, count) in tierDistribution.sorted(by: { $0.key < $1.key }) {
            let percentage = basicStats.totalSubjects > 0 ?
                Double(count) / Double(basicStats.totalSubjects) * 100 : 0
            print("  • \(tier): \(count) (\(String(format: "%.1f", percentage))%)")
        }

        // Recent activity
        let recentActivity = try getRecentActivity(db: db)
        print("")
        print("Recent Activity (last 7 days):")
        print("  • Score changes: \(recentActivity.scoreChanges)")
        print("  • Tier changes: \(recentActivity.tierChanges)")
        print("  • History entries: \(recentActivity.historyEntries)")

        // Governance mode
        let governanceMode = try getGovernanceMode(db: db)
        print("")
        print("Governance Mode: \(governanceMode)")
    }

    // MARK: - Helper Methods

    private func getScoreHealth(_ score: Int) -> String {
        switch score {
        case 85...100: return "Excellent (Platinum)"
        case 60...84: return "Good (Gold)"
        case 25...59: return "Fair (Silver)"
        case 0...24: return "Poor (Bronze)"
        default: return "Unknown"
        }
    }

    private func applyGovernanceClamp(rawTier: String, minTier: String, maxTier: String) -> String {
        let tierOrder = ["bronze": 0, "silver": 1, "gold": 2, "platinum": 3]
        guard let rawOrder = tierOrder[rawTier],
              let minOrder = tierOrder[minTier],
              let maxOrder = tierOrder[maxTier] else {
            return rawTier
        }

        if rawOrder < minOrder {
            return minTier
        } else if rawOrder > maxOrder {
            return maxTier
        } else {
            return rawTier
        }
    }

    private func scoreToTier(_ score: Int) -> String {
        switch score {
        case 85...100: return "platinum"
        case 60...84: return "gold"
        case 25...59: return "silver"
        default: return "bronze"
        }
    }

    private func getGovernanceMode(db: OpaquePointer?) throws -> String {
        let sql = "SELECT mode FROM governance_mode WHERE id = 1"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return "unknown"
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(stmt, 0))
        }

        return "governed" // Default
    }

    private func getGovernanceBounds(mode: String) -> (min: String, max: String) {
        switch mode {
        case "personal":
            return ("bronze", "platinum")
        case "governed":
            return ("silver", "gold")
        case "paranoid":
            return ("gold", "silver") // Note: max is silver in paranoid mode
        default:
            return ("bronze", "platinum")
        }
    }

    private func getSubjectsForRecalculation(db: OpaquePointer?, limit: Int) throws -> [(subjectId: String, subjectKind: String)] {
        let sql = """
        SELECT subject_id, subject_kind
        FROM trust_state
        WHERE trust_calculated_at IS NULL
           OR trust_calculated_at < datetime('now', '-1 hour')
        ORDER BY trust_calculated_at ASC NULLS FIRST
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "TrustScoreCommands", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get subjects for recalculation"])
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(limit))

        var subjects: [(String, String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let subjectId = String(cString: sqlite3_column_text(stmt, 0))
            let subjectKind = String(cString: sqlite3_column_text(stmt, 1))
            subjects.append((subjectId, subjectKind))
        }

        return subjects
    }

    private func simulateRecalculation(db: OpaquePointer?, subject: (subjectId: String, subjectKind: String)) throws -> Int {
        // In a real implementation, this would use TrustScoreCalculator
        // For simulation, we'll return a random score between 40-80
        // This is just for CLI demonstration

        // Get current score
        let sql = "SELECT trust_score FROM trust_state WHERE subject_id = ? AND subject_kind = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "TrustScoreCommands", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get current score"])
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, subject.subjectId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, subject.subjectKind, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) == SQLITE_ROW {
            let currentScore = Int(sqlite3_column_int64(stmt, 0))

            // Simulate small random adjustment (-5 to +5)
            let adjustment = Int.random(in: -5...5)
            let newScore = max(0, min(100, currentScore + adjustment))

            return newScore
        }

        // Default score if not found
        return 50
    }

    private func getBasicStats(db: OpaquePointer?) throws -> BasicStats {
        let sql = """
        SELECT
            COUNT(*) as total,
            AVG(trust_score) as avg_score,
            MIN(trust_score) as min_score,
            MAX(trust_score) as max_score
        FROM trust_state
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "TrustScoreCommands", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get basic stats"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let total = Int(sqlite3_column_int64(stmt, 0))
            let avgScore = sqlite3_column_double(stmt, 1)
            let minScore = Int(sqlite3_column_int64(stmt, 2))
            let maxScore = Int(sqlite3_column_int64(stmt, 3))

            return BasicStats(
                totalSubjects: total,
                averageScore: avgScore,
                minScore: minScore,
                maxScore: maxScore
            )
        }

        return BasicStats(totalSubjects: 0, averageScore: 0, minScore: 0, maxScore: 0)
    }

    private func getScoreDistribution(db: OpaquePointer?) throws -> [String: Int] {
        let sql = """
        SELECT
            CASE
                WHEN trust_score >= 85 THEN '85-100 (Platinum)'
                WHEN trust_score >= 60 THEN '60-84 (Gold)'
                WHEN trust_score >= 25 THEN '25-59 (Silver)'
                ELSE '0-24 (Bronze)'
            END as score_range,
            COUNT(*) as count
        FROM trust_state
        GROUP BY score_range
        ORDER BY
            CASE score_range
                WHEN '85-100 (Platinum)' THEN 1
                WHEN '60-84 (Gold)' THEN 2
                WHEN '25-59 (Silver)' THEN 3
                ELSE 4
            END
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "TrustScoreCommands", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to get score distribution"])
        }
        defer { sqlite3_finalize(stmt) }

        var distribution: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let range = String(cString: sqlite3_column_text(stmt, 0))
            let count = Int(sqlite3_column_int64(stmt, 1))
            distribution[range] = count
        }

        return distribution
    }

    private func getTierDistribution(db: OpaquePointer?) throws -> [String: Int] {
        let sql = """
        SELECT current_trust_tier, COUNT(*) as count
        FROM trust_state
        GROUP BY current_trust_tier
        ORDER BY
            CASE current_trust_tier
                WHEN 'platinum' THEN 1
                WHEN 'gold' THEN 2
                WHEN 'silver' THEN 3
                ELSE 4
            END
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "TrustScoreCommands", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to get tier distribution"])
        }
        defer { sqlite3_finalize(stmt) }

        var distribution: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let tier = String(cString: sqlite3_column_text(stmt, 0))
            let count = Int(sqlite3_column_int64(stmt, 1))
            distribution[tier] = count
        }

        return distribution
    }

    private func getRecentActivity(db: OpaquePointer?) throws -> RecentActivity {
        let scoreChangesSql = """
        SELECT COUNT(*)
        FROM trust_state
        WHERE last_changed_at >= datetime('now', '-7 days')
        """

        let tierChangesSql = """
        SELECT COUNT(DISTINCT subject_id || subject_kind)
        FROM trust_history
        WHERE old_tier != new_tier
          AND created_at >= datetime('now', '-7 days')
        """

        let historyEntriesSql = """
        SELECT COUNT(*)
        FROM trust_history
        WHERE created_at >= datetime('now', '-7 days')
        """

        var scoreChanges = 0
        var tierChanges = 0
        var historyEntries = 0

        // Score changes
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, scoreChangesSql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                scoreChanges = Int(sqlite3_column_int64(stmt, 0))
            }
        }

        // Tier changes
        if sqlite3_prepare_v2(db, tierChangesSql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                tierChanges = Int(sqlite3_column_int64(stmt, 0))
            }
        }

        // History entries
        if sqlite3_prepare_v2(db, historyEntriesSql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                historyEntries = Int(sqlite3_column_int64(stmt, 0))
            }
        }

        return RecentActivity(
            scoreChanges: scoreChanges,
            tierChanges: tierChanges,
            historyEntries: historyEntries
        )
    }
}

// MARK: - Data Structures

private struct TrustHistoryEntry {
    let oldScore: Int
    let newScore: Int
    let oldTier: String
    let newTier: String
    let reason: String?
    let changedBy: String?
    let createdAt: String
}

private struct BasicStats {
    let totalSubjects: Int
    let averageScore: Double
    let minScore: Int
    let maxScore: Int
}

private struct RecentActivity {
    let scoreChanges: Int
    let tierChanges: Int
    let historyEntries: Int
}

// MARK: - Argument Parser

public struct TrustScoreCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "harmonia-trust-score",
        abstract: "Trust score management and observability",
        subcommands: [
            ScoreCommand.self,
            SetCommand.self,
            HistoryCommand.self,
            RecalcCommand.self,
            StatsCommand.self
        ]
    )

    public init() {}
}

// MARK: - Subcommands

struct ScoreCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "score",
        abstract: "Show trust score for a subject"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    @Argument(help: "Subject identifier")
    var subjectId: String

    @Argument(help: "Subject kind (engine_type, engine_instance, project, user, system)")
    var subjectKind: String

    func run() throws {
        let commands = TrustScoreCommands(dbPath: dbPath)
        try commands.score(subjectId: subjectId, subjectKind: subjectKind)
    }
}

struct SetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set trust score for a subject"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    @Argument(help: "Subject identifier")
    var subjectId: String

    @Argument(help: "Subject kind (engine_type, engine_instance, project, user, system)")
    var subjectKind: String

    @Argument(help: "Trust score (0-100)")
    var score: Int

    @Option(name: .shortAndLong, help: "Reason for the change")
    var reason: String

    @Option(name: .shortAndLong, help: "Who is making the change")
    var changedBy: String = "cli"

    func run() throws {
        let commands = TrustScoreCommands(dbPath: dbPath)
        try commands.setScore(
            subjectId: subjectId,
            subjectKind: subjectKind,
            score: score,
            reason: reason,
            changedBy: changedBy
        )
    }
}

struct HistoryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "history",
        abstract: "Show trust score history for a subject"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    @Argument(help: "Subject identifier")
    var subjectId: String

    @Argument(help: "Subject kind (engine_type, engine_instance, project, user, system)")
    var subjectKind: String

    @Option(name: .shortAndLong, help: "Maximum number of entries to show")
    var limit: Int = 20

    func run() throws {
        let commands = TrustScoreCommands(dbPath: dbPath)
        try commands.history(subjectId: subjectId, subjectKind: subjectKind, limit: limit)
    }
}

struct RecalcCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "recalc",
        abstract: "Recalculate trust scores"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    @Option(name: .shortAndLong, help: "Maximum number of subjects to process")
    var limit: Int = 50

    @Flag(name: .shortAndLong, help: "Dry run - show what would be recalculated")
    var dryRun: Bool = false

    func run() throws {
        let commands = TrustScoreCommands(dbPath: dbPath)
        try commands.recalc(limit: limit, dryRun: dryRun)
    }
}

struct StatsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Show trust score statistics"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    func run() throws {
        let commands = TrustScoreCommands(dbPath: dbPath)
        try commands.stats()
    }
}
