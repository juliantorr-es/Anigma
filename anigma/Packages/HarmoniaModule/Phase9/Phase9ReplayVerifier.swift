//
//  Phase9ReplayVerifier.swift
//  HarmoniaModule
//
//  Full Phase 9.0 replay verifier entry point.
//  Wires together all components to provide end-to-end verification.
//

@preconcurrency import Foundation

/// Final Phase 9.0 replay verifier implementation.
/// Provides surgical failure reporting with byte-level divergence detection.
public final class Phase9ReplayVerifier: Sendable {

    private let kernel: Phase9LoopKernel
    private let encoder: CanonicalJSONEncoder
    private let hasher: BLAKE3Hasher

    public init(
        kernel: Phase9LoopKernel,
        encoder: CanonicalJSONEncoder,
        hasher: BLAKE3Hasher
    ) {
        self.kernel = kernel
        self.encoder = encoder
        self.hasher = hasher
    }

    /// Verify deterministic replay of a Phase 9.0 execution.
    /// Takes event log and pinned inputs, returns verification result.
    ///
    /// Full verification flow:
    /// 1. Compare event log bytes against the recorded kernel log
    /// 2. Check pinned inputs against the recorded kernel configuration
    /// 3. Return deterministic pass/fail with byte-level context for any drift
    public func verify(_ inputs: VerificationInputs) async throws -> ReplayVerificationOutcome {
        let baselineLog = kernel.eventLogBytes
        let baselineCanonical = try canonicalizeLog(baselineLog)
        let baselineDigest = try hasher.hash(baselineCanonical)
        let comparator = StageArtifactComparator(encoder: encoder, hasher: hasher)

        // Step 1: detect byte-level drift in the event log itself (canonicalized)
        let actualCanonical: Data
        do {
            actualCanonical = try canonicalizeLog(inputs.eventLogBytes)
        } catch {
            let diff = comparator.comparePayloads(baselineLog, inputs.eventLogBytes)
            let offset: Int
            let expectedContext: Data
            let actualContext: Data
            switch diff {
            case .identical:
                offset = 0
                expectedContext = Data()
                actualContext = Data()
            case .diverged(let foundOffset, let classification, let expected, let actual):
                return .fail(ReplayFailureReport(
                    stage: "event_log",
                    artifactKind: "event_log",
                    artifactId: "event-log",
                    eventIndex: 0,
                    classification: "event_log_decode_failed: \(classification)",
                    firstDiffOffset: foundOffset,
                    expectedContext: expected,
                    actualContext: actual,
                    expectedDigest: baselineDigest,
                    actualDigest: (try? hasher.hash(inputs.eventLogBytes)) ?? ""
                ))
            }
            // If we somehow get here, treat decode failure as drift
            return .fail(ReplayFailureReport(
                stage: "event_log",
                artifactKind: "event_log",
                artifactId: "event-log",
                eventIndex: 0,
                classification: "event_log_decode_failed",
                firstDiffOffset: offset,
                expectedContext: expectedContext,
                actualContext: actualContext,
                expectedDigest: baselineDigest,
                actualDigest: (try? hasher.hash(inputs.eventLogBytes)) ?? ""
            ))
        }

        switch comparator.comparePayloads(baselineCanonical, actualCanonical) {
        case .diverged(let offset, let classification, let expectedContext, let actualContext):
            let actualDigest = (try? hasher.hash(actualCanonical)) ?? ""
            return .fail(ReplayFailureReport(
                stage: "event_log",
                artifactKind: "event_log",
                artifactId: "event-log",
                eventIndex: 0,
                classification: classification,
                firstDiffOffset: offset,
                expectedContext: expectedContext,
                actualContext: actualContext,
                expectedDigest: baselineDigest,
                actualDigest: actualDigest
            ))
        case .identical:
            break
        }

        // Step 2: pinned input checks against the recorded kernel configuration
        if inputs.workspaceSnapshotHash != kernel.snapshotRootHash {
            return .fail(makePrecheckFailure(
                stage: "precheck",
                classification: "workspace_snapshot_mismatch",
                expected: kernel.snapshotRootHash,
                actual: inputs.workspaceSnapshotHash
            ))
        }

        if inputs.policyPackHash != kernel.policyPackVersion {
            return .fail(makePrecheckFailure(
                stage: "precheck",
                classification: "policy_pack_mismatch",
                expected: kernel.policyPackVersion,
                actual: inputs.policyPackHash
            ))
        }

        let expectedNormalizer = "1.0.0"
        if inputs.normalizerVersion != expectedNormalizer {
            return .fail(makePrecheckFailure(
                stage: "precheck",
                classification: "normalizer_version_mismatch",
                expected: expectedNormalizer,
                actual: inputs.normalizerVersion
            ))
        }

        if inputs.toolchainFingerprint != kernel.toolchainVersion {
            return .fail(makePrecheckFailure(
                stage: "precheck",
                classification: "toolchain_mismatch",
                expected: kernel.toolchainVersion,
                actual: inputs.toolchainFingerprint
            ))
        }

        // Success path
        let artifact = ReplayVerifiedArtifact(
            verificationId: "verify-\(UUID().uuidString.prefix(8))",
            stageCount: 1,
            totalVerifiedBytes: baselineCanonical.count,
            timestamp: 0
        )

        return .pass(artifact)
    }

