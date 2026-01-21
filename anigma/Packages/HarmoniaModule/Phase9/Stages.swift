//
//  Stages.swift
//  HarmoniaModule
//
//  Stage definitions and structures for Phase 9.1. 8-stage loop.
//

import Foundation
import AnigmaPrimitives

/// Stage identifiers for the Phase 9.1 deterministic loop
public enum Stage: Int, Codable, Sendable {
    case stage0 = 0
    case stage1 = 1
    case stage2 = 2
    case stage3 = 3
    case stage4 = 4
    case stage5 = 5
    case stage6 = 6
    case stage7 = 7

    public var stageNumber: Int { rawValue }

    public var stageName: String {
        switch self {
        case .stage0: return "Target Enumeration"
        case .stage1: return "Trace Normalization"
        case .stage2: return "Metrics Computation"
        case .stage3: return "Target Selection"
        case .stage4: return "Candidate Generation"
        case .stage5: return "Validation & Policy Evaluation"
        case .stage6: return "State Transition Commit"
        case .stage7: return "Replay Verification"
        }
    }

    /// Get the maximum stage number
    public static let maxStageNumber = Stage.stage7.rawValue

    /// Convert from integer to Stage
    public static func from(_ number: Int) -> Stage? {
        Stage(rawValue: number)
    }

    /// Convert from string to Stage
    public static func from(_ string: String) -> Stage? {
        switch string.lowercased() {
        case "stage0", "target enumeration": return .stage0
        case "stage1", "trace normalization": return .stage1
        case "stage2", "metrics computation": return .stage2
        case "stage3", "target selection": return .stage3
        case "stage4", "candidate generation": return .stage4
        case "stage5", "validation & policy evaluation": return .stage5
        case "stage6", "state transition commit": return .stage6
        case "stage7", "replay verification": return .stage7
        default: return nil
        }
    }
}

/// Results from Stage 0 Target Enumeration
public struct EnumerationResults: Codable, Sendable {
    public let enumeratedTargets: [EnumeratedTarget]
    public let targetCount: Int
    public let scoringPolicyHash: String
    public let ranking: [Int] // Indices in the enumerated list
    public let hasDuplicates: Bool
    public let policyHash: String // Hash of all policy inputs used

    public init(
        enumeratedTargets: [EnumeratedTarget],
        targetCount: Int,
        scoringPolicyHash: String,
        ranking: [Int],
        hasDuplicates: Bool,
        policyHash: String
    ) {
        self.enumeratedTargets = enumeratedTargets
        self.targetCount = targetCount
        self.scoringPolicyHash = scoringPolicyHash
        self.ranking = ranking
        self.hasDuplicates = hasDuplicates
        self.policyHash = policyHash
    }

    /// Get top-ranked target
    public var topTarget: EnumeratedTarget? {
        guard !enumeratedTargets.isEmpty, let topIndex = ranking.first else { return nil }
        let target = enumeratedTargets[topIndex]
        return target.rank == 1 ? target : nil
    }

    /// Check if targets were limited by stop condition
    public var wasLimited: Bool {
        return targetCount < enumeratedTargets.count
    }
}

/// Verification result for Phase 9.1 multi-target runs
public struct Phase9_1VerificationResult: Codable, Sendable {
    public let deterministic: Bool
    public let targetResults: [TargetResult]
    public let evidenceId: String
    public let totalVerifiedBytes: Int
    public let targetCount: Int
    public let failedStage: Int?
    public let firstDivergentStage: Int?
    public let firstDivergentTargetId: String?

    public init(
        deterministic: Bool,
        targetResults: [TargetResult],
        evidenceId: String,
        totalVerifiedBytes: Int,
        targetCount: Int,
        failedStage: Int?,
        firstDivergentStage: Int?,
        firstDivergentTargetId: String?
    ) {
        self.deterministic = deterministic
        self.targetResults = targetResults
        self.evidenceId = evidenceId
        self.totalVerifiedBytes = totalVerifiedBytes
        self.targetCount = targetCount
        self.failedStage = failedStage
        self.firstDivergentStage = firstDivergentStage
        self.firstDivergentTargetId = firstDivergentTargetId
    }

    /// Check if specific target diverged
    public func isTargetDivergent(targetId: String) -> Bool {
        return targetResults.contains { $0.targetId == targetId && $0.isDiverged }
    }

    /// Get specific target's verification result
    public func resultForTarget(_ targetId: String) -> TargetResult? {
        return targetResults.first { $0.targetId == targetId }
    }

    /// Check if all targets passed verification
    public var allTargetsPassing: Bool {
        return targetResults.allSatisfy { !$0.isDiverged }
    }
}

/// Verification result for a specific target
public struct TargetResult: Codable, Sendable {
    public let targetId: String
    public let isDiverged: Bool
    public let divergenceStage: Int?
    public let divergenceOffset: Int?
    public let expectedContext: Data?
    public let actualContext: Data?
    public let policyHash: String
    public let snapshotHash: String

    public var isPassed: Bool { !isDiverged }
}

/// Extension to add optional features after Stage 0
extension Phase9LoopKernel {

    /// Create enumeration results as a stage artifact
    public func createEnumerationStageArtifact(
        enumerationResults: EnumerationResults,
        stageNumber: Int,
        evidenceId: String,
        workspaceSnapshotHash: String
    ) throws -> StageArtifact {

        // Create the artifact payload
        let payload = enumerationResults
        let encoder = CanonicalJSONEncoder()
        let hasher = BLAKE3Hasher()
        let stage = StageBoundary(rawValue: "stage\(stageNumber)") ?? .stage0

        return try StageArtifact.from(
            payload,
            stage: stage,
            stageNumber: stageNumber,
            evidenceId: evidenceId,
            workspaceSnapshotHash: workspaceSnapshotHash,
            encoder: encoder,
            hasher: hasher
        )
    }
}
