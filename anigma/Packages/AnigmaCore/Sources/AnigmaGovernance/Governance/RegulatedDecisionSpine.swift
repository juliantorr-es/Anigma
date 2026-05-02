import Foundation

public enum MissionPrivacyClass: String, Sendable, Codable, CaseIterable {
    case publicData = "public"
    case `internal` = "internal"
    case confidential
    case personal
    case sensitive
    case regulated

    public var requiresRedaction: Bool {
        switch self {
        case .publicData, .internal:
            return false
        case .confidential, .personal, .sensitive, .regulated:
            return true
        }
    }
}

public enum MissionDataSubjectScope: String, Sendable, Codable, CaseIterable {
    case none
    case user
    case customer
    case employee
    case child
    case patient
    case applicant
    case tenant
    case mixed
}

public enum MissionPurpose: String, Sendable, Codable, CaseIterable {
    case search
    case retrieval
    case summarization
    case audit
    case support
    case evaluation
    case training
    case decisionSupport = "decision_support"
    case regulatedDecision = "regulated_decision"
}

public enum MissionRetentionClass: String, Sendable, Codable, CaseIterable {
    case transient
    case short
    case audit
    case legalHold = "legal_hold"
    case subjectToDeletion = "subject_to_deletion"
}

public enum MissionJurisdiction: String, Sendable, Codable, CaseIterable {
    case US
    case CA
    case CO
    case EU
    case hipaaAdjacent = "hipaa_adjacent"
    case financial
    case employment
    case custom
}

public enum RegulatedDecisionClass: String, Sendable, Codable, CaseIterable {
    case none
    case recommendationOnly = "recommendation_only"
    case decisionSupport = "decision_support"
    case substantialFactor = "substantial_factor"
    case automatedDecision = "automated_decision"

    public var requiresAssessment: Bool {
        self == .substantialFactor || self == .automatedDecision
    }
}

public enum AppealOrReviewPath: String, Sendable, Codable, CaseIterable {
    case none
    case operatorReview = "operator_review"
    case userAppeal = "user_appeal"
    case complianceReview = "compliance_review"
}

public enum RegulatedDecisionAdmissionError: Error, Equatable, Sendable {
    case missingImpactAssessmentReference
    case missingRegisteredImpactAssessment
    case missingHumanOversightAssignee
    case missingExplanationStrategy
    case missingAppealOrReviewPath
    case missingMonitoringPlan
    case missingIncidentEscalationPath
    case missingDataProvenanceStatement
    case redactionRequiredButDisabled
}

public struct MissionPrivacyProfile: Sendable, Codable, Equatable {
    public let privacyClass: MissionPrivacyClass
    public let dataSubjectScope: MissionDataSubjectScope
    public let allowedPurpose: MissionPurpose
    public let trainingAllowed: Bool
    public let evalAllowed: Bool
    public let retentionClass: MissionRetentionClass
    public let redactionRequired: Bool
    public let exportAllowed: Bool
    public let jurisdiction: MissionJurisdiction
    public let regulatedDecisionClass: RegulatedDecisionClass
    public let humanReviewRequired: Bool
    public let appealOrReviewPath: AppealOrReviewPath

    public init(
        privacyClass: MissionPrivacyClass,
        dataSubjectScope: MissionDataSubjectScope,
        allowedPurpose: MissionPurpose,
        trainingAllowed: Bool,
        evalAllowed: Bool,
        retentionClass: MissionRetentionClass,
        redactionRequired: Bool,
        exportAllowed: Bool,
        jurisdiction: MissionJurisdiction,
        regulatedDecisionClass: RegulatedDecisionClass,
        humanReviewRequired: Bool,
        appealOrReviewPath: AppealOrReviewPath
    ) {
        self.privacyClass = privacyClass
        self.dataSubjectScope = dataSubjectScope
        self.allowedPurpose = allowedPurpose
        self.trainingAllowed = trainingAllowed
        self.evalAllowed = evalAllowed
        self.retentionClass = retentionClass
        self.redactionRequired = redactionRequired
        self.exportAllowed = exportAllowed
        self.jurisdiction = jurisdiction
        self.regulatedDecisionClass = regulatedDecisionClass
        self.humanReviewRequired = humanReviewRequired
        self.appealOrReviewPath = appealOrReviewPath
    }

    public var requiresRegulatedDecisionGate: Bool {
        regulatedDecisionClass.requiresAssessment
    }
}

