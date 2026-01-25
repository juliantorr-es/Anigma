//
//  VerificationTypes.swift
//  HarmoniaModule
//
//  Core verification types for Phase 9.0 replay verifier.
//  Defines deterministic inputs, verification results, and failure reporting.
//

@preconcurrency import Foundation
import AnigmaPrimitives

/// Canonical stage identifiers for Phase 9 boundary artifacts.
public enum StageBoundary: String, Codable, Sendable {
    case stage0, stage1, stage2, stage3, stage4, stage5, stage6, stage7
}

/// Deterministic inputs required for replay verification.
/// All inputs must be exactly reproduced for verification to pass.
public struct VerificationInputs: Sendable, Codable {
    public let eventLogBytes: Data
    public let workspaceSnapshotHash: String
    public let policyPackHash: String
    public let normalizerVersion: String
    public let toolchainFingerprint: String
    public let sessionSeed: String

    // Phase 9.2: Concurrency and policy version as pinned inputs
    public let concurrencyLevel: Int
    public let scoringPolicyVersion: String
    public let abTestAssignment: String

    public init(
        eventLogBytes: Data,
        workspaceSnapshotHash: String,
        policyPackHash: String,
        normalizerVersion: String,
        toolchainFingerprint: String,
        sessionSeed: String
    ) {
        self.eventLogBytes = eventLogBytes
        self.workspaceSnapshotHash = workspaceSnapshotHash
        self.policyPackHash = policyPackHash
        self.normalizerVersion = normalizerVersion
        self.toolchainFingerprint = toolchainFingerprint
        self.sessionSeed = sessionSeed

        // Phase 9.2: Default values for backward compatibility
        self.concurrencyLevel = 1  // Sequential by default
        self.scoringPolicyVersion = "v1.0.0"
        self.abTestAssignment = "control"
    }

    public init(
        eventLogBytes: Data,
        workspaceSnapshotHash: String,
        policyPackHash: String,
        normalizerVersion: String,
        toolchainFingerprint: String,
        sessionSeed: String,
        concurrencyLevel: Int,
        scoringPolicyVersion: String,
        abTestAssignment: String
    ) {
        self.eventLogBytes = eventLogBytes
        self.workspaceSnapshotHash = workspaceSnapshotHash
        self.policyPackHash = policyPackHash
        self.normalizerVersion = normalizerVersion
        self.toolchainFingerprint = toolchainFingerprint
        self.sessionSeed = sessionSeed

        self.concurrencyLevel = concurrencyLevel
        self.scoringPolicyVersion = scoringPolicyVersion
        self.abTestAssignment = abTestAssignment
    }
}

/// Verification result from replay verification.
public enum ReplayVerificationOutcome: Sendable, Equatable {
    case pass(ReplayVerifiedArtifact)
    case fail(ReplayFailureReport)
}

/// Artifact representing successful replay verification.
public struct ReplayVerifiedArtifact: Sendable, Equatable {
    public let verificationId: String
    public let stageCount: Int
    public let totalVerifiedBytes: Int
    public let timestamp: Int64 // Sequence number, not wall-clock time

    public init(
        verificationId: String,
        stageCount: Int,
        totalVerifiedBytes: Int,
        timestamp: Int64
    ) {
        self.verificationId = verificationId
        self.stageCount = stageCount
        self.totalVerifiedBytes = totalVerifiedBytes
        self.timestamp = timestamp
    }
}

/// Detailed failure report when replay verification fails.
/// Provides surgical identification of where determinism broke.
public struct ReplayFailureReport: Sendable, Equatable {
    public let stage: String
    public let artifactKind: String
    public let artifactId: String
    public let eventIndex: Int
    public let classification: String
    public let firstDiffOffset: Int
    public let expectedContext: Data
    public let actualContext: Data
    public let expectedDigest: String
    public let actualDigest: String

    public init(
        stage: String,
        artifactKind: String,
        artifactId: String,
        eventIndex: Int,
        classification: String,
        firstDiffOffset: Int,
        expectedContext: Data,
        actualContext: Data,
        expectedDigest: String,
        actualDigest: String
    ) {
        self.stage = stage
        self.artifactKind = artifactKind
        self.artifactId = artifactId
        self.eventIndex = eventIndex
        self.classification = classification
        self.firstDiffOffset = firstDiffOffset
        self.expectedContext = expectedContext
        self.actualContext = actualContext
        self.expectedDigest = expectedDigest
        self.actualDigest = actualDigest
    }

