//
//  AccessControlContracts.swift
//  GovernanceContracts
//
//  Portable access control contract types for governance.
//  These are pure data/protocol shapes with no runtime dependencies.
//  Part of Tier 1 (Contracts) - may be imported by any tier.
//

import Foundation
import AnigmaPrimitives
import FoundationContracts

// MARK: - Mode Source

/// Source of the effective operating mode.
public enum ModeSource: String, Sendable, Codable {
    /// Mode is set at the project level
    case project = "project"
    
    /// Mode is set globally (applies to all projects without project-specific overrides)
    case global = "global"
    
    /// No mode is set; using system default
    case defaultMode = "default"
}

// MARK: - Operating Modes

/// Operating modes that control what AI agents can do.
public enum OperatingMode: String, Sendable, Codable {
    /// Agents can only read and analyze. No modifications allowed.
    case readOnly = "read_only"

    /// Agents can suggest changes but require human confirmation.
    case assistive = "assistive"

    /// Agents can execute changes autonomously (with governance checks).
    case autopilot = "autopilot"

    public var label: String {
        switch self {
        case .readOnly: return "Read Only"
        case .assistive: return "Assistive"
        case .autopilot: return "Autopilot"
        }
    }

    public var canWrite: Bool {
        self != .readOnly
    }

    public var requiresConfirmation: Bool {
        self == .assistive
    }
}

/// Raw value wrapper for OperatingMode (for Codable Set).
public enum OperatingModeRaw: String, Sendable, Codable {
    case readOnly = "read_only"
    case assistive = "assistive"
    case autopilot = "autopilot"

    public var operatingMode: OperatingMode {
        switch self {
        case .readOnly: return .readOnly
        case .assistive: return .assistive
        case .autopilot: return .autopilot
        }
    }
}

// MARK: - Governance Status

/// Summary of governance status.
public struct GovernanceStatus: Sendable, Codable {
    public let operatingMode: OperatingMode
    public let killSwitchActive: Bool
    public let killSwitchReason: String?
    public let accessPolicyCount: Int
    public let retentionPolicyCount: Int
    
    public init(
        operatingMode: OperatingMode,
        killSwitchActive: Bool,
        killSwitchReason: String? = nil,
        accessPolicyCount: Int = 0,
        retentionPolicyCount: Int = 0
    ) {
        self.operatingMode = operatingMode
        self.killSwitchActive = killSwitchActive
        self.killSwitchReason = killSwitchReason
        self.accessPolicyCount = accessPolicyCount
        self.retentionPolicyCount = retentionPolicyCount
    }
}

// MARK: - Access Control Types

/// Data sensitivity levels for classification.
public enum DataSensitivity: Int, Comparable, Sendable, Codable {
    case `public` = 0
    case `internal` = 100
    case confidential = 200
    case sensitive = 250
    case restricted = 300
    case topSecret = 400

    public static func < (lhs: DataSensitivity, rhs: DataSensitivity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .public: return "Public"
        case .internal: return "Internal"
        case .confidential: return "Confidential"
        case .sensitive: return "Sensitive"
        case .restricted: return "Restricted"
        case .topSecret: return "TopSecret"
        }
    }
}

/// Types of access that can be requested.
public enum AccessType: String, Sendable, Codable {
    case read = "read"
    case write = "write"
    case delete = "delete"
    case query = "query"
}

/// Represents the identity requesting access (typically a System).
public struct AccessPrincipal: Sendable, Hashable, Codable {
    /// Unique identifier for the principal.
    public let id: String

    /// The module this principal belongs to.
    public let module: String

    /// Roles assigned to this principal.
    public let roles: Set<String>

    /// Additional attributes for ABAC evaluation.
    public let attributes: [String: String]

    /// System principal for internal operations.
    public static func system(_ id: String, module: String, roles: Set<String> = []) -> AccessPrincipal {
        AccessPrincipal(id: id, module: module, roles: roles)
    }

    public init(
        id: String,
        module: String,
        roles: Set<String> = [],
        attributes: [String: String] = [:]
    ) {
        self.id = id
        self.module = module
        self.roles = roles
        self.attributes = attributes
    }
}

/// Represents a request to access a component.
public struct AccessRequest: Sendable, Codable {
    /// The principal requesting access.
    public let principal: AccessPrincipal

    /// The component type being accessed.
    public let componentType: String

    /// The sensitivity level of the component.
    public let sensitivity: DataSensitivity

    /// Data categories of the component.
    public let dataCategories: Set<String>

    /// The type of access being requested.
    public let accessType: AccessType

    /// The entity being accessed (if specific).
    public let entityId: EntityId?

    /// Justification for the access (required for restricted data).
    public let justification: String?

    /// Timestamp of the request.
    public let timestamp: Date

    public init(
        principal: AccessPrincipal,
        componentType: String,
        sensitivity: DataSensitivity,
        dataCategories: Set<String> = [],
        accessType: AccessType,
        entityId: EntityId? = nil,
        justification: String? = nil,
        timestamp: Date = Date()
    ) {
        self.principal = principal
        self.componentType = componentType
        self.sensitivity = sensitivity
        self.dataCategories = dataCategories
        self.accessType = accessType
        self.entityId = entityId
        self.justification = justification
        self.timestamp = timestamp
    }
}

