//
//  TelemetrySink.swift
//  TelemetryCore
//
//  Telemetry output sinks that only receive redacted events.
//  Cannot access raw events - privacy enforced by type system.
//

import Foundation
import OSLog

private let telemetryLogger = Logger(subsystem: "com.anigma.telemetry", category: "console-sink")

// MARK: - Wire Format for Serializable Events

/// Wire-format representation of redacted event for serialization.
/// Only this struct is Codable - runtime sinks stay non-Codable.
/// Uses Int64 timestamps for deterministic encoding.
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
/// Sinks can ONLY receive WireRedactedEvent, never raw events.
/// Note: Runtime plumbing - not Codable to prevent existential encoding.
public protocol TelemetrySink: Sendable {
    /// The unique identifier for this sink.
    var id: String { get }

    /// Whether this sink is enabled.
    var isEnabled: Bool { get }

    /// Handles a wire-format redacted telemetry event.
    /// Raw events are never exposed to sinks by design.
    func handle(_ event: WireRedactedEvent) async throws

    /// Flushes any buffered data.
    func flush() async throws
}

/// A file-based telemetry sink for local development.
public struct FileTelemetrySink: TelemetrySink {
    public let id: String
    public let isEnabled: Bool
    private let fileURL: URL
    private let wireEncoder: JSONEncoder

    public init(id: String = "file", fileURL: URL, enabled: Bool = true) {
        self.id = id
        self.isEnabled = enabled
        self.fileURL = fileURL
        self.wireEncoder = JSONEncoder()
        self.wireEncoder.outputFormatting = [.sortedKeys]
    }

    public func handle(_ event: WireRedactedEvent) async throws {
        guard isEnabled else { return }

        // Event is already in wire format
        let data = try wireEncoder.encode(event)
        let line = String(data: data, encoding: .utf8) ?? "{}\n"

        // Thread-safe file writing
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    if !FileManager.default.fileExists(atPath: self.fileURL.path) {
                        try "{}\n".write(to: self.fileURL, atomically: false, encoding: .utf8)
                    }
                    let fileHandle = try FileHandle(forWritingTo: self.fileURL)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(line.data(using: .utf8) ?? Data())
                    fileHandle.closeFile()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func flush() async throws {
        // File sink doesn't buffer, so flush is a no-op
    }
}

/// A memory-based telemetry sink for testing and development.
public actor MemoryTelemetrySink: TelemetrySink {
    public let id: String
    public let isEnabled: Bool
    private var events: [WireRedactedEvent] = []
    private let maxEvents: Int

    public init(id: String = "memory", maxEvents: Int = 1000, enabled: Bool = true) {
        self.id = id
        self.isEnabled = enabled
        self.maxEvents = maxEvents
    }

    public func handle(_ event: WireRedactedEvent) async throws {
        guard isEnabled else { return }

        events.append(event)

        // Prevent unbounded memory growth
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    public func flush() async throws {
        // Memory sink doesn't need flushing
    }

    /// Returns all stored events for testing.
    public func getAllEvents() -> [WireRedactedEvent] {
        events
    }

    /// Clears all stored events.
    public func clear() {
        events.removeAll()
    }

    /// Returns events matching a filter.
    public func getEvents(matching filter: (WireRedactedEvent) -> Bool) -> [WireRedactedEvent] {
        events.filter(filter)
    }
}

/// A console-based telemetry sink for development.
public struct ConsoleTelemetrySink: TelemetrySink {
    public let id: String
    public let isEnabled: Bool
    private let wireEncoder: JSONEncoder

    public init(id: String = "console", enabled: Bool = true) {
        self.id = id
        self.isEnabled = enabled
        self.wireEncoder = JSONEncoder()
        self.wireEncoder.outputFormatting = [.sortedKeys]
    }

    public func handle(_ event: WireRedactedEvent) async throws {
        guard isEnabled else { return }

        // Event is already in wire format
        let data = try wireEncoder.encode(event)
        let jsonString = String(data: data, encoding: .utf8) ?? "{}"
        telemetryLogger.info(
            "Telemetry event category=\(String(describing: event.category), privacy: .public) name=\(event.name, privacy: .public) original_event_id=\(event.originalEventId, privacy: .public) privacy=\(String(describing: event.privacyClassification), privacy: .public) redaction=\(String(describing: event.redactionLevel), privacy: .public) payload=\(jsonString, privacy: .public)"
        )
    }

    public func flush() async throws {
        // Console sink doesn't buffer
    }
}

/// A composite sink that forwards to multiple sinks.
public actor CompositeTelemetrySink: TelemetrySink {
    public let id: String
    public let isEnabled: Bool
    private let sinks: [TelemetrySink]

    public init(id: String = "composite", sinks: [TelemetrySink], enabled: Bool = true) {
        self.id = id
        self.isEnabled = enabled
        self.sinks = sinks
    }

    public func handle(_ event: WireRedactedEvent) async throws {
        guard isEnabled else { return }

        // Handle in parallel for performance
        try await withThrowingTaskGroup(of: Void.self) { group in
            for sink in sinks {
                group.addTask {
                    if sink.isEnabled {
                        try await sink.handle(event)
                    }
                }
            }

            // Wait for all sinks to complete
            for try await _ in group {}
        }
    }

    public func flush() async throws {
        guard isEnabled else { return }

        // Flush all sinks in parallel
        try await withThrowingTaskGroup(of: Void.self) { group in
            for sink in sinks {
                group.addTask {
                    if sink.isEnabled {
                        try await sink.flush()
                    }
                }
            }

            for try await _ in group {}
        }
    }
}
