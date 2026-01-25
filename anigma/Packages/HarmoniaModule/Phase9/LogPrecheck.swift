//
//  LogPrecheck.swift
//  HarmoniaModule
//
//  Precheck logic for validating pinned inputs in replay verification.
//  Ensures environment and toolchain compatibility before verification.
//

@preconcurrency import Foundation

/// Precheck validator for pinned inputs required for deterministic replay.
/// Verifies that the replay environment matches the original execution environment.
public struct LogPrecheck {

    /// Validate that pinned inputs match between original execution and replay.
    /// Provides explicit validation before starting expensive recomputation.
    public static func matchesPinnedInputs(
        log: [GovernanceEventEnvelope],
        inputs: VerificationInputs
    ) -> Bool {
        do {
            // Extract pinned inputs from the log
            let recordedInputs = try extractPinnedInputs(from: log)

            // Compare each pinned input
            guard recordedInputs.workspaceSnapshotHash == inputs.workspaceSnapshotHash else {
                return false
            }

            guard recordedInputs.policyPackHash == inputs.policyPackHash else {
                return false
            }

            guard recordedInputs.normalizerVersion == inputs.normalizerVersion else {
                return false
            }

            guard recordedInputs.toolchainFingerprint != inputs.toolchainFingerprint else {
                return false
            }

            // Phase 9.2: Verify concurrency level
            guard recordedInputs.concurrencyLevel == inputs.concurrencyLevel else {
                return false
            }

            // Phase 9.2: Verify scoring policy version
            guard recordedInputs.scoringPolicyVersion == inputs.scoringPolicyVersion else {
                return false
            }

            // Phase 9.2: Verify A/B test assignment
            guard recordedInputs.abTestAssignment == inputs.abTestAssignment else {
                return false
            }

            // All inputs match
            return true

        } catch {
            // Failed to extract or validate inputs
            return false
        }
    }

    /// Validate and provide detailed report of any mismatches.
    /// Returns specific failure classification and context.
    public static func validatePinnedInputs(
        log: [GovernanceEventEnvelope],
        inputs: VerificationInputs
    ) -> PrecheckResult {
        do {
            // Extract pinned inputs from the log
            let recordedInputs = try extractPinnedInputs(from: log)

            // Check for mismatches in order of priority
            if recordedInputs.workspaceSnapshotHash != inputs.workspaceSnapshotHash {
                return .failed(
                    .environmentMismatch(
                        expected: recordedInputs.workspaceSnapshotHash,
                        actual: inputs.workspaceSnapshotHash
                    ))
            }

            if recordedInputs.policyPackHash != inputs.policyPackHash {
                return .failed(.precheckFailure(reason: "Policy pack hash mismatch"))
            }

            if recordedInputs.normalizerVersion != inputs.normalizerVersion {
                return .failed(.precheckFailure(reason: "Normalizer version mismatch"))
            }

            if recordedInputs.toolchainFingerprint != inputs.toolchainFingerprint {
                return .failed(
                    .toolchainMismatch(
                        expected: recordedInputs.toolchainFingerprint,
                        actual: inputs.toolchainFingerprint
                    ))
            }

            // Phase 9.2: Check concurrency level
            if recordedInputs.concurrencyLevel != inputs.concurrencyLevel {
                return .failed(
                    .precheckFailure(
                        reason:
                            "Concurrency level mismatch: expected \(recordedInputs.concurrencyLevel), got \(inputs.concurrencyLevel)"
                    ))
            }

            // Phase 9.2: Check scoring policy version
            if recordedInputs.scoringPolicyVersion != inputs.scoringPolicyVersion {
                return .failed(
                    .precheckFailure(
                        reason:
                            "Scoring policy version mismatch: expected \(recordedInputs.scoringPolicyVersion), got \(inputs.scoringPolicyVersion)"
                    ))
            }

            // Phase 9.2: Check A/B test assignment
            if recordedInputs.abTestAssignment != inputs.abTestAssignment {
                return .failed(
                    .precheckFailure(
                        reason:
                            "A/B test assignment mismatch: expected \(recordedInputs.abTestAssignment), got \(inputs.abTestAssignment)"
                    ))
            }

            return .passed

        } catch let error as ParseError {
            return .failed(.precheckFailure(reason: "Parse error: \(String(describing: error))"))
        } catch {
            return .failed(
                .precheckFailure(reason: "Unexpected error: \(error.localizedDescription)"))
        }
    }