/// The result of an access control evaluation.
public struct AccessDecision: Sendable, Codable {
    /// Whether access was granted.
    public let allowed: Bool

    /// The policy that made the decision.
    public let policyId: String

    /// Reason for the decision.
    public let reason: String

    /// Any conditions attached to the grant.
    public let conditions: [String]

    /// Timestamp of the decision.
    public let timestamp: Date

    public init(
        allowed: Bool,
        policyId: String,
        reason: String,
        conditions: [String] = [],
        timestamp: Date = Date()
    ) {
        self.allowed = allowed
        self.policyId = policyId
        self.reason = reason
        self.conditions = conditions
        self.timestamp = timestamp
    }

    /// Quick factory for allowed decisions.
    public static func allow(policyId: String, reason: String, conditions: [String] = []) -> AccessDecision {
        AccessDecision(allowed: true, policyId: policyId, reason: reason, conditions: conditions)
    }

    /// Quick factory for denied decisions.
    public static func deny(policyId: String, reason: String) -> AccessDecision {
        AccessDecision(allowed: false, policyId: policyId, reason: reason)
    }
}

// MARK: - Access Controller Protocol

/// Protocol defining the interface for an Access Controller.
public protocol AccessController: Sendable {
    /// Evaluates an access request against all policies.
    func evaluate(_ request: AccessRequest) async -> AccessDecision

    /// Checks access and throws if denied.
    func checkAccess(_ request: AccessRequest) async throws

    /// Adds a policy to the controller.
    func addPolicy(_ policy: any AccessPolicy) async

    /// Lists all registered policies.
    func listPolicies() async -> [any AccessPolicy]
}

/// Protocol defining the interface for an Access Policy.
public protocol AccessPolicy: Sendable {
    var id: String { get }
    var priority: Int { get }
    func evaluate(_ request: AccessRequest) async -> AccessDecision?
}

// MARK: - Principal

/// Represents an authenticated identity performing operations.
/// Used for access control and audit trails.
public struct Principal: Sendable, Codable, Hashable {
    /// Unique identifier for the principal (user ID, service account, etc.)
    public let id: String

    /// Display name for audit logs
    public let displayName: String

    /// Attributes for ABAC (Attribute-Based Access Control)
    public let attributes: [String: String]

    /// Roles for RBAC (Role-Based Access Control)
    public let roles: Set<String>

    public init(
        id: String,
        displayName: String,
        attributes: [String: String] = [:],
        roles: Set<String> = []
    ) {
        self.id = id
        self.displayName = displayName
        self.attributes = attributes
        self.roles = roles
    }

    /// System principal for internal operations
    public static let system = Principal(
        id: "system",
        displayName: "Anigma System",
        roles: ["system"]
    )

    /// Anonymous principal for unauthenticated operations
    public static let anonymous = Principal(
        id: "anonymous",
        displayName: "Anonymous User"
    )
}

// MARK: - Runtime Write Gate API

/// Protocol for the runtime write gate.
/// Coordinates quality checks before write operations.
public protocol RuntimeWriteGateAPI: Sendable {
    /// Sets the audit logger for the gate.
    func setAuditLog(_ log: any AuditLogging) async

    /// Registers a quality check.
    func registerCheck(_ check: any WriteCheck) async

    /// Evaluates a write proposal against all registered checks.
    func evaluate(_ proposal: WriteProposal) async -> WriteGateDecision
}

// MARK: - Runtime Kill Switch API

/// Protocol for runtime kill switch operations.
/// Supports engaging and disengaging the kill switch at both global and project levels.
public protocol RuntimeKillSwitchAPI: Sendable {
    /// Engage the kill switch (blocks writes).
    func setKillSwitch(active: Bool, for projectId: String?, reason: String?, by principal: Principal) async throws

    /// Show the kill switch status.
    func showKillSwitch(for projectId: String?) async throws -> (active: Bool, reason: String?)

    /// Checks if a write operation is allowed for a project.
    func isWriteAllowed(forProject projectId: String?) async -> Bool

    /// Engages the kill switch (blocks writes).
    func activate(reason: String, by principalId: String) async

    /// Gets the current status of the kill switch.
    func killSwitchStatus() async -> (isActive: Bool, activationReason: String?)

    /// Deactivates the kill switch.
    func deactivate(by principalId: String) async
}

// MARK: - Runtime Governance API

/// Protocol for runtime governance operations.
/// Supports setting, showing, and clearing operating modes at both global and project levels.
/// This is a portable contract that can be used by any governance layer.
public protocol RuntimeGovernanceAPI: Sendable {
    /// Set governance operating mode (global or project-scoped).
    func setMode(_ mode: OperatingMode, for projectId: String?, by principal: Principal) async throws

    /// Show the effective operating mode for a project or global.
    func showMode(for projectId: String?) async throws -> (effective: OperatingMode, source: ModeSource)

    /// Clear a project-specific or global mode override.
    func clearMode(for projectId: String?, by principal: Principal) async throws
}

// Note: See also WriteGateContracts.swift for supporting types:
// - WriteCheck, WriteProposal, WriteGateDecision, WriteCheckResult
// - KillSwitchStatus
// WriteProposal, WriteGateDecision, WriteCheck, WriteCheckResult which are still in GovernanceCore.
// These types need to be extracted to GovernanceContracts for full portability.
