//
//  TelemetryComponent.swift
//  ObservatoriumModule
//
//  Telemetry event component for capturing system and user events.
//  Events are structured, timestamped, and privacy-aware.
//

import Foundation
import AnigmaCore

/// Component representing a telemetry event.
/// Events capture what happened, when, and with what context.
public struct TelemetryEventComponent: Component, Codable, Identifiable {
    // MARK: - Identity

    /// Unique event ID.
    public let id: TelemetryEventId

    /// Event type for categorization.
    public var eventType: TelemetryEventType

    /// Human-readable event name.
    public var name: String

    // MARK: - Context

    /// Module that generated this event.
    public var module: String

    /// Specific action or operation.
    public var action: String

    /// Target entity type (if any).
    public var targetType: String?

    /// Target entity ID (if any).
    public var targetId: String?

    /// Principal who triggered this event (anonymized if needed).
    public var principalId: String?

    /// Session ID for grouping related events.
    public var sessionId: String?

    /// Correlation ID for tracing across systems.
    public var correlationId: String?

    // MARK: - Timing

    /// When the event occurred.
    public let timestamp: Date

    /// Duration if this was a timed operation (in milliseconds).
    public var durationMs: Double?

    // MARK: - Payload

    /// Event-specific properties (must not contain PII).
    public var properties: [String: TelemetryValue]

    /// Severity/importance of this event.
    public var severity: AlertSeverity

    // MARK: - Sensitivity

    /// Sensitivity level for data handling.
    public var sensitivityLevel: TelemetrySensitivity

    /// Whether this event has been redacted.
    public var isRedacted: Bool

    // MARK: - Initialization

    public init(
        id: TelemetryEventId = TelemetryEventId(),
        eventType: TelemetryEventType,
        name: String,
        module: String,
        action: String,
        targetType: String? = nil,
        targetId: String? = nil,
        principalId: String? = nil,
        sessionId: String? = nil,
        correlationId: String? = nil,
        timestamp: Date = Date(),
        durationMs: Double? = nil,
        properties: [String: TelemetryValue] = [:],
        severity: AlertSeverity = .info,
        sensitivityLevel: TelemetrySensitivity = .public,
        isRedacted: Bool = false
    ) {
        self.id = id
        self.eventType = eventType
        self.name = name
        self.module = module
        self.action = action
        self.targetType = targetType
        self.targetId = targetId
        self.principalId = principalId
        self.sessionId = sessionId
        self.correlationId = correlationId
        self.timestamp = timestamp
        self.durationMs = durationMs
        self.properties = properties
        self.severity = severity
        self.sensitivityLevel = sensitivityLevel
        self.isRedacted = isRedacted
    }

    /// Returns a redacted copy suitable for external logging.
    public func redacted() -> TelemetryEventComponent {
        var copy = self
        copy.principalId = principalId.map { _ in "<redacted>" }
        copy.properties = properties.mapValues { value in
            if case .string(let s) = value, s.count > 20 {
                return .string("<redacted>")
            }
            return value
        }
        copy.isRedacted = true
        return copy
    }
}

/// Types of telemetry events.
public enum TelemetryEventType: String, Codable, Sendable {
    // System events
    case systemStart = "system.start"
    case systemStop = "system.stop"
    case systemHealth = "system.health"

    // User events
    case userAction = "user.action"
    case userNavigation = "user.navigation"
    case userSearch = "user.search"

    // Performance events
    case performanceTrace = "performance.trace"
    case performanceSpan = "performance.span"
    case performanceLatency = "performance.latency"

    // Domain events
    case workflowStart = "workflow.start"
    case workflowComplete = "workflow.complete"
    case workflowFailed = "workflow.failed"

    case jobStart = "job.start"
    case jobComplete = "job.complete"
    case jobFailed = "job.failed"

    case caseCreated = "case.created"
    case caseUpdated = "case.updated"
    case caseClosed = "case.closed"

    case documentProcessed = "document.processed"
    case exportGenerated = "export.generated"

    // Security events
    case authSuccess = "auth.success"
    case authFailure = "auth.failure"
    case accessDenied = "access.denied"
    case policyViolation = "policy.violation"

    // Error events
    case errorOccurred = "error.occurred"
    case errorResolved = "error.resolved"
}

/// Sensitivity levels for telemetry data.
public enum TelemetrySensitivity: String, Codable, Sendable, Comparable {
    case `public` = "public"     // Safe to log anywhere
    case `internal` = "internal" // Only internal systems
    case restricted = "restricted" // Only specific systems with access control

    public static func < (lhs: TelemetrySensitivity, rhs: TelemetrySensitivity) -> Bool {
        let order: [TelemetrySensitivity] = [.public, .internal, .restricted]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// Values that can be stored in telemetry properties.
public enum TelemetryValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case array([TelemetryValue])
    case dictionary([String: TelemetryValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Date.self) {
            self = .date(value)
        } else if let value = try? container.decode([TelemetryValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: TelemetryValue].self) {
            self = .dictionary(value)
        } else {
            throw DecodingError.typeMismatch(
                TelemetryValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode TelemetryValue"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .date(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .dictionary(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Telemetry Builders

extension TelemetryEventComponent {
    /// Creates a performance trace event.
    public static func performanceTrace(
        module: String,
        action: String,
        durationMs: Double,
        properties: [String: TelemetryValue] = [:],
        correlationId: String? = nil
    ) -> TelemetryEventComponent {
        TelemetryEventComponent(
            eventType: .performanceTrace,
            name: "\(module).\(action)",
            module: module,
            action: action,
            correlationId: correlationId,
            durationMs: durationMs,
            properties: properties
        )
    }

    /// Creates a workflow completion event.
    public static func workflowComplete(
        module: String,
        workflowName: String,
        durationMs: Double,
        success: Bool,
        properties: [String: TelemetryValue] = [:]
    ) -> TelemetryEventComponent {
        TelemetryEventComponent(
            eventType: success ? .workflowComplete : .workflowFailed,
            name: "workflow.\(workflowName)",
            module: module,
            action: workflowName,
            durationMs: durationMs,
            properties: properties,
            severity: success ? .info : .error
        )
    }

    /// Creates an error event from an ErrorRecordComponent.
    public static func fromError(_ error: ErrorRecordComponent) -> TelemetryEventComponent {
        TelemetryEventComponent(
            eventType: .errorOccurred,
            name: "error.\(error.errorType)",
            module: error.module,
            action: error.component ?? "unknown",
            correlationId: error.correlationId,
            properties: [
                "error_type": .string(error.errorType),
                "message": .string(error.message),
                "fingerprint": .string(error.fingerprint),
                "occurrence_count": .int(error.occurrenceCount)
            ],
            severity: error.severity,
            sensitivityLevel: error.maySensitive ? .restricted : .internal
        )
    }
}
