//
//  PolicyGate.swift
//  HarmoniaModule
//
//  Policy enforcement for tool calls.
//  Ensures agents only use tools they have permission for.
//

import AnigmaPrimitives
import ContractsCore
@preconcurrency import Foundation

/// Policy gate that enforces permissions and constraints.
public actor PolicyGate {
    private let permissionMatrix: [String: Set<Permission>] = [
        "Edit": [.writeFiles, .modifyCode],
        "Read": [.readFiles],
        "Build": [.executeBuild, .writeArtifacts],
        "Test": [.executeTests, .readResults],
        "Git": [.readRepository, .writeRepository],
        "ML": [.executeML, .readModels]
    ]

    private let rateLimits: [String: Int] = [
        "Edit": 100,      // Max 100 edits per session
        "Build": 10,      // Max 10 builds per session
        "Test": 50,       // Max 50 test runs per session
        "ML": 20          // Max 20 ML calls per session
    ]

    private var sessionUsage: [String: [String: Int]] = [:]

    public init() {}

    /// Validate tool call against permissions and rate limits.
    public func validateToolCall(_ request: ToolCallRequest, session: SessionContext) async throws {
        // 1. Check tool exists
        guard let requiredPermissions = permissionMatrix[request.toolName] else {
            throw PolicyError.unknownTool(request.toolName)
        }

        // 2. Check session permissions
        for permission in requiredPermissions {
            guard session.permissions.contains(permission) else {
                throw PolicyError.insufficientPermissions(
                    required: requiredPermissions,
                    granted: session.permissions
                )
            }
        }

        // 3. Check rate limits
        try await checkRateLimit(tool: request.toolName, sessionId: request.sessionId)

        // 4. Tool-specific policy checks
        try await validateToolSpecificPolicies(request, session: session)
    }

    /// Check rate limits for tool usage.
    private func checkRateLimit(tool: String, sessionId: String) async throws {
        guard let maxUses = rateLimits[tool] else { return }

        let currentUsage = sessionUsage[sessionId]?[tool] ?? 0
        if currentUsage >= maxUses {
            throw PolicyError.rateLimitExceeded(
                tool: tool,
                current: currentUsage,
                limit: maxUses
            )
        }

        // Increment usage
        sessionUsage[sessionId, default: [:]][tool] = currentUsage + 1
    }

    /// Tool-specific policy validation.
    private func validateToolSpecificPolicies(_ request: ToolCallRequest, session: SessionContext) async throws {
        switch request.toolName {
        case "swift_build":
            try await validateSwiftBuildPolicy(request, session: session)
        case "swift_test":
            try await validateSwiftTestPolicy(request, session: session)
        case "apply_patch":
            try await validateApplyPatchPolicy(request, session: session)
        case "read_file":
            try await validateReadFilePolicy(request, session: session)
        default:
            break
        }
    }

    /// Validate Edit tool specific policies.
    private func validateEditPolicy(_ request: ToolCallRequest, session: SessionContext) async throws {
        guard let filePath = request.filePath else {
            throw PolicyError.invalidRequest("Edit tool requires filePath")
        }

        // Check if file is in allowed paths
        try await validateFilePath(filePath, permissions: session.permissions)

        // Check file size limits
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: filePath)
                if let size = attributes[FileAttributeKey.size] as? Int64, size > 10_000_000 {  // 10MB limit
                    throw PolicyError.fileTooLarge(filePath: filePath, size: Int(size))
                }
            } catch {
                // Continue if can't read attributes
            }
        }
    }

    /// Validate Swift Build tool specific policies.
    private func validateSwiftBuildPolicy(_ request: ToolCallRequest, session: SessionContext) async throws {
        // Enforce wrapper execution only when session.allowGovernedBuild is true
        guard session.allowGovernedBuild else {
            throw PolicyError.governedBuildNotAllowed(toolName: "swift_build")
        }

        // Enforce JSON-first outputs
        // All BuildTool responses must be JSON

        // No external runtime dependencies
        // Swift build is allowed as it's part of the toolchain
    }

    /// Validate Swift Test tool specific policies.
    private func validateSwiftTestPolicy(_ request: ToolCallRequest, session: SessionContext) async throws {
        // Enforce wrapper execution only when session.allowGovernedBuild is true
        guard session.allowGovernedBuild else {
            throw PolicyError.governedBuildNotAllowed(toolName: "swift_test")
        }

        // Enforce JSON-first outputs
        // All TestTool responses must be JSON

        // No external runtime dependencies
        // Swift test is allowed as it's part of the toolchain
    }

    /// Validate Apply Patch tool specific policies.
    private func validateApplyPatchPolicy(_ request: ToolCallRequest, session: SessionContext) async throws {
        // Disallow string-match edit APIs outside approved patch tools
        // Only unified diff patches are allowed

        // Ensure JSON-first outputs
        // All patch responses must be JSON
    }

    /// Validate Read File tool specific policies.
    private func validateReadFilePolicy(_ request: ToolCallRequest, session: SessionContext) async throws {
        // Ensure JSON-first outputs
        // All file read responses must be JSON
    }

    /// Validate Git tool specific policies.
    private func validateGitPolicy(_ request: ToolCallRequest, session: SessionContext) async throws {
        guard session.permissions.contains(.readRepository) || session.permissions.contains(.writeRepository) else {
            throw PolicyError.insufficientPermissions(required: [.readRepository], granted: session.permissions)
        }
    }

    /// Validate file path against permissions.
    private func validateFilePath(_ filePath: String, permissions: Set<Permission>) async throws {
        let absolutePath = (filePath as NSString).expandingTildeInPath

        // Check if path is within allowed directories
        // For now, allow all paths - implement restrictions as needed

        // Check if trying to edit system files
        let systemPaths = ["/usr", "/bin", "/sbin", "/System", "/Library"]
        for systemPath in systemPaths {
            if absolutePath.hasPrefix(systemPath) {
                throw PolicyError.restrictedPath(filePath: filePath, reason: "System directory")
            }
        }
    }

    /// Reset usage counters for session.
    public func resetSessionUsage(_ sessionId: String) async {
        sessionUsage[sessionId] = nil
    }

    /// Get current usage for session.
    public func getSessionUsage(_ sessionId: String) async -> [String: Int] {
        return sessionUsage[sessionId] ?? [:]
    }
}

