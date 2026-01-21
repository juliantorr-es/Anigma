//
//  TelemetryClient.swift
//  AnigmaCore
//
//  Main telemetry client with mandatory redaction and privacy enforcement.
//  This actor lives in Tier 2 (Platform Runtime) as it manages execution.
//

import Foundation

/// Main telemetry client that enforces privacy by construction.
/// All emit calls go through redaction before reaching sinks.
public actor TelemetryClient {
    private let sinks: [TelemetrySink]
    private let configuration: TelemetryConfiguration

    public init(sinks: [TelemetrySink], configuration: TelemetryConfiguration = .default) {
        self.sinks = sinks
        self.configuration = configuration
    }

    /// Emits a telemetry event with mandatory redaction.
    /// This is the ONLY way to emit telemetry - ensures all events are redacted.
    public func emit(
        category: TelemetryCategory,
        name: String,
        privacyClassification: PrivacyClassification = .restricted,
        values: [String: TelemetryValue] = [:]
    ) async -> Result<Void, TelemetryError> {

        // Create the event with default restricted privacy
        let event = TelemetryEvent(
            category: category,
            name: name,
            privacyClassification: privacyClassification,
            values: values
        )

        return await emitEvent(event)
    }

    /// Emits a performance trace event.
    public func emitTrace(
        module: String,
        action: String,
        durationMs: Double,
        privacyClassification: PrivacyClassification = .restricted,
        additionalValues: [String: TelemetryValue] = [:]
    ) async -> Result<Void, TelemetryError> {
        let values: [String: TelemetryValue] = [
            "duration_ms": .double(durationMs),
            "module": .hashedToken(TelemetryHash(input: module)),
            "action": .hashedToken(TelemetryHash(input: action))
        ].merging(additionalValues) { $1 }

        return await emit(
            category: .performance,
            name: "trace",
            privacyClassification: privacyClassification,
            values: values
        )
    }

    /// Emits an error event.
    public func emitError(
        module: String,
        error: String,
        errorCode: String? = nil,
        privacyClassification: PrivacyClassification = .restricted,
        additionalValues: [String: TelemetryValue] = [:]
    ) async -> Result<Void, TelemetryError> {
        var values: [String: TelemetryValue] = [
            "module": .hashedToken(TelemetryHash(input: module)),
            "error": .hashedToken(TelemetryHash(input: error))
        ]

        if let errorCode = errorCode {
            values["error_code"] = .hashedToken(TelemetryHash(input: errorCode))
        }

        values.merge(additionalValues) { $1 }

        return await emit(
            category: .error,
            name: "occurred",
            privacyClassification: privacyClassification,
            values: values
        )
    }

    /// Emits a tool execution event.
    public func emitToolExecution(
        toolName: String,
        durationMs: Double,
        success: Bool,
        privacyClassification: PrivacyClassification = .restricted,
        additionalValues: [String: TelemetryValue] = [:]
    ) async -> Result<Void, TelemetryError> {
        let values: [String: TelemetryValue] = [
            "tool_name": .hashedToken(TelemetryHash(input: toolName)),
            "duration_ms": .double(durationMs),
            "success": .boolean(success)
        ].merging(additionalValues) { $1 }

        return await emit(
            category: .tool,
            name: "executed",
            privacyClassification: privacyClassification,
            values: values
        )
    }

    /// Internal method that handles the actual event emission pipeline.
    private func emitEvent(_ event: TelemetryEvent) async -> Result<Void, TelemetryError> {
        // Step 1: Apply sampling
        guard Sampling.shouldSample(event) else {
            return .success(()) // Silently drop unsampled events
        }

        // Step 2: Apply mandatory redaction
        let redactedEvent = Redaction.apply(to: event)

        // Step 3: Convert to wire format for sinks
        let wireEvent = WireRedactedEvent(from: redactedEvent)

        // Step 4: Send to all enabled sinks
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for sink in sinks {
                    guard sink.isEnabled else { continue }

                    group.addTask {
                        try await sink.handle(wireEvent)
                    }
                }

                // Wait for all sinks to complete
                for try await _ in group {}
            }

            return .success(())
        } catch {
            return .failure(.validationFailed("Failed to emit to sinks: \(error)"))
        }
    }

    /// Flushes all sinks.
    public func flush() async -> Result<Void, TelemetryError> {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for sink in sinks {
                    guard sink.isEnabled else { continue }

                    group.addTask {
                        try await sink.flush()
                    }
                }

                for try await _ in group {}
            }

            return .success(())
        } catch {
            return .failure(.validationFailed("Failed to flush sinks: \(error)"))
        }
    }

    /// Returns telemetry statistics for monitoring.
    public func getStatistics() -> TelemetryStatistics {
        return TelemetryStatistics(
            enabledSinks: sinks.filter { $0.isEnabled }.count,
            totalSinks: sinks.count,
            configuration: configuration
        )
    }
}

/// Configuration for TelemetryClient.
public struct TelemetryConfiguration: Sendable {
    public let environment: Environment
    public let samplingConfig: SamplingConfiguration
    public let redactionPolicy: RedactionPolicy

    public enum Environment: String, Sendable, Codable {
        case development
        case staging
        case production
    }

    public static let `default` = TelemetryConfiguration(
        environment: .production,
        samplingConfig: .default,
        redactionPolicy: .default
    )

    public static let development = TelemetryConfiguration(
        environment: .development,
        samplingConfig: .development,
        redactionPolicy: .default
    )
}

/// Telemetry statistics for monitoring.
public struct TelemetryStatistics: Sendable {
    public let enabledSinks: Int
    public let totalSinks: Int
    public let configuration: TelemetryConfiguration
}

// MARK: - Convenience Extensions

extension TelemetryClient {
    /// Creates a development-friendly telemetry client.
    public static func forDevelopment() -> TelemetryClient {
        let memorySink = MemoryTelemetrySink(id: "dev-memory", maxEvents: 1000)
        let consoleSink = ConsoleTelemetrySink(id: "dev-console")

        return TelemetryClient(
            sinks: [memorySink, consoleSink],
            configuration: .development
        )
    }

    /// Creates a production telemetry client.
    public static func forProduction(sinks: [TelemetrySink]) -> TelemetryClient {
        return TelemetryClient(
            sinks: sinks,
            configuration: .default
        )
    }
}
