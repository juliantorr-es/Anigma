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

    /// Job identifier (correlates multiple requests to a single job)
    public let jobId: String?

    /// Run identifier (correlates multiple jobs to a single run)
    public let runId: String?

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
        jobId: String? = nil,
        runId: String? = nil,
        priority: RequestPriority = .normal,
        timeout: TimeInterval = 30
    ) {
        self.requestId = MCPRequestId()
        self.jobId = jobId
        self.runId = runId
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

    /// Structured metadata useful for lifecycle logging.
    public func lifecycleMetadata(stage: String, reason: String? = nil, queueDepth: Int? = nil) -> [String: String] {
        var metadata: [String: String] = [
            "lifecycle_stage": stage,
            "request_id": requestId.stringValue,
            "client_id": clientId,
            "tool_name": toolName,
            "priority": String(priority.rawValue),
            "state": stateLabel
        ]

        if let jobId {
            metadata["job_id"] = jobId
        }
        if let runId {
            metadata["run_id"] = runId
        }
        if let reason {
            metadata["reason"] = reason
        }
        if let queueDepth {
            metadata["queue_depth"] = String(queueDepth)
        }

        return metadata
    }

    /// Stable key=value formatting for lifecycle log messages.
    public func lifecycleMetadataString(stage: String, reason: String? = nil, queueDepth: Int? = nil) -> String {
        lifecycleMetadata(stage: stage, reason: reason, queueDepth: queueDepth)
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
    }

    private var stateLabel: String {
        switch state {
        case .queued:
            return "queued"
        case .executing:
            return "executing"
        case .completed(let success, let durationMs):
            return "completed_\(success ? "success" : "failure")_\(durationMs)ms"
        case .failed(let error):
            return "failed_\(error)"
        }
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
