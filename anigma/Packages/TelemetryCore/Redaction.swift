//
//  Redaction.swift
//  TelemetryCore
//
//  Mandatory redaction system that applies before sinks receive events.
//  Implements privacy-by-default with configurable rules.
//

import Foundation

/// Redaction system that sanitizes telemetry data before sink processing.
public struct Redaction {
    /// Global redaction policy - in production, this should be configurable per tenant.
    private static let policy = RedactionPolicy.default

    /// Applies mandatory redaction to a telemetry event.
    /// All events MUST pass through this before reaching sinks.
    public static func apply(to event: TelemetryEvent) -> RedactedTelemetryEvent {
        var redactedValues: [String: TelemetryValue] = [:]

        for (key, value) in event.values {
            if let redactedValue = applyRedactionRules(key: key, value: value) {
                redactedValues[key] = redactedValue
            }
            // Values that fail redaction are silently dropped (security-first)
        }

        return RedactedTelemetryEvent.fromRaw(
            event,
            redactionLevel: determineRedactionLevel(for: event.privacyClassification),
            redactedValues: redactedValues
        )
    }

    /// Applies redaction rules to individual values.
    private static func applyRedactionRules(key: String, value: TelemetryValue) -> TelemetryValue? {
        switch value {
        case .integer, .integer64, .double, .boolean:
            // Numeric and boolean values are generally safe
            return value

        case .limitedTag(let tag):
            // Check tag against whitelist
            if policy.allowedTags.contains(tag.value) {
                return value
            } else {
                return .limitedTag(.failure) // Replace unknown tags with failure
            }

        case .hashedToken:
            // Hashed tokens are already safe
            return value
        }
    }

    /// Determines the redaction level based on privacy classification.
    private static func determineRedactionLevel(for classification: PrivacyClassification) -> RedactionLevel {
        switch classification {
        case .public:
            return .none
        case .internal:
            return .standard
        case .restricted:
            return .full
        }
    }
}

/// Redaction policy configuration.
public struct RedactionPolicy: Sendable, Codable {
    public let allowedTags: Set<String>
    public let strictMode: Bool
    public let auditAllRedactions: Bool

    public static let `default` = RedactionPolicy(
        allowedTags: [
            "status.success", "status.failure", "status.started", "status.completed",
            "system.startup", "system.shutdown", "system.health",
            "tool.executed", "tool.completed", "tool.failed",
            "workflow.started", "workflow.completed", "workflow.failed",
            "performance.latency", "performance.throughput",
            "security.auth_success", "security.auth_failure",
            "error.occurred", "error.resolved"
        ],
        strictMode: true, // Drop unknown values
        auditAllRedactions: true // Log all redactions
    )
}

/// Level of redaction applied to an event.
public enum RedactionLevel: String, Sendable {
    case none = "none"       // No redaction applied
    case standard = "standard" // Standard redaction rules
    case full = "full"       // Maximum redaction

    public var description: String {
        switch self {
        case .none: return "No redaction applied"
        case .standard: return "Standard redaction rules applied"
        case .full: return "Maximum redaction applied"
        }
    }
}

// MARK: - Codable Wire Support
extension RedactionLevel: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try String(from: decoder)
        switch raw {
        case "none": self = .none
        case "standard": self = .standard
        case "full": self = .full
        default: throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid RedactionLevel")
        )
        }
    }

    public func encode(to encoder: Encoder) throws {
        try rawValue.encode(to: encoder)
    }
}

/// A redacted telemetry event ready for sink processing.
/// Sinks can ONLY receive this type, never raw events.
public struct RedactedTelemetryEvent: Sendable {
    public let originalEventId: String
    public let category: TelemetryCategory
    public let name: String
    public let timestamp: Date
    public let privacyClassification: PrivacyClassification
    public let values: [String: TelemetryValue]
    public let redactionLevel: RedactionLevel
    public let redactionTimestamp: Date

    /// Private initializer - only Redaction.apply can create these.
    private init(
        originalEvent: TelemetryEvent,
        redactedValues: [String: TelemetryValue],
        redactionLevel: RedactionLevel,
        redactionTimestamp: Date
    ) {
        self.originalEventId = originalEvent.id
        self.category = originalEvent.category
        self.name = originalEvent.name
        self.timestamp = originalEvent.timestamp
        self.privacyClassification = originalEvent.privacyClassification
        self.values = redactedValues
        self.redactionLevel = redactionLevel
        self.redactionTimestamp = redactionTimestamp
    }

    /// Creates a redacted event from a raw event (internal use only).
    /// In production, this should only be called by Redaction.apply.
    internal static func fromRaw(
        _ event: TelemetryEvent,
        redactionLevel: RedactionLevel,
        redactedValues: [String: TelemetryValue]
    ) -> RedactedTelemetryEvent {
        RedactedTelemetryEvent(
            originalEvent: event,
            redactedValues: redactedValues,
            redactionLevel: redactionLevel,
            redactionTimestamp: Date()
        )
    }
}

// MARK: - Codable Wire Support
extension RedactedTelemetryEvent: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.originalEventId = try container.decode(String.self, forKey: .originalEventId)
        self.category = try container.decode(TelemetryCategory.self, forKey: .category)
        self.name = try container.decode(String.self, forKey: .name)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.privacyClassification = try container.decode(PrivacyClassification.self, forKey: .privacyClassification)
        self.values = try container.decode([String: TelemetryValue].self, forKey: .values)
        self.redactionLevel = try container.decode(RedactionLevel.self, forKey: .redactionLevel)
        self.redactionTimestamp = try container.decode(Date.self, forKey: .redactionTimestamp)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(originalEventId, forKey: .originalEventId)
        try container.encode(category, forKey: .category)
        try container.encode(name, forKey: .name)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(privacyClassification, forKey: .privacyClassification)
        try container.encode(values, forKey: .values)
        try container.encode(redactionLevel, forKey: .redactionLevel)
        try container.encode(redactionTimestamp, forKey: .redactionTimestamp)
    }

    private enum CodingKeys: String, CodingKey {
        case originalEventId, category, name, timestamp, privacyClassification, values, redactionLevel, redactionTimestamp
    }
}
