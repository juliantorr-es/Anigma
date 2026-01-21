//
//  TrustScoringConfig.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Configuration for dynamic trust scoring system.
//  Phase 4A: Conservative defaults to be tuned after Swift 6 experiment.
//

import Foundation
import AnigmaCore
import SecurityEventsManager
import HarmoniaModule

/// Canonical event type strings for trust scoring.
/// Centralized to avoid typos between config and event emission.
public enum TrustEventType: String, Sendable, CaseIterable {
    case capabilityBlocked = "capability_blocked"
    case capabilityGranted = "capability_granted"
    case doctrineViolation = "doctrine_violation"
    case researchInadequate = "research_inadequate"
    case capabilityEscalation = "capability_escalation"
    case trustDegraded = "trust_degraded"
    case trustPromoted = "trust_promoted"

    /// Convert from SecurityEventType string.
    public init?(from eventType: String) {
        self.init(rawValue: eventType)
    }
}

/// Configuration for dynamic trust scoring.
public struct TrustScoringConfig: Sendable {

    // MARK: - Tier Bands (0-100)

    /// Maximum score for bronze tier (0-24).
    public let bronzeMax: Int = 24

    /// Maximum score for silver tier (25-59).
    public let silverMax: Int = 59

    /// Maximum score for gold tier (60-84).
    public let goldMax: Int = 84
    // platinum: 85-100

    /// Convert score to trust tier.
    public func scoreToTier(_ score: Int) -> TrustTier {
        let clampedScore = max(0, min(100, score))
        switch clampedScore {
        case 0...bronzeMax: return .bronze
        case (bronzeMax + 1)...silverMax: return .silver
        case (silverMax + 1)...goldMax: return .gold
        default: return .platinum
        }
    }

    /// Convert tier to approximate score (for migration).
    public func tierToScore(_ tier: TrustTier) -> Int {
        switch tier {
        case .bronze: return 30
        case .silver: return 50
        case .gold: return 60
        case .platinum: return 85
        }
    }

    // MARK: - Default Baseline Scores

    /// Default trust scores per subject kind.
    public let defaultScores: [TrustSubjectKind: Int] = [
        .engineType: 60,      // migration/research engines (gold)
        .engineInstance: 50,  // individual engine instances (silver)
        .project: 50,         // projects (silver)
        .user: 50,            // users (silver)
        .system: 100          // system components (platinum)
    ]

    /// Get default score for a subject kind.
    public func defaultScore(for kind: TrustSubjectKind) -> Int {
        return defaultScores[kind] ?? 50  // Conservative silver default
    }

    // MARK: - Event Penalty/Reward Weights

    /// Event weights by type and severity.
    /// Negative = penalty, positive = reward.
    public let eventWeights: [TrustEventType: [SecurityEventSeverity: Int]] = [
        .capabilityBlocked: [
            .critical: -20,
            .high: -10,
            .medium: -5,
            .low: -2
        ],
        .doctrineViolation: [
            .critical: -15,
            .high: -10,
            .medium: -5,
            .low: -1
        ],
        .researchInadequate: [
            .medium: -3,
            .low: -1
        ],
        .capabilityGranted: [
            .low: 1  // Max +1/day
        ],
        .capabilityEscalation: [
            .medium: -5,
            .low: -2
        ]
        // Note: trustDegraded/trustPromoted are results, not inputs
    ]

    /// Get weight for an event type and severity.
    public func weight(for eventType: TrustEventType, severity: SecurityEventSeverity) -> Int {
        return eventWeights[eventType]?[severity] ?? 0
    }

    // MARK: - Temporal Decay

    /// Days after which decay starts.
    public let decayStartDays: Int = 3

    /// Decay rate per day (10%).
    public let decayRatePerDay: Double = 0.1

    /// Maximum scoring window in days.
    public let scoringWindowDays: Int = 30

    /// Calculate decay factor for an event age in days.
    public func decayFactor(ageDays: Int) -> Double {
        guard ageDays > decayStartDays else { return 1.0 }
        let decayDays = ageDays - decayStartDays
        return pow(1.0 - decayRatePerDay, Double(decayDays))
    }

    // MARK: - Recovery Parameters

    /// Clean window in hours for recovery bonus.
    public let cleanWindowHours: Int = 24

    /// Minimum score required to earn the clean window bonus.
    public let cleanWindowThreshold: Int = 60

    /// Days to look back for the clean window.
    public let cleanWindowDays: Int = 7

    /// Bonus points for clean window.
    public let cleanWindowBonus: Int = 1

    /// Maximum clean window bonus (caps consistent with scoring rules).
    public let maxCleanWindowBonus: Int = 5

    /// Maximum recovery per week.
    public let maxWeeklyRecovery: Int = 5

    /// Maximum positive adjustment per day.
    public let maxDailyPositive: Int = 1

    /// Minimum time between adjustments for same subject (seconds).
    public let adjustmentCooldownSeconds: Int = 300  // 5 minutes

    // MARK: - Critical Event Handling

    /// Severities that trigger immediate processing.
    public let immediateSeverities: [SecurityEventSeverity] = [.critical, .high]

    /// Maximum penalty per immediate adjustment.
    public let maxImmediatePenalty: Int = 20

    /// Cooldown between immediate adjustments (seconds).
    public let immediateCooldownSeconds: Int = 60  // 1 minute

    // MARK: - Governance Mode Adjustments

    /// Trust score adjustments per governance mode.
    public func modeAdjustment(for mode: GovernanceMode) -> Int {
        switch mode {
        case .personal: return 0      // No adjustment
        case .governed: return -5     // Slightly more conservative
        case .paranoid: return -10    // Significantly more conservative
        }
    }

    // MARK: - Validation

    /// Validate configuration consistency.
    public func validate() throws {
        // Ensure tier bands are ordered
        guard bronzeMax < silverMax else {
            throw TrustScoringError.invalidConfig("bronzeMax (\(bronzeMax)) must be < silverMax (\(silverMax))")
        }
        guard silverMax < goldMax else {
            throw TrustScoringError.invalidConfig("silverMax (\(silverMax)) must be < goldMax (\(goldMax))")
        }
        guard goldMax < 100 else {
            throw TrustScoringError.invalidConfig("goldMax (\(goldMax)) must be < 100")
        }

        // Ensure weights are reasonable
        for (eventType, severityWeights) in eventWeights {
            for (severity, weight) in severityWeights {
                if weight < -50 || weight > 50 {
                    throw TrustScoringError.invalidConfig("Weight \(weight) for \(eventType).\(severity) outside reasonable range [-50, 50]")
                }
            }
        }

        // Ensure decay rate is valid
        guard decayRatePerDay > 0 && decayRatePerDay < 1.0 else {
            throw TrustScoringError.invalidConfig("decayRatePerDay (\(decayRatePerDay)) must be in (0, 1)")
        }
    }
}

// MARK: - Supporting Types

public enum TrustScoringError: Error, LocalizedError {
    case invalidConfig(String)
    case calculationError(String)
    case databaseError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfig(let reason):
            return "Invalid trust scoring configuration: \(reason)"
        case .calculationError(let reason):
            return "Trust calculation error: \(reason)"
        case .databaseError(let reason):
            return "Database error in trust scoring: \(reason)"
        }
    }
}

// MARK: - Default Instance

extension TrustScoringConfig {
    /// Default configuration instance.
    public static let `default` = TrustScoringConfig()
}
