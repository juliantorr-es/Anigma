//
//  EvidenceEnforcement.swift
//  CathedralModule
//
//  Evidence enforcement system with violation detection and blocking
//

import Foundation
import ContractsCore

// MARK: - Evidence Enforcement System

/// Enforces evidence requirements and prevents bypass attempts
public actor EvidenceEnforcementSystem {
    private let evidenceSubstrate: EvidenceSubstrate
    private let config: CathedralConfig
    private let persistence: CathedralDatabasePersistence?
    private var violations: [EvidenceViolation] = []
    private var blockedOperations: Set<String> = []

    public init(
        evidenceSubstrate: EvidenceSubstrate,
        config: CathedralConfig,
        persistence: CathedralDatabasePersistence? = nil
    ) {
        self.evidenceSubstrate = evidenceSubstrate
        self.config = config
        self.persistence = persistence
    }

    // MARK: - Operation Enforcement

    /// Enforce evidence requirements and block if insufficient
    public func enforceOperation(
        operation: MLOperation,
        requirement: EvidenceRequirement
    ) async throws -> EnforcementDecision {
        // Check if operation is already blocked
        if blockedOperations.contains(operation.id) {
            throw CathedralError.validationFailed([
                "Operation \(operation.id) is blocked due to previous violations"
            ])
        }

        // Enforce evidence substrate
        let enforcementResult = try await evidenceSubstrate.enforceEvidenceSubstrate(
            operation: operation,
            requirement: requirement
        )

        // Check for violations
        if !enforcementResult.validation.violations.isEmpty {
            return try await handleViolations(
                operation: operation,
                violations: enforcementResult.validation.violations
            )
        }

        // Operation allowed
        return EnforcementDecision(
            operationId: operation.id,
            isAllowed: true,
            action: .allow,
            violations: [],
            timestamp: Date()
        )
    }

    // MARK: - Violation Handling

    private func handleViolations(
        operation: MLOperation,
        violations: [EvidenceViolation]
    ) async throws -> EnforcementDecision {
        // Record violations in memory
        self.violations.append(contentsOf: violations)

        // Persist violations to database
        if let persistence = persistence {
            for violation in violations {
                try? await persistence.persistViolation(violation)
            }
        }

        // Determine action based on severity
        let maxSeverity = violations.map { $0.severity }.max { $0.level < $1.level }

        let action: EnforcementAction
        if let severity = maxSeverity, severity.requiresBlocking {
            action = .block
            blockedOperations.insert(operation.id)
        } else if let severity = maxSeverity, severity.requiresQuarantine {
            action = .quarantine
            blockedOperations.insert(operation.id)
        } else {
            action = .warn
        }

        // Create enforcement evidence
        let enforcementEvidence = Evidence(
            type: .violationDetection,
            sessionId: operation.sessionId,
            agentId: "enforcement_system",
            contentHash: operation.id.sha256Hash,
            metadata: EvidenceMetadata(
                source: "EvidenceEnforcementSystem",
                operation: "handleViolations",
                parameters: [
                    "operationId": operation.id,
                    "action": action.rawValue,
                    "violationCount": String(violations.count),
                    "maxSeverity": maxSeverity?.rawValue ?? "unknown"
                ],
                quality: .verified
            )
        )

        try await evidenceSubstrate.recordEvidence(enforcementEvidence)

        let decision = EnforcementDecision(
            operationId: operation.id,
            isAllowed: action == .allow || action == .warn,
            action: action,
            violations: violations,
            timestamp: Date()
        )

        if !decision.isAllowed {
            throw CathedralError.validationFailed(
                violations.map { $0.description }
            )
        }

        return decision
    }

    // MARK: - Violation Reporting

    /// Get all violations for session
    public func getSessionViolations(sessionId: String) async -> [EvidenceViolation] {
        return violations
    }

    /// Get compliance report
    public func getComplianceReport(sessionId: String) async throws -> ComplianceReport {
        let chainValidation = try await evidenceSubstrate.validateChain(sessionId: sessionId)
        let sessionViolations = await getSessionViolations(sessionId: sessionId)

        let criticalCount = sessionViolations.filter { $0.severity == .critical }.count
        let highCount = sessionViolations.filter { $0.severity == .high }.count
        let mediumCount = sessionViolations.filter { $0.severity == .medium }.count
        let lowCount = sessionViolations.filter { $0.severity == .low }.count

        let complianceScore = calculateComplianceScore(
            chainValid: chainValidation.isValid,
            criticalViolations: criticalCount,
            highViolations: highCount,
            mediumViolations: mediumCount
        )

        return ComplianceReport(
            sessionId: sessionId,
            chainValid: chainValidation.isValid,
            totalViolations: sessionViolations.count,
            criticalViolations: criticalCount,
            highViolations: highCount,
            mediumViolations: mediumCount,
            lowViolations: lowCount,
            complianceScore: complianceScore,
            timestamp: Date()
        )
    }

    private func calculateComplianceScore(
        chainValid: Bool,
        criticalViolations: Int,
        highViolations: Int,
        mediumViolations: Int
    ) -> Double {
        var score = 1.0

        if !chainValid {
            score *= 0.0  // Chain corruption is fatal
        }

        score -= Double(criticalViolations) * 0.5
        score -= Double(highViolations) * 0.2
        score -= Double(mediumViolations) * 0.1

        return max(0.0, score)
    }
}

// MARK: - Enforcement Decision

public struct EnforcementDecision: Sendable, Codable {
    public let operationId: String
    public let isAllowed: Bool
    public let action: EnforcementAction
    public let violations: [EvidenceViolation]
    public let timestamp: Date

    public init(
        operationId: String,
        isAllowed: Bool,
        action: EnforcementAction,
        violations: [EvidenceViolation],
        timestamp: Date
    ) {
        self.operationId = operationId
        self.isAllowed = isAllowed
        self.action = action
        self.violations = violations
        self.timestamp = timestamp
    }
}

// MARK: - Enforcement Action

public enum EnforcementAction: String, Sendable, Codable {
    case allow = "allow"
    case warn = "warn"
    case block = "block"
    case quarantine = "quarantine"
}

// MARK: - Compliance Report

public struct ComplianceReport: Sendable, Codable {
    public let sessionId: String
    public let chainValid: Bool
    public let totalViolations: Int
    public let criticalViolations: Int
    public let highViolations: Int
    public let mediumViolations: Int
    public let lowViolations: Int
    public let complianceScore: Double
    public let timestamp: Date

    public init(
        sessionId: String,
        chainValid: Bool,
        totalViolations: Int,
        criticalViolations: Int,
        highViolations: Int,
        mediumViolations: Int,
        lowViolations: Int,
        complianceScore: Double,
        timestamp: Date
    ) {
        self.sessionId = sessionId
        self.chainValid = chainValid
        self.totalViolations = totalViolations
        self.criticalViolations = criticalViolations
        self.highViolations = highViolations
        self.mediumViolations = mediumViolations
        self.lowViolations = lowViolations
        self.complianceScore = complianceScore
        self.timestamp = timestamp
    }

    /// Whether this session passes compliance requirements
    public var isCompliant: Bool {
        return chainValid &&
               criticalViolations == 0 &&
               highViolations == 0 &&
               complianceScore >= 0.8
    }
}