    /// Verify with detailed diagnostics for debugging.
    /// Provides additional reporting information for complex failures.
    public func verifyWithDiagnostics(_ inputs: VerificationInputs) async throws -> VerificationDiagnosticsResult {
        // Run standard verification
        let standardResult = try await verify(inputs)

        // Create diagnostics for failed verification
        if case .fail(let failureReport) = standardResult {
            let diagnostics = VerificationDiagnostics(
                failureReport: failureReport,
                verificationInputs: inputs,
                kernelInfo: extractKernelInfo(),
                timestamp: 0
            )
            return VerificationDiagnosticsResult.from(standardResult, diagnostics: diagnostics)
        }

        // Create success diagnostics
        let successDiagnostics = VerificationDiagnostics(
            failureReport: nil,
            verificationInputs: inputs,
            kernelInfo: extractKernelInfo(),
            timestamp: 0
        )
        return VerificationDiagnosticsResult.from(standardResult, diagnostics: successDiagnostics)
    }

    /// Extract kernel information for diagnostics reporting.
    private func extractKernelInfo() -> KernelInfo {
        return KernelInfo(
            eventLogSize: kernel.eventLogBytes.count,
            snapshotHash: kernel.snapshotRootHash,
            policyPackVersion: kernel.policyPackVersion,
            toolchainVersion: kernel.toolchainVersion
        )
    }

    /// Verify multiple sessions in parallel for stress testing.
    /// Processes each verification independently and returns all results.
    public func verifyMultiple(_ inputs: [VerificationInputs]) async throws -> [ReplayVerificationOutcome] {
        var results: [ReplayVerificationOutcome] = []

        // In a real implementation, these would run in parallel
        // For now, sequential processing
        for inputs in inputs {
            let result = try await verify(inputs)
            results.append(result)
        }

        return results
    }

    /// Build a consistent failure report for pinned input mismatches.
    private func makePrecheckFailure(
        stage: String,
        classification: String,
        expected: String,
        actual: String
    ) -> ReplayFailureReport {
        let expectedDigest = (try? hasher.hash(Data(expected.utf8))) ?? ""
        let actualDigest = (try? hasher.hash(Data(actual.utf8))) ?? ""

        return ReplayFailureReport(
            stage: stage,
            artifactKind: "pinned_inputs",
            artifactId: "inputs",
            eventIndex: 0,
            classification: classification,
            firstDiffOffset: 0,
            expectedContext: Data(expected.utf8),
            actualContext: Data(actual.utf8),
            expectedDigest: expectedDigest,
            actualDigest: actualDigest
        )
    }

    /// Canonicalize the governance log to remove ordering noise before comparison.
    private func canonicalizeLog(_ data: Data) throws -> Data {
        let envelopes = try GovernanceEventLogParser.parse(data)
        let normalized = envelopes.map { envelope in
            CanonicalEnvelope(
                events: envelope.events,
                sessionId: envelope.sessionId
            )
        }
        return try encoder.encode(normalized)
    }

    /// Minimal deterministic representation of a governance envelope.
    private struct CanonicalEnvelope: Encodable {
        let events: [AnyCodableEvent]
        let sessionId: String
    }
}

/// Result with additional diagnostics for debugging verification failures.
public struct VerificationDiagnosticsResult: Sendable {
    public let standardResult: ReplayVerificationOutcome
    public let diagnostics: VerificationDiagnostics
    public let processingTimeMs: Int

    public static func from(_ result: ReplayVerificationOutcome, diagnostics: VerificationDiagnostics) -> VerificationDiagnosticsResult {
        return VerificationDiagnosticsResult(
            standardResult: result,
            diagnostics: diagnostics,
            processingTimeMs: 0
        )
    }
}

/// Additional diagnostic information for verification results.
public struct VerificationDiagnostics: Sendable {
    public let failureReport: ReplayFailureReport?
    public let verificationInputs: VerificationInputs
    public let kernelInfo: KernelInfo
    public let timestamp: Int64

    public init(
        failureReport: ReplayFailureReport?,
        verificationInputs: VerificationInputs,
        kernelInfo: KernelInfo,
        timestamp: Int64
    ) {
        self.failureReport = failureReport
        self.verificationInputs = verificationInputs
        self.kernelInfo = kernelInfo
        self.timestamp = timestamp
    }

    public var isFailed: Bool {
        return failureReport != nil
    }

    public var summary: String {
        guard let failureReport else { return "Verification passed" }
        return "FAIL: stage \(failureReport.stage) - \(failureReport.classification)"
    }
}

/// Information extracted from the kernel for diagnostics.
public struct KernelInfo: Sendable {
    public let eventLogSize: Int
    public let snapshotHash: String
    public let policyPackVersion: String
    public let toolchainVersion: String

    public init(
        eventLogSize: Int,
        snapshotHash: String,
        policyPackVersion: String,
        toolchainVersion: String
    ) {
        self.eventLogSize = eventLogSize
        self.snapshotHash = snapshotHash
        self.policyPackVersion = policyPackVersion
        self.toolchainVersion = toolchainVersion
    }
}

/// Factory for creating correctly configured replay verifiers.
public struct Phase9ReplayVerifierFactory {

    /// Create a standard replay verifier with default configuration.
    public static func createStandard(kernel: Phase9LoopKernel) -> Phase9ReplayVerifier {
        let encoder = CanonicalJSONEncoder()
        let hasher = BLAKE3Hasher()

        return Phase9ReplayVerifier(
            kernel: kernel,
            encoder: encoder,
            hasher: hasher
        )
    }

    /// Create a verifier with custom configuration for testing.
    public static func createCustom(
        kernel: Phase9LoopKernel,
        encoder: CanonicalJSONEncoder,
        hasher: BLAKE3Hasher
    ) -> Phase9ReplayVerifier {
        return Phase9ReplayVerifier(
            kernel: kernel,
            encoder: encoder,
            hasher: hasher
        )
    }
}
