//
//  EvidenceContracts.swift
//  ContractsCore
//
//  Canonical evidence types for Cathedral coordination and evidence enforcement
//  These are single source of truth for all evidence-related contracts
//

import FoundationContracts
import GovernanceContracts
import AnigmaPrimitives
import Foundation

// MARK: - Core Evidence Types

/// Evidence confidence levels for Cathedral coordination requirements
/// Status of evidence collection
public enum EvidenceStatus: String, Sendable, Codable, CaseIterable {
    case pending = "pending"
    case collecting = "collecting"
    case insufficient = "insufficient"
    case adequate = "adequate"
    case strong = "strong"
    case verified = "verified"
    case expired = "expired"
    case corrupted = "corrupted"
}

/// Represents minimum evidence quality required for operations
public enum EvidenceRequirement: String, Sendable, Codable, CaseIterable {
    case none = "none"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case strict = "strict"

    /// Numeric level for comparison (higher = more stringent)
    public var level: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .moderate: return 2
        case .high: return 3
        case .strict: return 4
        }
    }

    public static func < (lhs: EvidenceRequirement, rhs: EvidenceRequirement) -> Bool {
        return lhs.level < rhs.level
    }

    public static func <= (lhs: EvidenceRequirement, rhs: EvidenceRequirement) -> Bool {
        return lhs.level <= rhs.level
    }

    public static func > (lhs: EvidenceRequirement, rhs: EvidenceRequirement) -> Bool {
        return lhs.level > rhs.level
    }

    public static func >= (lhs: EvidenceRequirement, rhs: EvidenceRequirement) -> Bool {
        return lhs.level >= rhs.level
    }
}

/// Represents current state of evidence after analysis
public struct EvidenceState: Sendable, Codable {
    public let status: EvidenceStatus
    public let confidence: Double
    public let requirements: [EvidenceRequirement]
    public let collectedAt: Date
    public let expiresAt: Date?

    public init(
        status: EvidenceStatus,
        confidence: Double = 0.0,
        requirements: [EvidenceRequirement] = [],
        collectedAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.status = status
        self.confidence = confidence
        self.requirements = requirements
        self.collectedAt = collectedAt
        self.expiresAt = expiresAt
    }
}

// MARK: - Operation Status

/// Operation execution status - runtime state of operations
/// Different from EvidenceStatus - this is about operation completion, not evidence quality
public enum OperationExecutionStatus: String, Sendable, Codable, CaseIterable {
    case started = "started"
    case success = "success"
    case failed = "failed"
    case blocked = "blocked"
    case unknown = "unknown"

    /// Whether operation completed successfully
    public var isSuccessful: Bool {
        return self == .success
    }

    /// Whether operation completed (successfully or not)
    public var isCompleted: Bool {
        return self == .success || self == .failed || self == .blocked
    }

    /// Whether operation is still running
    public var isRunning: Bool {
        return self == .started
    }
}

// MARK: - Evidence Validation

/// Evidence validation result
public struct EvidenceValidationResult: Sendable, Codable {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]

    public init(isValid: Bool, errors: [String] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

/// Evidence validation modes for Cathedral coordination
/// Controls how strict evidence validation should be
public enum EvidenceValidationMode: String, Sendable, Codable, CaseIterable {
    case strict = "strict"
    case lenient = "lenient"
    case auditOnly = "audit_only"

    /// Whether this mode allows operations with minor violations
    public var allowsMinorViolations: Bool {
        return self == .lenient
    }

    /// Whether this mode blocks execution on any violation
    public var blocksOnAnyViolation: Bool {
        return self == .strict
    }
}

// MARK: - Evidence Violations

/// Evidence chain violation types for Cathedral coordination
/// Represents specific ways evidence integrity can be compromised
public enum EvidenceViolationType: String, Sendable, Codable, CaseIterable {
    case hashMismatch = "hash_mismatch"
    case brokenChain = "broken_chain"
    case missingEvidence = "missing_evidence"
    case tamperedEvidence = "tampered_evidence"
    case invalidTimestamp = "invalid_timestamp"
    case unauthorizedModification = "unauthorized_modification"
    case expiredEvidence = "expired_evidence"
    case insufficientEvidence = "insufficient_evidence"
    case requirementMismatch = "requirement_mismatch"
}

/// Evidence violation severity levels
/// Determines automatic response actions in Cathedral coordination
public enum EvidenceViolationSeverity: String, Sendable, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    /// Numeric severity for automated decision making
    public var level: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    /// Whether this severity should trigger automatic blocking
    public var requiresBlocking: Bool {
        return self == .high || self == .critical
    }

    /// Whether this severity should trigger immediate quarantine
    public var requiresQuarantine: Bool {
        return self == .critical
    }
}

