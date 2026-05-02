import Foundation

/// Specialized logger for doctrine and governance-related security events.
public struct DoctrineSecurityLogger {
    private let manager: SecurityEventsManager
    
    public init(manager: SecurityEventsManager) {
        self.manager = manager
    }
    
    /// Log when an action violates a doctrine rule.
    public func logDoctrineViolation(
        engineId: String,
        doctrineRule: String,
        violatingAction: String,
        severity: SecurityEventSeverity = .high,
        reason: String? = nil
    ) async throws {
        try await manager.recordEvent(
            type: .doctrineViolation,
            severity: severity,
            engineId: engineId,
            operation: violatingAction,
            details: SecurityEventDetails(
                engineId: engineId,
                doctrineRule: doctrineRule,
                reason: reason ?? "Doctrine rule violation: \(doctrineRule)",
                blockedAction: violatingAction,
                metadata: ["doctrineRule": doctrineRule]
            )
        )
    }
    
    /// Log when research is deemed inadequate for an operation.
    public func logResearchInadequate(
        engineId: String,
        operation: String,
        researchBundleId: String,
        reason: String,
        requiredResearchLevel: String? = nil
    ) async throws {
        var metadata = ["researchBundleId": researchBundleId]
        if let level = requiredResearchLevel {
            metadata["requiredLevel"] = level
        }
        
        try await manager.recordEvent(
            type: .researchInadequate,
            severity: .high,
            engineId: engineId,
            operation: operation,
            details: SecurityEventDetails(
                engineId: engineId,
                researchBundleId: researchBundleId,
                reason: reason,
                blockedAction: operation,
                metadata: metadata
            )
        )
    }
    
    /// Log when governance mode changes.
    public func logModeChanged(
        engineId: String,
        oldMode: String,
        newMode: String,
        reason: String? = nil,
        changedBy: String? = nil
    ) async throws {
        var metadata = [
            "oldMode": oldMode,
            "newMode": newMode
        ]
        if let changedBy = changedBy {
            metadata["changedBy"] = changedBy
        }
        
        try await manager.recordEvent(
            type: .modeChanged,
            severity: .medium,
            engineId: engineId,
            details: SecurityEventDetails(
                engineId: engineId,
                reason: reason ?? "Governance mode changed from \(oldMode) to \(newMode)",
                metadata: metadata
            )
        )
    }
}
