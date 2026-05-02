import Foundation
import GovernanceContracts
import AnigmaPrimitives
import ComplianceAuditModule

// MARK: - Regulated Decision Module

/// Comprehensive module for regulated decision governance
public struct RegulatedDecisionModule {
    
    // Core components
    public let registry: RegulatedDecisionImpactAssessmentRegistry
    public let gate: RegulatedDecisionGate
    public let operatorSurface: RegulatedDecisionOperatorSurface
    public let appealSurface: RegulatedDecisionAppealSurface
    
    // Configuration
    public let configuration: RegulatedDecisionConfiguration
    
    // MARK: - Initialization
    
    public init(
        registry: RegulatedDecisionImpactAssessmentRegistry = RegulatedDecisionImpactAssessmentRegistry(),
        auditService: AuditLoggingService,
        configuration: RegulatedDecisionConfiguration = .default
    ) {
        self.registry = registry
        self.gate = RegulatedDecisionGate(registry: registry)
        self.operatorSurface = RegulatedDecisionOperatorSurface(
            registry: registry,
            auditService: auditService
        )
        self.appealSurface = RegulatedDecisionAppealSurface(
            operatorSurface: operatorSurface
        )
        self.configuration = configuration
    }
    
    // MARK: - Decision Admission
    
    /// Admit a mission through the regulated decision gate
    public func admitMission(_ mission: RegulatedMissionDescriptor) async -> RegulatedDecisionAdmissionResult {
        return await gate.admit(mission)
    }
    
    // MARK: - Assessment Management
    
    /// Register a new impact assessment
    public func registerAssessment(_ assessment: RegulatedDecisionAssessment) async {
        await registry.register(assessment)
    }
    
    /// Get assessment by ID
    public func getAssessment(id: UUID) async -> RegulatedDecisionAssessment? {
        return await registry.assessment(id: id)
    }
    
    /// Get latest assessment for mission
    public func getLatestAssessment(for missionID: UUID) async -> RegulatedDecisionAssessment? {
        return await registry.latestAssessment(for: missionID)
    }
    
    // MARK: - Compliance Checking
    
    /// Check if a mission privacy profile requires regulated decision gate
    public func requiresRegulatedDecisionGate(_ privacyProfile: MissionPrivacyProfile) -> Bool {
        return privacyProfile.requiresRegulatedDecisionGate
    }
    
    /// Validate that a mission has all required fields for regulated decision processing
    public func validateMissionForRegulatedProcessing(_ mission: RegulatedMissionDescriptor) -> [RegulatedDecisionAdmissionError] {
        var errors: [RegulatedDecisionAdmissionError] = []
        
        if mission.privacy.requiresRegulatedDecisionGate {
            if mission.impactAssessmentID == nil {
                errors.append(.missingImpactAssessmentReference)
            }
            if mission.humanOversightAssignee == nil {
                errors.append(.missingHumanOversightAssignee)
            }
            if mission.explanationStrategy == nil {
                errors.append(.missingExplanationStrategy)
            }
            if mission.postDeploymentMonitoringPlan == nil {
                errors.append(.missingMonitoringPlan)
            }
            if mission.incidentEscalationPath == nil {
                errors.append(.missingIncidentEscalationPath)
            }
            if mission.dataProvenanceStatement == nil {
                errors.append(.missingDataProvenanceStatement)
            }
        }
        
        return errors
    }
    
    // MARK: - Module Information
    
    /// Get module capabilities
    public func getCapabilities() -> RegulatedDecisionModuleCapabilities {
        return RegulatedDecisionModuleCapabilities(
            decisionClasses: RegulatedDecisionClass.allCases,
            appealPaths: AppealOrReviewPath.allCases,
            supportsAssessmentRegistry: true,
            supportsOperatorReview: true,
            supportsUserAppeals: true,
            supportsComplianceReporting: true,
            supportsAuditIntegration: true
        )
    }
    
    /// Get module health status
    public func getHealthStatus() async -> RegulatedDecisionModuleHealth {
        let assessmentCount = 0 // Would query registry in real implementation
        
        return RegulatedDecisionModuleHealth(
            status: .healthy,
            assessmentCount: assessmentCount,
            gateOperational: true,
            operatorSurfaceOperational: true,
            appealSurfaceOperational: true,
            lastCheck: Date()
        )
    }
}

// MARK: - Configuration

public struct RegulatedDecisionConfiguration: Sendable, Codable {
    public let requireHumanOversightForAutomatedDecisions: Bool
    public let defaultExplanationStrategy: String
    public let defaultMonitoringPlan: String
    public let defaultEscalationPath: String
    public let auditAllDecisions: Bool
    