public struct RegulatedDecisionAssessment: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public let missionID: UUID
    public let decisionClass: RegulatedDecisionClass
    public let assessedAt: Date
    public let impactAssessmentReference: String
    public let humanOversightAssignee: String
    public let explanationStrategy: String
    public let appealOrReviewPath: AppealOrReviewPath
    public let postDeploymentMonitoringPlan: String
    public let incidentEscalationPath: String
    public let dataProvenanceStatement: String
    public let approvedByHuman: Bool
    public let notes: String?

    public init(
        id: UUID = UUID(),
        missionID: UUID,
        decisionClass: RegulatedDecisionClass,
        assessedAt: Date = Date(),
        impactAssessmentReference: String,
        humanOversightAssignee: String,
        explanationStrategy: String,
        appealOrReviewPath: AppealOrReviewPath,
        postDeploymentMonitoringPlan: String,
        incidentEscalationPath: String,
        dataProvenanceStatement: String,
        approvedByHuman: Bool,
        notes: String? = nil
    ) {
        self.id = id
        self.missionID = missionID
        self.decisionClass = decisionClass
        self.assessedAt = assessedAt
        self.impactAssessmentReference = impactAssessmentReference
        self.humanOversightAssignee = humanOversightAssignee
        self.explanationStrategy = explanationStrategy
        self.appealOrReviewPath = appealOrReviewPath
        self.postDeploymentMonitoringPlan = postDeploymentMonitoringPlan
        self.incidentEscalationPath = incidentEscalationPath
        self.dataProvenanceStatement = dataProvenanceStatement
        self.approvedByHuman = approvedByHuman
        self.notes = notes
    }
}

public struct RegulatedMissionDescriptor: Sendable, Codable, Equatable, Identifiable {
    public let descriptor: SaturatedMissionDescriptor
    public let privacy: MissionPrivacyProfile
    public let impactAssessmentID: UUID?
    public let humanOversightAssignee: String?
    public let explanationStrategy: String?
    public let postDeploymentMonitoringPlan: String?
    public let incidentEscalationPath: String?
    public let dataProvenanceStatement: String?

    public init(
        descriptor: SaturatedMissionDescriptor,
        privacy: MissionPrivacyProfile,
        impactAssessmentID: UUID? = nil,
        humanOversightAssignee: String? = nil,
        explanationStrategy: String? = nil,
        postDeploymentMonitoringPlan: String? = nil,
        incidentEscalationPath: String? = nil,
        dataProvenanceStatement: String? = nil
    ) {
        self.descriptor = descriptor
        self.privacy = privacy
        self.impactAssessmentID = impactAssessmentID
        self.humanOversightAssignee = humanOversightAssignee
        self.explanationStrategy = explanationStrategy
        self.postDeploymentMonitoringPlan = postDeploymentMonitoringPlan
        self.incidentEscalationPath = incidentEscalationPath
        self.dataProvenanceStatement = dataProvenanceStatement
    }

    public var id: UUID {
        descriptor.identityContext.missionID
    }
}

public struct RegulatedDecisionAdmissionResult: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let admitted: Bool
    public let decisionClass: RegulatedDecisionClass
    public let appealOrReviewPath: AppealOrReviewPath
    public let explanation: String
    public let denialReasons: [String]
    public let impactAssessmentID: UUID?
    public let humanOversightAssignee: String?
    public let assessedAt: Date?

    public init(
        id: UUID,
        admitted: Bool,
        decisionClass: RegulatedDecisionClass,
        appealOrReviewPath: AppealOrReviewPath,
        explanation: String,
        denialReasons: [String] = [],
        impactAssessmentID: UUID? = nil,
        humanOversightAssignee: String? = nil,
        assessedAt: Date? = nil
    ) {
        self.id = id
        self.admitted = admitted
        self.decisionClass = decisionClass
        self.appealOrReviewPath = appealOrReviewPath
        self.explanation = explanation
        self.denialReasons = denialReasons
        self.impactAssessmentID = impactAssessmentID
        self.humanOversightAssignee = humanOversightAssignee
        self.assessedAt = assessedAt
    }
}

public actor RegulatedDecisionImpactAssessmentRegistry {
    private var byID: [UUID: RegulatedDecisionAssessment] = [:]
    private var latestByMissionID: [UUID: RegulatedDecisionAssessment] = [:]

    public init() {}

    public func register(_ assessment: RegulatedDecisionAssessment) {
        byID[assessment.id] = assessment
        latestByMissionID[assessment.missionID] = assessment
    }

    public func assessment(id: UUID) -> RegulatedDecisionAssessment? {
        byID[id]
    }

    public func latestAssessment(for missionID: UUID) -> RegulatedDecisionAssessment? {
        latestByMissionID[missionID]
    }
}

