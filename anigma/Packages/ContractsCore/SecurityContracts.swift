//
//  SecurityContracts.swift
//  ContractsCore
//
//  Contract definition for SecurityContracts in ContractsCore.
//

import Foundation

// MARK: - Evidence Head Types

/// Information about an evidence head for transport and verification
public struct EvidenceHeadInfo: Sendable, Codable {
    public let eventId: String
    public let headHash: String
    public let timestamp: Int
    public let lastActor: String

    public init(eventId: String, headHash: String, timestamp: Int, lastActor: String) {
        self.eventId = eventId
        self.headHash = headHash
        self.timestamp = timestamp
        self.lastActor = lastActor
    }

private enum CodingKeys: String, CodingKey {
        case eventId, headHash, timestamp, lastActor
    }
}

// MARK: - Evidence Bundle Types

/// Evidence bundle for transport and verification
public struct EvidenceBundle: Sendable, Codable {
    public let id: String
    public let bundleType: String
    public let description: String
    public let createdAt: Int
    public let createdBy: String
    public let artifactPaths: [String]

    public init(
        id: String,
        bundleType: String,
        description: String,
        createdAt: Int,
        createdBy: String,
        artifactPaths: [String]
    ) {
        self.id = id
        self.bundleType = bundleType
        self.description = description
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.artifactPaths = artifactPaths
    }

    private enum CodingKeys: String, CodingKey {
        case id, bundleType, description, createdAt, createdBy, artifactPaths
    }
}

/// Redaction plan for transport and verification
public struct RedactionPlan: Sendable, Codable {
    public let sessionId: String
    public let redactionTargets: [RedactionTarget]
    public let patterns: [RedactionPattern]
    public let privilegeClaims: [PrivilegeClaim]
    public let requestedBy: String
    public let authorizedBy: String
    public let legalHoldReference: String?
    public let createdAt: Int

    public init(
        sessionId: String,
        redactionTargets: [RedactionTarget],
        patterns: [RedactionPattern],
        privilegeClaims: [PrivilegeClaim],
        requestedBy: String,
        authorizedBy: String,
        legalHoldReference: String? = nil,
        createdAt: Int
    ) {
        self.sessionId = sessionId
        self.redactionTargets = redactionTargets
        self.patterns = patterns
        self.privilegeClaims = privilegeClaims
        self.requestedBy = requestedBy
        self.authorizedBy = authorizedBy
        self.legalHoldReference = legalHoldReference
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId, redactionTargets, patterns, privilegeClaims
        case requestedBy, authorizedBy, legalHoldReference, createdAt
    }
}

/// Redaction target for transport and verification
public struct RedactionTarget: Sendable, Codable {
    public let documentId: String
    public let componentPath: String
    public let redactions: [ContentRedaction]

    public init(
        documentId: String,
        componentPath: String,
        redactions: [ContentRedaction]
    ) {
        self.documentId = documentId
        self.componentPath = componentPath
        self.redactions = redactions
    }

    private enum CodingKeys: String, CodingKey {
        case documentId, componentPath, redactions
    }
}

/// Content redaction action for transport and verification
public struct ContentRedaction: Sendable, Codable {
    public let redactionId: String
    public let startIndex: Int
    public let endIndex: Int
    public let replacementCharacter: String
    public let pattern: String?
    public let reason: String

    public init(
        redactionId: String,
        startIndex: Int,
        endIndex: Int,
        replacementCharacter: String,
        pattern: String? = nil,
        reason: String
    ) {
        self.redactionId = redactionId
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.replacementCharacter = replacementCharacter
        self.pattern = pattern
        self.reason = reason
    }

    private enum CodingKeys: String, CodingKey {
        case redactionId, startIndex, endIndex, replacementCharacter, pattern, reason
    }
}

/// Redaction pattern for transport and verification
public struct RedactionPattern: Sendable, Codable {
    public let id: String
    public let name: String
    public let regex: String
    public let description: String
    public let privilegeRequired: Bool
    public let approvedBy: String
    public let approvedAt: Int

    public init(
        id: String,
        name: String,
        regex: String,
        description: String,
        privilegeRequired: Bool,
        approvedBy: String,
        approvedAt: Int
    ) {
        self.id = id
        self.name = name
        self.regex = regex
        self.description = description
        self.privilegeRequired = privilegeRequired
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, regex, description, privilegeRequired, approvedBy, approvedAt
    }
}