    /// Create a precheck failure report for input mismatch
    public static func precheckFailure(reason: String) -> ReplayFailureReport {
        return ReplayFailureReport(
            stage: "precheck",
            artifactKind: "PinnedInputs",
            artifactId: "pinned-inputs",
            eventIndex: 0,
            classification: "input set mismatch",
            firstDiffOffset: 0,
            expectedContext: Data(),
            actualContext: Data(),
            expectedDigest: "",
            actualDigest: ""
        )
    }

    /// Create a toolchain mismatch failure report
    public static func toolchainMismatch(expected: String, actual: String) -> ReplayFailureReport {
        return ReplayFailureReport(
            stage: "precheck",
            artifactKind: "ToolchainFingerprint",
            artifactId: "toolchain-fingerprint",
            eventIndex: 0,
            classification: "toolchain mismatch",
            firstDiffOffset: 0,
            expectedContext: expected.data(using: .utf8) ?? Data(),
            actualContext: actual.data(using: .utf8) ?? Data(),
            expectedDigest: expected,
            actualDigest: actual
        )
    }

    /// Environment hash mismatch failure
    public static func environmentMismatch(expected: String, actual: String) -> ReplayFailureReport {
        return ReplayFailureReport(
            stage: "precheck",
            artifactKind: "EnvironmentSnapshot",
            artifactId: "environment-snapshot",
            eventIndex: 0,
            classification: "environment divergence",
            firstDiffOffset: 0,
            expectedContext: expected.data(using: .utf8) ?? Data(),
            actualContext: actual.data(using: .utf8) ?? Data(),
            expectedDigest: expected,
            actualDigest: actual
        )
    }
}

/// Stage boundary artifact with canonical encoding and BLAKE3 digest.
/// Represents the exact output of each stage in the deterministic loop.
public struct StageArtifact: Codable, Sendable, Equatable {
    public let stageNumber: Int
    public let stageName: String
    public let canonicalPayload: Data
    public let digest: String
    public let evidenceId: String
    public let stageDisplayName: String?

    public init(
        stageNumber: Int,
        stageName: String,
        canonicalPayload: Data,
        digest: String,
        evidenceId: String,
        stageDisplayName: String? = nil
    ) {
        self.stageNumber = stageNumber
        self.stageName = stageName
        self.canonicalPayload = canonicalPayload
        self.digest = digest
        self.evidenceId = evidenceId
        self.stageDisplayName = stageDisplayName
    }
    
    /// Create a StageArtifact from configuration
    public static func from<T: Encodable>(
        _ payload: T,
        stage: StageBoundary,
        stageNumber: Int,
        evidenceId: String,
        workspaceSnapshotHash: String,
        encoder: CanonicalJSONEncoder,
        hasher: BLAKE3Hasher
    ) throws -> StageArtifact {
        let canonicalPayload = try encoder.encode(payload)
        let digest = try hasher.hash(canonicalPayload)
        
        return StageArtifact(
            stageNumber: stageNumber,
            stageName: stage.rawValue,
            canonicalPayload: canonicalPayload,
            digest: digest,
            evidenceId: evidenceId,
            stageDisplayName: workspaceSnapshotHash
        )
    }
}

/// Protocol for recomputing stage artifacts from logs and inputs.
/// isolates the recomputation logic for testability.
public protocol StageArtifactProducer: Sendable {
    func recomputeArtifacts(from log: [GovernanceEventEnvelope], inputs: VerificationInputs) async throws -> [StageArtifact]
}

/// Index of stage boundary artifacts extracted from a log.
/// Provides efficient lookup for comparison during verification.
public struct StageArtifactIndex: Sendable {
    public let artifacts: [Int: StageArtifact] // stageNumber -> artifact

    public init(artifacts: [Int: StageArtifact]) {
        self.artifacts = artifacts
    }

    /// Extract artifacts from a governance event log
    public static func from(log: [GovernanceEventEnvelope]) throws -> StageArtifactIndex {
        var artifacts: [Int: StageArtifact] = [:]

        // Parse each envelope looking for stage boundary artifacts
        for envelope in log {
            for event in envelope.events {
                // Look for artifact records in events
                switch event {
                case .toolCompleted(let completed):
                    if completed.toolName == "stage_boundary" {
                        // This is a stage boundary marker
                        if let artifactData = completed.outputHash?.data(using: .utf8) {
                            let decoder = JSONDecoder()
                            if let artifact = try? decoder.decode(StageArtifact.self, from: artifactData) {
                                artifacts[artifact.stageNumber] = artifact
                            }
                        }
                    }
                default:
                    break
                }
            }
        }

        return StageArtifactIndex(artifacts: artifacts)
    }

    /// Get artifact for a specific stage
    public func getArtifact(for stage: Int) -> StageArtifact? {
        return artifacts[stage]
    }

    /// Get all stage numbers in order
    public var stageNumbers: [Int] {
        return artifacts.keys.sorted()
    }
}
