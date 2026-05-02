import Foundation

/// Specialized logger for threat and attack-related security events.
public struct ThreatSecurityLogger {
    private let manager: SecurityEventsManager
    
    public init(manager: SecurityEventsManager) {
        self.manager = manager
    }
    
    /// Log a red team attack or security test.
    public func logRedTeamAttack(
        engineId: String,
        attackType: String,
        targetOperation: String? = nil,
        severity: SecurityEventSeverity = .high,
        details: String? = nil
    ) async throws {
        try await manager.recordEvent(
            type: .redTeamAttack,
            severity: severity,
            engineId: engineId,
            operation: targetOperation,
            details: SecurityEventDetails(
                engineId: engineId,
                reason: details ?? "Red team attack detected: \(attackType)",
                blockedAction: targetOperation,
                metadata: ["attackType": attackType]
            )
        )
    }
    
    /// Log an unauthorized access attempt.
    public func logUnauthorizedAccess(
        engineId: String,
        attemptedResource: String,
        reason: String? = nil,
        metadata: [String: String]? = nil
    ) async throws {
        var details = metadata ?? [:]
        details["resource"] = attemptedResource
        
        try await manager.recordEvent(
            type: .unauthorizedAccess,
            severity: .critical,
            engineId: engineId,
            operation: "access_\(attemptedResource)",
            details: SecurityEventDetails(
                engineId: engineId,
                reason: reason ?? "Unauthorized access to \(attemptedResource)",
                blockedAction: "access_\(attemptedResource)",
                metadata: details
            )
        )
    }
    
    /// Log a network exfiltration attempt.
    public func logNetworkExfiltration(
        engineId: String,
        targetHost: String,
        dataType: String,
        severity: SecurityEventSeverity = .critical,
        reason: String? = nil
    ) async throws {
        try await manager.recordEvent(
            type: .networkExfiltration,
            severity: severity,
            engineId: engineId,
            details: SecurityEventDetails(
                engineId: engineId,
                reason: reason ?? "Network exfiltration detected: \(dataType) to \(targetHost)",
                blockedAction: "exfiltrate_\(dataType)_to_\(targetHost)",
                metadata: [
                    "targetHost": targetHost,
                    "dataType": dataType
                ]
            )
        )
    }
    
    /// Log a prompt injection attack.
    public func logPromptInjection(
        engineId: String,
        injectedContent: String? = nil,
        targetSystem: String? = nil,
        reason: String? = nil
    ) async throws {
        var metadata: [String: String] = [:]
        if let targetSystem = targetSystem {
            metadata["targetSystem"] = targetSystem
        }
        
        try await manager.recordEvent(
            type: .promptInjection,
            severity: .critical,
            engineId: engineId,
            operation: "prompt_injection",
            details: SecurityEventDetails(
                engineId: engineId,
                reason: reason ?? "Prompt injection attack detected",
                blockedAction: "prompt_injection",
                metadata: metadata
            )
        )
    }
}
