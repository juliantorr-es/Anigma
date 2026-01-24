//
//  CapabilityGovernanceAdapter.swift
//  PlatformCore
//
//  Adapter that bridges GovernanceController with CapabilityCore governance protocol.
//

import AnigmaCore
import AnigmaPrimitives
import CapabilityCore
import ContractsCore
import Foundation
import GovernanceCore

/// Adapter that allows GovernanceController to be used with CapabilityRegistry.
public struct CapabilityGovernanceAdapter: CapabilityRegistry.CapabilityGovernance {
    private let controller: GovernanceController

    public init(controller: GovernanceController) {
        self.controller = controller
    }

    public func canResolve(
        capabilityId: String,
        principal: String,
        context: [String: String]
    ) async -> (allowed: Bool, reason: String?) {
        // Create a write proposal for capability resolution
        // (treating capability resolution as a write operation for governance purposes)
        let proposal = WriteProposal(
            principal: principal,
            module: "CapabilityCore",
            operation: "resolve_capability",
            entityId: nil,
            componentType: capabilityId,
            context: context
        )

        let decision = await controller.canWrite(proposal)

        if decision.allowed {
            return (true, nil)
        } else {
            let reason = decision.failedChecks
                .map { $0.message }
                .joined(separator: "; ")
            return (false, reason.isEmpty ? "Access denied" : reason)
        }
    }
}

/// Adapter that allows AuditLogging to be used with CapabilityRegistry.
public struct CapabilityAuditAdapter: CapabilityRegistry.CapabilityAuditLog {
    private let auditLog: AuditLogging

    public init(auditLog: AuditLogging) {
        self.auditLog = auditLog
    }

    public func logResolution(
        capabilityId: String,
        principal: String,
        success: Bool,
        metadata: [String: String]
    ) async {
        let eventType: ContractsCore.AuditEventType = success ? .custom : .accessDenied

        var enrichedMetadata = metadata
        enrichedMetadata["capability_id"] = capabilityId
        enrichedMetadata["success"] = success ? "true" : "false"

        let description =
            success
            ? "Capability resolved: \(capabilityId)"
            : "Capability resolution failed: \(capabilityId)"

        try? await auditLog.record(
            eventType: eventType,
            principal: principal,
            module: "CapabilityCore",
            description: description,
            metadata: enrichedMetadata
        )
    }
}
