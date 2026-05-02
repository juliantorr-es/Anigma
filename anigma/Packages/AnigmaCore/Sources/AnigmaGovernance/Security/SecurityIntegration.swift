//
//  SecurityIntegration.swift
//  AnigmaCore
//
//  Integration points for SecurityEventsManager logging across AnigmaCore.
//  Provides convenience methods for logging security decisions at critical points.
//

import AnigmaFoundation
import GovernanceCore
import Foundation
import GovernanceContracts
import AnigmaPrimitives
import SecurityEventsManager

/// Singleton accessor for the global SecurityEventsManager instance.
/// This allows modules to log security events without direct dependency injection.
public class SecurityEventingService {
    public static var shared: SecurityEventsManager?
    
    /// Initialize the global security eventing service with a manager instance.
    public static func initialize(with manager: SecurityEventsManager) {
        Self.shared = manager
    }
}

/// Extension providing convenient logging helpers for common security scenarios.
extension SecurityEventsManager {
    
    // MARK: - Access Control Integration
    
    /// Log when access to a resource is evaluated.
    public nonisolated func logAccessEvaluation(
        engineId: String,
        principal: String,
        resource: String,
        accessType: String,
        allowed: Bool,
        reason: String
    ) {
        let severity: SecurityEventSeverity = allowed ? .low : .high
        let eventType: SecurityEventType = allowed ? .capabilityGranted : .capabilityBlocked
        
        let details = SecurityEventDetails(
            engineType: nil,
            engineId: engineId,
            capability: resource,
            reason: reason,
            blockedAction: allowed ? nil : accessType,
            metadata: [
                "principal": principal,
                "resource": resource,
                "accessType": accessType
            ]
        )
        
        Task {
            try? await self.recordEvent(
                type: eventType,
                severity: severity,
                engineId: engineId,
                operation: "access_\(accessType)_\(resource)",
                details: details
            )
        }
    }
    
    // MARK: - Governance Integration
    
    /// Log when a policy decision is made.
    public nonisolated func logPolicyDecision(
        engineId: String,
        policyId: String,
        decision: String,
        reason: String,
        severity: SecurityEventSeverity = .medium
    ) {
        let details = SecurityEventDetails(
            engineType: nil,
            engineId: engineId,
            doctrineRule: policyId,
            reason: reason,
            blockedAction: decision == "deny" ? "policy_violation" : nil,
            metadata: [
                "policyId": policyId,
                "decision": decision
            ]
        )
        
        Task {
            try? await self.recordEvent(
                type: SecurityEventType.doctrineViolation,
                severity: severity,
                engineId: engineId,
                operation: "policy_eval_\(policyId)",
                details: details
            )
        }
    }
    
    // MARK: - Threat Integration
    
    /// Log a detected threat and the enforcement action taken.
    public nonisolated func logThreatEnforcement(
        threatType: String,
        threatLevel: String,
        source: String,
        target: String?,
        action: String,
        reason: String
    ) {
        let severity: SecurityEventSeverity
        switch threatLevel {
        case "critical": severity = .critical
        case "high": severity = .high
        case "medium": severity = .medium
        default: severity = .low
        }
        
        let details = SecurityEventDetails(
            reason: reason,
            blockedAction: action,
            metadata: [
                "threatType": threatType,
                "threatLevel": threatLevel,
                "source": source,
                "target": target ?? "unknown",
                "action": action
            ]
        )
        
        let eventType: SecurityEventType
        switch threatType {
        case "prompt_injection": eventType = .promptInjection
        case "unauthorized_access": eventType = .unauthorizedAccess
        case "network_exfiltration": eventType = .networkExfiltration
        case "red_team": eventType = .redTeamAttack
        default: eventType = SecurityEventType.capabilityBlocked // Using a valid member as fallback
        }
        
        Task {
            try? await self.recordEvent(
                type: eventType,
                severity: severity,
                engineId: source,
                operation: "threat_enforcement",
                details: details
            )
        }
    }
    
    // MARK: - Capability Integration
    
    /// Log a capability decision with full context.
    public nonisolated func logCapabilityDecision(
        engineId: String,
        capability: String,
        granted: Bool,
        trustTier: String,
        zone: String,
        reason: String
    ) {
        let eventType: SecurityEventType = granted ? .capabilityGranted : .capabilityBlocked
        let severity: SecurityEventSeverity = granted ? .low : .high
        
        let details = SecurityEventDetails(
            engineType: nil,
            engineId: engineId,
            zone: zone,
            capability: capability,
            reason: reason,
            blockedAction: granted ? nil : "request_\(capability)",
            metadata: [
                "trustTier": trustTier,
                "granted": granted ? "true" : "false"
            ]
        )
        
        Task {
            try? await self.recordEvent(
                type: eventType,
                severity: severity,
                engineId: engineId,
                operation: "capability_\(granted ? "grant" : "block")_\(capability)",
                details: details
            )
        }
    }
}