public extension RedactionPattern {
    static var defaultPatterns: [RedactionPattern] {
        [
            RedactionPattern(
                id: "ssn",
                name: "Social Security Number",
                regex: "\\b\\d{3}-?\\d{2}-?\\d{4}\\b",
                description: "US Social Security Numbers",
                privilegeRequired: true,
                approvedBy: "legal_counsel",
                approvedAt: 1640995200
            ),
            RedactionPattern(
                id: "email",
                name: "Email Address",
                regex: "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b",
                description: "Email addresses",
                privilegeRequired: false,
                approvedBy: "privacy_officer",
                approvedAt: 1640995200
            ),
            RedactionPattern(
                id: "phone",
                name: "Phone Number",
                regex: "\\b(?:\\+?1[-.\\s]?)?\\(?([0-9]{3})\\)?[-.\\s]?([0-9]{3})[-.\\s]?([0-9]{4})\\b",
                description: "US phone numbers",
                privilegeRequired: true,
                approvedBy: "legal_counsel",
                approvedAt: 1640995200
            )
        ]
    }
}

/// Verification status for evidence signatures
public enum VerificationStatus: String, Sendable, Codable {
    case pending = "pending"
    case verified = "verified"
    case failed = "failed"
    case revoked = "revoked"
    case expired = "expired"
}

// MARK: - Bundle Manifest Types

/// Redacted bundle manifest for transport and verification
public struct RedactedBundleManifest: Sendable, Codable {
    public let bundleId: String
    public let originalBundleId: String
    public let redactionSessionId: String
    public let bundleType: String
    public let description: String
    public let purpose: String
    public let createdAt: Int
    public let createdBy: String
    public let originalManifestHash: String
    public let redactedComponentHashes: [String: String]
    public let auditTrailHash: String

    public init(
        bundleId: String,
        originalBundleId: String,
        redactionSessionId: String,
        bundleType: String,
        description: String,
        purpose: String,
        createdAt: Int,
        createdBy: String,
        originalManifestHash: String,
        redactedComponentHashes: [String: String],
        auditTrailHash: String
    ) {
        self.bundleId = bundleId
        self.originalBundleId = originalBundleId
        self.redactionSessionId = redactionSessionId
        self.bundleType = bundleType
        self.description = description
        self.purpose = purpose
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.originalManifestHash = originalManifestHash
        self.redactedComponentHashes = redactedComponentHashes
        self.auditTrailHash = auditTrailHash
    }

    private enum CodingKeys: String, CodingKey {
        case bundleId, originalBundleId, redactionSessionId, bundleType
        case description, purpose, createdAt, createdBy, originalManifestHash
        case redactedComponentHashes, auditTrailHash
    }
}

/// Privilege log for transport and verification
public struct PrivilegeLog: Sendable, Codable {
    public let sessionId: String
    public let privilegeClaims: [PrivilegeClaim]
    public let requestedBy: String
    public let authorizedBy: String
    public let legalHoldReference: String?
    public let createdAt: Int

    public init(
        sessionId: String,
        privilegeClaims: [PrivilegeClaim],
        requestedBy: String,
        authorizedBy: String,
        legalHoldReference: String? = nil,
        createdAt: Int
    ) {
        self.sessionId = sessionId
        self.privilegeClaims = privilegeClaims
        self.requestedBy = requestedBy
        self.authorizedBy = authorizedBy
        self.legalHoldReference = legalHoldReference
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId, privilegeClaims, requestedBy, authorizedBy
        case legalHoldReference, createdAt
    }
}

/// Redaction verification result for transport and verification
public struct RedactionVerificationResult: Sendable, Codable {
    public let redactedBundleId: String
    public let verificationStatus: String
    public let verifications: [RedactionVerification]
    public let discrepancies: [RedactionDiscrepancy]

    public init(
        redactedBundleId: String,
        verificationStatus: String,
        verifications: [RedactionVerification],
        discrepancies: [RedactionDiscrepancy]
    ) {
        self.redactedBundleId = redactedBundleId
        self.verificationStatus = verificationStatus
        self.verifications = verifications
        self.discrepancies = discrepancies
    }

    private enum CodingKeys: String, CodingKey {
        case redactedBundleId, verificationStatus, verifications, discrepancies
    }
}

