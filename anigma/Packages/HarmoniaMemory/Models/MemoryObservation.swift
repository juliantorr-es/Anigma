//
//  MemoryObservation.swift
//  HarmoniaMemory
//
//  Observation of system activity for memory persistence.
//  Captures tool calls, decisions, errors, and other events.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives

/// An observation of system activity for memory persistence.
public struct MemoryObservation: Codable, Sendable, Identifiable {
    /// Unique observation identifier.
    public let id: UUID

    /// Session identifier.
    public let sessionId: String

    /// Tenant identifier.
    public let tenantId: String

    /// Type of observation.
    public let observationType: ObservationType

    /// Timestamp when observation occurred.
    public let timestamp: Date

    /// Source of observation.
    public let source: ObservationSource

    /// Event data as JSON string.
    public let eventData: String

    /// Tool call details (if applicable).
    public let toolCall: ToolCall?

    /// Result of operation (if applicable).
    public let result: ObservationResult?

    /// Error information (if applicable).
    public let error: ObservationError?

    /// Tags for categorization.
    public let tags: [String]

    /// Contextual metadata.
    public let metadata: [String: String]

    /// Whether this observation is considered sensitive.
    public let isSensitive: Bool

    public init(
        id: UUID = UUID(),
        sessionId: String,
        tenantId: String,
        observationType: ObservationType,
        timestamp: Date = Date(),
        source: ObservationSource,
        eventData: String,
        toolCall: ToolCall? = nil,
        result: ObservationResult? = nil,
        error: ObservationError? = nil,
        tags: [String] = [],
        metadata: [String: String] = [:],
        isSensitive: Bool = false
    ) {
        self.id = id
        self.sessionId = sessionId
        self.tenantId = tenantId
        self.observationType = observationType
        self.timestamp = timestamp
        self.source = source
        self.eventData = eventData
        self.toolCall = toolCall
        self.result = result
        self.error = error
        self.tags = tags
        self.metadata = metadata
        self.isSensitive = isSensitive
    }
}

/// Type of observation.
public enum ObservationType: String, Codable, Sendable {
    /// Tool was called.
    case toolCall = "tool_call"

    /// Tool completed successfully.
    case toolResult = "tool_result"

    /// Tool failed with error.
    case toolError = "tool_error"

    /// Decision was made (governance, routing, etc.).
    case decision = "decision"

    /// Configuration change.
    case configChange = "config_change"

    /// User interaction.
    case userInteraction = "user_interaction"

    /// System event (startup, shutdown, health check).
    case systemEvent = "system_event"

    /// Inference request/response.
    case inference = "inference"

    /// Pipeline execution.
    case pipeline = "pipeline"

    /// Memory operation (store, retrieve, delete).
    case memoryOperation = "memory_operation"

    /// Security/audit event.
    case audit = "audit"
}

/// Source of observation.
public enum ObservationSource: String, Codable, Sendable {
    /// Harmonia CLI.
    case cli = "cli"

    /// Harmonia daemon.
    case daemon = "daemon"

    /// TUI interface.
    case tui = "tui"

    /// Web interface.
    case web = "web"

    /// API client.
    case api = "api"

    /// System process.
    case system = "system"

    /// Background job.
    case background = "background"
}

/// Result of an observation.
public struct ObservationResult: Codable, Sendable {
    /// Whether operation was successful.
    public let success: Bool

    /// Output/result data as JSON string.
    public let output: String?

    /// Duration in milliseconds.
    public let durationMs: Int?

    /// Resource usage metrics.
    public let metrics: [String: Double]

    public init(
        success: Bool,
        output: String? = nil,
        durationMs: Int? = nil,
        metrics: [String: Double] = [:]
    ) {
        self.success = success
        self.output = output
        self.durationMs = durationMs
        self.metrics = metrics
    }
}

/// Error information for an observation.
public struct ObservationError: Codable, Sendable {
    /// Error domain.
    public let domain: String

    /// Error code.
    public let code: Int

    /// Error message.
    public let message: String

    /// Stack trace (if available).
    public let stackTrace: String?

    /// Whether error is recoverable.
    public let isRecoverable: Bool

    public init(
        domain: String,
        code: Int,
        message: String,
        stackTrace: String? = nil,
        isRecoverable: Bool = false
    ) {
        self.domain = domain
        self.code = code
        self.message = message
        self.stackTrace = stackTrace
        self.isRecoverable = isRecoverable
    }
}

/// Tool call from inference system.
public struct ToolCall: Codable, Sendable {
    public let id: String
    public let name: String
    public let arguments: [String: String]

