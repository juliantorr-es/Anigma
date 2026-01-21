//
//  TrustScoreCalculator.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Dynamic trust scoring based on CCTV events.
//  Phase 4A: Core scoring algorithm with conservative defaults.
//  Phase 6: Fixed actor isolation with DatabaseActor.
//

import Foundation
import AnigmaCore
import DatabaseCore
import HarmoniaModule
// The following modules should now be imported from AnigmaCore or no longer needed due to refactoring
// import SecurityEventsManager 
// import TrustTierManager

/// Calculator for dynamic trust scores based on security events.
public actor TrustScoreCalculator {

    // MARK: - Dependencies

    private let config: TrustScoringConfig
    private let database: DatabaseActor
    private let securityEvents: SecurityEventsManager // Now an actor, needs to be initialized carefully
    private let trustTierManager: TrustTierManager // Now an actor, needs to be initialized carefully

    /// Last immediate adjustment timestamps per subject to prevent feedback loops.
    private var lastImmediateAdjustment: [String: Date] = [:]

    /// Last batch recalculation timestamp.
    private var lastBatchRecalculation: Date?

    // MARK: - Initialization

    public init(
        config: TrustScoringConfig = .default,
        dbPath: String = "harmonia_harness.sqlite",
        securityEvents: SecurityEventsManager = SecurityEventsManager(dbPath: "harmonia_harness.sqlite"),
        trustTierManager: TrustTierManager = TrustTierManager(dbPath: "harmonia_harness.sqlite")
    ) {
        self.config = config
        self.database = DatabaseActor(dbPath: dbPath)
        self.securityEvents = securityEvents
        self.trustTierManager = trustTierManager
    }

    // MARK: - Public API

    /// Calculate trust score for a subject based on recent events.
    /// Returns (score: Int, tier: TrustTier, changed: Bool).
    public func calculateScore(
        for subjectId: String,
        subjectKind: TrustSubjectKind
    ) async throws -> (score: Int, tier: TrustTier, changed: Bool) {
        logInfo("[TRUST][CALC] Calculating score for \(subjectKind.rawValue):\(subjectId)", category: "TrustScoreCalculator")

        // Get current trust state
        let currentState = try await getCurrentTrustState(subjectId: subjectId, subjectKind: subjectKind)
        let currentScore = currentState.score
        let currentTier = currentState.tier

        // Query relevant events since last calculation
        let events = try await queryRelevantEvents(
            subjectId: subjectId,
            subjectKind: subjectKind,
            since: currentState.calculatedAt
        )

        guard !events.isEmpty else {
            logInfo("[TRUST][CALC] No new events for \(subjectId)", category: "TrustScoreCalculator")
            return (currentScore, currentTier, false)
        }

        // Calculate weighted sum with temporal decay
        let weightedSum = calculateWeightedSum(events: events)
        logInfo("[TRUST][CALC] Weighted sum: \(weightedSum) from \(events.count) events", category: "TrustScoreCalculator")

        // Apply clean window bonus if applicable
        let cleanBonus = try await calculateCleanWindowBonus(
            subjectId: subjectId,
            subjectKind: subjectKind,
            currentScore: currentScore
        )

        // Calculate new score with clamping
        let rawNewScore = currentScore + weightedSum + cleanBonus
        let newScore = clampScore(rawNewScore)

        // Determine if score changed significantly
        let scoreChanged = abs(newScore - currentScore) >= 1
        let newTier = config.scoreToTier(newScore)
        let tierChanged = newTier != currentTier

        logInfo("[TRUST][CALC] Score: \(currentScore) → \(newScore), Tier: \(currentTier.rawValue) → \(newTier.rawValue)", category: "TrustScoreCalculator")

        if scoreChanged {
            // Update trust state
            try await updateTrustState(
                subjectId: subjectId,
                subjectKind: subjectKind,
                newScore: newScore,
                newTier: newTier,
                reason: "Automatic recalculation based on \(events.count) events"
            )
        }

        return (newScore, newTier, scoreChanged || tierChanged)
    }

    /// Process a critical event immediately (bypasses batch scheduling).
    public func processCriticalEvent(_ event: SecurityEvent) async throws -> Bool {
        guard let engineId = event.engineId else {
            logInfo("[TRUST][CRITICAL] Event has no engineId, skipping", category: "TrustScoreCalculator")
            return false
        }

        // Check if event severity warrants immediate processing
        let severity = SecurityEventSeverity(rawValue: event.severity) ?? .medium
        guard config.immediateSeverities.contains(severity) else {
            logInfo("[TRUST][CRITICAL] Event severity \(severity.rawValue) not in immediate set", category: "TrustScoreCalculator")
            return false
        }

        // Check cooldown to prevent feedback loops
        let subjectKey = "\(engineId)"
        if let lastAdjustment = lastImmediateAdjustment[subjectKey] {
            let cooldown = TimeInterval(config.immediateCooldownSeconds)
            if Date().timeIntervalSince(lastAdjustment) < cooldown {
                logInfo("[TRUST][CRITICAL] Cooldown active for \(engineId)", category: "TrustScoreCalculator")
                return false
            }
        }

        // Determine subject kind from event context
        let subjectKind: TrustSubjectKind = .engineInstance  // Default assumption
        let eventType = TrustEventType(from: event.type) ?? .capabilityBlocked

        let severity = SecurityEventSeverity(rawValue: event.severity) ?? .medium
        // Get weight for this event
        let weight = config.weight(for: eventType, severity: severity)
        guard weight < 0 else {
            logInfo("[TRUST][CRITICAL] Event has non-negative weight (\(weight)), skipping", category: "TrustScoreCalculator")
            return false
        }

        // Apply immediate penalty (capped)
        let penalty = max(weight, config.maxImmediatePenalty)

        // Get current score
        let currentState = try await getCurrentTrustState(subjectId: engineId, subjectKind: subjectKind)
        let newScore = clampScore(currentState.score + penalty)

        // Update trust state
        try await updateTrustState(
            subjectId: engineId,
            subjectKind: subjectKind,
            newScore: newScore,
            newTier: config.scoreToTier(newScore),
            reason: "Immediate penalty for \(event.type) (\(severity.rawValue))"
        )

        // Update cooldown timestamp
        lastImmediateAdjustment[subjectKey] = Date()

        logInfo("[TRUST][CRITICAL] Applied immediate penalty: \(penalty) for \(engineId)", category: "TrustScoreCalculator")
        return true
    }

    /// Recalculate trust scores for all subjects in batch.
    public func recalculateAll() async throws -> RecalcStats {
        logInfo("[TRUST][BATCH] Starting batch recalculation", category: "TrustScoreCalculator")

        var stats = RecalcStats()
        lastBatchRecalculation = Date()

        // Get all subjects with trust state
        let subjects = try await getAllSubjects()

        for subject in subjects {
            do {
                let (_, _, changed) = try await calculateScore(
                    for: subject.id,
                    subjectKind: subject.kind
                )

                stats.subjectsProcessed += 1
                if changed {
                    stats.subjectsChanged += 1
                }

                // Small delay to prevent database contention
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms

            } catch {
                logError("[TRUST][BATCH] Failed to recalculate \(subject.kind.rawValue):\(subject.id): \(error)", category: "TrustScoreCalculator")
                stats.errors += 1
            }
        }

        logInfo("[TRUST][BATCH] Completed: \(stats.subjectsProcessed) processed, \(stats.subjectsChanged) changed, \(stats.errors) errors", category: "TrustScoreCalculator")
        return stats
    }

    // MARK: - Private Helpers

    private func getCurrentTrustState(
        subjectId: String,
        subjectKind: TrustSubjectKind
    ) async throws -> (score: Int, tier: TrustTier, calculatedAt: Date?) {
        try await database.open()

        let sql = """
        SELECT trust_score, current_trust_tier, trust_calculated_at
        FROM trust_state
        WHERE subject_id = ? AND subject_kind = ?
        """

        let rows = try await database.query(sql, parameters: [
            .text(subjectId),
            .text(subjectKind.rawValue)
        ])

        if let row = rows.first {
            let score = row.int(for: "trust_score") ?? config.defaultScore(for: subjectKind)
            let tierString = row.string(for: "current_trust_tier") ?? "bronze"
            let calculatedAtString = row.string(for: "trust_calculated_at")

            let tier = TrustTier(rawValue: tierString) ?? .bronze
            var calculatedAt: Date?

            if let dateString = calculatedAtString {
                let formatter = ISO8601DateFormatter()
                calculatedAt = formatter.date(from: dateString)
            }

            return (score, tier, calculatedAt)
        } else {
            // Subject doesn't exist, return defaults
            let defaultScore = config.defaultScore(for: subjectKind)
            let defaultTier = config.scoreToTier(defaultScore)
            return (defaultScore, defaultTier, nil)
        }
    }

    private func queryRelevantEvents(
        subjectId: String,
        subjectKind: TrustSubjectKind,
        since calculatedAt: Date?
    ) async throws -> [SecurityEvent] {
        // Default to last 30 days if no calculatedAt
        let sinceDate = calculatedAt ?? Calendar.current.date(byAdding: .day, value: -config.scoringWindowDays, to: Date()) ?? Date()

        // Convert to string for SQL query
        let formatter = ISO8601DateFormatter()
        let sinceString = formatter.string(from: sinceDate)

        // PHASE 4A LIMITATION: Only engine_instance scoring is fully implemented
        // Phase 4B will add proper subject-event mapping for all subject kinds
        guard subjectKind == .engineInstance else {
            logInfo("[TRUST][CALC] Subject kind \(subjectKind.rawValue) not supported in Phase 4A", category: "TrustScoreCalculator")
            return []
        }

        try await database.open()

        let sql = """
        SELECT id, event_type, engine_id, operation, severity, details, created_at
        FROM security_events
        WHERE engine_id = ? AND created_at >= ?
        AND event_type NOT IN ('trust_degraded', 'trust_promoted', 'trust_recalculation')
        ORDER BY created_at ASC
        """

        let rows = try await database.query(sql, parameters: [
            .text(subjectId),
            .text(sinceString)
        ])

        var events: [SecurityEvent] = []
        for row in rows {
            if let event = parseSecurityEvent(row: row) {
                events.append(event)
            }
        }

        return events
    }

    private func parseSecurityEvent(row: DatabaseRow) -> SecurityEvent? {
        guard let id = row.string(for: "id"),
              let type = row.string(for: "event_type"),
              let severity = row.string(for: "severity"),
              let createdAt = row.string(for: "created_at") else {
            return nil
        }

        let engineId = row.string(for: "engine_id")
        let operation = row.string(for: "operation")
        let detailsJSON = row.string(for: "details") ?? "{}"
        let details: SecurityEventDetails
        if let decoded = try? JSONDecoder().decode(SecurityEventDetails.self, from: Data(detailsJSON.utf8)) {
            details = decoded
        } else {
            details = SecurityEventDetails()
        }

        return SecurityEvent(
            id: id,
            type: type,
            engineId: engineId,
            operation: operation,
            severity: severity,
            details: details,
            createdAt: createdAt
        )
    }

    private func calculateWeightedSum(events: [SecurityEvent]) -> Int {
        var total: Int64 = 0  // Use 64-bit to avoid overflow

        for event in events {
            guard let eventType = TrustEventType(from: event.type) else {
                continue
            }

            let severity = SecurityEventSeverity(rawValue: event.severity) ?? .medium
            let weight = Int64(config.weight(for: eventType, severity: severity))

            // Calculate age in days
            let formatter = ISO8601DateFormatter()
            guard let eventDate = formatter.date(from: event.createdAt) else {
                continue
            }

            let ageDays = Calendar.current.dateComponents([.day], from: eventDate, to: Date()).day ?? 0
            let decayFactor = config.decayFactor(ageDays: ageDays)

            let weighted = Int64(Double(weight) * decayFactor)
            total += weighted

            logInfo("[TRUST][WEIGHT] Event \(event.type): weight=\(weight), age=\(ageDays)d, decay=\(String(format: "%.3f", decayFactor)), contribution=\(weighted)", category: "TrustScoreCalculator")
        }

        // Clamp to Int range
        return Int(max(Int64(Int.min), min(Int64(Int.max), total)))
    }

    private func calculateCleanWindowBonus(
        subjectId: String,
        subjectKind: TrustSubjectKind,
        currentScore: Int
    ) async throws -> Int {
        // Only apply bonus to subjects with good standing
        guard currentScore >= config.cleanWindowThreshold else {
            return 0
        }

        try await database.open()

        // Count days since last negative event
        let sql = """
        SELECT COUNT(DISTINCT DATE(created_at)) as clean_days
        FROM security_events
        WHERE engine_id = ?
        AND created_at >= DATE('now', '-\(config.cleanWindowDays) days')
        AND event_type IN ('capability_blocked', 'doctrine_violation', 'research_inadequate', 'unauthorized_access')
        """

        let rows = try await database.query(sql, parameters: [
            .text(subjectId),
            .int(config.cleanWindowDays)
        ])

        guard let row = rows.first,
              let cleanDays = row.int(for: "clean_days") else {
            return 0
        }

        // Calculate bonus: 1 point per clean day, capped
        let bonus = min(cleanDays, config.maxCleanWindowBonus)

        if bonus > 0 {
            logInfo("[TRUST][CLEAN] \(subjectId) has \(cleanDays) clean days, bonus=\(bonus)", category: "TrustScoreCalculator")
        }

        return bonus
    }

    private func updateTrustState(
        subjectId: String,
        subjectKind: TrustSubjectKind,
        newScore: Int,
        newTier: TrustTier,
        reason: String
    ) async throws {
        try await database.open()

        let timestamp = ISO8601DateFormatter().string(from: Date())

        // Check if subject exists
        let checkSql = "SELECT COUNT(*) as count FROM trust_state WHERE subject_id = ? AND subject_kind = ?"
        let checkRows = try await database.query(checkSql, parameters: [
            .text(subjectId),
            .text(subjectKind.rawValue)
        ])

        let count = checkRows.first?.int(for: "count") ?? 0

        if count > 0 {
            // Update existing
            let updateSql = """
            UPDATE trust_state
            SET trust_score = ?, current_trust_tier = ?, trust_calculated_at = ?,
                last_changed_at = ?, changed_by = 'trust_calculator', reason = ?
            WHERE subject_id = ? AND subject_kind = ?
            """

            _ = try await database.execute(updateSql, parameters: [
                .int(newScore),
                .text(newTier.rawValue),
                .text(timestamp),
                .text(timestamp),
                .text(reason),
                .text(subjectId),
                .text(subjectKind.rawValue)
            ])
        } else {
            // Insert new
            let insertSql = """
            INSERT INTO trust_state
            (subject_id, subject_kind, trust_score, current_trust_tier, trust_calculated_at,
             last_changed_at, changed_by, reason)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """

            _ = try await database.execute(insertSql, parameters: [
                .text(subjectId),
                .text(subjectKind.rawValue),
                .int(newScore),
                .text(newTier.rawValue),
                .text(timestamp),
                .text(timestamp),
                .text("trust_calculator"),
                .text(reason)
            ])
        }

        // Log trust change event
        let eventType: SecurityEventType = newScore > 50 ? .trustPromoted : .trustDegraded
        let details = SecurityEventDetails(reason: reason)
        await securityEvents.logEvent(
            type: eventType,
            severity: .medium,
            engineId: subjectId,
            operation: "trust_recalculation",
            details: details
        )
    }

    private func getAllSubjects() async throws -> [(id: String, kind: TrustSubjectKind)] {
        try await database.open()

        let sql = "SELECT subject_id, subject_kind FROM trust_state"
        let rows = try await database.query(sql)

        var subjects: [(id: String, kind: TrustSubjectKind)] = []
        for row in rows {
            guard let id = row.string(for: "subject_id"),
                  let kindString = row.string(for: "subject_kind"),
                  let kind = TrustSubjectKind(rawValue: kindString) else {
                continue
            }
            subjects.append((id, kind))
        }

        return subjects
    }

    private func clampScore(_ score: Int) -> Int {
        max(0, min(100, score))
    }
}

// MARK: - Supporting Types

private struct RecalcStats: Sendable, Codable {
    public var subjectsProcessed: Int = 0
    public var subjectsChanged: Int = 0
    public var errors: Int = 0
}