/// Redacted bundle with metadata and audit trail
public struct RedactedBundle: Sendable, Codable {
    public let originalBundleId: String
    public let redactedBundleId: String
    public let redactionSessionId: String
    public let redactedComponents: [RedactedComponent]
    public let redactionAuditTrail: RedactionAuditTrail
    public let redactedManifest: RedactedBundleManifest
    public let bundleSignature: BundleSignature
    public let createdAt: Int

    public init(
        originalBundleId: String,
        redactedBundleId: String,
        redactionSessionId: String,
        redactedComponents: [RedactedComponent],
        redactionAuditTrail: RedactionAuditTrail,
        redactedManifest: RedactedBundleManifest,
        bundleSignature: BundleSignature,
        createdAt: Int
    ) {
        self.originalBundleId = originalBundleId
        self.redactedBundleId = redactedBundleId
        self.redactionSessionId = redactionSessionId
        self.redactedComponents = redactedComponents
        self.redactionAuditTrail = redactionAuditTrail
        self.redactedManifest = redactedManifest
        self.bundleSignature = bundleSignature
        self.createdAt = createdAt
    }
}

/// Component-level redaction record
public struct RedactedComponent: Sendable, Codable {
    public let originalComponentId: String
    public let componentPath: String
    public let originalContent: String
    public let redactedContent: String
    public let redactionResult: RedactionResult
    public let redactedAt: Int

    public init(
        originalComponentId: String,
        componentPath: String,
        originalContent: String,
        redactedContent: String,
        redactionResult: RedactionResult,
        redactedAt: Int
    ) {
        self.originalComponentId = originalComponentId
        self.componentPath = componentPath
        self.originalContent = originalContent
        self.redactedContent = redactedContent
        self.redactionResult = redactionResult
        self.redactedAt = redactedAt
    }
}

/// Redaction outcome per component
public struct RedactionResult: Sendable, Codable {
    public let documentUnitId: String
    public let sessionId: String
    public let originalContent: String
    public let redactedContent: String
    public let appliedRedactions: [AppliedRedaction]
    public let redactionMetrics: RedactionMetrics
    public let appliedBy: String
    public let appliedAt: Int

    public init(
        documentUnitId: String,
        sessionId: String,
        originalContent: String,
        redactedContent: String,
        appliedRedactions: [AppliedRedaction],
        redactionMetrics: RedactionMetrics,
        appliedBy: String,
        appliedAt: Int
    ) {
        self.documentUnitId = documentUnitId
        self.sessionId = sessionId
        self.originalContent = originalContent
        self.redactedContent = redactedContent
        self.appliedRedactions = appliedRedactions
        self.redactionMetrics = redactionMetrics
        self.appliedBy = appliedBy
        self.appliedAt = appliedAt
    }
}

/// Individual applied redaction detail
public struct AppliedRedaction: Sendable, Codable {
    public let redactionId: String
    public let startIndex: Int
    public let endIndex: Int
    public let originalText: String
    public let redactionText: String
    public let reason: String
    public let pattern: String?
    public let appliedAt: Int

    public init(
        redactionId: String,
        startIndex: Int,
        endIndex: Int,
        originalText: String,
        redactionText: String,
        reason: String,
        pattern: String? = nil,
        appliedAt: Int
    ) {
        self.redactionId = redactionId
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.originalText = originalText
        self.redactionText = redactionText
        self.reason = reason
        self.pattern = pattern
        self.appliedAt = appliedAt
    }
}

/// Metrics describing the redaction operation
public struct RedactionMetrics: Sendable, Codable {
    public let originalLength: Int
    public let redactedLength: Int
    public let redactionCount: Int
    public let redactionPercentage: Double

    public init(
        originalLength: Int,
        redactedLength: Int,
        redactionCount: Int,
        redactionPercentage: Double
    ) {
        self.originalLength = originalLength
        self.redactedLength = redactedLength
        self.redactionCount = redactionCount
        self.redactionPercentage = redactionPercentage
    }
}

/// Audit trail capturing a redaction session
public struct RedactionAuditTrail: Sendable, Codable {
    public let sessionId: String
    public let originalBundleId: String
    public let redactionPlan: RedactionPlan
    public let redactedComponents: [RedactedComponent]
    public let requestedBy: String
    public let authorizedBy: String
    public let legalHoldReference: String?
    public let privilegeLog: PrivilegeLog?
    public let createdAt: Int

