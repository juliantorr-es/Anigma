//
//  AccessumFlowClient.swift
//  AnigmaHostMac
//
//  Access control and flow management client for Mac.
//  Provides policy enforcement, permission management, and access auditing.
//

import Foundation
import ContractsCore
import AnigmaCore

/// Client for accessum-flow binary integration
public struct AccessumFlowClient: Sendable {
    private let binaryPath: String

    public init(binaryPath: String = "/usr/local/bin/accessum-flow") {
        self.binaryPath = binaryPath
    }

    // MARK: - Policy Management

    /// List all access policies
    public func listPolicies() async throws -> PolicyListResponse {
        let output = try await execute(["policy", "list", "--format", "json"])
        return try JSONDecoder().decode(PolicyListResponse.self, from: output)
    }

    /// Create a new access policy
    public func createPolicy(name: String, rules: [AccessRule]) async throws -> PolicyResponse {
        let rulesJSON = try JSONEncoder().encode(rules)
        let rulesString = String(data: rulesJSON, encoding: .utf8) ?? "[]"
        let output = try await execute(["policy", "create", "--name", name, "--rules", rulesString, "--format", "json"])
        return try JSONDecoder().decode(PolicyResponse.self, from: output)
    }

    /// Update an existing policy
    public func updatePolicy(id: String, rules: [AccessRule]) async throws -> PolicyResponse {
        let rulesJSON = try JSONEncoder().encode(rules)
        let rulesString = String(data: rulesJSON, encoding: .utf8) ?? "[]"
        let output = try await execute(["policy", "update", "--id", id, "--rules", rulesString, "--format", "json"])
        return try JSONDecoder().decode(PolicyResponse.self, from: output)
    }

    /// Delete a policy
    public func deletePolicy(id: String) async throws -> AccessumSuccessResponse {
        let output = try await execute(["policy", "delete", "--id", id, "--format", "json"])
        return try JSONDecoder().decode(AccessumSuccessResponse.self, from: output)
    }

    // MARK: - Permission Checking

    /// Check if an action is permitted
    public func checkPermission(actor: String, resource: String, action: String) async throws -> PermissionCheckResponse {
        let output = try await execute(["check", "--actor", actor, "--resource", resource, "--action", action, "--format", "json"])
        return try JSONDecoder().decode(PermissionCheckResponse.self, from: output)
    }

    /// Evaluate multiple permissions at once
    public func batchCheck(checks: [PermissionCheck]) async throws -> BatchCheckResponse {
        let checksJSON = try JSONEncoder().encode(checks)
        let checksString = String(data: checksJSON, encoding: .utf8) ?? "[]"
        let output = try await execute(["check", "batch", "--checks", checksString, "--format", "json"])
        return try JSONDecoder().decode(BatchCheckResponse.self, from: output)
    }

    // MARK: - Access Auditing

    /// Get access audit log
    public func getAuditLog(limit: Int = 100, offset: Int = 0) async throws -> AuditLogResponse {
        let output = try await execute(["audit", "log", "--limit", "\(limit)", "--offset", "\(offset)", "--format", "json"])
        return try JSONDecoder().decode(AuditLogResponse.self, from: output)
    }

    /// Search audit log by criteria
    public func searchAudit(actor: String? = nil, resource: String? = nil, startDate: Date? = nil, endDate: Date? = nil) async throws -> AuditLogResponse {
        var args = ["audit", "search", "--format", "json"]
        if let actor = actor {
            args.append(contentsOf: ["--actor", actor])
        }
        if let resource = resource {
            args.append(contentsOf: ["--resource", resource])
        }
        if let startDate = startDate {
            args.append(contentsOf: ["--from", ISO8601DateFormatter().string(from: startDate)])
        }
        if let endDate = endDate {
            args.append(contentsOf: ["--to", ISO8601DateFormatter().string(from: endDate)])
        }
        let output = try await execute(args)
        return try JSONDecoder().decode(AuditLogResponse.self, from: output)
    }

    // MARK: - Flow Control

    /// Get current flow status
    public func getFlowStatus() async throws -> FlowStatusResponse {
        let output = try await execute(["flow", "status", "--format", "json"])
        return try JSONDecoder().decode(FlowStatusResponse.self, from: output)
    }

    /// Enable a flow control rule
    public func enableFlow(ruleId: String) async throws -> AccessumSuccessResponse {
        let output = try await execute(["flow", "enable", "--id", ruleId, "--format", "json"])
        return try JSONDecoder().decode(AccessumSuccessResponse.self, from: output)
    }

    /// Disable a flow control rule
    public func disableFlow(ruleId: String) async throws -> AccessumSuccessResponse {
        let output = try await execute(["flow", "disable", "--id", ruleId, "--format", "json"])
        return try JSONDecoder().decode(AccessumSuccessResponse.self, from: output)
    }

    // MARK: - Execution

    private func execute(_ arguments: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AccessumFlowError.executionFailed(message: errorMessage)
        }

        return outputData
    }
}

// MARK: - Response Types

public struct PolicyListResponse: Codable {
    public let policies: [PolicyInfo]
}

public struct PolicyInfo: Codable, Identifiable {
    public let id: String
    public let name: String
    public let rulesCount: Int
    public let createdAt: Date
    public let updatedAt: Date
}

public struct PolicyResponse: Codable {
    public let id: String
    public let name: String
    public let rules: [AccessRule]
}

public struct AccessRule: Codable {
    public let actor: String
    public let resource: String
    public let actions: [String]
    public let effect: AccessEffect
}

public enum AccessEffect: String, Codable {
    case allow
    case deny
}

public struct PermissionCheck: Codable {
    public let actor: String
    public let resource: String
    public let action: String
}

public struct PermissionCheckResponse: Codable {
    public let permitted: Bool
    public let reason: String?
    public let matchedPolicy: String?
}

public struct BatchCheckResponse: Codable {
    public let results: [PermissionCheckResponse]
}

public struct AuditLogResponse: Codable {
    public let entries: [AuditEntry]
    public let total: Int
}

public struct AuditEntry: Codable, Identifiable {
    public let id: String
    public let timestamp: Date
    public let actor: String
    public let resource: String
    public let action: String
    public let result: String
    public let policyId: String?
}

public struct FlowStatusResponse: Codable {
    public let activeRules: Int
    public let totalRules: Int
    public let blockedFlows: Int
    public let rules: [FlowRule]
}

public struct FlowRule: Codable, Identifiable {
    public let id: String
    public let name: String
    public let enabled: Bool
    public let condition: String
}

public struct AccessumSuccessResponse: Codable {
    public let success: Bool
    public let message: String?
}

// MARK: - Errors

public enum AccessumFlowError: Error, LocalizedError {
    case executionFailed(message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Accessum Flow execution failed: \(message)"
        case .invalidResponse:
            return "Invalid response from accessum-flow"
        }
    }
}