    public static let `default` = RegulatedDecisionConfiguration(
        requireHumanOversightForAutomatedDecisions: true,
        defaultExplanationStrategy: "transparency_report",
        defaultMonitoringPlan: "continuous_monitoring",
        defaultEscalationPath: "compliance_team",
        auditAllDecisions: true
    )
    
    public init(
        requireHumanOversightForAutomatedDecisions: Bool,
        defaultExplanationStrategy: String,
        defaultMonitoringPlan: String,
        defaultEscalationPath: String,
        auditAllDecisions: Bool
    ) {
        self.requireHumanOversightForAutomatedDecisions = requireHumanOversightForAutomatedDecisions
        self.defaultExplanationStrategy = defaultExplanationStrategy
        self.defaultMonitoringPlan = defaultMonitoringPlan
        self.defaultEscalationPath = defaultEscalationPath
        self.auditAllDecisions = auditAllDecisions
    }
}

// MARK: - Module Status Types

public struct RegulatedDecisionModuleCapabilities: Sendable, Codable {
    public let decisionClasses: [RegulatedDecisionClass]
    public let appealPaths: [AppealOrReviewPath]
    public let supportsAssessmentRegistry: Bool
    public let supportsOperatorReview: Bool
    public let supportsUserAppeals: Bool
    public let supportsComplianceReporting: Bool
    public let supportsAuditIntegration: Bool
    
    public init(
        decisionClasses: [RegulatedDecisionClass],
        appealPaths: [AppealOrReviewPath],
        supportsAssessmentRegistry: Bool,
        supportsOperatorReview: Bool,
        supportsUserAppeals: Bool,
        supportsComplianceReporting: Bool,
        supportsAuditIntegration: Bool
    ) {
        self.decisionClasses = decisionClasses
        self.appealPaths = appealPaths
        self.supportsAssessmentRegistry = supportsAssessmentRegistry
        self.supportsOperatorReview = supportsOperatorReview
        self.supportsUserAppeals = supportsUserAppeals
        self.supportsComplianceReporting = supportsComplianceReporting
        self.supportsAuditIntegration = supportsAuditIntegration
    }
}

public struct RegulatedDecisionModuleHealth: Sendable, Codable {
    public let status: AnigmaPrimitives.HealthStatus
    public let assessmentCount: Int
    public let gateOperational: Bool
    public let operatorSurfaceOperational: Bool
    public let appealSurfaceOperational: Bool
    public let lastCheck: Date
    
    public init(
        status: AnigmaPrimitives.HealthStatus,
        assessmentCount: Int,
        gateOperational: Bool,
        operatorSurfaceOperational: Bool,
        appealSurfaceOperational: Bool,
        lastCheck: Date
    ) {
        self.status = status
        self.assessmentCount = assessmentCount
        self.gateOperational = gateOperational
        self.operatorSurfaceOperational = operatorSurfaceOperational
        self.appealSurfaceOperational = appealSurfaceOperational
        self.lastCheck = lastCheck
    }
}

// MARK: - Integration Helpers

extension RegulatedDecisionModule {
    /// Create a builder for constructing regulated mission descriptors
    public static func createMissionBuilder() -> RegulatedMissionDescriptorBuilder {
        return RegulatedMissionDescriptorBuilder()
    }
    
    /// Create a builder for constructing impact assessments
    public static func createAssessmentBuilder() -> RegulatedDecisionAssessmentBuilder {
        return RegulatedDecisionAssessmentBuilder()
    }
}

// MARK: - Builder Types

public struct RegulatedMissionDescriptorBuilder {
    private var descriptor: SaturatedMissionDescriptor = SaturatedMissionDescriptor.default
    private var privacy: MissionPrivacyProfile = MissionPrivacyProfile(
        privacyClass: .regulated,
        dataSubjectScope: .user,
        allowedPurpose: .regulatedDecision,
        trainingAllowed: false,
        evalAllowed: false,
        retentionClass: .legalHold,
        redactionRequired: true,
        exportAllowed: false,
        jurisdiction: .US,
        regulatedDecisionClass: .automatedDecision,
        humanReviewRequired: true,
        appealOrReviewPath: .userAppeal
    )
    private var impactAssessmentID: UUID? = nil
    private var humanOversightAssignee: String? = nil
    private var explanationStrategy: String? = nil
    private var postDeploymentMonitoringPlan: String? = nil
    private var incidentEscalationPath: String? = nil
    private var dataProvenanceStatement: String? = nil
    
    public init() {}
    
