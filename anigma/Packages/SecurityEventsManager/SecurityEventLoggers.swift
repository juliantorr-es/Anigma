import Foundation

/// Convenience API for accessing security event loggers.
public struct SecurityEventLoggers {
    private let manager: SecurityEventsManager
    
    public var capability: CapabilitySecurityLogger
    public var trust: TrustSecurityLogger
    public var doctrine: DoctrineSecurityLogger
    public var threat: ThreatSecurityLogger
    
    public init(manager: SecurityEventsManager) {
        self.manager = manager
        self.capability = CapabilitySecurityLogger(manager: manager)
        self.trust = TrustSecurityLogger(manager: manager)
        self.doctrine = DoctrineSecurityLogger(manager: manager)
        self.threat = ThreatSecurityLogger(manager: manager)
    }
    
    /// Direct access to the underlying manager for custom event recording.
    public nonisolated func getManager() -> SecurityEventsManager {
        return manager
    }
}