/// Specific evidence violation instance
public struct EvidenceViolation: Sendable, Codable {
    public let type: EvidenceViolationType
    public let severity: EvidenceViolationSeverity
    public let description: String
    public let evidenceId: String?
    public let timestamp: Date

    public init(
        type: EvidenceViolationType,
        severity: EvidenceViolationSeverity,
        description: String,
        evidenceId: String? = nil,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.severity = severity
        self.description = description
        self.evidenceId = evidenceId
        self.timestamp = timestamp
    }
}

// MARK: - Evidence Receipts

/// PlatformReceipt for optimization evidence
public struct EvidenceReceipt: Sendable, Codable {
    public let receiptId: String
    public let stepId: String
    public let sessionId: String
    public let workflowId: String
    public let optimizationProfile: String
    public let evidenceRequirement: EvidenceRequirement
    public let operationStatus: OperationExecutionStatus
    public let confidence: Double
    public let createdAt: Date
    public let metadata: [String: String]

    public init(
        receiptId: String,
        stepId: String,
        sessionId: String,
        workflowId: String,
        optimizationProfile: String,
        evidenceRequirement: EvidenceRequirement,
        operationStatus: OperationExecutionStatus,
        confidence: Double,
        createdAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.receiptId = receiptId
        self.stepId = stepId
        self.sessionId = sessionId
        self.workflowId = workflowId
        self.optimizationProfile = optimizationProfile
        self.evidenceRequirement = evidenceRequirement
        self.operationStatus = operationStatus
        self.confidence = confidence
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

public struct EvidencePayloadReference: Sendable, Codable, Hashable {
    public let payloadId: String
    public let payloadHash: String
    public let redactedMetadata: [String: String]

    public init(payloadId: String, payloadHash: String, redactedMetadata: [String: String] = [:]) {
        self.payloadId = payloadId
        self.payloadHash = payloadHash
        self.redactedMetadata = redactedMetadata
    }
}

public enum EvidenceDeletionReason: String, Sendable, Codable {
    case userRequest
    case retentionExpiry
    case legalHold
    case cryptoShred
    case policyViolation
}

public struct EvidenceTombstone: Sendable, Codable {
    public let tombstoneId: String
    public let payloadReference: EvidencePayloadReference
    public let reason: EvidenceDeletionReason
    public let retentionPolicy: RetentionPolicy
    public let legalHold: Bool
    public let deletedAt: Date

    public init(
        tombstoneId: String = UUID().uuidString,
        payloadReference: EvidencePayloadReference,
        reason: EvidenceDeletionReason,
        retentionPolicy: RetentionPolicy,
        legalHold: Bool,
        deletedAt: Date = Date()
    ) {
        self.tombstoneId = tombstoneId
        self.payloadReference = payloadReference
        self.reason = reason
        self.retentionPolicy = retentionPolicy
        self.legalHold = legalHold
        self.deletedAt = deletedAt
    }
}

public struct PrivacyPreservingEvidenceReceipt: Sendable, Codable {
    public let receiptId: String
    public let descriptorHash: String
    public let payloadReferences: [EvidencePayloadReference]
    public let tombstones: [EvidenceTombstone]
    public let metadata: [String: String]
    public let createdAt: Date

    public init(
        receiptId: String = UUID().uuidString,
        descriptorHash: String,
        payloadReferences: [EvidencePayloadReference] = [],
        tombstones: [EvidenceTombstone] = [],
        metadata: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.receiptId = receiptId
        self.descriptorHash = descriptorHash
        self.payloadReferences = payloadReferences
        self.tombstones = tombstones
        self.metadata = metadata
        self.createdAt = createdAt
    }

    public var containsRawSensitivePayload: Bool { false }
}

/// PlatformReceipt for optimization history
public struct OptimizationReceipt: Sendable, Codable {
    public let receiptId: String
    public let stepId: String
    public let optimizationType: String
    public let beforeMetrics: [String: Double]
    public let afterMetrics: [String: Double]
    public let improvementScore: Double
    public let timestamp: Date

    public init(
        receiptId: String,
        stepId: String,
        optimizationType: String,
        beforeMetrics: [String: Double],
        afterMetrics: [String: Double],
        improvementScore: Double,
        timestamp: Date = Date()
    ) {
        self.receiptId = receiptId
        self.stepId = stepId
        self.optimizationType = optimizationType
        self.beforeMetrics = beforeMetrics
        self.afterMetrics = afterMetrics
        self.improvementScore = improvementScore
        self.timestamp = timestamp
    }
}

// MARK: - Audit Trail Protocols

/// Hook for MAKER optimization audit trail integration
public protocol MakerOptimizationAuditTrail: Sendable {
    /// Record optimization step with evidence receipt
    func recordOptimizationStep(
        stepId: String,
        optimizationProfile: String,
        originalCandidate: String,
        optimizedCandidate: String,
        evidenceRequirement: EvidenceRequirement
    ) async throws -> EvidenceReceipt
    
    /// Get optimization history for analysis
    func getOptimizationHistory(stepId: String) async -> [OptimizationReceipt]
}

// MARK: - Contract Requirements

/// Evidence requirement contract for Cathedral operations
/// Defines what evidence is needed before operations can proceed
public struct EvidenceRequirementContract: Sendable, Codable {
    public let requirement: EvidenceRequirement
    public let validationMode: EvidenceValidationMode
    public let allowedViolationTypes: [EvidenceViolationType]
    public let maxViolationSeverity: EvidenceViolationSeverity
    public let gracePeriodSeconds: Int

    public init(
        requirement: EvidenceRequirement,
        validationMode: EvidenceValidationMode = .strict,
        allowedViolationTypes: [EvidenceViolationType] = [],
        maxViolationSeverity: EvidenceViolationSeverity = .medium,
        gracePeriodSeconds: Int = 0
    ) {
        self.requirement = requirement
        self.validationMode = validationMode
        self.allowedViolationTypes = allowedViolationTypes
        self.maxViolationSeverity = maxViolationSeverity
        self.gracePeriodSeconds = gracePeriodSeconds
    }
}

/// Extended evidence validation result with current status
public struct ExtendedEvidenceValidationResult: Sendable, Codable {
    public let isValid: Bool
    public let currentStatus: EvidenceStatus
    public let requirement: EvidenceRequirement
    public let violations: [EvidenceViolation]

    public init(
        isValid: Bool,
        currentStatus: EvidenceStatus,
        requirement: EvidenceRequirement,
        violations: [EvidenceViolation] = []
    ) {
        self.isValid = isValid
        self.currentStatus = currentStatus
        self.requirement = requirement
        self.violations = violations
    }
}

// MARK: - Evidence Ring (MMR) Architecture

/// Represents a tamper-evident collection of evidence secured by a BLAKE3 Merkle Mountain Range.
/// The MMR structure allows for efficient O(log N) proofs of inclusion and append-only integrity.
public struct EvidenceRing: Sendable, Codable {
    /// Unique identifier for this evidence ring (e.g., associated with a specific Project or Session).
    public let ringId: String
    
    /// The current set of MMR peak hashes. Peaks represent the roots of the perfect Merkle trees
    /// that compose the mountain range.
    public let peaks: [String]
    
    /// The aggregate root hash of the evidence ring (BLAKE3 hash of all peaks and ring metadata).
    /// This is the "Evidence Ring Root" used for global state attestation.
    public let rootHash: String
    
    /// Total number of leaf entries (evidence items) in the ring.
    public let size: Int
    
    /// The policy used for hashing (mandated: blake3Tier1V2).
    public let hashingPolicy: String
    
    /// When the ring was last extended or rotated.
    public let updatedAt: Date
    
    /// Optional metadata about the ring's purpose or governance context.
    public let metadata: [String: String]

    public init(
        ringId: String = UUID().uuidString,
        peaks: [String] = [],
        rootHash: String = "",
        size: Int = 0,
        hashingPolicy: String = "blake3Tier1V2",
        updatedAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.ringId = ringId
        self.peaks = peaks
        self.rootHash = rootHash
        self.size = size
        self.hashingPolicy = hashingPolicy
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

/// A leaf entry in the EvidenceRing representing a single piece of cryptographic proof.
public struct EvidenceRingEntry: Sendable, Codable {
    /// The BLAKE3 hash of the evidence payload or receipt.
    public let evidenceHash: String
    
    /// Reference to the underlying EvidenceReceipt or PrivacyPreservingEvidenceReceipt.
    public let receiptId: String
    
    /// The absolute position in the MMR leaf sequence (0-indexed).
    public let leafIndex: Int
    
    /// Attestation timestamp.
    public let timestamp: Date
    
    public init(
        evidenceHash: String,
        receiptId: String,
        leafIndex: Int,
        timestamp: Date = Date()
    ) {
        self.evidenceHash = evidenceHash
        self.receiptId = receiptId
        self.leafIndex = leafIndex
        self.timestamp = timestamp
    }
}

/// Proof that a media operation maintained or explicitly accounted for data copies.
/// Every media operation must produce a MediaCopyProof indicating whether zero-copy
/// continuity was maintained or a materialization occurred.
public struct MediaCopyProof: Sendable, Codable, Hashable {
    /// The token being proven.
    public let token: String
    
    /// Number of bytes copied (0 if perfect zero-copy).
    public let copiedBytes: Int64
    
    /// Timestamp of the operation.
    public let timestamp: Date
    
    /// The media operation that was performed.
    public let operation: String
    
    /// Events emitted during the operation (for audit trail).
    public let events: [String]
    
    /// Whether this operation was zero-copy.
    public var isZeroCopy: Bool {
        return copiedBytes == 0
    }
    
    public init(
        token: String,
        copiedBytes: Int64 = 0,
        timestamp: Date = Date(),
        operation: String,
        events: [String] = []
    ) {
        self.token = token
        self.copiedBytes = copiedBytes
        self.timestamp = timestamp
        self.operation = operation
        self.events = events
    }
}

/// A cryptographic proof of inclusion for an entry within an EvidenceRing.
public struct EvidenceInclusionProof: Sendable, Codable {
    /// The leaf index of the entry being proven.
    public let leafIndex: Int
    
    /// The sibling hashes along the path from leaf to the corresponding MMR peak.
    public let path: [String]
    
    /// The peak hash that this path reconstructs.
    public let peakHash: String
    
    /// The MMR root hash this proof verifies against.
    public let rootHash: String
    
    public init(leafIndex: Int, path: [String], peakHash: String, rootHash: String) {
        self.leafIndex = leafIndex
        self.path = path
        self.peakHash = peakHash
        self.rootHash = rootHash
    }
}

// MARK: - Evidence Ring Protocols

/// Interface for managing EvidenceRings within the Anigma ecosystem.
public protocol EvidenceRingProvider: Sendable {
    /// Get the current state of an evidence ring.
    func getRing(ringId: String) async throws -> EvidenceRing?
    
    /// Append a new evidence entry to the ring, updating its MMR root.
    func appendEvidence(
        ringId: String,
        evidenceHash: String,
        receiptId: String
    ) async throws -> EvidenceRingEntry
    
    /// Generate an inclusion proof for a specific evidence hash in a ring.
    func generateProof(ringId: String, evidenceHash: String) async throws -> EvidenceInclusionProof
    
    /// Verify an inclusion proof against a known ring root.
    func verifyProof(_ proof: EvidenceInclusionProof, rootHash: String) async throws -> Bool
}

// MARK: - Receipt Signing Contract

/// Protocol for cryptographic signing of receipts.
/// This is the Tier 1 contract surface extracted from ExecutionCore.
/// Concrete implementations live in appropriate runtime/execution layers.
///
/// This protocol is safe for Tier 1 because:
/// - Uses only portable Foundation types (Data, String)
/// - Uses only Swift standard conformances (Sendable)
/// - No runtime, Apple, database, daemon, or execution-layer types
public protocol ReceiptSigner: Sendable {
    /// Signs the data and returns base64-encoded signature
    func sign(data: Data) async throws -> String

    /// Verifies the signature for the provided data.
    func verify(data: Data, signature: String) async throws -> Bool

    /// Unique identifier for this signer
    var signerID: String { get }
}

