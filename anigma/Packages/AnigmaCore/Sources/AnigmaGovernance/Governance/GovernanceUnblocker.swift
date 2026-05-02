//
//  GovernanceUnblocker.swift
//  AnigmaCore
//
//  Deterministic unblocking workflow for denied governance operations.
//  When a write is blocked, this system provides structured troubleshooting
//  and resolution paths to prevent permanent blocking.
//

import AnigmaFoundation
import Foundation
import AnigmaPrimitives
import GovernanceCore
import GovernanceContracts

/// Structured analysis of why a write was denied
public struct GovernanceDenialAnalysis: Error, Sendable, Codable {
    /// The original proposal that was denied
    public let originalProposal: WriteProposal
    
    /// The decision that denied the write
    public let denialDecision: WriteGateDecision
    
    /// Detailed breakdown of which checks failed
    public let failedChecks: [WriteCheckResult]
    
    /// Suggested resolution paths
    public let resolutionOptions: [GovernanceResolutionOption]
    
    /// Timestamp of the analysis
    public let analyzedAt: Date
    
    public init(
        originalProposal: WriteProposal,
        denialDecision: WriteGateDecision,
        failedChecks: [WriteCheckResult],
        resolutionOptions: [GovernanceResolutionOption],
        analyzedAt: Date = Date()
    ) {
        self.originalProposal = originalProposal
        self.denialDecision = denialDecision
        self.failedChecks = failedChecks
        self.resolutionOptions = resolutionOptions
        self.analyzedAt = analyzedAt
    }
}

/// Structured resolution option for unblocking
public struct GovernanceResolutionOption: Sendable, Codable {
    /// Unique identifier for this resolution path
    public let id: String
    
    /// Human-readable title
    public let title: String
    
    /// Detailed description of what this resolves
    public let description: String
    
    /// The type of resolution
    public let resolutionType: ResolutionType
    
    /// Estimated risk level
    public let riskLevel: RiskLevel
    
    /// Prerequisites that must be true
    public let prerequisites: [String]
    
    /// Steps to execute this resolution
    public let executionSteps: [String]
    
    /// Expected outcome
    public let expectedOutcome: String
    
    public enum ResolutionType: String, Sendable, Codable {
        case modeChange = "MODE_CHANGE"
        case adminOverride = "ADMIN_OVERRIDE"
        case policyAdjustment = "POLICY_ADJUSTMENT"
        case contextCorrection = "CONTEXT_CORRECTION"
        case emergencyBypass = "EMERGENCY_BYPASS"
    }
    
    public enum RiskLevel: String, Sendable, Codable {
        case low = "LOW"
        case medium = "MEDIUM"
        case high = "HIGH"
        case critical = "CRITICAL"
    }
}