public actor RegulatedDecisionGate {
    private let registry: RegulatedDecisionImpactAssessmentRegistry

    public init(registry: RegulatedDecisionImpactAssessmentRegistry = RegulatedDecisionImpactAssessmentRegistry()) {
        self.registry = registry
    }

    public func admit(_ mission: RegulatedMissionDescriptor) async -> RegulatedDecisionAdmissionResult {
        var denialReasons: [String] = []
        let privacy = mission.privacy

        if privacy.privacyClass.requiresRedaction, !privacy.redactionRequired {
            denialReasons.append("Sensitive or regulated missions require redaction")
        }

        if privacy.requiresRegulatedDecisionGate {
            guard let assessmentID = mission.impactAssessmentID else {
                denialReasons.append("Missing impact assessment reference")
                return deny(mission: mission, reasons: denialReasons)
            }

            guard let assessment = await registry.assessment(id: assessmentID) else {
                denialReasons.append("Impact assessment reference does not resolve in registry")
                return deny(mission: mission, reasons: denialReasons)
            }

            if assessment.missionID != mission.id {
                denialReasons.append("Impact assessment mission ID does not match the requested mission")
            }

            if assessment.decisionClass != privacy.regulatedDecisionClass {
                denialReasons.append("Impact assessment class does not match the mission decision class")
            }

            if assessment.humanOversightAssignee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                denialReasons.append("Missing human oversight assignee")
            }

            if assessment.explanationStrategy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                denialReasons.append("Missing explanation strategy")
            }

            if assessment.appealOrReviewPath == .none {
                denialReasons.append("Missing appeal or review path")
            }

            if assessment.postDeploymentMonitoringPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                denialReasons.append("Missing post-deployment monitoring plan")
            }

            if assessment.incidentEscalationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                denialReasons.append("Missing incident escalation path")
            }

            if assessment.dataProvenanceStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                denialReasons.append("Missing data provenance statement")
            }

            if privacy.humanReviewRequired && !assessment.approvedByHuman {
                denialReasons.append("Human review required but assessment is not human-approved")
            }

            if !denialReasons.isEmpty {
                return deny(mission: mission, reasons: denialReasons, assessment: assessment)
            }

            return RegulatedDecisionAdmissionResult(
                id: mission.id,
                admitted: true,
                decisionClass: privacy.regulatedDecisionClass,
                appealOrReviewPath: assessment.appealOrReviewPath,
                explanation: "Mission admitted with impact assessment \(assessment.id.uuidString) and human oversight assigned to \(assessment.humanOversightAssignee).",
                impactAssessmentID: assessment.id,
                humanOversightAssignee: assessment.humanOversightAssignee,
                assessedAt: assessment.assessedAt
            )
        }

        if privacy.humanReviewRequired && mission.humanOversightAssignee == nil {
            denialReasons.append("Human review is required but no oversight assignee was provided")
        }

        if !denialReasons.isEmpty {
            return deny(mission: mission, reasons: denialReasons)
        }

        return RegulatedDecisionAdmissionResult(
            id: mission.id,
            admitted: true,
            decisionClass: privacy.regulatedDecisionClass,
            appealOrReviewPath: privacy.appealOrReviewPath,
            explanation: "Mission admitted without regulated-decision gate requirement.",
            denialReasons: []
        )
    }

    private func deny(
        mission: RegulatedMissionDescriptor,
        reasons: [String],
        assessment: RegulatedDecisionAssessment? = nil
    ) -> RegulatedDecisionAdmissionResult {
        RegulatedDecisionAdmissionResult(
            id: mission.id,
            admitted: false,
            decisionClass: mission.privacy.regulatedDecisionClass,
            appealOrReviewPath: assessment?.appealOrReviewPath ?? mission.privacy.appealOrReviewPath,
            explanation: "Mission denied: \(reasons.joined(separator: "; "))",
            denialReasons: reasons,
            impactAssessmentID: assessment?.id ?? mission.impactAssessmentID,
            humanOversightAssignee: assessment?.humanOversightAssignee ?? mission.humanOversightAssignee,
            assessedAt: assessment?.assessedAt
        )
    }
}
