import Foundation
import ContractsCore

/// Workflow for retention sweep with governed deletion
public struct RetentionSweepWorkflow {
    private let retentionSystem: RetentionSystem

    public init(retentionSystem: RetentionSystem) {
        self.retentionSystem = retentionSystem
    }

    public func execute(
        policyID: String,
        cutoffDays: Int,
        targetTypes: Set<String>
    ) async throws -> DeletionManifest {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -cutoffDays,
            to: Date()
        ) ?? Date()

        return try await retentionSystem.applyRetentionSweep(
            policyID: policyID,
            cutoffDate: cutoffDate,
            targetTypes: targetTypes
        )
    }
}

/// Workflow for redaction with governed content mutation
public struct RedactionWorkflow {
    private let redactionSystem: RedactionSystem

    public init(redactionSystem: RedactionSystem) {
        self.redactionSystem = redactionSystem
    }

    public func execute(
        rulesetHash: String,
        rules: [RedactionRule],
        targets: [RedactionTarget]
    ) async throws -> RedactionManifest {
        return try await redactionSystem.applyRedactionRules(
            rulesetHash: rulesetHash,
            rules: rules,
            targets: targets
        )
    }
}

/// Workflow for compaction with integrity preservation
public struct CompactionWorkflow {
    private let compactionSystem: CompactionSystem

    public init(compactionSystem: CompactionSystem) {
        self.compactionSystem = compactionSystem
    }

    public func execute() async throws -> CompactionReport {
        return try await compactionSystem.runCompaction()
    }
}
