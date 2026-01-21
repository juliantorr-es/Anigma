//
//  InRunDeterminismValidator.swift
//  HarmoniaModule
//
//  Live determinism validation during Phase 9.1 loop execution.
//  Detects non-deterministic behavior in target enumeration, scoring, and selection.
//  Stops execution immediately if any stage violates the determinism contract.
//

import Foundation

/// Live determinism validator for Phase 9.1 loop execution.
/// Validates that target enumeration, scoring, and selection produce deterministic results.
public actor InRunDeterminismValidator {

    private var recordedEnumerations: [String: EnumerationSnapshot] = [:]
    private var recordedScores: [String: ScoringSnapshot] = [:]
    private var recordedSelections: [String: SelectionSnapshot] = [:]
    private var violations: [DeterminismViolation] = []

    public init() {}

    /// Snapshot of enumeration results for determinism validation.
    public struct EnumerationSnapshot: Sendable {
        public let scope: String
        public let targetIds: [String]
        public let targetCount: Int
        public let scoringPolicyHash: String
        public let digest: String
        public let timestamp: Int64

        public init(
            scope: String,
            targets: [EnumeratedTarget],
            scoringPolicyHash: String,
            digest: String,
            timestamp: Int64
        ) {
            self.scope = scope
            self.targetIds = targets.map { $0.targetId }
            self.targetCount = targets.count
            self.scoringPolicyHash = scoringPolicyHash
            self.digest = digest
            self.timestamp = timestamp
        }
    }

    /// Snapshot of scoring results for determinism validation.
    public struct ScoringSnapshot: Sendable {
        public let targetId: String
        public let score: Int
        public let rank: Int
        public let policyHash: String
        public let timestamp: Int64
    }

    /// Snapshot of selection results for determinism validation.
    public struct SelectionSnapshot: Sendable {
        public let selectedTargetId: String
        public let rank: Int
        public let rationale: String
        public let timestamp: Int64
    }

    /// Record an enumeration for determinism validation.
    public func recordEnumeration(
        scope: String,
        targets: [EnumeratedTarget],
        scoringPolicyHash: String,
        digest: String
    ) throws {
        let snapshot = EnumerationSnapshot(
            scope: scope,
            targets: targets,
            scoringPolicyHash: scoringPolicyHash,
            digest: digest,
            timestamp: Int64(Date().timeIntervalSince1970)
        )

        // Check for previous enumeration with same scope
        if let previous = recordedEnumerations[scope] {
            // Compare for determinism
            if previous.digest != snapshot.digest {
                let violation = DeterminismViolation(
                    stage: "enumeration",
                    scope: scope,
                    expected: previous.digest,
                    actual: snapshot.digest,
                    reason: "Enumeration digest mismatch for scope \(scope)"
                )
                violations.append(violation)
                throw DeterminismError.enumerationDivergence(violation)
            }

            // Also validate target order and count
            if previous.targetIds != snapshot.targetIds {
                let violation = DeterminismViolation(
                    stage: "enumeration",
                    scope: scope,
                    expected: "\(previous.targetIds)",
                    actual: "\(snapshot.targetIds)",
                    reason: "Target ordering divergence for scope \(scope)"
                )
                violations.append(violation)
                throw DeterminismError.targetOrderingDivergence(violation)
            }
        }

        recordedEnumerations[scope] = snapshot
    }

    /// Record a scoring result for determinism validation.
    public func recordScore(
        targetId: String,
        score: Int,
        rank: Int,
        policyHash: String
    ) throws {
        let snapshot = ScoringSnapshot(
            targetId: targetId,
            score: score,
            rank: rank,
            policyHash: policyHash,
            timestamp: Int64(Date().timeIntervalSince1970)
        )

        // Check for previous score with same target
        if let previous = recordedScores[targetId] {
            // Scores must be identical
            if previous.score != snapshot.score || previous.rank != snapshot.rank {
                let violation = DeterminismViolation(
                    stage: "scoring",
                    scope: targetId,
                    expected: "score:\(previous.score) rank:\(previous.rank)",
                    actual: "score:\(snapshot.score) rank:\(snapshot.rank)",
                    reason: "Score divergence for target \(targetId)"
                )
                violations.append(violation)
                throw DeterminismError.scoringDivergence(violation)
            }
        }

        recordedScores[targetId] = snapshot
    }

    /// Record a selection for determinism validation.
    public func recordSelection(
        selectedTargetId: String,
        rank: Int,
        rationale: String
    ) throws {
        let snapshot = SelectionSnapshot(
            selectedTargetId: selectedTargetId,
            rank: rank,
            rationale: rationale,
            timestamp: Int64(Date().timeIntervalSince1970)
        )

        // Selection must always be rank 1 (top target)
        guard rank == 1 else {
            let violation = DeterminismViolation(
                stage: "selection",
                scope: "rank",
                expected: "1",
                actual: "\(rank)",
                reason: "Selected target must have rank 1, got \(rank)"
            )
            violations.append(violation)
            throw DeterminismError.selectionViolation(violation)
        }

        // Check for previous selection - must be identical
        if let previous = recordedSelections["current"] {
            if previous.selectedTargetId != snapshot.selectedTargetId {
                let violation = DeterminismViolation(
                    stage: "selection",
                    scope: "target_id",
                    expected: previous.selectedTargetId,
                    actual: snapshot.selectedTargetId,
                    reason: "Selected target divergence"
                )
                violations.append(violation)
                throw DeterminismError.selectionDivergence(violation)
            }
        }

        recordedSelections["current"] = snapshot
    }

    /// Get all recorded violations.
    public func getViolations() -> [DeterminismViolation] {
        return violations
    }

    /// Check if any violations have been recorded.
    public var hasViolations: Bool {
        return !violations.isEmpty
    }

    /// Clear all recorded data and violations.
    public func reset() {
        recordedEnumerations.removeAll()
        recordedScores.removeAll()
        recordedSelections.removeAll()
        violations.removeAll()
    }
}

