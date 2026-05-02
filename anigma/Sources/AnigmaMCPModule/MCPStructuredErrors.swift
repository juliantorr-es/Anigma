//
//  MCPStructuredErrors.swift
//  AnigmaMCPModule
//
//  Structured error types for MCP tools with error codes, recovery hints, and context.
//

import Foundation

/// Structured error code for MCP tool failures
public enum MCPErrorCode: String, Sendable, Codable {
    // General errors
    case internalError = "INTERNAL_ERROR"
    case notImplemented = "NOT_IMPLEMENTED"
    case timeout = "TIMEOUT"
    case cancelled = "CANCELLED"

    // Argument errors
    case invalidArgument = "INVALID_ARGUMENT"
    case missingArgument = "MISSING_ARGUMENT"
    case argumentTypeMismatch = "ARGUMENT_TYPE_MISMATCH"

    // Resource errors
    case resourceNotFound = "RESOURCE_NOT_FOUND"
    case resourceUnavailable = "RESOURCE_UNAVAILABLE"
    case resourceExhausted = "RESOURCE_EXHAUSTED"

    // File system errors
    case fileNotFound = "FILE_NOT_FOUND"
    case permissionDenied = "PERMISSION_DENIED"
    case directoryTraversal = "DIRECTORY_TRAVERSAL"
    case pathOutsideRoot = "PATH_OUTSIDE_ROOT"

    // Module errors
    case modulePending = "MODULE_PENDING"
    case moduleUnavailable = "MODULE_UNAVAILABLE"
    case moduleInitializationFailed = "MODULE_INITIALIZATION_FAILED"

    // Execution errors
    case executionFailed = "EXECUTION_FAILED"
    case processExitNonZero = "PROCESS_EXIT_NON_ZERO"

    // Database errors
    case databaseError = "DATABASE_ERROR"
    case queryFailed = "QUERY_FAILED"

    // Governance errors
    case governanceViolation = "GOVERNANCE_VIOLATION"
    case insufficientPermissions = "INSUFFICIENT_PERMISSIONS"

    // Search/indexing errors
    case indexingFailed = "INDEXING_FAILED"
    case searchFailed = "SEARCH_FAILED"
}

/// Recovery hint for users
public struct MCPRecoveryHint: Sendable, Codable {
    public let action: String
    public let details: String
    public let retryable: Bool

    public init(action: String, details: String, retryable: Bool = false) {
        self.action = action
        self.details = details
        self.retryable = retryable
    }
}

/// Structured error response for MCP tools
public struct MCPToolError: Sendable, Codable, LocalizedError {
    /// Error code for programmatic handling
    public let code: MCPErrorCode

    /// Human-readable error message
    public let message: String

    /// Tool where error occurred
    public let toolName: String

    /// Optional context about what was being done
    public let context: String?

    /// Recovery hint for the user
    public let hint: MCPRecoveryHint?

    /// Underlying error details (for logging)
    public let details: String?

    /// HTTP-like status code
    public let statusCode: Int

    public init(
        code: MCPErrorCode,
        message: String,
        toolName: String,
        context: String? = nil,
        hint: MCPRecoveryHint? = nil,
        details: String? = nil,
        statusCode: Int? = nil
    ) {
        self.code = code
        self.message = message
        self.toolName = toolName
        self.context = context
        self.hint = hint
        self.details = details
        self.statusCode = statusCode ?? Self.httpStatusCode(for: code)
    }

    /// Convert to human-readable error description
    public var errorDescription: String? {
        var result = "[\(toolName):\(code.rawValue)] \(message)"
        if let context = context {
            result += "\nContext: \(context)"
        }
        if let hint = hint {
            result += "\nSuggestion: \(hint.action) - \(hint.details)"
        }
        return result
    }

    /// Serialize to JSON for MCP response
    public func toJSON() -> [String: Any] {
        var dict: [String: Any] = [
            "code": code.rawValue,
            "message": message,
            "tool": toolName,
            "status": statusCode
        ]

        if let context = context {
            dict["context"] = context
        }

        if let hint = hint {
            dict["hint"] = [
                "action": hint.action,
                "details": hint.details,
                "retryable": hint.retryable
            ]
        }

        if let details = details {
            dict["details"] = details
        }

        return dict
    }

