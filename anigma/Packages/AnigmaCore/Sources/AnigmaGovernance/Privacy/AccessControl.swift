//
//  AccessControl.swift
//  AnigmaCore
//
//  Internal access control infrastructure for the Anigma ECS.
//  Implements RBAC (Role-Based) and ABAC (Attribute-Based) access control
//  to govern which Systems can access which Components.
//
//  This is mandatory infrastructure, not optional middleware.
//  All sensitive component access should flow through these controls.
//
//  Design principles:
//  - Deny by default for sensitive components
//  - Explicit grants required for access
//  - All access decisions are logged
//  - Policies are declarative and auditable
//

import AnigmaFoundation
import GovernanceCore
import Foundation
import AnigmaPrimitives
import GovernanceContracts

// MARK: - Sensitivity Classification

/// Data sensitivity levels for components.
/// Higher levels require more restrictive access controls.
public enum PrivacySensitivity: Int, Comparable, Sendable, Codable {
    /// Public data with no access restrictions.
    case `public` = 0

    /// Internal data visible to authenticated systems.
    case `internal` = 1

    /// Confidential data requiring explicit access grants.
    case confidential = 2

    /// Sensitive data (PII, medical, financial) with strict access controls.
    case sensitive = 3

    /// Restricted data requiring per-access justification and logging.
    case restricted = 4

    public static func < (lhs: PrivacySensitivity, rhs: PrivacySensitivity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .public: return "Public"
        case .internal: return "Internal"
        case .confidential: return "Confidential"
        case .sensitive: return "Sensitive"
        case .restricted: return "Restricted"
        }
    }
}

// MARK: - Function Clearance

/// Clearance levels for agentic functions and tools.
/// Maps to governance policies to determine if a function execution requires approval.
public enum FunctionClearance: Int, Comparable, Sendable, Codable {
    /// Safe functions with no external impact (e.g., math, text transformation).
    case regular = 0

    /// Functions that access internal data or user state (e.g., calendar read, search).
    case sensitive = 1

    /// Functions that can mutate user data or perform external actions (e.g., send email, delete file).
    /// Requires explicit user confirmation in most operating modes.
    case dangerous = 2

    /// Functions that could compromise system integrity or security.
    /// Requires multi-factor authorization or admin approval.
    case critical = 3

    public static func < (lhs: FunctionClearance, rhs: FunctionClearance) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Sensitive Component Protocol

/// Protocol for components that carry sensitivity metadata.
/// Components conforming to this will have their access governed.
public protocol GovernedSensitiveComponent: Component {
    /// The sensitivity level of this component's data.
    static var sensitivity: DataSensitivity { get }

    /// Optional data categories for ABAC policies (e.g., "medical", "financial", "pii").
    static var dataCategories: Set<String> { get }
}

/// Default implementations for GovernedSensitiveComponent.
public extension GovernedSensitiveComponent {
    static var sensitivity: DataSensitivity { .internal }
    static var dataCategories: Set<String> { [] }
}

// MARK: - Built-in Policies

/// Policy that allows access based on roles.
public struct RoleBasedPolicy: AccessPolicy, Sendable {
    public let id: String
    public let priority: Int

    /// Roles that are granted access.
    public let allowedRoles: Set<String>

    /// Component types this policy applies to (empty = all).
    public let componentTypes: Set<String>

    /// Maximum sensitivity level this policy can grant access to.
    public let maxSensitivity: DataSensitivity

    /// Access types this policy grants.
    public let accessTypes: Set<AccessType>

    public init(
        id: String,
        priority: Int = 100,
        allowedRoles: Set<String>,
        componentTypes: Set<String> = [],
        maxSensitivity: DataSensitivity = .confidential,
        accessTypes: Set<AccessType> = [.read, .query]
    ) {
        self.id = id
        self.priority = priority
        self.allowedRoles = allowedRoles
        self.componentTypes = componentTypes
        self.maxSensitivity = maxSensitivity
        self.accessTypes = accessTypes
    }

