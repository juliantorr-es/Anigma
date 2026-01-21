//
//  TrustTierManager.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Persistent trust tier management with governance mode integration.
//  Stores trust state in database, not ephemeral memory.
//

import Foundation
import SQLite3
import AnigmaCore
import SecurityEventsManager
import HarmoniaModule

/// Persistent trust tier management.
public actor TrustTierManager {

    private let dbPath: String
    private let securityEvents: SecurityEventsManager
    private let scoringConfig: TrustScoringConfig

    public init(
        dbPath: String = "harmonia_harness.sqlite",
        securityEvents: SecurityEventsManager = SecurityEventsManager(),
        scoringConfig: TrustScoringConfig = .default
    ) {
        self.dbPath = dbPath
        self.securityEvents = securityEvents
        self.scoringConfig = scoringConfig
    }

    // MARK: - Trust Score & Tier Management

    /// Get trust score for a subject.
    public func getTrustScore(
        subjectId: String,
        subjectKind: TrustSubjectKind
    ) -> Int {
        return getStoredScore(subjectId: subjectId, subjectKind: subjectKind)
    }

    /// Get effective trust tier for a subject, respecting governance mode bounds.
    public func getEffectiveTrust(
        subjectId: String,
        subjectKind: TrustSubjectKind
    ) -> TrustTier {
        let currentMode = GovernanceMode.current(dbPath: dbPath)
        let storedScore = getStoredScore(subjectId: subjectId, subjectKind: subjectKind)
        let storedTier = scoringConfig.scoreToTier(storedScore)

        // Clamp stored tier within mode bounds
        let minTier = TrustTier.minimum(for: currentMode)
        let maxTier = TrustTier.maximum(for: currentMode)

        if storedTier < minTier {
            return minTier
        } else if storedTier > maxTier {
            return maxTier
        } else {
            return storedTier
        }
    }

    /// Resolve effective trust tier for an engine in context (hierarchy resolution).
    public func resolveEffectiveTrust(
        engineType: String,
        engineId: String? = nil,
        projectId: String? = nil
    ) -> TrustTier {
        // Priority order:
        // 1. engine_instance:{engineId}
        // 2. engine_type:{engineType}@project:{projectId}
        // 3. engine_type:{engineType}
        // 4. Default from config

        if let engineId = engineId {
            // Check engine instance
            let instanceScore = getStoredScore(
                subjectId: engineId,
                subjectKind: .engineInstance
            )
            if instanceScore != scoringConfig.defaultScore(for: .engineInstance) {
                return scoringConfig.scoreToTier(instanceScore)
            }
        }

        if let projectId = projectId {
            // Check engine type + project composite
            let compositeId = createCompositeSubjectId(engineType: engineType, projectId: projectId)
            let compositeScore = getStoredScore(
                subjectId: compositeId,
                subjectKind: .engineType
            )
            if compositeScore != scoringConfig.defaultScore(for: .engineType) {
                return scoringConfig.scoreToTier(compositeScore)
            }
        }

        // Check engine type global
        let typeScore = getStoredScore(
            subjectId: engineType,
            subjectKind: .engineType
        )
        if typeScore != scoringConfig.defaultScore(for: .engineType) {
            return scoringConfig.scoreToTier(typeScore)
        }

        // Return default
        return scoringConfig.scoreToTier(scoringConfig.defaultScore(for: .engineType))
    }

    /// Set trust score for a subject with audit trail.
    public func setTrustScore(
        subjectId: String,
        subjectKind: TrustSubjectKind,
        score: Int,
        reason: String,
        changedBy: String = "system",
        signature: String? = nil
    ) -> Bool {
        let clampedScore = max(0, min(100, score))
        let oldScore = getStoredScore(subjectId: subjectId, subjectKind: subjectKind)
        let oldTier = scoringConfig.scoreToTier(oldScore)
        let newTier = scoringConfig.scoreToTier(clampedScore)

        // Log trust change event if tier changed
        if newTier != oldTier {
            securityEvents.logTrustChange(
                subjectId: subjectId,
                subjectKind: subjectKind.rawValue,
                oldTier: oldTier.rawValue,
                newTier: newTier.rawValue,
                reason: reason,
                changedBy: changedBy
            )
        }

        // Update database
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_close(db) }

        let sql = """
        INSERT OR REPLACE INTO trust_state
        (subject_id, subject_kind, trust_score, current_trust_tier, trust_calculated_at, last_changed_at, changed_by, reason, signature)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, subjectId, -1, nil)
        sqlite3_bind_text(stmt, 2, subjectKind.rawValue, -1, nil)
        sqlite3_bind_int64(stmt, 3, Int64(clampedScore))
        sqlite3_bind_text(stmt, 4, newTier.rawValue, -1, nil)
        sqlite3_bind_text(stmt, 5, changedBy, -1, nil)
        sqlite3_bind_text(stmt, 6, reason, -1, nil)

        if let signature = signature {
            sqlite3_bind_text(stmt, 7, signature, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 7)
        }

        let success = sqlite3_step(stmt) == SQLITE_DONE

        if success {
            logInfo("[TRUST] Set \(subjectKind.rawValue) '\(subjectId)' to score \(clampedScore) (\(newTier.rawValue)): \(reason)", category: "TrustTierManager")
        }

        return success
    }

    /// Set trust tier for a subject with audit trail.
    /// Note: This method converts tier to approximate score. Use setTrustScore for precise control.
    public func setTrust(
        subjectId: String,
        subjectKind: TrustSubjectKind,
        tier: TrustTier,
        reason: String,
        changedBy: String = "system",
        signature: String? = nil
    ) -> Bool {
        let score = scoringConfig.tierToScore(tier)
        return setTrustScore(
            subjectId: subjectId,
            subjectKind: subjectKind,
            score: score,
            reason: reason,
            changedBy: changedBy,
            signature: signature
        )
    }

    /// Degrade trust score (e.g., after security event).
    public func degradeTrust(
        subjectId: String,
        subjectKind: TrustSubjectKind,
        reason: String,
        severity: SecurityEventSeverity = .medium
    ) -> Bool {
        let currentScore = getStoredScore(subjectId: subjectId, subjectKind: subjectKind)

        // Determine degradation amount based on severity
        let penalty: Int
        switch severity {
        case .low:
            penalty = -5
        case .medium:
            penalty = -10
        case .high:
            penalty = -15
        case .critical:
            penalty = -20
        }

        let newScore = max(0, currentScore + penalty)

        if newScore == currentScore && currentScore == 0 {
            logInfo("[TRUST] \(subjectId) already at minimum score (0)", category: "TrustTierManager")
            return true
        }

        return setTrustScore(
            subjectId: subjectId,
            subjectKind: subjectKind,
            score: newScore,
            reason: "Trust degraded due to security event: \(reason)",
            changedBy: "security_system"
        )
    }

    /// Promote trust score (e.g., after successful operations).
    public func promoteTrust(
        subjectId: String,
        subjectKind: TrustSubjectKind,
        reason: String,
        changedBy: String = "system"
    ) -> Bool {
        let currentScore = getStoredScore(subjectId: subjectId, subjectKind: subjectKind)

        // Apply recovery bonus (max +1 per day, +5 per week)
        let lastPromotion = getLastPromotionDate(subjectId: subjectId, subjectKind: subjectKind)
        let now = Date()

        // Check if we can promote today
        let canPromoteToday = canPromoteToday(lastPromotion: lastPromotion)
        let canPromoteThisWeek = canPromoteThisWeek(subjectId: subjectId, subjectKind: subjectKind)

        guard canPromoteToday && canPromoteThisWeek else {
            logInfo("[TRUST] \(subjectId) promotion limit reached (daily/weekly)", category: "TrustTierManager")
            return false
        }

        let newScore = min(100, currentScore + 1)

        if newScore == currentScore && currentScore == 100 {
            logInfo("[TRUST] \(subjectId) already at maximum score (100)", category: "TrustTierManager")
            return true
        }

        // Record promotion
        recordPromotion(subjectId: subjectId, subjectKind: subjectKind)

        return setTrustScore(
            subjectId: subjectId,
            subjectKind: subjectKind,
            score: newScore,
            reason: "Trust promoted: \(reason)",
            changedBy: changedBy
        )
    }

    /// Get trust record for a specific subject.
    public func getTrustRecord(
        subjectId: String,
        subjectKind: TrustSubjectKind
    ) -> TrustStateRecord? {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT subject_id, subject_kind, current_trust_tier, last_changed_at, changed_by, reason, signature FROM trust_state WHERE subject_id = ? AND subject_kind = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, subjectId, -1, nil)
        sqlite3_bind_text(stmt, 2, subjectKind.rawValue, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return parseTrustRecord(stmt: stmt)
        }

        return nil
    }

    /// Get trust state records for observability.
    public func getTrustStates(
        subjectKind: TrustSubjectKind? = nil,
        minTier: TrustTier? = nil,
        limit: Int = 100
    ) -> [TrustStateRecord] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_close(db) }

        var conditions: [String] = []
        var params: [Any] = []

        if let subjectKind = subjectKind {
            conditions.append("subject_kind = ?")
            params.append(subjectKind.rawValue)
        }

        if let minTier = minTier {
            // Convert tier to order for comparison
            let tierOrder = ["bronze": 0, "silver": 1, "gold": 2, "platinum": 3]
            if let minOrder = tierOrder[minTier.rawValue] {
                conditions.append("CASE current_trust_tier " +
                                 "WHEN 'bronze' THEN 0 " +
                                 "WHEN 'silver' THEN 1 " +
                                 "WHEN 'gold' THEN 2 " +
                                 "WHEN 'platinum' THEN 3 END >= ?")
                params.append(minOrder)
            }
        }

        var sql = "SELECT subject_id, subject_kind, current_trust_tier, last_changed_at, changed_by, reason, signature FROM trust_state"
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY last_changed_at DESC LIMIT ?"
        params.append(limit)

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        for (index, param) in params.enumerated() {
            let paramIndex = Int32(index + 1)
            if let stringParam = param as? String {
                sqlite3_bind_text(stmt, paramIndex, stringParam, -1, nil)
            } else if let intParam = param as? Int {
                sqlite3_bind_int64(stmt, paramIndex, Int64(intParam))
            }
        }

        var records: [TrustStateRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let record = parseTrustRecord(stmt: stmt) {
                records.append(record)
            }
        }

        return records
    }

    /// Get trust statistics for observability.
    public func getTrustStats() -> TrustStats {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return TrustStats()
        }
        defer { sqlite3_close(db) }

        var stats = TrustStats()

        // Total subjects
        let totalSql = "SELECT COUNT(*) FROM trust_state"
        if let total = queryCount(db: db, sql: totalSql) {
            stats.totalSubjects = total
        }

        // Subjects by kind
        let kindSql = "SELECT subject_kind, COUNT(*) FROM trust_state GROUP BY subject_kind"
        var kindStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, kindSql, -1, &kindStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(kindStmt) }
            while sqlite3_step(kindStmt) == SQLITE_ROW {
                let kind = String(cString: sqlite3_column_text(kindStmt, 0))
                let count = Int(sqlite3_column_int64(kindStmt, 1))
                stats.subjectsByKind[kind] = count
            }
        }

        // Subjects by tier
        let tierSql = "SELECT current_trust_tier, COUNT(*) FROM trust_state GROUP BY current_trust_tier"
        var tierStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, tierSql, -1, &tierStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(tierStmt) }
            while sqlite3_step(tierStmt) == SQLITE_ROW {
                let tier = String(cString: sqlite3_column_text(tierStmt, 0))
                let count = Int(sqlite3_column_int64(tierStmt, 1))
                stats.subjectsByTier[tier] = count
            }
        }

        // Score statistics
        let scoreSql = "SELECT AVG(trust_score), MIN(trust_score), MAX(trust_score) FROM trust_state"
        var scoreStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, scoreSql, -1, &scoreStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(scoreStmt) }
            if sqlite3_step(scoreStmt) == SQLITE_ROW {
                stats.averageScore = Double(sqlite3_column_double(scoreStmt, 0))
                stats.minScore = Int(sqlite3_column_int64(scoreStmt, 1))
                stats.maxScore = Int(sqlite3_column_int64(scoreStmt, 2))
            }
        }

        // Score distribution
        let distributionSql = """
        SELECT
            CASE
                WHEN trust_score >= 85 THEN 'platinum'
                WHEN trust_score >= 60 THEN 'gold'
                WHEN trust_score >= 25 THEN 'silver'
                ELSE 'bronze'
            END as tier_group,
            COUNT(*) as count
        FROM trust_state
        GROUP BY tier_group
        """
        var distStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, distributionSql, -1, &distStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(distStmt) }
            while sqlite3_step(distStmt) == SQLITE_ROW {
                let tierGroup = String(cString: sqlite3_column_text(distStmt, 0))
                let count = Int(sqlite3_column_int64(distStmt, 1))
                stats.scoreDistribution[tierGroup] = count
            }
        }

        // Recent changes (last 7 days)
        let recentSql = "SELECT COUNT(*) FROM trust_state WHERE last_changed_at >= datetime('now', '-7 days')"
        if let recent = queryCount(db: db, sql: recentSql) {
            stats.recentChanges7d = recent
        }

        // Recent trust history entries
        let historySql = "SELECT COUNT(*) FROM trust_history WHERE created_at >= datetime('now', '-7 days')"
        if let historyCount = queryCount(db: db, sql: historySql) {
            stats.recentHistoryEntries = historyCount
        }

        return stats
    }

    // MARK: - Private Methods

    private func getStoredTrust(subjectId: String, subjectKind: TrustSubjectKind) -> TrustTier {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return .bronze  // Default fallback
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT current_trust_tier FROM trust_state WHERE subject_id = ? AND subject_kind = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return .bronze
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, subjectId, -1, nil)
        sqlite3_bind_text(stmt, 2, subjectKind.rawValue, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            let tierString = String(cString: sqlite3_column_text(stmt, 0))
            return TrustTier(rawValue: tierString) ?? .bronze
        }

        // Default trust for new subjects
        return .bronze
    }

    private func degradeOneLevel(_ tier: TrustTier) -> TrustTier {
        switch tier {
        case .platinum: return .gold
        case .gold: return .silver
        case .silver: return .bronze
        case .bronze: return .bronze
        }
    }

    private func degradeTwoLevels(_ tier: TrustTier) -> TrustTier {
        switch tier {
        case .platinum: return .silver
        case .gold: return .bronze
        case .silver: return .bronze
        case .bronze: return .bronze
        }
    }

    private func promoteOneLevel(_ tier: TrustTier) -> TrustTier {
        switch tier {
        case .bronze: return .silver
        case .silver: return .gold
        case .gold: return .platinum
        case .platinum: return .platinum
        }
    }

    private func parseTrustRecord(stmt: OpaquePointer?) -> TrustStateRecord? {
        guard let subjectId = sqlite3_column_text(stmt, 0),
              let subjectKind = sqlite3_column_text(stmt, 1),
              let currentTier = sqlite3_column_text(stmt, 2),
              let lastChangedAt = sqlite3_column_text(stmt, 3) else {
            return nil
        }

        let changedBy = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 4))
        let reason = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 5))
        let signature = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 6))

        guard let trustTier = TrustTier(rawValue: String(cString: currentTier)),
              let subjectKindEnum = TrustSubjectKind(rawValue: String(cString: subjectKind)) else {
            return nil
        }

        return TrustStateRecord(
            subjectId: String(cString: subjectId),
            subjectKind: subjectKindEnum,
            currentTrustTier: trustTier,
            lastChangedAt: String(cString: lastChangedAt),
            changedBy: changedBy,
            reason: reason,
            signature: signature
        )
    }

    private func getStoredScore(subjectId: String, subjectKind: TrustSubjectKind) -> Int {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return scoringConfig.defaultScore(for: subjectKind)  // Default fallback
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT trust_score FROM trust_state WHERE subject_id = ? AND subject_kind = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return scoringConfig.defaultScore(for: subjectKind)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, subjectId, -1, nil)
        sqlite3_bind_text(stmt, 2, subjectKind.rawValue, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            let score = Int(sqlite3_column_int64(stmt, 0))
            return score
        }

        // Default score for new subjects
        return scoringConfig.defaultScore(for: subjectKind)
    }

    private func createCompositeSubjectId(engineType: String, projectId: String) -> String {
        return "\(engineType)@\(projectId)"
    }

    private func getLastPromotionDate(subjectId: String, subjectKind: TrustSubjectKind) -> Date? {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT MAX(last_changed_at) FROM trust_history WHERE subject_id = ? AND subject_kind = ? AND new_score > old_score"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, subjectId, -1, nil)
        sqlite3_bind_text(stmt, 2, subjectKind.rawValue, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            if let dateString = sqlite3_column_text(stmt, 0) {
                let formatter = ISO8601DateFormatter()
                return formatter.date(from: String(cString: dateString))
            }
        }
        return nil
    }

    private func canPromoteToday(lastPromotion: Date?) -> Bool {
        guard let lastPromotion = lastPromotion else {
            return true // No previous promotions
        }

        let calendar = Calendar.current
        let now = Date()

        // Check if last promotion was today
        return !calendar.isDate(lastPromotion, inSameDayAs: now)
    }

    private func canPromoteThisWeek(subjectId: String, subjectKind: TrustSubjectKind) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT COUNT(*) FROM trust_history WHERE subject_id = ? AND subject_kind = ? AND new_score > old_score AND last_changed_at >= datetime('now', '-7 days')"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, subjectId, -1, nil)
        sqlite3_bind_text(stmt, 2, subjectKind.rawValue, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            let count = Int(sqlite3_column_int64(stmt, 0))
            return count < 5 // Max 5 promotions per week
        }
        return true
    }

    private func recordPromotion(subjectId: String, subjectKind: TrustSubjectKind) {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return
        }
        defer { sqlite3_close(db) }

        let sql = "INSERT INTO trust_promotion_tracking (subject_id, subject_kind, promoted_at) VALUES (?, ?, CURRENT_TIMESTAMP)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, subjectId, -1, nil)
        sqlite3_bind_text(stmt, 2, subjectKind.rawValue, -1, nil)

        _ = sqlite3_step(stmt)
    }

    private func queryCount(db: OpaquePointer?, sql: String) -> Int? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        return nil
    }
}