    public mutating func withDescriptor(_ descriptor: SaturatedMissionDescriptor) -> Self {
        self.descriptor = descriptor
        return self
    }
    
    public mutating func withPrivacy(_ privacy: MissionPrivacyProfile) -> Self {
        self.privacy = privacy
        return self
    }
    
    public mutating func withImpactAssessmentID(_ id: UUID) -> Self {
        self.impactAssessmentID = id
        return self
    }
    
    public mutating func withHumanOversightAssignee(_ assignee: String) -> Self {
        self.humanOversightAssignee = assignee
        return self
    }
    
    public mutating func withExplanationStrategy(_ strategy: String) -> Self {
        self.explanationStrategy = strategy
        return self
    }
    
    public mutating func withPostDeploymentMonitoringPlan(_ plan: String) -> Self {
        self.postDeploymentMonitoringPlan = plan
        return self
    }
    
    public mutating func withIncidentEscalationPath(_ path: String) -> Self {
        self.incidentEscalationPath = path
        return self
    }
    
    public mutating func withDataProvenanceStatement(_ statement: String) -> Self {
        self.dataProvenanceStatement = statement
        return self
    }
    
    public func build() -> RegulatedMissionDescriptor {
        return RegulatedMissionDescriptor(
            descriptor: descriptor,
            privacy: privacy,
            impactAssessmentID: impactAssessmentID,
            humanOversightAssignee: humanOversightAssignee,
            explanationStrategy: explanationStrategy,
            postDeploymentMonitoringPlan: postDeploymentMonitoringPlan,
            incidentEscalationPath: incidentEscalationPath,
            dataProvenanceStatement: dataProvenanceStatement
        )
    }
}

public struct RegulatedDecisionAssessmentBuilder {
    private var missionID: UUID = UUID()
    private var decisionClass: RegulatedDecisionClass = .automatedDecision
    private var impactAssessmentReference: String = ""
    private var humanOversightAssignee: String = "compliance@company.com"
    private var explanationStrategy: String = "transparency_report"
    private var appealOrReviewPath: AppealOrReviewPath = .userAppeal
    private var postDeploymentMonitoringPlan: String = "continuous_monitoring"
    private var incidentEscalationPath: String = "compliance_team"
    private var dataProvenanceStatement: String = "Data sourced from user inputs with proper consent"
    private var approvedByHuman: Bool = false
    private var notes: String? = nil
    
    public init() {}
    
    public mutating func withMissionID(_ id: UUID) -> Self {
        self.missionID = id
        return self
    }
    
    public mutating func withDecisionClass(_ decisionClass: RegulatedDecisionClass) -> Self {
        self.decisionClass = decisionClass
        return self
    }
    
    public mutating func withImpactAssessmentReference(_ reference: String) -> Self {
        self.impactAssessmentReference = reference
        return self
    }
    
    public mutating func withHumanOversightAssignee(_ assignee: String) -> Self {
        self.humanOversightAssignee = assignee
        return self
    }
    
    public mutating func withExplanationStrategy(_ strategy: String) -> Self {
        self.explanationStrategy = strategy
        return self
    }
    
    public mutating func withAppealOrReviewPath(_ path: AppealOrReviewPath) -> Self {
        self.appealOrReviewPath = path
        return self
    }
    
    public mutating func withPostDeploymentMonitoringPlan(_ plan: String) -> Self {
        self.postDeploymentMonitoringPlan = plan
        return self
    }
    
    public mutating func withIncidentEscalationPath(_ path: String) -> Self {
        self.incidentEscalationPath = path
        return self
    }
    
    public mutating func withDataProvenanceStatement(_ statement: String) -> Self {
        self.dataProvenanceStatement = statement
        return self
    }
    
    public mutating func withApprovedByHuman(_ approved: Bool) -> Self {
        self.approvedByHuman = approved
        return self
    }
    
    public mutating func withNotes(_ notes: String) -> Self {
        self.notes = notes
        return self
    }
    
    public func build() -> RegulatedDecisionAssessment {
        return RegulatedDecisionAssessment(
            id: UUID(),
            missionID: missionID,
            decisionClass: decisionClass,
            assessedAt: Date(),
            impactAssessmentReference: impactAssessmentReference,
            humanOversightAssignee: humanOversightAssignee,
            explanationStrategy: explanationStrategy,
            appealOrReviewPath: appealOrReviewPath,
            postDeploymentMonitoringPlan: postDeploymentMonitoringPlan,
            incidentEscalationPath: incidentEscalationPath,
            dataProvenanceStatement: dataProvenanceStatement,
            approvedByHuman: approvedByHuman,
            notes: notes
        )
    }
}