    public init(id: String, name: String, arguments: [String: String]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - ECS Component

extension MemoryObservation: Component {}

// MARK: - Convenience Initializers

extension MemoryObservation {
    /// Creates a tool call observation.
    public static func toolCall(
        sessionId: String,
        tenantId: String,
        source: ObservationSource,
        toolCall: ToolCall,
        metadata: [String: String] = [:],
        tags: [String] = []
    ) -> MemoryObservation {
        MemoryObservation(
            sessionId: sessionId,
            tenantId: tenantId,
            observationType: .toolCall,
            source: source,
            eventData: encodeToolCall(toolCall),
            toolCall: toolCall,
            tags: ["tool", toolCall.name] + tags,
            metadata: metadata
        )
    }
}

// MARK: - Configuration Structs

struct ToolResultConfiguration: Sendable {
    let sessionId: String
    let tenantId: String
    let source: String
    let toolCall: ToolCall
    let result: AnigmaCore.ToolResult
    let metadata: [String: String]
    let tags: [String]
    
    init(
        sessionId: String,
        tenantId: String,
        source: String,
        toolCall: ToolCall,
        result: AnigmaCore.ToolResult,
        metadata: [String: String],
        tags: [String]
    ) {
        self.sessionId = sessionId
        self.tenantId = tenantId
        self.source = source
        self.toolCall = toolCall
        self.result = result
        self.metadata = metadata
        self.tags = tags
    }
}

struct ToolErrorConfiguration: Sendable {
    let sessionId: UUID
    let tenantId: UUID
    let source: String
    let toolCall: ToolCall
    let error: Error
    let metadata: [String: String]?
    let tags: [String]?
    
    init(
        sessionId: UUID,
        tenantId: UUID,
        source: String,
        toolCall: ToolCall,
        error: Error,
        metadata: [String: String]? = nil,
        tags: [String]? = nil
    ) {
        self.sessionId = sessionId
        self.tenantId = tenantId
        self.source = source
        self.toolCall = toolCall
        self.error = error
        self.metadata = metadata
        self.tags = tags
    }
}

/// A sendable, codable wrapper for dictionary values
public struct SendableValue: Codable, Sendable {
    public let stringValue: String?
    public let intValue: Int?
    public let doubleValue: Double?
    public let boolValue: Bool?
    
    public init(_ value: String) {
        self.stringValue = value
        self.intValue = nil
        self.doubleValue = nil
        self.boolValue = nil
    }
    
    public init(_ value: Int) {
        self.stringValue = nil
        self.intValue = value
        self.doubleValue = nil
        self.boolValue = nil
    }
    
    public init(_ value: Double) {
        self.stringValue = nil
        self.intValue = nil
        self.doubleValue = value
        self.boolValue = nil
    }
    
    public init(_ value: Bool) {
        self.stringValue = nil
        self.intValue = nil
        self.doubleValue = nil
        self.boolValue = value
    }
}

/// Configuration for decision observations with proper Sendable conformance
struct DecisionConfiguration: Sendable {
    let sessionId: String
    let tenantId: String
    let source: String
    let decisionType: String
    let decisionData: [String: SendableValue]
    let metadata: [String: SendableValue]
    let tags: [String]
    
    init(
        sessionId: String,
        tenantId: String,
        source: String,
        decisionType: String,
        decisionData: [String: SendableValue],
        metadata: [String: SendableValue],
        tags: [String]
    ) {
        self.sessionId = sessionId
        self.tenantId = tenantId
        self.source = source
        self.decisionType = decisionType
        self.decisionData = decisionData
        self.metadata = metadata
        self.tags = tags
    }
}

// MARK: - Helper Functions

func decision(config: DecisionConfiguration) -> MemoryObservation {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    
    // Convert decisionData to JSON string
    let eventData: String
    if let data = try? encoder.encode(config.decisionData),
       let jsonString = String(data: data, encoding: .utf8) {
        eventData = jsonString
    } else {
        eventData = "{}"
    }
    
    // Convert metadata to [String: String]
    var metadataString: [String: String] = [:]
    for (key, value) in config.metadata {
        if let stringValue = value.stringValue {
            metadataString[key] = stringValue
        } else if let intValue = value.intValue {
            metadataString[key] = String(intValue)
        } else if let doubleValue = value.doubleValue {
            metadataString[key] = String(doubleValue)
        } else if let boolValue = value.boolValue {
            metadataString[key] = String(boolValue)
        } else {
            metadataString[key] = ""
        }
    }
    
    return MemoryObservation(
        sessionId: config.sessionId,
        tenantId: config.tenantId,
        observationType: .decision,
        source: ObservationSource(rawValue: config.source) ?? .system,
        eventData: eventData,
        tags: ["decision", config.decisionType] + config.tags,
        metadata: metadataString
    )
}

// MARK: - Private Helpers

private func encodeToolCall(_ toolCall: ToolCall) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    guard let data = try? encoder.encode(toolCall) else {
        return "{}"
    }
    return String(data: data, encoding: .utf8) ?? "{}"
}

private func encodeResult(_ result: ObservationResult) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    guard let data = try? encoder.encode(result) else {
        return "{}"
    }
    return String(data: data, encoding: .utf8) ?? "{}"
}

private func encodeError(_ error: ObservationError) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    guard let data = try? encoder.encode(error) else {
        return "{}"
    }
    return String(data: data, encoding: .utf8) ?? "{}"
}
