//
//  ToolCallLoopBreaker.swift
//  HarmoniaModule
//
//  Circuit breaker for tool call loops.
//  Prevents agents from spamming same failing tool call forever.
//

import AnigmaPrimitives
import DatabaseCore
@preconcurrency import Foundation

/// Circuit breaker for tool call loops.
/// Detects repeated tool calls within sliding time windows and blocks infinite loops.
public actor ToolCallLoopBreaker {
    // Configuration
    private let maxRepetitions: Int = 2  // Block after 2 repeats
    private let timeWindow: TimeInterval = 60.0  // 1 minute window
    private let cooldownDuration: TimeInterval = 300.0  // 5 minute cooldown

    // State tracking
    private var callHistory: [String: [Date]] = [:]
    private var blockingState: [String: BlockingInfo] = [:]
    private var totalStats = LoopBreakerStats(
        totalCalls: 0,
        blockedCalls: 0,
        warningsIssued: 0,
        uniqueTools: [],
        recentCalls: []
    )

    // Evidence recording (optional)
    private var evidenceRecorder: (any LoopEvidenceRecorder)?

    /// Information about a blocked call
    private struct BlockingInfo: Sendable {
        let blockedAt: Date
        let reason: String
        let recoveryStrategy: RecoveryStrategy
    }

    public init(evidenceRecorder: (any LoopEvidenceRecorder)? = nil) {
        self.evidenceRecorder = evidenceRecorder
    }

    /// Check if tool call should be allowed based on request.
    public func checkCall(request: ToolCallRequest, toolCallId: String) async -> CallCheckResult {
        let now = Date()
        let fingerprint = request.fingerprint

        // Check blocking state
        if let blockingInfo = blockingState[fingerprint] {
            let timeSinceBlocked = now.timeIntervalSince(blockingInfo.blockedAt)
            if timeSinceBlocked < cooldownDuration {
                // Still in cooldown
                return .blocked(
                    reason: blockingInfo.reason,
                    requiredRecovery: blockingInfo.recoveryStrategy
                )
            } else {
                // Cooldown expired, clear block
                blockingState.removeValue(forKey: fingerprint)
            }
        }

        // Check call history
        var timestamps = callHistory[fingerprint, default: []]
        timestamps = timestamps.filter { now.timeIntervalSince($0) <= timeWindow }

        if timestamps.count >= maxRepetitions {
            // Block this call
            let blockingInfo = BlockingInfo(
                blockedAt: now,
                reason: "Tool call repeated \(timestamps.count) times within \(timeWindow)s",
                recoveryStrategy: determineRecoveryStrategy(for: request)
            )
            blockingState[fingerprint] = blockingInfo

            // Record evidence for blocked call
            try? await evidenceRecorder?.recordLoopEvent(
                toolCallId: toolCallId,
                event: .callBlocked,
                fingerprint: fingerprint,
                context: [
                    "timestamp": now,
                    "attempt_count": timestamps.count,
                    "reason": blockingInfo.reason,
                    "recovery_strategy": blockingInfo.recoveryStrategy.rawValue
                ]
            )

            return .blocked(
                reason: blockingInfo.reason,
                requiredRecovery: blockingInfo.recoveryStrategy
            )
        }

        // Add current call to history
        timestamps.append(now)
        callHistory[fingerprint] = timestamps

        // Record evidence for allowed call
        try? await evidenceRecorder?.recordLoopEvent(
            toolCallId: toolCallId,
            event: .callAllowed,
            fingerprint: fingerprint,
            context: ["timestamp": now, "attempt_count": timestamps.count]
        )

        // Issue warning on second attempt
        if timestamps.count == 2 {
            try? await evidenceRecorder?.recordLoopEvent(
                toolCallId: toolCallId,
                event: .warningIssued,
                fingerprint: fingerprint,
                context: ["timestamp": now, "attempt_count": timestamps.count]
            )
            return .warning(attemptNumber: 2)
        }

        return .allowed
    }

    /// Determine recovery strategy based on tool type.
    private func determineRecoveryStrategy(for request: ToolCallRequest) -> RecoveryStrategy {
        switch request.toolName {
        case "apply_patch":
            return .requireUnifiedDiff
        case "read_file":
            return .requireFreshReadDelta
        case "git_diff":
            return .requireFreshReadDelta
        case "swift_build", "swift_test":
            return .escalateToHuman
        default:
            return .escalateToHuman
        }
    }

    /// Reset call history for a specific session.
    public func resetSession(sessionId: String) async {
        let keysToRemove = callHistory.keys.filter { $0.contains(sessionId) }
        for key in keysToRemove {
            callHistory.removeValue(forKey: key)
            blockingState.removeValue(forKey: key)
        }
    }

    /// Clear all history (for testing).
    public func clearAll() async {
        callHistory.removeAll()
        blockingState.removeAll()
    }

    /// Get statistics for monitoring.
    public func getStats() async -> LoopBreakerStats {
        return totalStats
    }
}

/// Result of loop breaker check.
public enum CallCheckResult: Sendable {
    case allowed
    case blocked(reason: String, requiredRecovery: RecoveryStrategy)
    case warning(attemptNumber: Int)
}
