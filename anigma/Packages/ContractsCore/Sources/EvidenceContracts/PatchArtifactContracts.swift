//
//  PatchArtifactContracts.swift
//  ContractsCore
//
//  Contract definition for PatchArtifactContracts in ContractsCore.
//

import FoundationContracts
import GovernanceContracts
import Foundation
import CryptoKit
import AnigmaPrimitives

/// Patch artifact representing a governed code change with full evidence chain.
public struct PatchArtifact: Sendable, Codable {
    /// Unique identifier for this patch (BLAKE3 of normalized diff).
    public let id: String
    /// Unified diff text (normalized).
    public let diff: String
    /// Metadata about the patch creation.
    public let metadata: PatchMetadata
    /// Chain of receipts for each stage of the pipeline.
    public let receipts: [PatchReceipt]
    /// Validation results from fast and full validation packs.
    public let validationResults: ValidationResults?
    /// Evidence references (hashes, timestamps, signatures).
    public let evidenceRefs: [EvidenceRef]
    /// Rollback information if applicable.
    public let rollbackInfo: RollbackInfo?

    public init(
        id: String,
        diff: String,
        metadata: PatchMetadata,
        receipts: [PatchReceipt],
        validationResults: ValidationResults? = nil,
        evidenceRefs: [EvidenceRef] = [],
        rollbackInfo: RollbackInfo? = nil
    ) {
        self.id = id
        self.diff = diff
        self.metadata = metadata
        self.receipts = receipts
        self.validationResults = validationResults
        self.evidenceRefs = evidenceRefs
        self.rollbackInfo = rollbackInfo
    }
}

/// Metadata about patch creation.
public struct PatchMetadata: Sendable, Codable {
    /// Agent that created the patch.
    public let author: String
    /// Timestamp of creation.
    public let createdAt: Date
    /// Phase ID this patch belongs to.
    public let phaseId: String
    /// Acceptance criteria references.
    public let acceptanceRefs: [String]
    /// Description of the change.
    public let description: String
    /// Risk notes.
    public let riskNotes: String?
    /// Trust tier required.
    public let trustTier: TrustTier
    /// Security zone.
    public let securityZone: SecurityZone

    public init(
        author: String,
        createdAt: Date,
        phaseId: String,
        acceptanceRefs: [String],
        description: String,
        riskNotes: String? = nil,
        trustTier: TrustTier,
        securityZone: SecurityZone
    ) {
        self.author = author
        self.createdAt = createdAt
        self.phaseId = phaseId
        self.acceptanceRefs = acceptanceRefs
        self.description = description
        self.riskNotes = riskNotes
        self.trustTier = trustTier
        self.securityZone = securityZone
    }
}

/// PlatformReceipt for a pipeline stage.
public struct PatchReceipt: Sendable, Codable {
    /// Stage of the pipeline.
    public let stage: PatchStage
    /// Timestamp.
    public let timestamp: Date
    /// Status (success/failure).
    public let status: PatchReceiptStatus
    /// Details (free-form).
    public let details: [String: String]
    /// Evidence references for this stage.
    public let evidenceRefs: [EvidenceRef]
    /// Hash of the receipt for integrity.
    public let receiptHash: String

    public init(
        stage: PatchStage,
        timestamp: Date,
        status: PatchReceiptStatus,
        details: [String: String] = [:],
        evidenceRefs: [EvidenceRef] = [],
        receiptHash: String
    ) {
        self.stage = stage
        self.timestamp = timestamp
        self.status = status
        self.details = details
        self.evidenceRefs = evidenceRefs
        self.receiptHash = receiptHash
    }
}

/// Stage in the patch production pipeline.
public enum PatchStage: String, Sendable, Codable, CaseIterable {
    case inspection = "inspection"
    case generation = "generation"
    case proposal = "proposal"
    case validation = "validation"
    case approval = "approval"
    case merge = "merge"
    case rollback = "rollback"
    case quarantine = "quarantine"
}

/// Status of a receipt.
public enum PatchReceiptStatus: String, Sendable, Codable {
    case pending = "pending"
    case success = "success"
    case failure = "failure"
    case quarantined = "quarantined"
}

/// Validation results from fast and full validation packs.
public struct ValidationResults: Sendable, Codable {
    /// Fast validation results (quick checks).
    public let fast: ValidationPackResult
    /// Full validation results (comprehensive gates).
    public let full: ValidationPackResult?
    /// Overall verdict.
    public let verdict: ValidationVerdict

