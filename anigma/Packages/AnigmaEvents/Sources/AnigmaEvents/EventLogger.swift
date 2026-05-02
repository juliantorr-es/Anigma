// EventLogger.swift
// Simple event logging for debugging and monitoring

import Foundation
import os.log

/// Event logging levels
public enum EventLogLevel: String {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
}

/// Event logger for AnigmaEvents
public struct EventLogger {
    private static let subsystem = "com.anigma.events"
    private static let log = Logger(subsystem: subsystem, category: "events")
    
    /// Enable or disable event logging
    public static var enabled: Bool = true
    
    /// Log an event
    /// - Parameters:
    ///   - event: The event that was published or received
    ///   - level: Log level
    ///   - direction: Whether event was published or received
    ///   - source: Source of the event
    public static func log<Event: AnigmaEvent>(
        _ event: Event,
        level: EventLogLevel = .info,
        direction: String = "published",
        source: String? = nil
    ) {
        guard enabled else { return }
        
        let eventType = Event.eventType
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let sourceInfo = source ?? "unknown"
        
        let message = "[Event] \(timestamp) [\(level.rawValue.uppercased())] [\(direction)] \(eventType) from \(sourceInfo)"
        
        switch level {
        case .debug:
            log.debug("\n\(message)\n")
        case .info:
            log.info("\n\(message)\n")
        case .warning:
            log.warning("\n\(message)\n")
        case .error:
            log.error("\n\(message)\n")
        }
    }
    
    /// Log event publishing
    public static func logPublished<Event: AnigmaEvent>(_ event: Event, source: String? = nil) {
        log(event, level: .info, direction: "published", source: source)
    }
    
    /// Log event receiving
    public static func logReceived<Event: AnigmaEvent>(_ event: Event, source: String? = nil) {
        log(event, level: .info, direction: "received", source: source)
    }
    
    /// Log event processing error
    public static func logError<Event: AnigmaEvent>(_ event: Event, error: Error, source: String? = nil) {
        log(event, level: .error, direction: "error", source: source)
        log.debug("Error details: \(error.localizedDescription)")
    }
}

/// Extension to DefaultEventBus for automatic logging
public extension DefaultEventBus {
    /// Publish an event with automatic logging
    func publishWithLogging<Event: AnigmaEvent>(_ event: Event, source: String? = nil) async -> Task<Void, any Error> {
        EventLogger.logPublished(event, source: source)
        return await self.publish(event, source: source)
    }
}

/// Extension to shared event bus for convenience
public extension EventBus {
    /// Convenience helper that adds logging before publishing.
    func publishWithLogging<Event: AnigmaEvent>(_ event: Event, source: String? = nil) async -> Task<Void, any Error> {
        EventLogger.logPublished(event, source: source)
        return await self.publish(event, source: source)
    }
}
