//
//  PostgresRLS.swift
//  DatabaseCore
//
//  Row-Level Security (RLS) primitives for PostgreSQL.
//  Provides tenant isolation, policy enforcement, and session context management.
//

import Foundation
import AnigmaPrimitives

// MARK: - RLS Context

/// Context for Row-Level Security session state.
/// Sets PostgreSQL GUC variables that RLS policies reference.
public struct PostgresRLSContext: Sendable, Codable, Equatable {
    /// Current tenant/project identifier for multi-tenant isolation
    public let tenantID: UUID
    /// Current principal identifier for audit and access control
    public let principalID: PrincipalID
    /// Optional project ID for project-scoped isolation
    public let projectID: ProjectID?
    /// Trust tier for accessing restricted data (1-5, higher = more trusted)
    public let trustTier: Int
    /// Session identifier for request tracking
    public let sessionID: String

    public init(
        tenantID: UUID,
        principalID: PrincipalID,
        projectID: ProjectID? = nil,
        trustTier: Int = 1,
        sessionID: String = UUID().uuidString
    ) {
        self.tenantID = tenantID
        self.principalID = principalID
        self.projectID = projectID
        self.trustTier = max(1, min(5, trustTier))
        self.sessionID = sessionID
    }

    /// Creates RLS SQL SET LOCAL statements for this context
    public var setLocalStatements: [String] {
        var statements: [String] = []
        statements.append("SET LOCAL anigma.current_tenant_id = '" + tenantID.uuidString.escapedForSQL + "'")
        statements.append("SET LOCAL anigma.current_principal_id = '" + principalID.rawValue.uuidString.escapedForSQL + "'")
        statements.append("SET LOCAL anigma.current_session_id = '" + sessionID.escapedForSQL + "'")
        statements.append("SET LOCAL anigma.current_trust_tier = '" + String(trustTier) + "'")
        if let projectID {
            statements.append("SET LOCAL anigma.current_project_id = '" + projectID.rawValue.uuidString.escapedForSQL + "'")
        } else {
            statements.append("SET LOCAL anigma.current_project_id = NULL")
        }
        return statements
    }

    /// Single combined SET LOCAL statement for efficiency
    public var setLocalStatement: String {
        let projectValue = projectID.map { "'" + $0.rawValue.uuidString.escapedForSQL + "'" } ?? "NULL"
        return [
            "SET LOCAL anigma.current_tenant_id = '" + tenantID.uuidString.escapedForSQL + "'",
            "anigma.current_principal_id = '" + principalID.rawValue.uuidString.escapedForSQL + "'",
            "anigma.current_project_id = " + projectValue,
            "anigma.current_session_id = '" + sessionID.escapedForSQL + "'",
            "anigma.current_trust_tier = '" + String(trustTier) + "'"
        ].joined(separator: ", ")
    }

    /// Reset RLS context
    public static var resetStatement: String {
        """
        SET LOCAL 
            anigma.current_tenant_id = NULL,
            anigma.current_principal_id = NULL,
            anigma.current_project_id = NULL,
            anigma.current_session_id = NULL,
            anigma.current_trust_tier = NULL
        """
    }
}

// MARK: - String Extension for SQL Escaping

extension String {
    var escapedForSQL: String {
        replacingOccurrences(of: "'", with: "''")
    }
}

// MARK: - Policy Types

public enum PostgresRLSPolicyCommand: String, Sendable, Codable, CaseIterable {
    case all, select, insert, update, delete
}

public struct PostgresRLSPolicy: Sendable, Codable, Equatable {
    public let name: String
    public let table: String
    public let roles: [String]
    public let usingExpression: String
    public let checkExpression: String?
    public let command: PostgresRLSPolicyCommand

    public init(
        name: String,
        table: String,
        roles: [String] = ["public"],
        usingExpression: String,
        checkExpression: String? = nil,
        command: PostgresRLSPolicyCommand = .all
    ) {
        self.name = name
        self.table = table
        self.roles = roles
        self.usingExpression = usingExpression
        self.checkExpression = checkExpression
        self.command = command
    }

    public var createSQL: String {
        let rolesClause = roles.isEmpty ? "" : " TO " + roles.map { "\"" + $0 + "\"" }.joined(separator: ", ")
        let usingClause = " USING (" + usingExpression + ")"
        let checkClause = checkExpression.map { " WITH CHECK (" + $0 + ")" } ?? ""
        return "CREATE POLICY " + name + " ON " + table + rolesClause + usingClause + checkClause
    }

    public func renameSQL(to newName: String) -> String {
        "ALTER POLICY " + name + " ON " + table + " RENAME TO " + newName
    }

    public var dropSQL: String {
        "DROP POLICY IF EXISTS " + name + " ON " + table
    }
}

// MARK: - Tenant Isolation Policies

public enum TenantIsolationPolicy: Sendable, Codable, CaseIterable {
    case projectScoped, tenantScoped, multiTenant, systemWide

    public func policy(for table: String, column: String = "project_id") -> PostgresRLSPolicy {
        switch self {
        case .projectScoped:
            return PostgresRLSPolicy(
                name: table + "_project_isolation",
                table: table,
                usingExpression: column + " = current_setting('anigma.current_project_id', true)::uuid",
                checkExpression: column + " = current_setting('anigma.current_project_id', true)::uuid"
            )
        case .tenantScoped:
            return PostgresRLSPolicy(
                name: table + "_tenant_isolation",
                table: table,
                usingExpression: "tenant_id = current_setting('anigma.current_tenant_id', true)::uuid",
                checkExpression: "tenant_id = current_setting('anigma.current_tenant_id', true)::uuid"
            )
        case .multiTenant:
            return PostgresRLSPolicy(
                name: table + "_multi_tenant",
                table: table,
                usingExpression: "(project_id = current_setting('anigma.current_project_id', true)::uuid OR tenant_id = current_setting('anigma.current_tenant_id', true)::uuid)",
                checkExpression: "(project_id = current_setting('anigma.current_project_id', true)::uuid OR tenant_id = current_setting('anigma.current_tenant_id', true)::uuid)"
            )
        case .systemWide:
            return PostgresRLSPolicy(
                name: table + "_system",
                table: table,
                usingExpression: "true",
                checkExpression: "true"
            )
        }
    }
}