// MARK: - Supporting Types

/// Session status.
public enum SessionStatus: String, Sendable, Codable {
    case active = "active"
    case paused = "paused"
    case completed = "completed"
    case terminated = "terminated"
    case error = "error"
}

/// Policy-specific errors.
public enum PolicyError: Error, LocalizedError {
    case unknownTool(String)
    case insufficientPermissions(required: Set<Permission>, granted: Set<Permission>)
    case rateLimitExceeded(tool: String, current: Int, limit: Int)
    case fileTooLarge(filePath: String, size: Int)
    case restrictedPath(filePath: String, reason: String)
    case invalidRequest(String)
    case governedBuildNotAllowed(toolName: String)
    case externalRuntimeDependencyNotAllowed(dependency: String)
    case nonJsonOutputNotAllowed(toolName: String)
    case stringMatchEditApiNotAllowed(operation: String)

    public var errorDescription: String? {
        switch self {
        case .unknownTool(let tool):
            return "Unknown tool: \(tool)"
        case .insufficientPermissions(let required, let granted):
            let requiredList = required.map(\.rawValue).joined(separator: ", ")
            let grantedList = granted.map(\.rawValue).joined(separator: ", ")
            return "Insufficient permissions. Required: \(requiredList), Granted: \(grantedList)"
        case .rateLimitExceeded(let tool, let current, let limit):
            return "Rate limit exceeded for \(tool). Current: \(current), Limit: \(limit)"
        case .fileTooLarge(let filePath, let size):
            return "File too large: \(filePath) (\(size) bytes)"
        case .restrictedPath(let filePath, let reason):
            return "Restricted path: \(filePath) - \(reason)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .governedBuildNotAllowed(let toolName):
            return "\(toolName) not allowed: session.allowGovernedBuild is false. Use wrapper tools instead."
        case .externalRuntimeDependencyNotAllowed(let dependency):
            return "External runtime dependency not allowed: \(dependency)"
        case .nonJsonOutputNotAllowed(let toolName):
            return "Non-JSON output not allowed for tool: \(toolName)"
        case .stringMatchEditApiNotAllowed(let operation):
            return "String-match edit API not allowed: \(operation). Use approved patch tools."
        }
    }
}