    public func evaluate(_ request: AccessRequest) async -> AccessDecision? {
        // Check if policy applies to this component type
        if !componentTypes.isEmpty && !componentTypes.contains(request.componentType) {
            return nil
        }

        // Check access type
        guard accessTypes.contains(request.accessType) else {
            return nil
        }

        // Check sensitivity
        guard request.sensitivity <= maxSensitivity else {
            return .deny(policyId: id, reason: "Sensitivity level \(request.sensitivity.label) exceeds policy maximum \(maxSensitivity.label)")
        }

        // Check roles
        let matchingRoles = request.principal.roles.intersection(allowedRoles)
        if matchingRoles.isEmpty {
            return nil // Let another policy handle it
        }

        return .allow(
            policyId: id,
            reason: "Role match: \(matchingRoles.joined(separator: ", "))"
        )
    }
}

/// Policy that allows access based on module ownership.
/// Systems can access components from their own module.
public struct ModuleOwnershipPolicy: AccessPolicy, Sendable {
    public let id: String
    public let priority: Int

    /// Module to component type mappings.
    public let moduleComponents: [String: Set<String>]

    /// Maximum sensitivity for module-owned access.
    public let maxSensitivity: DataSensitivity

    public init(
        id: String = "module-ownership",
        priority: Int = 200,
        moduleComponents: [String: Set<String>],
        maxSensitivity: DataSensitivity = .sensitive
    ) {
        self.id = id
        self.priority = priority
        self.moduleComponents = moduleComponents
        self.maxSensitivity = maxSensitivity
    }

    public func evaluate(_ request: AccessRequest) async -> AccessDecision? {
        guard let ownedComponents = moduleComponents[request.principal.module] else {
            return nil
        }

        guard ownedComponents.contains(request.componentType) else {
            return nil
        }

        guard request.sensitivity <= maxSensitivity else {
            return .deny(policyId: id, reason: "Module ownership does not grant access to \(request.sensitivity.label) data")
        }

        return .allow(
            policyId: id,
            reason: "Module \(request.principal.module) owns component type \(request.componentType)"
        )
    }
}

/// Policy that requires justification for restricted data.
public struct RestrictedDataPolicy: AccessPolicy, Sendable {
    public let id: String
    public let priority: Int

    public init(id: String = "restricted-data", priority: Int = 500) {
        self.id = id
        self.priority = priority
    }

    public func evaluate(_ request: AccessRequest) async -> AccessDecision? {
        guard request.sensitivity == .restricted else {
            return nil
        }

        guard let justification = request.justification, !justification.isEmpty else {
            return .deny(policyId: id, reason: "Restricted data access requires justification")
        }

        // For restricted data, we allow but with audit condition
        return .allow(
            policyId: id,
            reason: "Restricted access with justification: \(justification)",
            conditions: ["AUDIT_REQUIRED", "JUSTIFICATION_RECORDED"]
        )
    }
}

/// Default deny policy (should be last in the chain).
public struct DefaultDenyPolicy: AccessPolicy, Sendable {
    public let id: String = "default-deny"
    public let priority: Int = 0

    public init() {}

    public func evaluate(_ request: AccessRequest) async -> AccessDecision? {
        .deny(policyId: id, reason: "No policy granted access")
    }
}

// MARK: - Access Controller

/// Policy that allows access based on attributes (ABAC).
public struct AttributeBasedPolicy: AccessPolicy, Sendable {
    public let id: String
    public let priority: Int

    /// Rules defining required attributes for access.
    public let requiredAttributes: [String: String]

    public init(id: String, priority: Int = 300, requiredAttributes: [String: String]) {
        self.id = id
        self.priority = priority
        self.requiredAttributes = requiredAttributes
    }

