//
//  AgentTrace.swift
//  TelemetryCore
//
//  Canonical observability contract for agentic workflows.
//  Provides structured tracing for multi-step agent operations.
//

import Foundation
import AnigmaPrimitives

/// A canonical trace for an agent operation.
/// Used for observability, debugging, and audit trails.
public struct AgentTrace: Sendable, Identifiable, Codable {
    public let id: String
    public let runId: String
    public let parentId: String?
    public let groupId: String?
    public let subgoalId: String?
    public let name: String
    public let timestamp: Date
    public let type: AgentTraceType
    public let payload: AgentTracePayload
    public let metadata: [String: String]

    public init(
        id: String = UUID().uuidString,
        runId: String,
        parentId: String? = nil,
        groupId: String? = nil,
        subgoalId: String? = nil,
        name: String,
        timestamp: Date = Date(),
        type: AgentTraceType,
        payload: AgentTracePayload = .empty,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.runId = runId
        self.parentId = parentId
        self.groupId = groupId
        self.subgoalId = subgoalId
        self.name = name
        self.timestamp = timestamp
        self.type = type
        self.payload = payload
        self.metadata = metadata
    }
}

/// Types of agent traces.
public enum AgentTraceType: String, Sendable, Codable, CaseIterable {
    case planning = "planning"
    case reasoning = "reasoning"
    case action = "action"
    case toolUse = "tool_use"
    case memoryAccess = "memory_access"
    case observation = "observation"
    case error = "error"
    case completion = "completion"
}

/// Structured payload for agent traces.
public enum AgentTracePayload: Sendable, Codable {
    case empty
    case text(String)
    case tool(ToolPayload)
    case error(ErrorPayload)
    case json(String) // For complex structured data

    public struct ToolPayload: Sendable, Codable {
        public let name: String
        public let input: String
        public let output: String?
        public let duration: TimeInterval?
        
        public init(name: String, input: String, output: String? = nil, duration: TimeInterval? = nil) {
            self.name = name
            self.input = input
            self.output = output
            self.duration = duration
        }
    }

    public struct ErrorPayload: Sendable, Codable {
        public let code: String
        public let message: String
        public let stackTrace: String?
        
        public init(code: String, message: String, stackTrace: String? = nil) {
            self.code = code
            self.message = message
            self.stackTrace = stackTrace
        }
    }
}

// MARK: - Factory Methods

extension AgentTrace {
    public static func start(runId: String, name: String, metadata: [String: String] = [:]) -> AgentTrace {
        AgentTrace(runId: runId, name: name, type: .planning, metadata: metadata)
    }

    public func step(name: String, type: AgentTraceType, payload: AgentTracePayload = .empty) -> AgentTrace {
        AgentTrace(
            runId: self.runId,
            parentId: self.id,
            groupId: self.groupId,
            subgoalId: self.subgoalId,
            name: name,
            type: type,
            payload: payload,
            metadata: self.metadata
        )
    }

    /// Converts the trace to a canonical TelemetryEvent.
    public func asTelemetryEvent() -> TelemetryEvent {
        var values: [String: TelemetryValue] = [
            "run_id": .string(runId),
            "trace_type": .string(type.rawValue)
        ]

        if let parentId = parentId { values["parent_id"] = .string(parentId) }
        if let groupId = groupId { values["group_id"] = .string(groupId) }
        if let subgoalId = subgoalId { values["subgoal_id"] = .string(subgoalId) }

        // Add payload data
        switch payload {
        case .empty: break
        case .text(let text): values["content"] = .string(text)
        case .json(let json): values["payload"] = .string(json)
        case .tool(let tool):
            values["tool_name"] = .string(tool.name)
            values["tool_input"] = .string(tool.input)
            if let output = tool.output { values["tool_output"] = .string(output) }
            if let duration = tool.duration { values["tool_duration"] = .double(duration) }
        case .error(let error):
            values["error_code"] = .string(error.code)
            values["error_message"] = .string(error.message)
            if let stack = error.stackTrace { values["error_stack"] = .string(stack) }
        }

        // Add metadata
        for (key, value) in metadata {
            values["meta_\(key)"] = .string(value)
        }

        return TelemetryEvent(
            id: id,
            category: .workflow,
            name: "agent_trace.\(name)",
            timestamp: timestamp,
            privacyClassification: .internal,
            values: values
        )
    }
}
