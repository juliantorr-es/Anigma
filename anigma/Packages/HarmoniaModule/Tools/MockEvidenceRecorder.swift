//
//  MockEvidenceRecorder.swift
//  HarmoniaModule
//
//  Mock implementation of EvidenceRecorder for development and testing.
//  In production, this should be replaced with a proper database-backed implementation.
//

import AnigmaPrimitives
import Foundation

/// Mock evidence recorder that stores events in memory.
/// Suitable for development and testing but not for production use.
public actor LoopMockEvidenceRecorder: LoopEvidenceRecorder {
    private var events: [LoopEventRecord] = []

    public init() {}

    public func recordLoopEvent(
        toolCallId: String,
        event: LoopEvent,
        fingerprint: String,
        context: [String: Sendable]
    ) async throws {
        let record = LoopEventRecord(
            toolCallId: toolCallId,
            event: event,
            fingerprint: fingerprint,
            context: context.mapValues { String(describing: $0) },
            timestamp: Date()
        )

        events.append(record)

        // In production, this would write to a persistent database
        // For now, we just keep the last 1000 events in memory
        if events.count > 1000 {
            events.removeFirst(100)
        }
    }

    /// Get all recorded events (for testing)
    public func getAllEvents() -> [LoopEventRecord] {
        return events
    }

    /// Get events for a specific tool call (for testing)
    public func getEventsFor(toolCallId: String) -> [LoopEventRecord] {
        return events.filter { $0.toolCallId == toolCallId }
    }

    /// Clear all events (for testing)
    public func clearAll() {
        events.removeAll()
    }
}

/// Record of a loop breaker event
public struct LoopEventRecord: Codable, Sendable {
    public let toolCallId: String
    public let event: LoopEvent
    public let fingerprint: String
    public let context: [String: String]
    public let timestamp: Date

    public init(
        toolCallId: String,
        event: LoopEvent,
        fingerprint: String,
        context: [String: String],
        timestamp: Date
    ) {
        self.toolCallId = toolCallId
        self.event = event
        self.fingerprint = fingerprint
        self.context = context
        self.timestamp = timestamp
    }
}
