//
//  DoctrineViolationLogger.swift
//  GovernedMigrationCore
//
//  [Brief description of file purpose]
//

#if GOVERNED_CORE

import Foundation
import DoctrineCore
import AnigmaPrimitives
import ContractsCore

public protocol DoctrineViolationLogger: Sendable {
    func record(_ violation: DoctrineViolation) async -> (security: SecurityEvent, trust: TrustChange)
}

/// Minimal, governed logger that maps doctrine violations into the canonical
/// `SecurityEvent` and `TrustChange` types used by GovernedMigrationCore.
/// Side effects (persistence, scoring) are intentionally out of scope here
/// to keep GOVERNED_CORE free of placeholder manager types.
public actor GovernedDoctrineViolationLogger: DoctrineViolationLogger {
    public init() {}

    public func record(_ violation: DoctrineViolation) async -> (security: SecurityEvent, trust: TrustChange) {
        let securityEvent = createSecurityEvent(from: violation)
        let trustChange = createTrustChange(from: violation)
        return (security: securityEvent, trust: trustChange)
    }

    private func createSecurityEvent(from violation: DoctrineViolation) -> SecurityEvent {
        SecurityEvent(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            eventType: ContractsCore.AuditEventType.custom,
            engineId: "doctrine_guard",
            operation: violation.ruleId,
            severity: mapSeverityToSecurityEvent(violation.severity),
            details: violation.message,
            metadata: ["original_event_type": "doctrine_violation"]
        )
    }

    private func createTrustChange(from violation: DoctrineViolation) -> TrustChange {
        let delta = mapSeverityToTrustImpact(violation.severity)
        let oldScore = 0
        let newScore = max(0, oldScore + delta)
        return TrustChange(
            subjectId: "doctrine_guard",
            subjectKind: "engine_instance",
            oldScore: oldScore,
            newScore: newScore,
            delta: delta,
            reason: "Doctrine violation \(violation.ruleId)"
        )
    }

    private func mapSeverityToSecurityEvent(_ severity: DoctrineSeverity) -> String {
        switch severity {
        case .critical: return "critical"
        case .error: return "high"
        case .warning: return "medium"
        case .info: return "low"
        }
    }

    private func mapSeverityToTrustImpact(_ severity: DoctrineSeverity) -> Int {
        switch severity {
        case .critical: return -10
        case .error: return -5
        case .warning: return -2
        case .info: return -1
        }
    }
}

#endif
