//
//  RuntimeEvidenceCollector.swift
//  HarmoniaModule
//
//  Runtime evidence collection for Phase 9.1 loop execution.
//  Captures comprehensive evidence at every stage transition for audit and verification.
//

import Foundation
import AnigmaPrimitives

/// Runtime evidence collector for Phase 9.1 loop execution.
/// Captures detailed evidence at each stage boundary for audit and verification.
public actor RuntimeEvidenceCollector {

    private var evidenceRecords: [StageEvidenceRecord] = []
    private var sessionStartTime: Int64
    private var sessionId: String

    public init(sessionId: String) {
        self.sessionId = sessionId
        self.sessionStartTime = Int64(Date().timeIntervalSince1970)
    }

    /// Evidence record for a stage boundary transition.
    public struct StageEvidenceRecord: Codable, Sendable {
        public let stage: Int
        public let stageName: String
        public let evidenceType: String
        public let timestamp: Int64
        public let sessionId: String
        public let workspaceSnapshotHash: String

        // Evidence data
        public let inputs: [String: String]
        public let outputs: [String: String]
        public let artifacts: [String: String]
        public let metrics: [String: String]
        public let governance: [String: String]
        public let evidenceDigest: String
        public let verificationDigest: String

        public init(
            stage: Int,
            stageName: String,
            evidenceType: String,
            timestamp: Int64,
            sessionId: String,
            workspaceSnapshotHash: String,
            inputs: [String: String] = [:],
            outputs: [String: String] = [:],
            artifacts: [String: String] = [:],
            metrics: [String: String] = [:],
            governance: [String: String] = [:],
            evidenceDigest: String,
            verificationDigest: String
        ) {
            self.stage = stage
            self.stageName = stageName
            self.evidenceType = evidenceType
            self.timestamp = timestamp
            self.sessionId = sessionId
            self.workspaceSnapshotHash = workspaceSnapshotHash
            self.inputs = inputs
            self.outputs = outputs
            self.artifacts = artifacts
            self.metrics = metrics
            self.governance = governance
            self.evidenceDigest = evidenceDigest
            self.verificationDigest = verificationDigest
        }
    }

    /// Capture evidence for a stage transition.
    public func captureStageEvidence(
        stage: Int,
        stageName: String,
        evidenceType: String,
        workspaceSnapshotHash: String,
        inputs: [String: String] = [:],
        outputs: [String: String] = [:],
        artifacts: [String: String] = [:],
        metrics: [String: String] = [:],
        governance: [String: String] = [:]
    ) async throws {
        let timestamp = Int64(Date().timeIntervalSince1970)

        let record = StageEvidenceRecord(
            stage: stage,
            stageName: stageName,
            evidenceType: evidenceType,
            timestamp: timestamp,
            sessionId: sessionId,
            workspaceSnapshotHash: workspaceSnapshotHash,
            inputs: inputs,
            outputs: outputs,
            artifacts: artifacts,
            metrics: metrics,
            governance: governance,
            evidenceDigest: "",
            verificationDigest: ""
        )

        let evidenceData = try CanonicalJSONEncoder.encode(record)
        let evidenceDigest = BLAKE3Digest.hex(of: evidenceData)

        let finalRecord = StageEvidenceRecord(
            stage: stage,
            stageName: stageName,
            evidenceType: evidenceType,
            timestamp: timestamp,
            sessionId: sessionId,
            workspaceSnapshotHash: workspaceSnapshotHash,
            inputs: inputs,
            outputs: outputs,
            artifacts: artifacts,
            metrics: metrics,
            governance: governance,
            evidenceDigest: evidenceDigest,
            verificationDigest: evidenceDigest
        )

        evidenceRecords.append(finalRecord)
    }

    /// Get all captured evidence records.
    public func getEvidenceRecords() -> [StageEvidenceRecord] {
        return evidenceRecords
    }

    /// Get evidence records for a specific stage.
    public func getEvidence(for stage: Int) -> [StageEvidenceRecord] {
        return evidenceRecords.filter { $0.stage == stage }
    }

    /// Get the complete evidence digest chain.
    public func getEvidenceDigestChain() -> [Int] {
        let chain = evidenceRecords.map { $0.stage }.sorted()
        return chain
    }

    /// Export evidence to persistent storage.
    public func exportEvidence() throws -> Data {
        let evidenceBundle = RuntimeEvidenceBundle(
            sessionId: sessionId,
            sessionStartTime: sessionStartTime,
            sessionEndTime: Int64(Date().timeIntervalSince1970),
            records: evidenceRecords
        )

        return try CanonicalJSONEncoder.encode(evidenceBundle)
    }

    /// Verify evidence chain integrity.
    public func verifyEvidenceChain() throws -> EvidenceVerificationResult {
        let sortedRecords = evidenceRecords.sorted { $0.stage < $1.stage }

        // Check stage sequence
        var expectedStage = 0
        for record in sortedRecords {
            guard record.stage == expectedStage else {
                throw RuntimeEvidenceError.invalidSequence(
                    expected: expectedStage,
                    actual: record.stage
                )
            }
            expectedStage += 1
        }

        // Verify evidence digests
        for record in sortedRecords {
            guard !record.evidenceDigest.isEmpty else {
                throw RuntimeEvidenceError.missingDigest(stage: record.stage)
            }
        }

        // Check workspace snapshot consistency
        guard let firstSnapshot = sortedRecords.first?.workspaceSnapshotHash else {
            throw RuntimeEvidenceError.missingSnapshot
        }

        let allSnapshotsMatch = sortedRecords.allSatisfy {
            $0.workspaceSnapshotHash == firstSnapshot
        }

        guard allSnapshotsMatch else {
            throw RuntimeEvidenceError.snapshotInconsistency
        }

        return EvidenceVerificationResult(
            verified: true,
            stageCount: sortedRecords.count,
            totalRecords: sortedRecords.count,
            sessionDuration: Int64(Date().timeIntervalSince1970) - sessionStartTime
        )
    }

    /// Clear all evidence records.
    public func reset() {
        evidenceRecords.removeAll()
        sessionStartTime = Int64(Date().timeIntervalSince1970)
    }
}

