import Foundation
import GovernanceContracts
import AnigmaPrimitives
import ComplianceAuditModule

// MARK: - Regulated Decision Operator Surface

/// Operator surface for reviewing and managing regulated decisions
public struct RegulatedDecisionOperatorSurface {
    private let registry: RegulatedDecisionImpactAssessmentRegistry
    private let auditService: AuditLoggingService
    
    public init(
        registry: RegulatedDecisionImpactAssessmentRegistry,
        auditService: AuditLoggingService
    ) {
        self.registry = registry
        self.auditService = auditService
    }
    
    // MARK: - Decision Review Operations
    
    /// Get all regulated decisions requiring review
    public func getDecisionsRequiringReview() async -> [RegulatedDecisionAssessment] {
        // In a real implementation, this would query the registry
        // For now, return empty array as placeholder
        return []
    }
    
    /// Get a specific regulated decision by ID
    public func getDecision(id: UUID) async -> RegulatedDecisionAssessment? {
        return await registry.assessment(id: id)
    }
    
    /// Get decisions by mission ID
    public func getDecisions(for missionID: UUID) async -> [RegulatedDecisionAssessment] {
        if let latest = await registry.latestAssessment(for: missionID) {
            return [latest]
        }
        return []
    }
    
    // MARK: - Appeal Management
    
    /// Record an appeal against a regulated decision
    public func recordAppeal(
        decisionID: UUID,
        appealReason: String,
        appealedBy: String
    ) async throws {
        guard var assessment = await registry.assessment(id: decisionID) else {
            throw RegulatedDecisionError.decisionNotFound(decisionID)
        }
        
        // Update assessment with appeal information
        let updatedNotes = (assessment.notes ?? "") + "\nAppeal: " + appealReason
        assessment = RegulatedDecisionAssessment(
            id: assessment.id,
            missionID: assessment.missionID,
            decisionClass: assessment.decisionClass,
            assessedAt: assessment.assessedAt,
            impactAssessmentReference: assessment.impactAssessmentReference,
            humanOversightAssignee: assessment.humanOversightAssignee,
            explanationStrategy: assessment.explanationStrategy,
            appealOrReviewPath: .userAppeal,
            postDeploymentMonitoringPlan: assessment.postDeploymentMonitoringPlan,
            incidentEscalationPath: assessment.incidentEscalationPath,
            dataProvenanceStatement: assessment.dataProvenanceStatement,
            approvedByHuman: false, // Reset approval for appeal
            notes: updatedNotes
        )
        
        await registry.register(assessment)
        
        try await auditService.logGovernanceDecision(
            GovernanceDecisionAuditEvent(
                baseEvent: AuditEvent(
                    eventType: .governanceDecision,
                    principal: appealedBy,
                    operationType: "regulated_decision_appeal",
                    resourceId: decisionID.uuidString,
                    resourceType: "regulated_decision",
                    action: "appeal_recorded",
                    result: "recorded",
                    details: [
                        "decision_id": decisionID.uuidString,
                        "reason": appealReason,
                        "appeal_path": "user_appeal"
                    ],
                    metadata: [
                        "decision_id": decisionID.uuidString,
                        "reason": appealReason,
                        "appeal_path": "user_appeal"
                    ],
                    complianceFlags: ["policy_enforcement"]
                ),
                decisionType: .escalated,
                policyId: "regulated_decision",
                policyVersion: "1",
                blockingFactors: [appealReason],
                approvalChain: [appealedBy],
                justification: "User appeal recorded for regulated decision",
                appealsProcess: "user_appeal",
                automatedReview: false
            )
        )
    }
    
    // MARK: - Explanation Management
    
    /// Get explanation for a regulated decision
    public func getExplanation(for decisionID: UUID) async -> String? {
        guard let assessment = await registry.assessment(id: decisionID) else {
            return nil
        }
        
        return "Decision ID: " + decisionID.uuidString + "\n" +
               "Decision Class: " + assessment.decisionClass.rawValue + "\n" +
               "Explanation Strategy: " + assessment.explanationStrategy + "\n" +
               "Human Oversight: " + assessment.humanOversightAssignee + "\n" +
               "Assessed At: " + assessment.assessedAt.formatted()
    }
    