    /// Get HTTP status code equivalent
    private static func httpStatusCode(for code: MCPErrorCode) -> Int {
        switch code {
        case .missingArgument, .invalidArgument, .argumentTypeMismatch:
            return 400
        case .permissionDenied, .insufficientPermissions, .governanceViolation:
            return 403
        case .fileNotFound, .resourceNotFound:
            return 404
        case .directoryTraversal, .pathOutsideRoot:
            return 403
        case .resourceExhausted:
            return 429
        case .timeout:
            return 408
        case .cancelled:
            return 499
        case .notImplemented:
            return 501
        case .moduleUnavailable, .resourceUnavailable:
            return 503
        case .internalError, .executionFailed, .databaseError, .indexingFailed, .searchFailed:
            return 500
        default:
            return 500
        }
    }
}

/// Helper to create common errors
public extension MCPToolError {
    static func missingArgument(
        tool: String,
        argument: String,
        context: String? = nil
    ) -> MCPToolError {
        MCPToolError(
            code: .missingArgument,
            message: "Required argument '\(argument)' is missing",
            toolName: tool,
            context: context,
            hint: MCPRecoveryHint(
                action: "Provide required argument",
                details: "The '\(argument)' parameter must be supplied to \(tool)",
                retryable: true
            )
        )
    }

    static func invalidArgument(
        tool: String,
        argument: String,
        reason: String,
        context: String? = nil
    ) -> MCPToolError {
        MCPToolError(
            code: .invalidArgument,
            message: "Argument '\(argument)' is invalid: \(reason)",
            toolName: tool,
            context: context,
            hint: MCPRecoveryHint(
                action: "Correct the argument value",
                details: reason,
                retryable: true
            )
        )
    }

    static func fileNotFound(
        tool: String,
        path: String,
        context: String? = nil
    ) -> MCPToolError {
        MCPToolError(
            code: .fileNotFound,
            message: "File not found: \(path)",
            toolName: tool,
            context: context,
            hint: MCPRecoveryHint(
                action: "Check file path",
                details: "Ensure the file exists at '\(path)'",
                retryable: true
            )
        )
    }

    static func modulePending(
        tool: String,
        module: String,
        context: String? = nil
    ) -> MCPToolError {
        MCPToolError(
            code: .modulePending,
            message: "Required module '\(module)' is still initializing",
            toolName: tool,
            context: context,
            hint: MCPRecoveryHint(
                action: "Retry after module initialization",
                details: "The \(module) module is still loading. Retry in a few seconds.",
                retryable: true
            )
        )
    }

    static func executionFailed(
        tool: String,
        reason: String,
        context: String? = nil,
        details: String? = nil,
        retryable: Bool = false
    ) -> MCPToolError {
        MCPToolError(
            code: .executionFailed,
            message: "Tool execution failed: \(reason)",
            toolName: tool,
            context: context,
            hint: MCPRecoveryHint(
                action: "Review execution error",
                details: reason,
                retryable: retryable
            ),
            details: details
        )
    }

    static func timeout(
        tool: String,
        duration: TimeInterval,
        context: String? = nil
    ) -> MCPToolError {
        MCPToolError(
            code: .timeout,
            message: "Tool execution timed out after \(Int(duration))s",
            toolName: tool,
            context: context,
            hint: MCPRecoveryHint(
                action: "Retry with more time or simpler inputs",
                details: "The operation did not complete within \(Int(duration)) seconds",
                retryable: true
            )
        )
    }

    static func governanceViolation(
        tool: String,
        reason: String,
        context: String? = nil
    ) -> MCPToolError {
        MCPToolError(
            code: .governanceViolation,
            message: "Governance policy violation: \(reason)",
            toolName: tool,
            context: context,
            hint: MCPRecoveryHint(
                action: "Check system governance policies",
                details: reason,
                retryable: false
            )
        )
    }
}
