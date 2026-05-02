//
//  TelemetrySink.swift
//  TelemetryCore
//
//  Telemetry output sink definitions.
//  Defined in Tier 1 (TelemetryCore) as pure protocols and data structures.
//

import Foundation

// MARK: - Wire Format for Serializable Events

/// Wire-format representation of redacted event for serialization.
public struct WireRedactedEvent: Codable, Sendable {
    public let originalEventId: String
    public let category: TelemetryCategory
    public let name: String
    public let timestampMillis: Int64
    public let privacyClassification: PrivacyClassification
    public let values: [String: TelemetryValue]
    public let redactionLevel: RedactionLevel
    public let redactionTimestampMillis: Int64

    public init(from event: RedactedTelemetryEvent) {
        self.originalEventId = event.originalEventId
        self.category = event.category
        self.name = event.name
        self.timestampMillis = Int64(event.timestamp.timeIntervalSince1970 * 1000)
        self.privacyClassification = event.privacyClassification
        self.values = event.values
        self.redactionLevel = event.redactionLevel
        self.redactionTimestampMillis = Int64(event.redactionTimestamp.timeIntervalSince1970 * 1000)
    }
}

/// Protocol for telemetry sinks that receive redacted events.
/// Defined in Tier 1 (TelemetryCore).
public protocol TelemetrySink: Sendable {
    /// The unique identifier for this sink.
    var id: String { get }

    /// Whether this sink is enabled.
    var isEnabled: Bool { get }

    /// Handles a wire-format redacted telemetry event.
    func handle(_ event: WireRedactedEvent) async throws

    /// Flushes any buffered data.
    func flush() async throws
}