/// Main governance unblocking system
public actor GovernanceUnblocker: Sendable {
    private let governance: any GoverningController
    private let auditLog: any AuditLogging
    
    public init(governance: any GoverningController, auditLog: any AuditLogging) {
        self.governance = governance
        self.auditLog = auditLog
    }
    
    /// Analyze why a write was denied and suggest resolutions
    public func analyzeDenial(_ proposal: WriteProposal, decision: WriteGateDecision) -> GovernanceDenialAnalysis {
        let failedChecks = decision.checkResults.filter { !$0.passed }
        let resolutionOptions = generateResolutionOptions(proposal, failedChecks: failedChecks)
        
        return GovernanceDenialAnalysis(
            originalProposal: proposal,
            denialDecision: decision,
            failedChecks: failedChecks,
            resolutionOptions: resolutionOptions
        )
    }
    
    /// Generate appropriate resolution options based on failure reasons
    private func generateResolutionOptions(_ proposal: WriteProposal, failedChecks: [WriteCheckResult]) -> [GovernanceResolutionOption] {
        var options: [GovernanceResolutionOption] = []
        
        // Check for operating mode issues
        if failedChecks.contains(where: { $0.checkId == "operating-mode" }) {
            options.append(operatingModeResolution(proposal))
        }
        
        // Check for admin privilege issues
        if failedChecks.contains(where: { $0.checkId == "governance-admin" }) {
            options.append(adminOverrideResolution(proposal))
        }
        
        // Check for kill switch issues
        if failedChecks.contains(where: { $0.message.contains("kill switch") }) {
            options.append(killSwitchResolution())
        }
        
        // Always provide context correction as a low-risk option
        options.append(contextCorrectionResolution(proposal))
        
        return options
    }
    
    /// Resolution: Change operating mode to allow writes
    private func operatingModeResolution(_ proposal: WriteProposal) -> GovernanceResolutionOption {
        let projectId = proposal.context["projectId"] as? String
        
        return GovernanceResolutionOption(
            id: "mode-change-" + (projectId ?? "global"),
            title: "Change Operating Mode to Allow Writes",
            description: "Switch from readOnly to assistive or autopilot mode to permit this operation",
            resolutionType: .modeChange,
            riskLevel: .medium,
            prerequisites: [
                "Requires admin privileges",
                "Affects all operations in this mode scope"
            ],
            executionSteps: [
                "1. Identify current mode: await governance.showMode(for: projectId)",
                "2. Change to appropriate mode: await governance.setMode(.assistive, for: projectId, by: adminPrincipal)",
                "3. Retry the original operation",
                "4. Consider switching back to original mode after operation completes"
            ],
            expectedOutcome: "Operation will be allowed if principal has appropriate permissions"
        )
    }
    
    /// Resolution: Use admin override for critical operations
    private func adminOverrideResolution(_ proposal: WriteProposal) -> GovernanceResolutionOption {
        return GovernanceResolutionOption(
            id: "admin-override-" + proposal.principal,
            title: "Execute as Admin (Carveout)",
            description: "Use administrative privileges to bypass mode restrictions for critical operations",
            resolutionType: .adminOverride,
            riskLevel: .high,
            prerequisites: [
                "Requires admin role (cli-admin, system, etc.)",
                "Should only be used for recovery operations",
                "Create audit trail explaining why override was necessary"
            ],
            executionSteps: [
                "1. Verify admin credentials",
                "2. Create new proposal with admin principal",
                "3. Execute: await governance.canWrite(newAdminProposal)",
                "4. Document override in incident log",
                "5. Review if mode change would be better long-term solution"
            ],
            expectedOutcome: "Operation will succeed with admin privileges"
        )
    }
    
    /// Resolution: Disable kill switch (emergency only)
    private func killSwitchResolution() -> GovernanceResolutionOption {
        return GovernanceResolutionOption(
            id: "kill-switch-disable",
            title: "Disable Kill Switch (Emergency)",
            description: "Deactivate kill switch to restore write capabilities - use only for critical recovery",
            resolutionType: .emergencyBypass,
            riskLevel: .critical,
            prerequisites: [
                "Requires system/admin principal",
                "Understand why kill switch was activated",
                "Have plan to reactivate after recovery"
            ],
            executionSteps: [
                "1. Check current status: await governance.killSwitchStatus()",
                "2. Deactivate: await governance.killSwitch.setKillSwitch(active: false, for: nil, by: admin)",
                "3. Execute blocked operations",
                "4. Investigate root cause of kill switch activation",
                "5. Reactivate kill switch if still needed: await governance.killSwitch.setKillSwitch(active: true, ...)"
            ],
            expectedOutcome: "All writes will be allowed until kill switch is reactivated"
        )
    }
    
    /// Resolution: Fix context/issues in the proposal
    private func contextCorrectionResolution(_ proposal: WriteProposal) -> GovernanceResolutionOption {
        return GovernanceResolutionOption(
            id: "context-correction",
            title: "Correct Proposal Context",
            description: "Fix issues in the write proposal that caused denial (missing context, wrong sensitivity, etc.)",
            resolutionType: .contextCorrection,
            riskLevel: .low,
            prerequisites: [
                "Review denial reasons in decision.checkResults",
                "Understand what context was missing/invalid"
            ],
            executionSteps: [
                "1. Examine failed checks: decision.checkResults.filter { !$0.passed }",
                "2. Create corrected proposal with proper context",
                "3. Add missing fields (projectId, sensitivity, etc.)",
                "4. Retry with corrected proposal",
                "5. Verify all checks now pass"
            ],
            expectedOutcome: "Operation will succeed with proper context"
        )
    }
    
    /// Execute a resolution option and return the result
    public func executeResolution(_ option: GovernanceResolutionOption, by principal: Principal) async throws -> GovernanceResolutionResult {
        // Log the resolution attempt
        try await auditLog.recordEvent(
            id: UUID(),
            type: AuditEventType.custom,
            principal: principal.id,
            module: "GovernanceUnblocker",
            description: "Attempting resolution: \(option.title)",
            metadata: [
                "resolutionId": option.id,
                "resolutionType": option.resolutionType.rawValue,
                "riskLevel": option.riskLevel.rawValue
            ]
        )
        
        // Execute based on resolution type
        switch option.resolutionType {
        case .modeChange:
            return try await executeModeChange(option, by: principal)
        case .adminOverride:
            return try await executeAdminOverride(option, by: principal)
        case .emergencyBypass:
            return try await executeEmergencyBypass(option, by: principal)
        case .contextCorrection:
            return .requiresManualImplementation(
                message: "Context correction requires manual proposal adjustment",
                suggestion: "Create new proposal with corrected context and retry"
            )
        case .policyAdjustment:
            return .requiresManualImplementation(
                message: "Policy adjustments require manual configuration",
                suggestion: "Review and adjust governance policies as needed"
            )
        }
    }
    
    private func executeModeChange(_ option: GovernanceResolutionOption, by principal: Principal) async throws -> GovernanceResolutionResult {
        // Extract projectId from original proposal context
        // This would need the original proposal to be stored or passed in
        return .requiresManualImplementation(
            message: "Mode change requires projectId from original proposal",
            suggestion: "Call governance.setMode() with appropriate parameters"
        )
    }
    
    private func executeAdminOverride(_ option: GovernanceResolutionOption, by principal: Principal) async throws -> GovernanceResolutionResult {
        // Admin override would create a new proposal with admin principal
        return .requiresManualImplementation(
            message: "Admin override requires new proposal with admin credentials",
            suggestion: "Create new WriteProposal with admin principal and retry"
        )
    }
    
    private func executeEmergencyBypass(_ option: GovernanceResolutionOption, by principal: Principal) async throws -> GovernanceResolutionResult {
        // Emergency bypass would disable kill switch
        return .requiresManualImplementation(
            message: "Emergency bypass requires explicit kill switch deactivation",
            suggestion: "Call governance.killSwitch.setKillSwitch(active: false, ...)"
        )
    }
}

/// Result of attempting a governance resolution
public enum GovernanceResolutionResult: Sendable {
    case success(message: String)
    case failed(error: String)
    case requiresManualImplementation(message: String, suggestion: String)
    case partialSuccess(message: String, warnings: [String])
}

/// Enhanced write analysis result
public enum GovernanceWriteAnalysis: Sendable {
    case allowed(decision: WriteGateDecision)
    case denied(analysis: GovernanceDenialAnalysis)
}
