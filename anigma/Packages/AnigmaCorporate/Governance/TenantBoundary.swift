//
//  TenantBoundary.swift
//  AnigmaCorporate
//
//  Enforces tenant isolation and admin policies.
//

import Foundation
import AnigmaCore

public struct TenantID: Hashable, Sendable, Codable {
    public let value: String
    public init(_ value: String) { self.value = value }
}

public struct WorkspaceID: Hashable, Sendable, Codable {
    public let value: String
    public init(_ value: String) { self.value = value }
}

public struct TenantContext: Sendable {
    public let tenantId: TenantID
    public let workspaceId: WorkspaceID
    public let authenticatedUser: String

    public init(tenantId: TenantID, workspaceId: WorkspaceID, authenticatedUser: String) {
        self.tenantId = tenantId
        self.workspaceId = workspaceId
        self.authenticatedUser = authenticatedUser
    }
}

public actor TenantBoundary {
    private var activeTenants: Set<TenantID> = []

    public init() {}

    public func registerTenant(_ id: TenantID) {
        activeTenants.insert(id)
    }

    public func validateAccess(context: TenantContext) throws {
        guard activeTenants.contains(context.tenantId) else {
            throw CorporateError.accessDenied("Invalid tenant")
        }
        // Additional policy checks would go here
    }
}

public actor AdminConsole {
    private let boundary: TenantBoundary

    public init(boundary: TenantBoundary) {
        self.boundary = boundary
    }

    public func provisionTenant(id: String) async {
        await boundary.registerTenant(TenantID(id))
    }

    public func exportAuditLog(for tenant: TenantID) async throws -> Data {
        let csv = await AuditLogger.shared.exportLogsAsCSV(forTenant: tenant.value)
        guard let data = csv.data(using: .utf8) else {
            throw CorporateError.internalError("Failed to encode audit logs")
        }
        return data
    }
}
