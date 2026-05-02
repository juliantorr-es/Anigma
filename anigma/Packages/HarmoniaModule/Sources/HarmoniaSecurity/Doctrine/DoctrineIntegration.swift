//
//  DoctrineIntegration.swift
//  HarmoniaModule
//
//  Integration layer for doctrine guards in migration engines and AST rules.
//

import Foundation
import HarmoniaCore
import AnigmaPrimitives
import os.log
@preconcurrency import Foundation
import DoctrineCore
import AnigmaCore

/// Service to convert doctrine violations to debt tasks.
private let log = Logger(subsystem: "com.anigma.harmonia", category: "actor")
public actor DoctrineDebtTaskService {
    fileprivate let violationStore: DoctrineCore.DoctrineViolationStore

    public init(violationStore: DoctrineCore.DoctrineViolationStore = try! DoctrineCore.DoctrineViolationStore()) {
        self.violationStore = violationStore
    }

    /// Convert unresolved doctrine violations to debt tasks.
    public func convertViolationsToDebtTasks() async throws -> [DoctrineDebtTask] {
        let violations = try violationStore.getUnresolvedViolations()
        return violations.compactMap { DoctrineDebtTask.fromViolation($0) }
    }

    /// Get blocking debt tasks (critical violations).
    public func getBlockingDebtTasks() async throws -> [DoctrineDebtTask] {
        let tasks = try await convertViolationsToDebtTasks()
        return tasks.filter { $0.blocking }
    }

    /// Update task status.
    public func updateTaskStatus(_ taskId: UUID, newStatus: DoctrineDebtTask.TaskStatus) async throws {
        // In practice, this would update the task in a database
        // For now, just log the update
        log.info("Updated doctrine debt task \(taskId) to status \(newStatus.rawValue)")
    }

    /// Get doctrine health score.
    public func getDoctrineHealthScore() async throws -> Double {
        let violations = try violationStore.getUnresolvedViolations()

        // Calculate score based on severity and count
        var score = 100.0

        for violation in violations {
            switch violation.severity {
            case DoctrineCore.DoctrineSeverity.critical:
                score -= 10.0
            case DoctrineCore.DoctrineSeverity.error:
                score -= 5.0
            case DoctrineCore.DoctrineSeverity.warning:
                score -= 2.0
            case .info:
                score -= 0.5
            }
        }

        return max(0.0, score)
    }

    /// Get doctrine statistics.
    public func getDoctrineStatistics() async throws -> [String: Sendable] {
        let violations = try violationStore.getUnresolvedViolations()
        let byDomain = Dictionary(grouping: violations) {
            $0.ruleId.split(separator: "_").first.map(String.init) ?? "unknown"
        }.mapValues { $0.count }

        return [
            "total_violations": violations.count,
            "critical_violations": violations.filter { $0.severity == DoctrineCore.DoctrineSeverity.critical }.count,
            "error_violations": violations.filter { $0.severity == DoctrineCore.DoctrineSeverity.error }.count,
            "warning_violations": violations.filter { $0.severity == DoctrineCore.DoctrineSeverity.warning }.count,
            "by_domain": byDomain
        ]
    }

    /// Get unresolved violations for external consumers.
    public func getUnresolvedViolations() throws -> [DoctrineViolation] {
        try violationStore.getUnresolvedViolations()
    }
}
