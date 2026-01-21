//
//  EvidenceSubstrate.swift
//  CathedralModule
//
//  Unified evidence enforcement interface for Cathedral coordination
//

import Foundation
import ContractsCore
import DatabaseCore

// MARK: - Evidence Substrate

/// Unified interface for evidence-driven Cathedral coordination
public actor EvidenceSubstrate {
    private let tamperSystem: TamperEvidenceSystem
    private let config: CathedralConfig

    public init(
        tamperSystem: TamperEvidenceSystem,
        config: CathedralConfig = CathedralConfig()
    ) {
        self.tamperSystem = tamperSystem
        self.config = config
    }

    // MARK: - Evidence Enforcement (Core Invariant #1)

    /// Enforce evidence requirements before allowing operation to proceed
    /// This is the primary entry point for Cathedral coordination
    public func enforceEvidenceSubstrate(
        operation: MLOperation,
        requirement: EvidenceRequirement
    ) async throws -> EvidenceEnforcementResult {
        let startTime = Date()

        // 1. Validate existing evidence for this operation
        let validation = try await validateOperationEvidence(
            operation: operation,
            requirement: requirement
        )

        // 2. Check if evidence meets requirements
        guard validation.isValid else {
            // Record enforcement violation
            let violation = EvidenceViolation(
                type: .insufficientEvidence,
                severity: .high,
                description: "Operation \(operation.type.rawValue) blocked: evidence requirement \(requirement.rawValue) not met",
                evidenceId: operation.id
            )

            try await recordViolation(violation, sessionId: operation.sessionId)

            throw CathedralError.validationFailed([violation.description])
        }

        // 3. Record successful enforcement
        let enforcementEvidence = Evidence(
            type: .validationCheck,
            sessionId: operation.sessionId,
            agentId: operation.agentId,
            contentHash: operation.id.sha256Hash,
            metadata: EvidenceMetadata(
                source: "EvidenceSubstrate",
                operation: "enforceEvidenceSubstrate",
                parameters: [
                    "operationType": operation.type.rawValue,
                    "requirement": requirement.rawValue,
                    "validationResult": "passed"
                ],
                quality: .verified
            ),
            previousHash: try await getLastHash(sessionId: operation.sessionId)
        )

        try await tamperSystem.recordEvidence(enforcementEvidence)

        return EvidenceEnforcementResult(
            isAllowed: true,
            validation: validation,
            enforcementTimestamp: startTime,
            processingDuration: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Evidence Validation

    private func validateOperationEvidence(
        operation: MLOperation,
        requirement: EvidenceRequirement
    ) async throws -> ExtendedEvidenceValidationResult {
        // Get all evidence for this session
        let sessionEvidence = await tamperSystem.getSessionEvidence(sessionId: operation.sessionId)

        // Check chain integrity first (Invariant #2)
        let chainValidation = try await tamperSystem.validateChain(sessionId: operation.sessionId)
        guard chainValidation.isIntact else {
            let violations = chainValidation.violations.map { violation in
                EvidenceViolation(
                    type: .brokenChain,
                    severity: .critical,
                    description: violation.description,
                    evidenceId: violation.eventId
                )
            }

            return ExtendedEvidenceValidationResult(
                isValid: false,
                currentStatus: .corrupted,
                requirement: requirement,
                violations: violations
            )
        }

        // Filter evidence relevant to this operation
        let relevantEvidence = sessionEvidence.filter { evidence in
            evidence.metadata.operation.contains(operation.type.rawValue) ||
            evidence.type == .queryExecution ||
            evidence.type == .retrievalResult
        }

        // Check evidence freshness
        let now = Date()
        let freshEvidence = relevantEvidence.filter { evidence in
            if let expiryTime = evidence.metadata.expiryTime {
                return expiryTime > now
            }
            return true
        }

        // Assess evidence quality
        let assessment = assessEvidenceQuality(evidence: freshEvidence)

        // Check timeout
        if config.requireFreshEvidence {
            let oldestAllowed = now.addingTimeInterval(-config.evidenceTimeoutSeconds)
            let hasRecentEvidence = freshEvidence.contains { $0.timestamp > oldestAllowed }

            if !hasRecentEvidence && requirement != .none {
                return ExtendedEvidenceValidationResult(
                    isValid: false,
                    currentStatus: .expired,
                    requirement: requirement,
                    violations: [
                        EvidenceViolation(
                            type: .expiredEvidence,
                            severity: .medium,
                            description: "No fresh evidence within timeout period (\(config.evidenceTimeoutSeconds)s)",
                            evidenceId: operation.id
                        )
                    ]
                )
            }
        }

        return ExtendedEvidenceValidationResult(
            isValid: assessment.confidence >= requirementConfidence(requirement),
            currentStatus: assessment.status,
            requirement: requirement,
            violations: []
        )
    }

    private func assessEvidenceQuality(
        evidence: [Evidence]
    ) -> (status: EvidenceStatus, confidence: Double) {
        guard !evidence.isEmpty else {
            return (.pending, 0.0)
        }

        let avgQuality = evidence.reduce(0.0) { $0 + $1.metadata.quality.confidence } / Double(evidence.count)

        let status: EvidenceStatus
        switch avgQuality {
        case 0.0..<0.3: status = .insufficient
        case 0.3..<0.6: status = .adequate
        case 0.6..<0.9: status = .strong
        default: status = .verified
        }

        return (status, avgQuality)
    }

    private func requirementConfidence(_ requirement: EvidenceRequirement) -> Double {
        switch requirement {
        case .none: return 0.0
        case .low: return 0.25
        case .moderate: return 0.5
        case .high: return 0.75
        case .strict: return 1.0
        }
    }

    // MARK: - Violation Recording (Invariant #3)

    private func recordViolation(_ violation: EvidenceViolation, sessionId: String) async throws {
        let violationFingerprint = [
            violation.type.rawValue,
            violation.evidenceId ?? "unknown",
            String(violation.timestamp.timeIntervalSince1970),
            violation.description
        ].joined(separator: "|")

        let violationEvidence = Evidence(
            type: .violationDetection,
            sessionId: sessionId,
            agentId: "system",
            contentHash: violationFingerprint.sha256Hash,
            metadata: EvidenceMetadata(
                source: "EvidenceSubstrate",
                operation: "recordViolation",
                parameters: [
                    "violationType": violation.type.rawValue,
                    "severity": violation.severity.rawValue,
                    "description": violation.description,
                    "evidenceId": violation.evidenceId ?? "unknown"
                ],
                quality: .verified
            ),
            previousHash: try await getLastHash(sessionId: sessionId)
        )

        try await tamperSystem.recordEvidence(violationEvidence)
    }

    // MARK: - Evidence Recording

    public func recordEvidence(_ evidence: Evidence) async throws {
        try await tamperSystem.recordEvidence(evidence)
    }

    // MARK: - Chain Inspection

    public func validateChain(sessionId: String) async throws -> EvidenceChainValidation {
        return try await tamperSystem.performComprehensiveValidation(sessionId: sessionId)
    }

    private func getLastHash(sessionId: String) async throws -> String? {
        let sessionEvidence = await tamperSystem.getSessionEvidence(sessionId: sessionId)
        return sessionEvidence.last?.computeHash()
    }
}

// MARK: - ML Operation

public struct MLOperation: Sendable, Codable {
    public let id: String
    public let type: MLOperationType
    public let sessionId: String
    public let agentId: String
    public let parameters: [String: String]

    public init(
        id: String = UUID().uuidString,
        type: MLOperationType,
        sessionId: String,
        agentId: String,
        parameters: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.sessionId = sessionId
        self.agentId = agentId
        self.parameters = parameters
    }
}

public enum MLOperationType: String, Sendable, Codable, CaseIterable {
    case embedding = "embedding"
    case retrieval = "retrieval"
    case generation = "generation"
    case classification = "classification"
    case transformation = "transformation"
}

// MARK: - Evidence Enforcement Result

public struct EvidenceEnforcementResult: Sendable, Codable {
    public let isAllowed: Bool
    public let validation: ExtendedEvidenceValidationResult
    public let enforcementTimestamp: Date
    public let processingDuration: TimeInterval

    public init(
        isAllowed: Bool,
        validation: ExtendedEvidenceValidationResult,
        enforcementTimestamp: Date,
        processingDuration: TimeInterval
    ) {
        self.isAllowed = isAllowed
        self.validation = validation
        self.enforcementTimestamp = enforcementTimestamp
        self.processingDuration = processingDuration
    }
}
