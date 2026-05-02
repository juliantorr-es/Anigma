import Foundation

public enum PrivacyVerifierFindingKind: String, Sendable, Codable {
    case rawSensitivePayloadInReceipt
    case crossTenantRetrieval
    case trainingWithoutPermission
    case missingDeletionPropagation
    case regulatedDecisionWithoutHumanReview
    case connectorScopeViolation
}

/// A receipt proving a human has reviewed a regulated decision
public struct HumanReviewReceipt: Sendable, Codable {
    public let reviewID: String
    public let reviewedBy: String
    public let reviewedAt: Date
    public let decisionClass: RegulatedDecisionClass
    public let approved: Bool
    public let notes: String?
    
    public init(
        reviewID: String = UUID().uuidString,
        reviewedBy: String,
        reviewedAt: Date = Date(),
        decisionClass: RegulatedDecisionClass,
        approved: Bool,
        notes: String? = nil
    ) {
        self.reviewID = reviewID
        self.reviewedBy = reviewedBy
        self.reviewedAt = reviewedAt
        self.decisionClass = decisionClass
        self.approved = approved
        self.notes = notes
    }
}

public struct PrivacyVerifierFinding: Sendable, Codable, Equatable {
    public let kind: PrivacyVerifierFindingKind
    public let message: String
    public let evidence: [String]

    public init(kind: PrivacyVerifierFindingKind, message: String, evidence: [String] = []) {
        self.kind = kind
        self.message = message
        self.evidence = evidence
    }

    public func asComplianceMatrixFinding() -> PrivacyEvaluationMatrixFinding {
        PrivacyEvaluationMatrixFinding(
            name: "compliance",
            status: "fail",
            score: 0,
            evidence: evidence,
            notes: [message]
        )
    }
}

public struct PrivacyEvaluationMatrixFinding: Sendable, Codable, Equatable {
    public let name: String
    public let status: String
    public let score: Int
    public let evidence: [String]
    public let notes: [String]
}

public struct PrivacyVerifierLane: Sendable {
    public init() {}

    public func verify(
        contract: MissionPrivacyContract,
        receiptsContainRawSensitivePayload: Bool,
        crossTenantRetrieval: Bool,
        deletionPropagated: Bool,
        connectorScopeAllowed: Bool
    ) -> [PrivacyVerifierFinding] {
        var findings: [PrivacyVerifierFinding] = []

        if receiptsContainRawSensitivePayload {
            findings.append(.init(
                kind: .rawSensitivePayloadInReceipt,
                message: "Immutable receipt contains raw sensitive payload",
                evidence: ["receipt"]
            ))
        }

        if crossTenantRetrieval {
            findings.append(.init(
                kind: .crossTenantRetrieval,
                message: "Retrieval crosses tenant or project boundary",
                evidence: ["retrieval"]
            ))
        }

        if !contract.trainingAllowed {
            findings.append(.init(
                kind: .trainingWithoutPermission,
                message: "Training requested without permission",
                evidence: ["trainingAllowed=false"]
            ))
        }

        if !deletionPropagated {
            findings.append(.init(
                kind: .missingDeletionPropagation,
                message: "Deletion did not propagate to derived data",
                evidence: ["deletion"]
            ))
        }

        if contract.regulatedDecisionClass != .none && !contract.humanReviewRequired {
            findings.append(.init(
                kind: .regulatedDecisionWithoutHumanReview,
                message: "Regulated decision lacks human review - BLOCKING execution",
                evidence: ["regulatedDecisionClass=\(contract.regulatedDecisionClass.rawValue)"]
            ))
        }

        if !connectorScopeAllowed {
            findings.append(.init(
                kind: .connectorScopeViolation,
                message: "Connector scope exceeds mission purpose",
                evidence: ["connectorScope"]
            ))
        }

        return findings
    }
}
