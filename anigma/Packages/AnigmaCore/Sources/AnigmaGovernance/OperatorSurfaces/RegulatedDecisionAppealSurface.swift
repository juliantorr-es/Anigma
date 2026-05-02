import Foundation
import AnigmaPrimitives

// MARK: - Regulated Decision Appeal Surface

/// User-facing surface for appealing regulated decisions
public struct RegulatedDecisionAppealSurface {
    private let operatorSurface: RegulatedDecisionOperatorSurface
    
    public init(operatorSurface: RegulatedDecisionOperatorSurface) {
        self.operatorSurface = operatorSurface
    }
    
    // MARK: - User Appeal Operations
    
    /// Get appeal status for a decision
    public func getAppealStatus(for decisionID: UUID) async -> RegulatedDecisionAppealStatus? {
        guard let assessment = await operatorSurface.getDecision(id: decisionID) else {
            return nil
        }
        
        let hasActiveAppeal = assessment.appealOrReviewPath == .userAppeal
        let appealNotes = assessment.notes?.contains("Appeal:") ?? false
        
        return RegulatedDecisionAppealStatus(
            decisionID: decisionID,
            hasActiveAppeal: hasActiveAppeal,
            appealPath: assessment.appealOrReviewPath,
            appealNotesAvailable: appealNotes,
            humanOversightAssignee: assessment.humanOversightAssignee
        )
    }
    
    /// File an appeal against a regulated decision
    public func fileAppeal(
        decisionID: UUID,
        appealReason: String,
        userID: String
    ) async throws -> RegulatedDecisionAppealResult {
        do {
            try await operatorSurface.recordAppeal(
                decisionID: decisionID,
                appealReason: appealReason,
                appealedBy: userID
            )
            
            return RegulatedDecisionAppealResult(
                success: true,
                decisionID: decisionID,
                appealFiledAt: Date(),
                message: "Appeal successfully filed and will be reviewed"
            )
        } catch RegulatedDecisionError.decisionNotFound(let id) {
            return RegulatedDecisionAppealResult(
                success: false,
                decisionID: id,
                appealFiledAt: nil,
                message: "Decision not found: " + id.uuidString
            )
        } catch {
            return RegulatedDecisionAppealResult(
                success: false,
                decisionID: decisionID,
                appealFiledAt: nil,
                message: "Failed to file appeal: " + error.localizedDescription
            )
        }
    }
    
    /// Get explanation for why a decision was made
    public func getDecisionExplanation(for decisionID: UUID) async -> String? {
        return await operatorSurface.getExplanation(for: decisionID)
    }
    
    /// Check if a decision is appealable
    public func isDecisionAppealable(decisionID: UUID) async -> Bool {
        guard let assessment = await operatorSurface.getDecision(id: decisionID) else {
            return false
        }
        
        // Decisions are appealable if they require assessment and have human oversight
        return assessment.decisionClass.requiresAssessment && 
               !assessment.humanOversightAssignee.isEmpty
    }
}

// MARK: - Supporting Types

public struct RegulatedDecisionAppealStatus: Sendable, Codable {
    public let decisionID: UUID
    public let hasActiveAppeal: Bool
    public let appealPath: AppealOrReviewPath
    public let appealNotesAvailable: Bool
    public let humanOversightAssignee: String
    
    public init(
        decisionID: UUID,
        hasActiveAppeal: Bool,
        appealPath: AppealOrReviewPath,
        appealNotesAvailable: Bool,
        humanOversightAssignee: String
    ) {
        self.decisionID = decisionID
        self.hasActiveAppeal = hasActiveAppeal
        self.appealPath = appealPath
        self.appealNotesAvailable = appealNotesAvailable
        self.humanOversightAssignee = humanOversightAssignee
    }
}

public struct RegulatedDecisionAppealResult: Sendable, Codable {
    public let success: Bool
    public let decisionID: UUID
    public let appealFiledAt: Date?
    public let message: String
    
    public init(
        success: Bool,
        decisionID: UUID,
        appealFiledAt: Date?,
        message: String
    ) {
        self.success = success
        self.decisionID = decisionID
        self.appealFiledAt = appealFiledAt
        self.message = message
    }
}

// MARK: - Disclosure Types

public struct RegulatedDecisionDisclosure: Sendable, Codable {
    public let decisionID: UUID
    public let decisionClass: RegulatedDecisionClass
    public let humanOversightAssignee: String
    public let appealPath: AppealOrReviewPath
    public let explanationAvailable: Bool
    public let disclosureDate: Date
    
    public init(
        decisionID: UUID,
        decisionClass: RegulatedDecisionClass,
        humanOversightAssignee: String,
        appealPath: AppealOrReviewPath,
        explanationAvailable: Bool,
        disclosureDate: Date = Date()
    ) {
        self.decisionID = decisionID
        self.decisionClass = decisionClass
        self.humanOversightAssignee = humanOversightAssignee
        self.appealPath = appealPath
        self.explanationAvailable = explanationAvailable
        self.disclosureDate = disclosureDate
    }
}