    public func evaluate(_ request: AccessRequest) async -> AccessDecision? {
        for (key, requiredValue) in requiredAttributes {
            guard let userValue = request.principal.attributes[key] else {
                return .deny(policyId: id, reason: "Missing required attribute: \(key)")
            }

            if userValue != requiredValue {
                return .deny(policyId: id, reason: "Attribute mismatch for \(key): expected \(requiredValue), got \(userValue)")
            }
        }

        return .allow(policyId: id, reason: "All ABAC requirements met")
    }
}

/// Central access controller that evaluates policies.
/// Thread-safe actor for concurrent access decisions.
public actor AccessController: AnigmaFoundation.AccessController {
    private var policies: [any AccessPolicy] = []
    private var auditLog: (any AuditLogging)?

    public init() {
        // Add default deny policy
        policies.append(DefaultDenyPolicy())
    }

    /// Sets the audit log for recording decisions.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Adds a policy to the controller.
    public func addPolicy(_ policy: any AccessPolicy) {
        policies.append(policy)
        // Re-sort by priority (highest first)
        policies.sort { $0.priority > $1.priority }
    }

    /// Removes a policy by ID.
    public func removePolicy(id: String) {
        policies.removeAll { $0.id == id }
    }

    /// Evaluates an access request against all policies.
    public func evaluate(_ request: AccessRequest) async -> AccessDecision {
        var decision: AccessDecision?

        for policy in policies {
            if let result = await policy.evaluate(request) {
                decision = result
                break
            }
        }

        let finalDecision = decision ?? AccessDecision.deny(
            policyId: "fallback",
            reason: "No policy matched"
        )


        // Log to SecurityEventsManager if available
        if let securityManager = SecurityEventingService.shared {
            securityManager.logAccessEvaluation(
                engineId: request.principal.id,
                principal: request.principal.id,
                resource: request.componentType,
                accessType: String(describing: request.accessType),
                allowed: finalDecision.allowed,
                reason: finalDecision.reason
            )
        }

        // Log the decision
        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: AuditEventType.custom,
                principal: request.principal.id,
                module: request.principal.module,
                description: "Access \(finalDecision.allowed ? "granted" : "denied") for \(request.componentType)",
                metadata: {
                    var dict: [String: String] = [
                        "event_type_original": "accessDecision", // Preserve original string
                        "component_type": request.componentType,
                        "access_type": String(describing: request.accessType),
                        "decision": finalDecision.allowed ? "granted" : "denied"
                    ]
                    if let entityId = request.entityId {
                        dict["entity_id"] = entityId.raw.uuidString
                    }
                    return dict
                }()
            )
        }

        return finalDecision
    }

    /// Convenience method to check and throw on denial.
    public func checkAccess(_ request: AccessRequest) async throws {
        let decision = await evaluate(request)

        if !decision.allowed {
            throw AccessControlError.accessDenied(
                principal: request.principal.id,
                component: request.componentType,
                reason: decision.reason
            )
        }
    }

    /// Lists all registered policies.
    public func listPolicies() async -> [any AnigmaFoundation.AccessPolicy] {
        policies.map { $0 as any AnigmaFoundation.AccessPolicy }
    }

    /// Lists policy metadata.
    public func listPolicyMetadata() -> [(id: String, priority: Int)] {
        policies.map { ($0.id, $0.priority) }
    }
}

// MARK: - Access Control Errors

public enum AccessControlError: Error, LocalizedError, Sendable {
    case accessDenied(principal: String, component: String, reason: String)
    case policyNotFound(id: String)
    case invalidConfiguration(message: String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied(let principal, let component, let reason):
            return "Access denied: \(principal) cannot access \(component) - \(reason)"
        case .policyNotFound(let id):
            return "Policy not found: \(id)"
        case .invalidConfiguration(let message):
            return "Invalid access control configuration: \(message)"
        }
    }
}

// MARK: - Access-Controlled World Extension

/// Extension to World that provides access-controlled component access.
extension World {
    /// Gets a component with access control check.
    public func getComponentControlled<C: GovernedSensitiveComponent>(
        _ entity: EntityId,
        _ type: C.Type,
        principal: AccessPrincipal,
        controller: AccessController,
        justification: String? = nil
    ) async throws -> C? {
        let request = AccessRequest(
            principal: principal,
            componentType: String(describing: C.self),
            sensitivity: C.sensitivity,
            dataCategories: C.dataCategories,
            accessType: .read,
            entityId: entity,
            justification: justification
        )

        try await controller.checkAccess(request)
        return getComponent(entity, type)
    }

    /// Queries components with access control check.
    public func queryControlled<C: GovernedSensitiveComponent>(
        _ type: C.Type,
        principal: AccessPrincipal,
        controller: AccessController,
        justification: String? = nil
    ) async throws -> [(EntityId, C)] {
        let request = AccessRequest(
            principal: principal,
            componentType: String(describing: C.self),
            sensitivity: C.sensitivity,
            dataCategories: C.dataCategories,
            accessType: .query,
            justification: justification
        )

        try await controller.checkAccess(request)
        return query(type)
    }
}