    public init(
        sessionId: String,
        originalBundleId: String,
        redactionPlan: RedactionPlan,
        redactedComponents: [RedactedComponent],
        requestedBy: String,
        authorizedBy: String,
        legalHoldReference: String? = nil,
        privilegeLog: PrivilegeLog? = nil,
        createdAt: Int
    ) {
        self.sessionId = sessionId
        self.originalBundleId = originalBundleId
        self.redactionPlan = redactionPlan
        self.redactedComponents = redactedComponents
        self.requestedBy = requestedBy
        self.authorizedBy = authorizedBy
        self.legalHoldReference = legalHoldReference
        self.privilegeLog = privilegeLog
        self.createdAt = createdAt
    }
}

/// Signature of bundle manifest
public struct BundleSignature: Sendable, Codable {
    public let signatureId: String
    public let bundleId: String
    public let manifestHash: String
    public let signerIdentity: String
    public let signerRole: String
    public let exportPurpose: String
    public let signingTimestamp: Int
    public let keyFingerprint: String
    public let signatureData: String

    public init(
        signatureId: String,
        bundleId: String,
        manifestHash: String,
        signerIdentity: String,
        signerRole: String,
        exportPurpose: String,
        signingTimestamp: Int,
        keyFingerprint: String,
        signatureData: String
    ) {
        self.signatureId = signatureId
        self.bundleId = bundleId
        self.manifestHash = manifestHash
        self.signerIdentity = signerIdentity
        self.signerRole = signerRole
        self.exportPurpose = exportPurpose
        self.signingTimestamp = signingTimestamp
        self.keyFingerprint = keyFingerprint
        self.signatureData = signatureData
    }
}

/// Signature verification response
public struct VerificationResult: Sendable, Codable {
    public let isValid: Bool
    public let signerIdentity: String
    public let signerRole: String
    public let keyFingerprint: String
    public let keyStatus: SigningKeyStatus
    public let verificationTimestamp: Int
    public let verificationDetails: String

    public init(
        isValid: Bool,
        signerIdentity: String,
        signerRole: String,
        keyFingerprint: String,
        keyStatus: SigningKeyStatus,
        verificationTimestamp: Int,
        verificationDetails: String
    ) {
        self.isValid = isValid
        self.signerIdentity = signerIdentity
        self.signerRole = signerRole
        self.keyFingerprint = keyFingerprint
        self.keyStatus = keyStatus
        self.verificationTimestamp = verificationTimestamp
        self.verificationDetails = verificationDetails
    }
}

/// Signing key status
public struct SigningKeyStatus: Sendable, Codable {
    public let status: KeyStatusEnum
    public let revokedAt: Int?
    public let revocationReason: String?

    public var isActive: Bool {
        status == .active && revokedAt == nil
    }

    public init(status: KeyStatusEnum, revokedAt: Int? = nil, revocationReason: String? = nil) {
        self.status = status
        self.revokedAt = revokedAt
        self.revocationReason = revocationReason
    }
}

/// Key status enumeration
public enum KeyStatusEnum: String, Sendable, Codable {
    case active = "active"
    case revoked = "revoked"
    case expired = "expired"
}
/// Redaction verification for transport and verification
public struct RedactionVerification: Sendable, Codable {
    public let componentId: String
    public let verificationStatus: String
    public let details: String

    public init(componentId: String, verificationStatus: String, details: String) {
        self.componentId = componentId
        self.verificationStatus = verificationStatus
        self.details = details
    }

    private enum CodingKeys: String, CodingKey {
        case componentId, verificationStatus, details
    }
}

/// Redaction discrepancy for transport and verification
public struct RedactionDiscrepancy: Sendable, Codable {
    public let componentId: String
    public let expectedHash: String
    public let actualHash: String
    public let discrepancyType: String

    public init(componentId: String, expectedHash: String, actualHash: String, discrepancyType: String) {
        self.componentId = componentId
        self.expectedHash = expectedHash
        self.actualHash = actualHash
        self.discrepancyType = discrepancyType
    }

    private enum CodingKeys: String, CodingKey {
        case componentId, expectedHash, actualHash, discrepancyType
    }
}

/// Redaction transparency report for transport and verification
public struct RedactionTransparencyReport: Sendable, Codable {
    public let bundleId: String
    public let sessionId: String
    public let redactionCount: Int
    public let redactedComponents: [String]
    public let statistics: RedactionStatistics?
    public let examples: [RedactionExample]?

