//
//  HealthStatus.swift
//  AnigmaPrimitives
//
//  Canonical health status enumeration used across all Anigma modules.
//  This resolves the ambiguity between multiple HealthStatus definitions.
//

import Foundation

/// Canonical health status enumeration used across all Anigma modules.
///
/// This enum consolidates the various HealthStatus definitions that were
/// previously defined in different modules (CoreUtilities, ComplianceAuditModule,
/// HarmoniaWorkflowContracts, AnigmaCore, etc.) to resolve compilation ambiguity.
public enum HealthStatus: String, Codable, CaseIterable, Sendable {
    /// System is operating normally
    case healthy = "healthy"
    
    /// System is operating but with reduced capacity or minor issues
    case degraded = "degraded"
    
    /// System is experiencing significant issues but still partially functional
    case unhealthy = "unhealthy"
    
    /// System status cannot be determined
    case unknown = "unknown"
    
    /// System requires attention but is still operational (mapped from AnigmaCore's "warning")
    case warning = "warning"
    
    /// System is in critical condition and may fail (mapped from AnigmaCore's "critical")
    case critical = "critical"
    
    /// Convenience property for checking if status indicates operational system
    public var isOperational: Bool {
        return self == .healthy || self == .degraded || self == .warning
    }
    
    /// Convenience property for checking if status indicates problems
    public var hasProblems: Bool {
        return self == .unhealthy || self == .critical
    }
}

// MARK: - Legacy Compatibility

public extension HealthStatus {
    /// Map from AnigmaCore's legacy HealthStatus (warning, critical)
    /// to the canonical HealthStatus enum
    init(anigmaCoreHealthStatus: AnigmaCoreHealthStatus) {
        switch anigmaCoreHealthStatus {
            case .healthy: self = .healthy
            case .degraded: self = .degraded
            case .unhealthy: self = .unhealthy
            case .unknown: self = .unknown
            case .warning: self = .warning
            case .critical: self = .critical
        }
    }
    
    /// Map from ComplianceAuditModule's HealthStatus
    /// to the canonical HealthStatus enum
    init(complianceAuditHealthStatus: ComplianceAuditHealthStatus) {
        switch complianceAuditHealthStatus {
            case .healthy: self = .healthy
            case .degraded: self = .degraded
            case .unhealthy: self = .unhealthy
            case .unknown: self = .unknown
            case .warning: self = .warning
            case .critical: self = .critical
        }
    }
    
    /// Map from HarmoniaWorkflowContracts' HealthStatus
    /// to the canonical HealthStatus enum
    init(workflowContractsHealthStatus: WorkflowContractsHealthStatus) {
        switch workflowContractsHealthStatus {
            case .healthy: self = .healthy
            case .degraded: self = .degraded
            case .unhealthy: self = .unhealthy
            case .unknown: self = .unknown
            case .warning: self = .warning
            case .critical: self = .critical
        }
    }
}

// MARK: - Type Aliases for Backward Compatibility

/// Type alias for AnigmaCore's HealthStatus (for backward compatibility)
public typealias AnigmaCoreHealthStatus = HealthStatus

/// Type alias for ComplianceAuditModule's HealthStatus (for backward compatibility)
public typealias ComplianceAuditHealthStatus = HealthStatus

/// Type alias for HarmoniaWorkflowContracts' HealthStatus (for backward compatibility)
public typealias WorkflowContractsHealthStatus = HealthStatus
