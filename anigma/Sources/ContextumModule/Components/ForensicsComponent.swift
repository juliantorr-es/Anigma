import Foundation

/// Forensic investigation state and linkage
public struct ForensicsComponent: Codable, Sendable {
    public let reportID: UUID
    public let subjectReceiptID: String
    public let subjectRunID: UUID?
    public let subjectWorkflowID: UUID?
    public let investigationType: InvestigationType
    public let reportArtifactHash: String?
    public let created: Date

    public enum InvestigationType: String, Codable, Sendable {
        case failureReport
        case performanceAnomaly
        case contextDriftAnalysis
        case replayComparison
    }

    public init(
        reportID: UUID = UUID(),
        subjectReceiptID: String,
        subjectRunID: UUID?,
        subjectWorkflowID: UUID?,
        investigationType: InvestigationType,
        reportArtifactHash: String? = nil,
        created: Date = Date()
    ) {
        self.reportID = reportID
        self.subjectReceiptID = subjectReceiptID
        self.subjectRunID = subjectRunID
        self.subjectWorkflowID = subjectWorkflowID
        self.investigationType = investigationType
        self.reportArtifactHash = reportArtifactHash
        self.created = created
    }
}

/// Reference to evidence used in forensic investigation
public struct ForensicEvidenceComponent: Codable, Sendable {
    public let reportID: UUID
    public let evidenceType: EvidenceType
    public let referenceID: String  // receiptID, eventID, chunkHash, etc
    public let evidenceHash: String?
    public let description: String?

    public enum EvidenceType: String, Codable, Sendable {
        case preflightSearchEvent
        case postflightOutcomeEvent
        case executionReceipt
        case planArtifact
        case contextChunk
        case environmentSnapshot
        case indexStateSnapshot
        case comparisonRunReceipt
    }

    public init(
        reportID: UUID,
        evidenceType: EvidenceType,
        referenceID: String,
        evidenceHash: String? = nil,
        description: String? = nil
    ) {
        self.reportID = reportID
        self.evidenceType = evidenceType
        self.referenceID = referenceID
        self.evidenceHash = evidenceHash
        self.description = description
    }
}

/// Replay linkage between original and replay runs
public struct ReplayLinkageComponent: Codable, Sendable {
    public let originalRunID: UUID
    public let replayRunID: UUID
    public let replayReceiptID: String
    public let reconstructionMethod: String  // "artifact_store_hash_lookup" etc
    public let corpusSnapshotHash: String?
    public let contextSetHash: String  // Hash of chunk hashes returned
    public let created: Date

    public init(
        originalRunID: UUID,
        replayRunID: UUID,
        replayReceiptID: String,
        reconstructionMethod: String,
        corpusSnapshotHash: String?,
        contextSetHash: String,
        created: Date = Date()
    ) {
        self.originalRunID = originalRunID
        self.replayRunID = replayRunID
        self.replayReceiptID = replayReceiptID
        self.reconstructionMethod = reconstructionMethod
        self.corpusSnapshotHash = corpusSnapshotHash
        self.contextSetHash = contextSetHash
        self.created = created
    }
}

/// Root cause hypothesis with explicit evidence backing
public struct RootCauseHypothesisComponent: Codable, Sendable {
    public let reportID: UUID
    public let hypothesisID: UUID
    public let hypothesisType: HypothesisType
    public let ruleID: String  // Which detection rule fired
    public let ruleSpecHash: String  // Hash of rule definition for reproducibility
    public let evidenceReferences: [String]  // References to ForensicEvidenceComponent entries
    public let confidence: Confidence
    public let explanation: String

    public enum HypothesisType: String, Codable, Sendable {
        case missingContext
        case lowQualityContext
        case modelDrift
        case environmentMismatch
        case resourceExhaustion
        case policyViolation
        case corruptedInput
    }

    public enum Confidence: String, Codable, Sendable {
        case high
        case medium
        case low
    }

    public init(
        reportID: UUID,
        hypothesisID: UUID = UUID(),
        hypothesisType: HypothesisType,
        ruleID: String,
        ruleSpecHash: String,
        evidenceReferences: [String],
        confidence: Confidence,
        explanation: String
    ) {
        self.reportID = reportID
        self.hypothesisID = hypothesisID
        self.hypothesisType = hypothesisType
        self.ruleID = ruleID
        self.ruleSpecHash = ruleSpecHash
        self.evidenceReferences = evidenceReferences
        self.confidence = confidence
        self.explanation = explanation
    }
}