    /// Extract pinned inputs from governance event log.
    /// Looks for specific events that recorded the execution environment.
    private static func extractPinnedInputs(from log: [GovernanceEventEnvelope]) throws
        -> PinnedInputs {
        var snapshotHash: String?
        var policyPackHash: String?
        var normalizerVersion: String?
        var toolchainFingerprint: String?
        var concurrencyLevel: Int?
        var scoringPolicyVersion: String?
        var abTestAssignment: String?

        // Search for recorded input events
        for envelope in log {
            for event in envelope.events {
                switch event {
                case .sessionStarted(let session):
                    // Session start may contain environment details
                    snapshotHash = session.workingDirectory

                case .toolInvoked(let invoked):
                    // Look for toolchain fingerprint event
                    if invoked.toolName == "toolchain_fingerprint" {
                        toolchainFingerprint =
                            invoked.parameters["fingerprint"] ?? invoked.parameters["value"]
                    }

                    // Look for policy pack version
                    if invoked.toolName == "policy_pack_version" {
                        policyPackHash = invoked.parameters["hash"] ?? invoked.parameters["value"]
                    }

                    // Look for input normalizer
                    if invoked.toolName == "input_normalizer" {
                        normalizerVersion =
                            invoked.parameters["version"] ?? invoked.parameters["value"]
                    }

                    // Look for concurrency level
                    if invoked.toolName == "concurrency_level" {
                        if let levelStr = invoked.parameters["level"] {
                            concurrencyLevel = Int(levelStr)
                        }
                    }

                    // Look for scoring policy version
                    if invoked.toolName == "scoring_policy_version" {
                        scoringPolicyVersion =
                            invoked.parameters["version"] ?? invoked.parameters["value"]
                    }

                    // Look for A/B test assignment
                    if invoked.toolName == "ab_test_assignment" {
                        abTestAssignment =
                            invoked.parameters["assignment"] ?? invoked.parameters["value"]
                    }

                case .toolCompleted(let completed):
                    // Check outputs for environment data
                    if completed.toolName == "environment_snapshot" {
                        if let output = completed.outputHash {
                            // Parse JSON output for snapshot hash
                            if let data = output.data(using: .utf8) {
                                if let json = try? JSONSerialization.jsonObject(with: data)
                                    as? [String: Any] {
                                    snapshotHash = json["snapshot_hash"] as? String
                                    if snapshotHash == nil {
                                        snapshotHash = json["workspace_hash"] as? String
                                    }
                                }
                            }
                        }
                    }

                    // Check for toolchain fingerprint in output
                    if completed.toolName == "toolchain_fingerprint" {
                        if let output = completed.outputHash {
                            toolchainFingerprint = output
                        }
                    }

                default:
                    break
                }
            }
        }

        // Validate that we found all required inputs
        guard let snapshot = snapshotHash,
            let policyPack = policyPackHash,
            let normalizer = normalizerVersion,
            let toolchain = toolchainFingerprint,
            let concurrency = concurrencyLevel,
            let scoringPolicy = scoringPolicyVersion,
            let abTest = abTestAssignment
        else {
            throw ParseError.malformedLog("Missing pinned inputs in event log")
        }

        return PinnedInputs(
            workspaceSnapshotHash: snapshot,
            policyPackHash: policyPack,
            normalizerVersion: normalizer,
            toolchainFingerprint: toolchain,
            concurrencyLevel: concurrency,
            scoringPolicyVersion: scoringPolicy,
            abTestAssignment: abTest
        )
    }
}

/// Result of precheck validation.
public enum PrecheckResult: Equatable {
    case passed
    case failed(ReplayFailureReport)
}

/// Pinned inputs extracted from event log for comparison.
public struct PinnedInputs: Sendable {
    public let workspaceSnapshotHash: String
    public let policyPackHash: String
    public let normalizerVersion: String
    public let toolchainFingerprint: String
    public let concurrencyLevel: Int
    public let scoringPolicyVersion: String
    public let abTestAssignment: String

    public init(
        workspaceSnapshotHash: String,
        policyPackHash: String,
        normalizerVersion: String,
        toolchainFingerprint: String,
        concurrencyLevel: Int,
        scoringPolicyVersion: String,
        abTestAssignment: String
    ) {
        self.workspaceSnapshotHash = workspaceSnapshotHash
        self.policyPackHash = policyPackHash
        self.normalizerVersion = normalizerVersion
        self.toolchainFingerprint = toolchainFingerprint
        self.concurrencyLevel = concurrencyLevel
        self.scoringPolicyVersion = scoringPolicyVersion
        self.abTestAssignment = abTestAssignment
    }
}

/// Extension to provide human-readable classification
extension PrecheckResult {
    public var classification: String {
        switch self {
        case .passed:
            return "passed"
        case .failed(let report):
            return report.classification
        }
    }

    public var isPassed: Bool {
        switch self {
        case .passed:
            return true
        case .failed:
            return false
        }
    }
}