    public init(
        bundleId: String,
        sessionId: String,
        redactionCount: Int,
        redactedComponents: [String],
        statistics: RedactionStatistics?,
        examples: [RedactionExample]?
    ) {
        self.bundleId = bundleId
        self.sessionId = sessionId
        self.redactionCount = redactionCount
        self.redactedComponents = redactedComponents
        self.statistics = statistics
        self.examples = examples
    }

    private enum CodingKeys: String, CodingKey {
        case bundleId, sessionId, redactionCount, redactedComponents
        case statistics, examples
    }
}

/// Redaction statistics for transport and verification
public struct RedactionStatistics: Sendable, Codable {
    public let totalDocuments: Int
    public let totalRedactions: Int
    public let redactionTypes: [String]

    public init(totalDocuments: Int, totalRedactions: Int, redactionTypes: [String]) {
        self.totalDocuments = totalDocuments
        self.totalRedactions = totalRedactions
        self.redactionTypes = redactionTypes
    }

    private enum CodingKeys: String, CodingKey {
        case totalDocuments, totalRedactions, redactionTypes
    }
}

/// Redaction example for transport and verification
public struct RedactionExample: Sendable, Codable {
    public let originalText: String
    public let redactionText: String
    public let reason: String

    public init(originalText: String, redactionText: String, reason: String) {
        self.originalText = originalText
        self.redactionText = redactionText
        self.reason = reason
    }

    private enum CodingKeys: String, CodingKey {
        case originalText, redactionText, reason
    }
}

    /// Privilege claim for transport and verification
public struct PrivilegeClaim: Sendable, Codable {
    public let userId: String
    public let privilege: String
    public let justification: String
    public let timestamp: Int

    public init(userId: String, privilege: String, justification: String, timestamp: Int) {
        self.userId = userId
        self.privilege = privilege
        self.justification = justification
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case userId, privilege, justification, timestamp
    }
}

// MARK: - Retrieval Evidence Types

/// Embedding recipe for retrieval evidence tracking
public struct EmbeddingRecipe: Sendable, Codable {
    public let modelId: String
    public let dimensions: Int
    public let engine: String
    public let quantization: String?

    public init(modelId: String, dimensions: Int, engine: String, quantization: String? = nil) {
        self.modelId = modelId
        self.dimensions = dimensions
        self.engine = engine
        self.quantization = quantization
    }

    private enum CodingKeys: String, CodingKey {
        case modelId, dimensions, engine, quantization
    }
}

/// Retrieval evidence record for auditability and replay
public struct RetrievalEvidenceRecord: Sendable, Codable {
    public let queryId: String
    public let queryText: String
    public let queryTimestamp: Int
    public let embeddingRecipe: EmbeddingRecipe
    public let similarityThreshold: Float
    public let maxResults: Int
    public let results: [RetrievalHit]
    public let executionTimeMs: Int
    public let totalCandidates: Int

    public init(
        queryId: String,
        queryText: String,
        queryTimestamp: Int,
        embeddingRecipe: EmbeddingRecipe,
        similarityThreshold: Float,
        maxResults: Int,
        results: [RetrievalHit],
        executionTimeMs: Int,
        totalCandidates: Int
    ) {
        self.queryId = queryId
        self.queryText = queryText
        self.queryTimestamp = queryTimestamp
        self.embeddingRecipe = embeddingRecipe
        self.similarityThreshold = similarityThreshold
        self.maxResults = maxResults
        self.results = results
        self.executionTimeMs = executionTimeMs
        self.totalCandidates = totalCandidates
    }

    private enum CodingKeys: String, CodingKey {
        case queryId, queryText, queryTimestamp, embeddingRecipe
        case similarityThreshold, maxResults, results, executionTimeMs, totalCandidates
    }
}

/// Retrieval hit result for evidence tracking
public struct RetrievalHit: Sendable, Codable {
    public let documentId: String
    public let score: Float
    public let contentHash: String
    public let metadata: [String: String]

    public init(documentId: String, score: Float, contentHash: String, metadata: [String: String]) {
        self.documentId = documentId
        self.score = score
        self.contentHash = contentHash
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case documentId, score, contentHash, metadata
    }
}

// MARK: - Contract Conformances

extension EvidenceHeadInfo: WorkflowContract {
    public static let id = ContractID(
        name: "evidence.head",
        major: 1,
        minor: 0,
        schemaHash: "sha256:evidence-head-v1.0"
    )

