//
//  AdminPolicyManager.swift
//  AnigmaSystemSpine
//
//  Created by Anigma Agent.
//

import Foundation

public enum UserRole: String, Codable, Sendable {
    case user
    case auditor
    case admin
    case itAdmin = "it_admin"
}

public struct PolicyPack: Codable, Sendable {
    public let id: String
    public let name: String
    public let allowedConnectors: [String]
    public let maxScopeLevel: String // e.g. "read_only", "limited_write", "full"
    public let requireApprovalForWriteBack: Bool
    public let retentionDays: Int
    public let legalHoldEnabled: Bool
    public let exportRestricted: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        allowedConnectors: [String] = [],
        maxScopeLevel: String = "read_only",
        requireApprovalForWriteBack: Bool = true,
        retentionDays: Int = 365,
        legalHoldEnabled: Bool = false,
        exportRestricted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.allowedConnectors = allowedConnectors
        self.maxScopeLevel = maxScopeLevel
        self.requireApprovalForWriteBack = requireApprovalForWriteBack
        self.retentionDays = retentionDays
        self.legalHoldEnabled = legalHoldEnabled
        self.exportRestricted = exportRestricted
    }
}

public actor AdminPolicyManager {
    private var policies: [String: PolicyPack] = [:] // TenantID -> Policy
    private var userRoles: [String: UserRole] = [:] // UserID -> Role

    public init() {}

    public func setPolicy(tenantId: String, policy: PolicyPack) {
        policies[tenantId] = policy
    }

    public func getPolicy(tenantId: String) -> PolicyPack? {
        return policies[tenantId]
    }

    public func setUserRole(userId: String, role: UserRole) {
        userRoles[userId] = role
    }

    public func getUserRole(userId: String) -> UserRole {
        return userRoles[userId] ?? .user
    }

    public func canEnableConnector(tenantId: String, connectorType: String) -> Bool {
        guard let policy = policies[tenantId] else { return true } // Default allow if no policy? Or deny? Default deny is safer.
        return policy.allowedConnectors.contains(connectorType)
    }

    public func isWriteBackAllowed(tenantId: String) -> Bool {
        guard let policy = policies[tenantId] else { return false }
        return !policy.requireApprovalForWriteBack
    }

    public func exportAuditLog(tenantId: String, requesterId: String) throws -> Data {
        let role = getUserRole(userId: requesterId)
        guard role == .admin || role == .auditor else {
            throw NSError(domain: "AdminPolicyManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Insufficient permissions"])
        }

        // Stub for audit log export
        return Data()
    }
}