/// Determinism violation record.
public struct DeterminismViolation: Sendable, Codable {
    public let stage: String
    public let scope: String
    public let expected: String
    public let actual: String
    public let reason: String
    public let timestamp: Int64

    public init(
        stage: String,
        scope: String,
        expected: String,
        actual: String,
        reason: String
    ) {
        self.stage = stage
        self.scope = scope
        self.expected = expected
        self.actual = actual
        self.reason = reason
        self.timestamp = Int64(Date().timeIntervalSince1970)
    }
}

/// Errors in determinism validation.
public enum DeterminismError: Error, LocalizedError {
    case enumerationDivergence(DeterminismViolation)
    case targetOrderingDivergence(DeterminismViolation)
    case scoringDivergence(DeterminismViolation)
    case selectionViolation(DeterminismViolation)
    case selectionDivergence(DeterminismViolation)

    public var localizedDescription: String? {
        switch self {
        case .enumerationDivergence(let violation):
            return "\(violation.reason): expected \(violation.expected), got \(violation.actual)"
        case .targetOrderingDivergence(let violation):
            return "Target ordering divergence: \(violation.reason)"
        case .scoringDivergence(let violation):
            return "Scoring divergence: \(violation.reason)"
        case .selectionViolation(let violation):
            return "Selection constraint violated: \(violation.reason)"
        case .selectionDivergence(let violation):
            return "Selection divergence: \(violation.reason)"
        }
    }
}

/// Single-commit invariant enforcer for Phase 9.1.
public actor SingleCommitInvariantEnforcer {

    private var commitsAttempted: Int = 0
    private let maxCommitsPerRun: Int = 1

    public init() {}

    /// Try to record a commit attempt.
    /// Throws if already attempted to commit in this run.
    public func attemptCommit(reason: String) throws {
        commitsAttempted += 1
        guard commitsAttempted <= maxCommitsPerRun else {
            throw SingleCommitError.multipleCommitAttempts(
                attempted: commitsAttempted,
                reason: reason
            )
        }
    }

    /// Get the number of commits attempted in this run.
    public var commitCount: Int {
        return commitsAttempted
    }

    /// Reset for new run.
    public func reset() {
        commitsAttempted = 0
    }
}

/// Errors in single-commit invariant enforcement.
public enum SingleCommitError: Error, LocalizedError {
    case multipleCommitAttempts(attempted: Int, reason: String)

    public var localizedDescription: String? {
        switch self {
        case .multipleCommitAttempts(let count, let reason):
            return
                "Attempted \(count) commits in single run (reason: \(reason)); only 1 commit allowed"
        }
    }
}
