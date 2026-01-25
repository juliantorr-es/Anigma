//
//  StageArtifactComparator.swift
//  HarmoniaModule
//
//  Stage artifact comparator with byte-level diffing.
//  Detects first divergence point and provides surgical failure diagnostics.
//

@preconcurrency import Foundation

/// Comparator for stage artifacts with byte-level divergence detection.
/// Produces surgical failure reports showing exact bytes where determinism broke.
public struct StageArtifactComparator {

    private let encoder: CanonicalJSONEncoder
    private let hasher: BLAKE3Hasher

    public init(encoder: CanonicalJSONEncoder, hasher: BLAKE3Hasher) {
        self.encoder = encoder
        self.hasher = hasher
    }

    /// Compare recorded and recomputed stage artifacts.
    /// Returns verification result with failure details if divergence detected.
    public func compare(
        recorded: StageArtifactIndex,
        recomputed: [StageArtifact]
    ) -> ReplayVerificationOutcome {

        // Build index for recomputed artifacts for efficient lookup
        var recomputedIndex: [Int: StageArtifact] = [:]
        for artifact in recomputed {
            recomputedIndex[artifact.stageNumber] = artifact
        }

        // Compare stage by stage in order
        for stageNumber in recorded.stageNumbers {
            guard let recordedArtifact = recorded.getArtifact(for: stageNumber) else {
                continue
            }

            guard let recomputedArtifact = recomputedIndex[stageNumber] else {
                // Recomputed artifact missing
                return .fail(ReplayFailureReport(
                    stage: String(stageNumber),
                    artifactKind: recordedArtifact.stageName,
                    artifactId: recordedArtifact.evidenceId,
                    eventIndex: stageNumber,
                    classification: "missing artifact",
                    firstDiffOffset: 0,
                    expectedContext: recordedArtifact.canonicalPayload,
                    actualContext: Data(),
                    expectedDigest: recordedArtifact.digest,
                    actualDigest: ""
                ))
            }

            // Compare digests first for fast path
            if recordedArtifact.digest != recomputedArtifact.digest {
                if let failure = analyzeByteOffDivergence(
                    stage: stageNumber,
                    stageName: recordedArtifact.stageName,
                    expectedPayload: recordedArtifact.canonicalPayload,
                    actualPayload: recomputedArtifact.canonicalPayload,
                    expectedDigest: recordedArtifact.digest,
                    actualDigest: recomputedArtifact.digest,
                    evidenceId: recordedArtifact.evidenceId
                ) {
                    return .fail(failure)
                }
            }
        }

        // All artifacts match - verification passed
        let totalBytes = recomputed.reduce(0) { $0 + $1.canonicalPayload.count }
        let artifact = ReplayVerifiedArtifact(
            verificationId: "verify-\(UUID().uuidString.prefix(8))",
            stageCount: recomputed.count,
            totalVerifiedBytes: totalBytes,
            timestamp: 0
        )
        
        return .pass(artifact)
    }
    
    /// Find the first byte offset where two payloads differ.
    /// Returns -1 if payloads are identical.
    private func findFirstDiffOffset(expected: Data, actual: Data) -> Int {
        let minLength = min(expected.count, actual.count)

        for i in 0..<minLength {
            if expected[i] != actual[i] {
                return i
            }
        }

        // Check if one is longer
        if expected.count != actual.count {
            return minLength
        }

        // Identical
        return -1
    }

    private func analyzeByteOffDivergence(
        stage: Int,
        stageName: String,
        expectedPayload: Data,
        actualPayload: Data,
        expectedDigest: String,
        actualDigest: String,
        evidenceId: String
    ) -> ReplayFailureReport? {
        let contextWindow = 32
        let firstDiffOffset = findFirstDiffOffset(expected: expectedPayload, actual: actualPayload)

        guard firstDiffOffset >= 0 else {
            return nil
        }

        let startOffset = max(0, firstDiffOffset - contextWindow / 2)
        let endOffset = min(expectedPayload.count, firstDiffOffset + contextWindow / 2)

        let expectedContext = expectedPayload.subdata(in: startOffset..<endOffset)
        let actualContext = actualPayload.subdata(in: startOffset..<endOffset)

        let classification = classifyDivergence(
            expectedPayload: expectedPayload,
            actualPayload: actualPayload,
            divergeOffset: firstDiffOffset
        )

        return ReplayFailureReport(
            stage: String(stage),
            artifactKind: stageName,
            artifactId: "stage-\(stage)-artifact",
            eventIndex: stage,
            classification: classification,
            firstDiffOffset: firstDiffOffset,
            expectedContext: expectedContext,
            actualContext: actualContext,
            expectedDigest: expectedDigest,
            actualDigest: actualDigest
        )
    }

    /// Classify the type of divergence detected.
    /// Provides insight into what kind of nondeterminism occurred.
    private func classifyDivergence(
        expectedPayload: Data,
        actualPayload: Data,
        divergeOffset: Int
    ) -> String {

        // Check if it's a length difference
        if expectedPayload.count != actualPayload.count {
            return "ordering drift"
        }

        // Check if it's floating point formatting (unlikely with canonical JSON)
        if let expectedStr = String(data: expectedPayload, encoding: .utf8),
           let actualStr = String(data: actualPayload, encoding: .utf8) {

            // Look for decimal point differences
            if expectedStr.contains(".") && actualStr.contains(".") {
                return "canonicalization drift"
            }

            // Check for whitespace differences
            if expectedStr.filter({ !$0.isWhitespace }) == actualStr.filter({ !$0.isWhitespace }) {
                return "whitespace drift"
            }

            // Check for line ending differences
            if expectedStr.replacingOccurrences(of: "\r\n", with: "\n") ==
               actualStr.replacingOccurrences(of: "\r\n", with: "\n") {
                return "line ending drift"
            }
        }

        // Default unknown
        return "unknown"
    }

    /// Quick comparison of two payloads without full artifact wrapping.
    public func comparePayloads(_ expected: Data, _ actual: Data) -> PayloadComparisonResult {
        if expected == actual {
            return .identical
        }

        let firstDiff = findFirstDiffOffset(expected: expected, actual: actual)
        let classification = classifyDivergence(
            expectedPayload: expected,
            actualPayload: actual,
            divergeOffset: firstDiff
        )

        let contextWindow = 32
        let startOffset = max(0, firstDiff - contextWindow / 2)
        let endOffset = min(expected.count, firstDiff + contextWindow / 2)

        let expectedContext = expected.subdata(in: startOffset..<endOffset)
        let actualContext = actual.subdata(in: startOffset..<endOffset)

        return .diverged(
            offset: firstDiff,
            classification: classification,
            expectedContext: expectedContext,
            actualContext: actualContext
        )
    }
}

/// Result of comparing two payloads.
public enum PayloadComparisonResult: Sendable {
    case identical
    case diverged(
        offset: Int,
        classification: String,
        expectedContext: Data,
        actualContext: Data
    )

    public var isDiverged: Bool {
        switch self {
        case .identical:
            return false
        case .diverged:
            return true
        }
    }
}