    /// Update explanation for a regulated decision
    public func updateExplanation(
        decisionID: UUID,
        explanation: String,
        updatedBy: String
    ) async throws {
        guard var assessment = await registry.assessment(id: decisionID) else {
            throw RegulatedDecisionError.decisionNotFound(decisionID)
        }
        
        let updatedNotes = (assessment.notes ?? "") + "\nExplanation updated by " + updatedBy + ": " + explanation
        assessment = RegulatedDecisionAssessment(
            id: assessment.id,
            missionID: assessment.missionID,
            decisionClass: assessment.decisionClass,
            assessedAt: Date(), // Update timestamp
            impactAssessmentReference: assessment.impactAssessmentReference,
            humanOversightAssignee: assessment.humanOversightAssignee,
            explanationStrategy: assessment.explanationStrategy,
            appealOrReviewPath: assessment.appealOrReviewPath,
            postDeploymentMonitoringPlan: assessment.postDeploymentMonitoringPlan,
            incidentEscalationPath: assessment.incidentEscalationPath,
            dataProvenanceStatement: assessment.dataProvenanceStatement,
            approvedByHuman: assessment.approvedByHuman,
            notes: updatedNotes
        )
        
        await registry.register(assessment)
        
        try await auditService.logGovernanceDecision(
            GovernanceDecisionAuditEvent(
                baseEvent: AuditEvent(
                    eventType: .governanceDecision,
                    principal: updatedBy,
                    operationType: "regulated_decision_explanation",
                    resourceId: decisionID.uuidString,
                    resourceType: "regulated_decision",
                    action: "explanation_updated",
                    result: "recorded",
                    details: [
                        "decision_id": decisionID.uuidString,
                        "explanation_length": String(explanation.count)
                    ],
                    metadata: [
                        "decision_id": decisionID.uuidString,
                        "explanation_length": String(explanation.count)
                    ],
                    complianceFlags: ["policy_enforcement"]
                ),
                decisionType: .approved,
                policyId: "regulated_decision",
                policyVersion: "1",
                approvalChain: [updatedBy],
                justification: "Explanation updated for regulated decision",
                appealsProcess: "explanation_review",
                automatedReview: false
            )
        )
    }
    
    // MARK: - Compliance Reporting
    
    /// Get compliance report for regulated decisions
    public func getComplianceReport() async -> RegulatedDecisionComplianceReport {
        // In a real implementation, this would query the registry and build a comprehensive report
        // For now, return a placeholder report
        return RegulatedDecisionComplianceReport(
            totalDecisions: 0,
            decisionsRequiringAssessment: 0,
            decisionsWithHumanOversight: 0,
            decisionsWithAppeals: 0,
            complianceIssues: [],
            generatedAt: Date()
        )
    }
}

// MARK: - Supporting Types

public enum RegulatedDecisionError: Error, Equatable {
    case decisionNotFound(UUID)
    case assessmentNotFound(UUID)
    case complianceViolation(String)
}

public struct RegulatedDecisionComplianceReport: Sendable, Codable {
    public let totalDecisions: Int
    public let decisionsRequiringAssessment: Int
    public let decisionsWithHumanOversight: Int
    public let decisionsWithAppeals: Int
    public let complianceIssues: [String]
    public let generatedAt: Date
    
    public init(
        totalDecisions: Int,
        decisionsRequiringAssessment: Int,
        decisionsWithHumanOversight: Int,
        decisionsWithAppeals: Int,
        complianceIssues: [String],
        generatedAt: Date
    ) {
        self.totalDecisions = totalDecisions
        self.decisionsRequiringAssessment = decisionsRequiringAssessment
        self.decisionsWithHumanOversight = decisionsWithHumanOversight
        self.decisionsWithAppeals = decisionsWithAppeals
        self.complianceIssues = complianceIssues
        self.generatedAt = generatedAt
    }
}
