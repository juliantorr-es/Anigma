import Foundation

/// Canonical trace identifier for agent/runtime observability.
public struct TraceID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init() {
        self.rawValue = UUID().uuidString
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    public var description: String { rawValue }
}

/// Canonical span identifier for parent/child span relationships.
public struct SpanID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init() {
        self.rawValue = UUID().uuidString
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    public var description: String { rawValue }
}

/// Canonical identifier for a single logical runtime run.
public struct RunID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init() {
        self.rawValue = UUID().uuidString
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    public var description: String { rawValue }
}

/// Canonical group identifier for related spans across logical boundaries.
public struct GroupID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID().uuidString }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

/// Canonical subgoal identifier for hierarchical task decomposition.
public struct SubgoalID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID().uuidString }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

/// Canonical checkpoint identifier for resumable agent state.
public struct CheckpointID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID().uuidString }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

/// Canonical tool call identifier for external capability execution.
public struct ToolCallID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID().uuidString }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

/// Minimal canonical trace context shared across observability and runtime surfaces.
/// Supports hierarchical tracing across daemon, job, CLI, MCP, retrieval, and guardrail boundaries.
public struct TraceContext: Hashable, Codable, Sendable {
    public let name: String
    public let runID: RunID
    public let traceID: TraceID
    public let spanID: SpanID
    public let parentSpanID: SpanID?
    
    // Hierarchical and task-specific IDs
    public let groupID: GroupID?
    public let subgoalID: SubgoalID?
    public let checkpointID: CheckpointID?
    public let toolCallID: ToolCallID?

    public init(
        name: String,
        runID: RunID = RunID(),
        traceID: TraceID = TraceID(),
        spanID: SpanID = SpanID(),
        parentSpanID: SpanID? = nil,
        groupID: GroupID? = nil,
        subgoalID: SubgoalID? = nil,
        checkpointID: CheckpointID? = nil,
        toolCallID: ToolCallID? = nil
    ) {
        self.name = name
        self.runID = runID
        self.traceID = traceID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
        self.groupID = groupID
        self.subgoalID = subgoalID
        self.checkpointID = checkpointID
        self.toolCallID = toolCallID
    }

    public static func root(
        name: String,
        runID: RunID = RunID(),
        traceID: TraceID = TraceID(),
        spanID: SpanID = SpanID()
    ) -> TraceContext {
        TraceContext(name: name, runID: runID, traceID: traceID, spanID: spanID, parentSpanID: nil)
    }

    public func childSpan(name: String, spanID: SpanID = SpanID()) -> TraceContext {
        TraceContext(
            name: name,
            runID: runID,
            traceID: traceID,
            spanID: spanID,
            parentSpanID: self.spanID,
            groupID: self.groupID,
            subgoalID: self.subgoalID,
            checkpointID: self.checkpointID,
            toolCallID: self.toolCallID
        )
    }

    public var isRootSpan: Bool {
        parentSpanID == nil
    }

    /// Compatibility bridge to existing diagnostic correlation fields.
    public var correlationID: String {
        traceID.rawValue
    }
}

/// Migration bridge for legacy flat span metadata.
public struct FlatSpanSummary: Codable, Sendable {
    public let trace_id: String
    public let span_id: String
    public let parent_id: String?
    public let name: String
    public let run_id: String?
    
    public init(trace_id: String, span_id: String, parent_id: String? = nil, name: String, run_id: String? = nil) {
        self.trace_id = trace_id
        self.span_id = span_id
        self.parent_id = parent_id
        self.name = name
        self.run_id = run_id
    }
}

extension TraceContext {
    /// Migrate from a flat span summary.
    public init(migration summary: FlatSpanSummary) {
        self.name = summary.name
        self.runID = summary.run_id.map { RunID(rawValue: $0) } ?? RunID()
        self.traceID = TraceID(rawValue: summary.trace_id)
        self.spanID = SpanID(rawValue: summary.span_id)
        self.parentSpanID = summary.parent_id.map { SpanID(rawValue: $0) }
        
        // Initial migration defaults hierarchical IDs to nil
        self.groupID = nil
        self.subgoalID = nil
        self.checkpointID = nil
        self.toolCallID = nil
    }
}

/// Canonical agent-facing alias.
public typealias AgentTraceContext = TraceContext
