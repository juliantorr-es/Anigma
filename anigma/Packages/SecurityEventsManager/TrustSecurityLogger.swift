import Foundation

/// Specialized logger for trust-related security events.
public struct TrustSecurityLogger {
    private let manager: SecurityEventsManager
    
    public init(manager: SecurityEventsManager) {
        self.manager = manager
    }
    
    /// Log when trust tier is promoted (elevated).
    public func logTrustPromoted(
        engineId: String,
        entityId: String,
        oldTier: String,
        newTier: String,
        reason: String? = nil,
        metadata: [String: String]? = nil
    ) async throws {
        var details = metadata ?? [:]
        details["oldTier"] = oldTier
        details["newTier"] = newTier
        
        try await manager.recordEvent(
            type: .trustPromoted,
            severity: .medium,
            engineId: engineId,
            details: SecurityEventDetails(
                engineId: engineId,
                reason: reason ?? "Trust tier promoted",
                metadata: details
            )
        )
    }
    
    /// Log when trust tier is degraded (demoted).
    public func logTrustDegraded(
        engineId: String,
        entityId: String,
        oldTier: String,
        newTier: String,
        reason: String,
        metadata: [String: String]? = nil
    ) async throws {
        var details = metadata ?? [:]
        details["oldTier"] = oldTier
        details["newTier"] = newTier
        
        try await manager.recordEvent(
            type: .trustDegraded,
            severity: .high,
            engineId: engineId,
            details: SecurityEventDetails(
                engineId: engineId,
                reason: reason,
                metadata: details
            )
        )
    }
    
    /// Log when trust is recalculated.
    public func logTrustRecalculation(
        engineId: String,
        entityId: String,
        riskFactors: [String],
        newTier: String,
        reason: String? = nil
    ) async throws {
        try await manager.recordEvent(
            type: .trustRecalculation,
            severity: .medium,
            engineId: engineId,
            details: SecurityEventDetails(
                engineId: engineId,
                reason: reason ?? "Trust recalculated",
                metadata: [
                    "newTier": newTier,
                    "riskFactors": riskFactors.joined(separator: ",")
                ]
            )
        )
    }
}