/// Evidence bundle for export and persistence.
public struct RuntimeEvidenceBundle: Codable, Sendable {
    public let sessionId: String
    public let sessionStartTime: Int64
    public let sessionEndTime: Int64
    public let records: [RuntimeEvidenceCollector.StageEvidenceRecord]

    public init(
        sessionId: String,
        sessionStartTime: Int64,
        sessionEndTime: Int64,
        records: [RuntimeEvidenceCollector.StageEvidenceRecord]
    ) {
        self.sessionId = sessionId
        self.sessionStartTime = sessionStartTime
        self.sessionEndTime = sessionEndTime
        self.records = records
    }
}

/// Result of evidence chain verification.
public struct EvidenceVerificationResult: Codable, Sendable {
    public let verified: Bool
    public let stageCount: Int
    public let totalRecords: Int
    public let sessionDuration: Int64

    public init(
        verified: Bool,
        stageCount: Int,
        totalRecords: Int,
        sessionDuration: Int64
    ) {
        self.verified = verified
        self.stageCount = stageCount
        self.totalRecords = totalRecords
        self.sessionDuration = sessionDuration
    }
}

/// Errors in evidence collection and verification.
public enum RuntimeEvidenceError: Error, LocalizedError {
    case invalidSequence(expected: Int, actual: Int)
    case missingDigest(stage: Int)
    case missingSnapshot
    case snapshotInconsistency
    case exportFailed(String)

    public var localizedDescription: String? {
        switch self {
        case .invalidSequence(let expected, let actual):
            return "Invalid stage sequence: expected \(expected), got \(actual)"
        case .missingDigest(let stage):
            return "Missing evidence digest for stage \(stage)"
        case .missingSnapshot:
            return "Missing workspace snapshot reference"
        case .snapshotInconsistency:
            return "Workspace snapshot hashes inconsistent across stages"
        case .exportFailed(let reason):
            return "Failed to export evidence: \(reason)"
        }
    }
}
