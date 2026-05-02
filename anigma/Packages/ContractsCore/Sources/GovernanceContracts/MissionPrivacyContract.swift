import Foundation

public enum MissionDataClass: String, Sendable, Codable {
    case runtimeInput
    case retrievalMemory
    case evaluationData
    case trainingData
    case telemetry
    case auditEvidence
    case supportExport
    case regulatedDecisionRecord
}

public enum MissionPurpose: String, Sendable, Codable {
    case search
    case retrieval
    case summarization
    case audit
    case support
    case evaluation
    case training
    case decisionSupport
    case regulatedDecision
}

public enum RetentionClass: String, Sendable, Codable {
    case transient
    case short
    case audit
    case legalHold
    case subjectToDeletion
}

public enum JurisdictionTag: String, Sendable, Codable {
    case us = "US"
    case ca = "CA"
    case co = "CO"
    case eu = "EU"
    case hipaaAdjacent = "HIPAA_adjacent"
    case financial
    case employment
    case custom
}

public enum RegulatedDecisionClass: String, Sendable, Codable {
    case none
    case recommendationOnly
    case decisionSupport
    case substantialFactor
    case automatedDecision
}

public enum DataSubjectScope: String, Sendable, Codable {
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

public struct MissionPrivacyContract: Sendable, Codable, Equatable {
    public let privacyClass: String
    public let dataSubjectScope: DataSubjectScope
    public let allowedPurpose: MissionPurpose
    public let trainingAllowed: Bool
    public let evalAllowed: Bool
    public let retentionClass: RetentionClass
    public let redactionRequired: Bool
    public let exportAllowed: Bool
    public let jurisdiction: JurisdictionTag
    public let regulatedDecisionClass: RegulatedDecisionClass
    public let humanReviewRequired: Bool
    public let appealOrReviewPath: String

    public init(
        privacyClass: String,
        dataSubjectScope: DataSubjectScope,
        allowedPurpose: MissionPurpose,
        trainingAllowed: Bool,
        evalAllowed: Bool,
        retentionClass: RetentionClass,
        redactionRequired: Bool,
        exportAllowed: Bool,
        jurisdiction: JurisdictionTag,
        regulatedDecisionClass: RegulatedDecisionClass,
        humanReviewRequired: Bool,
        appealOrReviewPath: String
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

    public static func `default`(purpose: MissionPurpose = .audit) -> MissionPrivacyContract {
        MissionPrivacyContract(
            privacyClass: "internal",
            dataSubjectScope: .none,
            allowedPurpose: purpose,
            trainingAllowed: false,
            evalAllowed: false,
            retentionClass: .audit,
            redactionRequired: true,
            exportAllowed: false,
            jurisdiction: .us,
            regulatedDecisionClass: .none,
            humanReviewRequired: false,
            appealOrReviewPath: "none"
        )
    }
}

public protocol MissionPrivacyVerifying: Sendable {
    func verify(_ contract: MissionPrivacyContract, for dataClass: MissionDataClass) throws -> Bool
}

public struct MissionPrivacyVerifier: MissionPrivacyVerifying, Sendable {
    public init() {}

    public func verify(_ contract: MissionPrivacyContract, for dataClass: MissionDataClass) throws -> Bool {
        switch dataClass {
        case .trainingData:
            return contract.trainingAllowed
        case .evaluationData:
            return contract.evalAllowed
        case .regulatedDecisionRecord:
            return contract.regulatedDecisionClass != .none && contract.humanReviewRequired
        case .auditEvidence:
            return contract.redactionRequired
        default:
            return !contract.privacyClass.isEmpty
        }
    }
}