    public static func validateInvariants(_ value: EvidenceHeadInfo) throws {
        guard !value.eventId.isEmpty else {
            throw ValidationError.schemaViolation("eventId cannot be empty")
        }
        guard !value.headHash.isEmpty else {
            throw ValidationError.invalidEvidence("headHash cannot be empty")
        }
        guard !value.lastActor.isEmpty else {
            throw ValidationError.invalidEvidence("lastActor cannot be empty")
        }
    }
}

/// Evidence signature for transport and verification
public struct EvidenceSignature: Sendable, Codable {
    public let signatureId: String
    public let evidenceHeadHash: String
    public let signerIdentity: String
    public let signerRole: String
    public let signingTimestamp: Int
    public let authorizationReference: String?
    public let hardwareAttestation: String?
    public let keyFingerprint: String
    public let signatureData: String
    public let verificationStatus: VerificationStatus

    public init(
        signatureId: String,
        evidenceHeadHash: String,
        signerIdentity: String,
        signerRole: String,
        signingTimestamp: Int,
        authorizationReference: String? = nil,
        hardwareAttestation: String? = nil,
        keyFingerprint: String,
        signatureData: String,
        verificationStatus: VerificationStatus
    ) {
        self.signatureId = signatureId
        self.evidenceHeadHash = evidenceHeadHash
        self.signerIdentity = signerIdentity
        self.signerRole = signerRole
        self.signingTimestamp = signingTimestamp
        self.authorizationReference = authorizationReference
        self.hardwareAttestation = hardwareAttestation
        self.keyFingerprint = keyFingerprint
        self.signatureData = signatureData
        self.verificationStatus = verificationStatus
    }

    private enum CodingKeys: String, CodingKey {
        case signatureId, evidenceHeadHash, signerIdentity, signerRole
        case signingTimestamp, authorizationReference, hardwareAttestation
        case keyFingerprint, signatureData, verificationStatus
    }
}

extension EvidenceSignature: WorkflowContract {
    public static let id = ContractID(
        name: "evidence.signature",
        major: 1,
        minor: 0,
        schemaHash: "sha256:evidence-signature-v1.0"
    )

    public static func validateInvariants(_ value: EvidenceSignature) throws {
        guard !value.signatureId.isEmpty else {
            throw ValidationError.invalidEvidence("signatureId cannot be empty")
        }
        guard !value.evidenceHeadHash.isEmpty else {
            throw ValidationError.invalidEvidence("evidenceHeadHash cannot be empty")
        }
        guard !value.signerIdentity.isEmpty else {
            throw ValidationError.invalidEvidence("signerIdentity cannot be empty")
        }
        guard !value.keyFingerprint.isEmpty else {
            throw ValidationError.invalidEvidence("keyFingerprint cannot be empty")
        }
    }
}

extension RedactedBundleManifest: WorkflowContract {
    public static let id = ContractID(
        name: "bundle.redacted",
        major: 1,
        minor: 0,
        schemaHash: "sha256:redacted-bundle-v1.0"
    )

    public static func validateInvariants(_ value: RedactedBundleManifest) throws {
        guard !value.bundleId.isEmpty else {
            throw ValidationError.invalidEvidence("bundleId cannot be empty")
        }
        guard !value.originalBundleId.isEmpty else {
            throw ValidationError.invalidEvidence("originalBundleId cannot be empty")
        }
        guard !value.redactionSessionId.isEmpty else {
            throw ValidationError.invalidEvidence("redactionSessionId cannot be empty")
        }
    }
}

extension RetrievalEvidenceRecord: WorkflowContract {
    public static let id = ContractID(
        name: "retrieval.evidence",
        major: 1,
        minor: 0,
        schemaHash: "sha256:retrieval-evidence-v1.0"
    )

    public static func validateInvariants(_ value: RetrievalEvidenceRecord) throws {
        guard !value.queryId.isEmpty else {
            throw ValidationError.invalidEvidence("queryId cannot be empty")
        }
        guard !value.queryText.isEmpty else {
            throw ValidationError.invalidEvidence("queryText cannot be empty")
        }
        guard value.similarityThreshold >= 0.0 && value.similarityThreshold <= 1.0 else {
            throw ValidationError.invalidEvidence("similarityThreshold must be between 0.0 and 1.0")
        }
        guard value.maxResults > 0 else {
            throw ValidationError.invalidEvidence("maxResults must be positive")
        }
    }
}