// MARK: - RLS Manager

public final class PostgresRLSManager: Sendable {
    private let database: any DatabaseExecutor
    private let contract: PostgresRLSContract

    public init(database: any DatabaseExecutor, contract: PostgresRLSContract = .canonical) {
        self.database = database
        self.contract = contract
    }

    public func applyContext(_ context: PostgresRLSContext) async throws {
        _ = try await database.executeAsync(context.setLocalStatement)
    }

    public func resetContext() async throws {
        _ = try await database.executeAsync(PostgresRLSContext.resetStatement)
    }

    public func enableRLS(on table: String) async throws {
        _ = try await database.executeAsync("ALTER TABLE " + table + " ENABLE ROW LEVEL SECURITY")
    }

    public func forceRLS(on table: String) async throws {
        _ = try await database.executeAsync("ALTER TABLE " + table + " FORCE ROW LEVEL SECURITY")
    }

    public func disableRLS(on table: String) async throws {
        _ = try await database.executeAsync("ALTER TABLE " + table + " DISABLE ROW LEVEL SECURITY")
    }

    public func createPolicy(_ policy: PostgresRLSPolicy) async throws {
        _ = try await database.executeAsync(policy.createSQL)
    }

    public func dropPolicy(_ policy: PostgresRLSPolicy) async throws {
        _ = try await database.executeAsync(policy.dropSQL)
    }

    public func applyTenantIsolation(
        to tables: [String],
        isolation: TenantIsolationPolicy,
        tenantColumn: String = "project_id"
    ) async throws {
        for table in tables {
            try await enableRLS(on: table)
            try await createPolicy(isolation.policy(for: table, column: tenantColumn))
            try await forceRLS(on: table)
        }
    }

    public func getPolicies(for table: String) async throws -> [PostgresRLSPolicy] {
        let rows = try await database.query(
            "SELECT policyname, roles, cmd, qual, with_check FROM pg_policies WHERE tablename = ?",
            parameters: [.text(table)]
        )
        return rows.compactMap { row in
            guard let name = row.string(for: "policyname"),
                  let cmd = row.string(for: "cmd") else { return nil }
            let command = PostgresRLSPolicyCommand(rawValue: cmd) ?? .all
            let roles = row.string(for: "roles")?.split(separator: ",").map(String.init) ?? ["public"]
            return PostgresRLSPolicy(
                name: name,
                table: table,
                roles: roles,
                usingExpression: row.string(for: "qual") ?? "true",
                checkExpression: row.string(for: "with_check"),
                command: command
            )
        }
    }
}

// MARK: - Contract

public struct PostgresRLSContract: Sendable, Codable, Equatable {
    public let contractID: String
    public let requiredGUCVariables: [String]
    public let requiredTables: [String]
    public let defaultIsolation: TenantIsolationPolicy
    public let enforceRLSFallback: Bool

    public init(
        contractID: String = "postgres.rls.v1",
        requiredGUCVariables: [String] = [
            "anigma.current_tenant_id", "anigma.current_principal_id",
            "anigma.current_project_id", "anigma.current_session_id", "anigma.current_trust_tier"
        ],
        requiredTables: [String] = [],
        defaultIsolation: TenantIsolationPolicy = .projectScoped,
        enforceRLSFallback: Bool = false
    ) {
        self.contractID = contractID
        self.requiredGUCVariables = requiredGUCVariables
        self.requiredTables = requiredTables
        self.defaultIsolation = defaultIsolation
        self.enforceRLSFallback = enforceRLSFallback
    }
    public static let canonical = PostgresRLSContract()
}

// MARK: - Validation

public struct PostgresRLSValidationReport: Sendable, Codable, Equatable {
    public let requiredTables: [String]
    public let tablesWithRLS: [String]
    public let tablesWithoutRLS: [String]
    public let tablesWithoutPolicies: [String]
    public let validatedAt: Date

    public var isValid: Bool { tablesWithoutRLS.isEmpty && tablesWithoutPolicies.isEmpty }
}

public enum PostgresRLSError: Error, CustomStringConvertible, Sendable {
    case contextNotSet, policyCreationFailed(String), policyNotFound(String, String)
    case rlsNotEnabled(String), validationFailed([String]), trustTierInsufficient(required: Int, actual: Int)

    public var description: String {
        switch self {
        case .contextNotSet: return "RLS context not set"
        case let .policyCreationFailed(r): return "Policy creation failed: " + r
        case let .policyNotFound(p, t): return "Policy '" + p + "' not found on table '" + t + "'"
        case let .rlsNotEnabled(t): return "RLS not enabled on '" + t + "'"
        case let .validationFailed(i): return "Validation failed: " + i.joined(separator: "; ")
        case let .trustTierInsufficient(r, a): return "Trust tier " + String(a) + " < required " + String(r)
        }
    }
}

public struct TrustTierChecker: Sendable {
    public static func require(minimumTier: Int, context: PostgresRLSContext) throws {
        guard context.trustTier >= minimumTier else {
            throw PostgresRLSError.trustTierInsufficient(required: minimumTier, actual: context.trustTier)
        }
    }
}
