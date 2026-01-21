import Foundation

/// Configuration for tool-specific timeouts
public struct ToolTimeoutConfig: Sendable {
    public let fastReadTimeout: TimeInterval = 2.0
    public let searchTimeout: TimeInterval = 5.0
    public let databaseTimeout: TimeInterval = 5.0
    public let heavyComputeTimeout: TimeInterval = 30.0
    public let mutationTimeout: TimeInterval = 10.0
    public let defaultTimeout: TimeInterval = 30.0

    public init() {}

    /// Returns the appropriate timeout for a tool
    public func timeout(for toolName: String) -> TimeInterval {
        switch toolName {
        // Fast reads: 2s
        case "read_file", "list_artifacts", "list_models", "git_diff":
            return fastReadTimeout

        // Search operations: 5s
        case "context_search":
            return searchTimeout

        // Database queries: 5s
        case "database_query", "trace_query":
            return databaseTimeout

        // Heavy compute: 30s
        case "swift_build", "swift_test", "digest_codebase":
            return heavyComputeTimeout

        // Mutations: 10s
        case "apply_patch", "create_tool_contract", "context_purge", "codebase_index_purge":
            return mutationTimeout

        // Health checks and observability: 2s
        case "get_system_health", "list_active_alerts":
            return fastReadTimeout

        // Verification operations: 10s
        case "verify_evidence_chain":
            return mutationTimeout

        // Default: 30s
        default:
            return defaultTimeout
        }
    }
}

/// Error type for timeout operations
public struct MCPTimeoutError: Error, Sendable {
    public let toolName: String
    public let timeoutSeconds: Double
    public let elapsed: TimeInterval

    public var description: String {
        "Tool '\(toolName)' timeout after \(String(format: "%.1f", elapsed))s (limit: \(timeoutSeconds)s)"
    }
}

/// Executes a tool handler with timeout enforcement
public func executeToolWithTimeout<T: Sendable>(
    toolName: String,
    config: ToolTimeoutConfig = ToolTimeoutConfig(),
    handler: @escaping @Sendable () async throws -> T
) async throws -> T {
    let timeoutSeconds = config.timeout(for: toolName)

    return try await withThrowingTaskGroup(of: T.self) { group in
        // Add the handler task
        group.addTask { @Sendable in
            try await handler()
        }

        // Add a timeout task
        group.addTask { @Sendable in
            try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            throw MCPTimeoutError(toolName: toolName, timeoutSeconds: timeoutSeconds, elapsed: timeoutSeconds)
        }

        // Get the first result (either handler success or timeout)
        if let result = try await group.next() {
            group.cancelAll()
            return result
        }

        // Should not reach here
        throw MCPTimeoutError(toolName: toolName, timeoutSeconds: timeoutSeconds, elapsed: timeoutSeconds)
    }
}