    public init(fast: ValidationPackResult, full: ValidationPackResult? = nil, verdict: ValidationVerdict) {
        self.fast = fast
        self.full = full
        self.verdict = verdict
    }
}

/// Result of a validation pack execution.
public struct ValidationPackResult: Sendable, Codable {
    /// Name of the validation pack (e.g., "fast", "full").
    public let packName: String
    /// Timestamp of execution.
    public let timestamp: Date
    /// Did the pack pass?
    public let passed: Bool
    /// Details of each check.
    public let checks: [ValidationCheck]
    /// Evidence references.
    public let evidenceRefs: [EvidenceRef]

    public init(
        packName: String,
        timestamp: Date,
        passed: Bool,
        checks: [ValidationCheck],
        evidenceRefs: [EvidenceRef] = []
    ) {
        self.packName = packName
        self.timestamp = timestamp
        self.passed = passed
        self.checks = checks
        self.evidenceRefs = evidenceRefs
    }
}

/// Individual validation check.
public struct ValidationCheck: Sendable, Codable {
    public let name: String
    public let passed: Bool
    public let message: String?
    public let evidenceRefs: [EvidenceRef]

    public init(name: String, passed: Bool, message: String? = nil, evidenceRefs: [EvidenceRef] = []) {
        self.name = name
        self.passed = passed
        self.message = message
        self.evidenceRefs = evidenceRefs
    }
}

/// Overall validation verdict.
public enum ValidationVerdict: String, Sendable, Codable {
    case approved = "approved"
    case rejected = "rejected"
    case needsHumanReview = "needs_human_review"
    case quarantined = "quarantined"
}

/// Rollback information.
public struct RollbackInfo: Sendable, Codable {
    /// Whether rollback is possible.
    public let possible: Bool
    /// Complexity of rollback.
    public let complexity: RollbackComplexity
    /// Steps to rollback.
    public let steps: [String]
    /// Evidence of rollback execution.
    public let evidenceRefs: [EvidenceRef]

    public init(
        possible: Bool,
        complexity: RollbackComplexity,
        steps: [String] = [],
        evidenceRefs: [EvidenceRef] = []
    ) {
        self.possible = possible
        self.complexity = complexity
        self.steps = steps
        self.evidenceRefs = evidenceRefs
    }
}

// MARK: - Contracts

/// Contract for validating patch artifacts.
public struct PatchArtifactContract: WorkflowContract {
    public static let id = ContractID(
        name: "maker.patch.artifact",
        major: 1,
        minor: 0,
        schemaHash: "v1.0"
    )

    public let payload: PatchArtifact

    public init(_ payload: PatchArtifact) {
        self.payload = payload
    }

    public static func validateInvariants(_ value: PatchArtifactContract) throws {
        // Validate that patch ID matches diff hash.
        let diffHash = blake3Hex(value.payload.diff)
        guard diffHash == value.payload.id else {
            throw ValidationError.invalidRequest("Patch ID must be BLAKE3 of normalized diff")
        }

        // Validate that at least inspection receipt exists.
        let hasInspection = value.payload.receipts.contains { $0.stage == .inspection }
        guard hasInspection else {
            throw ValidationError.invalidRequest("Patch must have at least an inspection receipt")
        }

        // Validate that receipts are in correct order (if multiple).
        let stages = value.payload.receipts.map { $0.stage }
        let sortedStages = stages.sorted { $0.orderIndex < $1.orderIndex }
        guard stages == sortedStages else {
            throw ValidationError.invalidRequest("Receipts must be in pipeline order")
        }

        // Validate that validation results match verdict.
        if let validation = value.payload.validationResults {
            if validation.verdict == .approved {
                guard validation.fast.passed else {
                    throw ValidationError.invalidRequest("Fast validation must pass for approved verdict")
                }
                if let full = validation.full {
                    guard full.passed else {
                        throw ValidationError.invalidRequest("Full validation must pass for approved verdict")
                    }
                }
            }
        }
    }
}

extension PatchStage {
    /// Order index for pipeline sequencing.
    var orderIndex: Int {
        switch self {
        case .inspection: return 0
        case .generation: return 1
        case .proposal: return 2
        case .validation: return 3
        case .approval: return 4
        case .merge: return 5
        case .rollback: return 6
        case .quarantine: return 7
        }
    }
}

/// Helper function - now uses BLAKE3 for Saturated Architecture.
private func blake3Hex(_ string: String) -> String {
    let data = Data(string.utf8)
    return BLAKE3Digest.hex(of: data)
}
