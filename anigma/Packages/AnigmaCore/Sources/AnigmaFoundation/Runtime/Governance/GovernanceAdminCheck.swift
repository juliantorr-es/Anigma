import AnigmaFoundation
import AnigmaPrimitives
import Foundation
import GovernanceCore
import GovernanceContracts

// Note: This file was moved from AnigmaGovernance to RuntimeCore
// to resolve circular dependency. It only uses portable governance types.

/// Admin carveout for governance operations.
/// Allows governance-admin principals to change governance state (mode, kill switch)
/// even when current mode would deny writes.
///
/// **Why this exists**: Without this, readOnly mode becomes permanent - you can't change
/// mode because changing mode requires a write. This check provides a controlled escape hatch.
///
/// **Audit trail**: All admin operations still produce receipts and audit events.
/// They're just allowed regardless of current OperatingMode.
public struct GovernanceAdminCheck: WriteCheck, Sendable {
    public let id = "governance-admin"
    public let name = "Governance Admin Privilege"
    public let isBlocking = true  // Blocking - enforces admin-only when mode denies writes
    
    private let modeProvider: @Sendable (String?) async -> OperatingMode
    
    public init(modeProvider: @escaping @Sendable (String?) async -> OperatingMode) {
        self.modeProvider = modeProvider
    }
    
    public init() {
        // Fallback: always allow if no mode provider (for tests)
        self.modeProvider = { _ in .assistive }
    }
    
    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        // Only applies to governance-related database operations
        proposal.componentType == "governance"
    }
    
    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        // Get current mode for this project
        let projectId = proposal.context["projectId"]
        let mode = await modeProvider(projectId)
        
        // If current mode allows writes, allow governance operation for anyone
        if mode.canWrite {
            return .pass(
                checkId: id,
                message: "Governance operation allowed in \(mode.label) mode"
            )
        }
        
        // Mode denies writes - check if principal is admin (escape hatch)
        if proposal.principal == "system" || 
           proposal.principal == "test-admin" ||
           proposal.principal == "cli-admin" ||
           proposal.principal == "daemon-admin" ||
           proposal.principal.lowercased().contains("admin") {
            return .pass(
                checkId: id,
                message: "Governance admin principal '\(proposal.principal)' allowed despite \(mode.label) mode"
            )
        }
        
        // Non-admin attempting governance operation in restrictive mode - deny
        return .fail(
            checkId: id,
            message: "Principal '\(proposal.principal)' is not authorized for governance operations in \(mode.label) mode"
        )
    }
}
