//
//  EvidenceContracts.swift
//  ContractsCore
//
//  Canonical evidence types for Cathedral coordination and evidence enforcement
//  These are single source of truth for all evidence-related contracts
//

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

/// Receipt for optimization evidence
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

/// Receipt for optimization history
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