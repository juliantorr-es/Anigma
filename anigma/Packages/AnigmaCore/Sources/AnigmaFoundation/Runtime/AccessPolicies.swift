//
//  AccessPolicies.swift
//  AnigmaFoundation
//
//  Standard access policies for the platform.
//

import Foundation
import AnigmaPrimitives
import GovernanceContracts

/// Policy that grants access based on roles.
public struct RoleBasedPolicy: AccessPolicy, Sendable {
    public let id: String
    public let priority: Int
    public let allowedRoles: Set<String>
    public let componentTypes: Set<String>?
    public let maxSensitivity: DataSensitivity
    public let accessTypes: [AccessType]

    public init(
        id: String,
        priority: Int,
        allowedRoles: Set<String>,
        componentTypes: Set<String>? = nil,
        maxSensitivity: DataSensitivity = .internal,
        accessTypes: [AccessType] = [.read]
    ) {
        self.id = id
        self.priority = priority
        self.allowedRoles = allowedRoles
        self.componentTypes = componentTypes
        self.maxSensitivity = maxSensitivity
        self.accessTypes = accessTypes
    }

    public func evaluate(_ request: AccessRequest) async -> AccessDecision? {
        // If this policy restricts by component type and it doesn't match, skip
        if let types = componentTypes, !types.contains(request.componentType) {
            return nil
        }

        // If sensitivity is too high, this policy doesn't apply (or denies)
        if request.sensitivity > maxSensitivity {
            return nil
        }

        // Check if role is allowed
        let principalRoles = request.principal.roles
        let hasRole = !allowedRoles.isDisjoint(with: principalRoles)

        if hasRole && accessTypes.contains(request.accessType) {
            return AccessDecision.allow(policyId: id, reason: "Principal has required role")
        }

        return nil
    }
}

/// Policy that restricts access based on module ownership.
public struct ModuleOwnershipPolicy: AccessPolicy, Sendable {
    public let id: String
    public let priority: Int
    public let moduleComponents: [String: Set<String>]
    public let maxSensitivity: DataSensitivity

    public init(
        id: String,
        priority: Int,
        moduleComponents: [String: Set<String>],
        maxSensitivity: DataSensitivity = .confidential
    ) {
        self.id = id
        self.priority = priority
        self.moduleComponents = moduleComponents
        self.maxSensitivity = maxSensitivity
    }

    public func evaluate(_ request: AccessRequest) async -> AccessDecision? {
        let principalModule = request.principal.module
        
        // If principal's module owns this component type
        if let ownedTypes = moduleComponents[principalModule], 
           ownedTypes.contains(request.componentType) {
            
            // Still check sensitivity
            if request.sensitivity <= maxSensitivity {
                return AccessDecision.allow(policyId: id, reason: "Module owns this component type")
            }
        }

        return nil
    }
}

/// Policy that requires explicit justification for restricted data access.
public struct RestrictedDataPolicy: AccessPolicy, Sendable {
    public let id: String = "restricted-data-justification"
    public let priority: Int = 800

    public init() {}

    public func evaluate(_ request: AccessRequest) async -> AccessDecision? {
        if request.sensitivity >= .restricted {
            if let justification = request.justification, !justification.isEmpty {
                return nil // Allow other policies to decide if justification is present
            } else {
                return AccessDecision.deny(policyId: id, reason: "Justification required for restricted data")
            }
        }
        return nil
    }
}
