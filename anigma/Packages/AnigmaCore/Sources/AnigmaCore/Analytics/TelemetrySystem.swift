//
//  TelemetrySystem.swift
//  AnigmaCore
//
//  Observability and performance tracing for the Anigma runtime.
//

import Foundation
import TelemetryCore

public struct AnigmaTelemetryEvent: Sendable, Codable {
    public let id: UUID
    public let name: String
    public let timestamp: Date
    public let duration: TimeInterval?
    public let restrictedMetadata: [String: TelemetryValue]
    public let metadata: [String: String]
    public let level: TelemetryLevel
}

public enum TelemetryLevel: String, Codable, Sendable {
    case debug, info, warning, error, critical
}

/// System for collecting and reporting runtime metrics.
public actor TelemetrySystem: System, Sendable {
    public nonisolated var name: String { "system.observability.telemetry" }
    private var events: [AnigmaTelemetryEvent] = []

    public init() {}

    public func update(world: World) async {
        // Periodic flush or maintenance could go here
    }

    /// Record a point-in-time event with restricted values.
    public func record(
        name: String,
        level: TelemetryLevel = .info,
        metadata: [String: TelemetryValue] = [:]
    ) {
        let event = AnigmaTelemetryEvent(
            id: UUID(),
            name: name,
            timestamp: Date(),
            duration: nil,
            restrictedMetadata: metadata,
            metadata: [:],
            level: level
        )
        events.append(event)

        // In a real implementation, this would buffer and flush to disk or a network sink
        if level == .critical {
            print("TELEMETRY CRITICAL: \(name) - \(metadata)")
        }
    }

    /// Record a point-in-time event with legacy string metadata.
    public func record(
        name: String,
        level: TelemetryLevel = .info,
        metadata: [String: String] = [:]
    ) {
        let event = AnigmaTelemetryEvent(
            id: UUID(),
            name: name,
            timestamp: Date(),
            duration: nil,
            restrictedMetadata: [:],
            metadata: metadata,
            level: level
        )
        events.append(event)

        // In a real implementation, this would buffer and flush to disk or a network sink
        if level == .critical {
            print("TELEMETRY CRITICAL: \(name) - \(metadata)")
        }
    }

    /// Measure the duration of an asynchronous operation.
    public func measure<T>(
        name: String,
        metadata: [String: String] = [:],
        operation: () async throws -> T
    ) async throws -> T {
        let start = Date()
        do {
            let result = try await operation()
            let duration = Date().timeIntervalSince(start)
            record(name: name, level: .info, metadata: metadata.merging(["duration": "\(duration)"]) { a, _ in a })
            return result
        } catch {
            record(name: name, level: .error, metadata: metadata.merging(["error": error.localizedDescription]) { a, _ in a })
            throw error
        }
    }
}
