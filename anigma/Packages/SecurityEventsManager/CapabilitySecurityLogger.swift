import Foundation

/// Specialized logger for capability-related security events.
public struct CapabilitySecurityLogger {
    private let manager: SecurityEventsManager
    
    public init(manager: SecurityEventsManager) {
        self.manager = manager
    }
    
    /// Log when a capability is blocked or denied.
    public func logCapabilityBlocked(
        engineId: String,
        operation: String,
        capability: String,
        reason: String,
        zone: String? = nil
    ) async throws {
        try await manager.recordEvent(
            type: .capabilityBlocked,
            severity: .high,
            engineId: engineId,
            operation: operation,
            details: SecurityEventDetails(
                engineId: engineId,
                zone: zone,
                capability: capability,
                reason: reason,
                blockedAction: operation
            )
        )
    }
    
    /// Log when a capability is granted or elevated.
    public func logCapabilityGranted(
        engineId: String,
        operation: String,
        capability: String,
        grantedBy: String? = nil,
        reason: String? = nil
    ) async throws {
        try await manager.recordEvent(
            type: .capabilityGranted,
            severity: .medium,
            engineId: engineId,
            operation: operation,
            details: SecurityEventDetails(
                engineId: engineId,
                capability: capability,
                reason: reason ?? "Capability granted",
                attemptedAction: operation,
                metadata: grantedBy.flatMap { ["grantedBy": $0] }
            )
        )
    }
    
    /// Log when a capability escalation attempt is detected.
    public func logCapabilityEscalation(
        engineId: String,
        attemptedCapability: String,
        currentCapability: String,
        reason: String
    ) async throws {
        try await manager.recordEvent(
            type: .capabilityEscalation,
            severity: .critical,
            engineId: engineId,
            details: SecurityEventDetails(
                engineId: engineId,
                capability: attemptedCapability,
                reason: reason,
                attemptedAction: "escalate to \(attemptedCapability)",
                blockedAction: "capability_escalation",
                metadata: ["currentCapability": currentCapability]
            )
        )
    }
}
