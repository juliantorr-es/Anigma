import Foundation

/// Unique identifier for an MCP request.
public struct MCPRequestId: Sendable, Hashable {
    public let value: UUID

    public init() {
        self.value = UUID()
    }

    public var stringValue: String {
        value.uuidString
    }
}

/// Represents the lifecycle state of an MCP request.
public enum MCPRequestState: Sendable {
    case queued
    case executing
    case completed(success: Bool, durationMs: Int)
    case failed(error: String)
}

/// Tracks context for a single MCP tool call through its entire lifecycle.
public struct MCPRequestContext: Sendable {
    /// Unique identifier for this request
    public let requestId: MCPRequestId

    /// Timestamp when request was created
    public let createdAt: Date

    /// Client identifier (derived from request metadata)
    public let clientId: String

    /// Tool name being invoked
    public let toolName: String

    /// Priority level of this request
    public let priority: RequestPriority

    /// Deadline for request completion
    public let deadline: Date

    /// Current state of the request
    public private(set) var state: MCPRequestState

    public init(
        clientId: String,
        toolName: String,
        priority: RequestPriority = .normal,
        timeout: TimeInterval = 30
    ) {
        self.requestId = MCPRequestId()
        self.createdAt = Date()
        self.clientId = clientId
        self.toolName = toolName
        self.priority = priority
        self.deadline = Date(timeIntervalSinceNow: timeout)
        self.state = .queued
    }

    /// Returns elapsed time since request creation
    public var elapsedTime: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }

    /// Returns remaining time until deadline
    public var remainingTime: TimeInterval {
        deadline.timeIntervalSinceNow
    }

    /// Checks if request has exceeded deadline
    public var isExpired: Bool {
        remainingTime < 0
    }

    /// Marks request as executing
    mutating func markExecuting() {
        self.state = .queued  // Will be overwritten by updateState
    }

    /// Updates request state with completion info
    mutating func markCompleted(success: Bool) {
        let durationMs = Int(elapsedTime * 1000)
        self.state = .completed(success: success, durationMs: durationMs)
    }

    /// Updates request state with error info
    mutating func markFailed(_ error: String) {
        self.state = .failed(error: error)
    }
}

/// Priority levels for MCP requests.
/// Higher priority requests are processed before lower priority ones.
public enum RequestPriority: Int, Comparable, Sendable {
    /// Health checks, observability queries
    case critical = 100

    /// Fast read operations (file reads, list operations)
    case high = 75

    /// Standard operations (searches, queries)
    case normal = 50

    /// Heavy compute operations (builds, tests, patches)
    case low = 25

    public static func < (lhs: RequestPriority, rhs: RequestPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Maps tool names to their priority levels
public func toolPriority(_ toolName: String) -> RequestPriority {
    switch toolName {
    // Critical: health and observability
    case "get_system_health", "list_active_alerts":
        return .critical

    // High: fast reads
    case "read_file", "list_artifacts", "list_models", "git_diff":
        return .high

    // Normal: searches and queries
    case "context_search", "database_query", "trace_query":
        return .normal

    // Low: heavy compute and mutations
    case "swift_build", "swift_test", "apply_patch", "digest_codebase", "context_purge",
         "codebase_index_purge",
         "create_tool_contract", "verify_evidence_chain":
        return .low

    // Default to normal
    default:
        return .normal
    }
}
