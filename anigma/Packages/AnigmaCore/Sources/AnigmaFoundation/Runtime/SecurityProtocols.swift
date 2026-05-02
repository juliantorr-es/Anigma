//
//  SecurityProtocols.swift
//  AnigmaFoundation
//
//  Protocols for security infrastructure to support dependency injection
//  and resolve circular dependencies with AnigmaGovernance.
//

import Foundation
import AnigmaPrimitives
import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts

/// Protocol for security infrastructure components.
public protocol SecurityInfrastructure: Sendable {
    /// Gets the enforcement engine.
    var enforcementEngine: any PolicyEnforcementEngineAPI { get async }
}

/// Interface for the policy enforcement engine.
public protocol PolicyEnforcementEngineAPI: Sendable {
    /// Enforces a threat decision.
    func enforce(_ threat: DetectedThreat) async -> EnforcementDecision
}

/// Capability for components that require audit logging.
public protocol AuditLoggable: Sendable {
    func setAuditLog(_ auditLog: any AuditLogging) async
}
