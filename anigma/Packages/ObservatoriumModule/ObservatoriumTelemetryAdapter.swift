//
//  ObservatoriumTelemetryAdapter.swift
//  ObservatoriumModule
//
//  Compatibility adapter that routes existing telemetry through TelemetryCore.
//  Provides smooth migration path while preserving existing APIs.
//

import AnigmaCore
import Foundation
import TelemetryCore

/// Adapter that bridges existing Observatorium telemetry to unified TelemetryCore.
/// Routes all telemetry through mandatory redaction and sampling pipeline.
public actor ObservatoriumTelemetryAdapter {
    private let telemetryClient: TelemetryClient

    public init(telemetryClient: TelemetryClient) {
        self.telemetryClient = telemetryClient
    }

    /// Adapts existing TelemetryEventComponent to TelemetryCore.
    public func recordTelemetryEvent(_ event: TelemetryEventComponent) async {
        // Convert event properties to TelemetryValue types
        var convertedValues: [String: TelemetryCore.TelemetryValue] = [:]

        for (key, value) in event.properties {
            if let telemetryValue = convertTelemetryValue(value) {
                convertedValues[key] = telemetryValue
            }
        }

        // Add common event metadata
        convertedValues["module"] = .hashedToken(TelemetryHash(input: event.module))
        convertedValues["action"] = .hashedToken(TelemetryHash(input: event.action))
        convertedValues["severity"] = .hashedToken(TelemetryHash(input: event.severity.rawValue))

        if let duration = event.durationMs {
            convertedValues["duration_ms"] = .double(duration)
        }

        // Convert event type to category
        let category = convertEventType(event.eventType)
        let privacyClassification = convertSensitivity(event.sensitivityLevel)

        // Emit through unified client with mandatory redaction
        _ = await telemetryClient.emit(
            category: category,
            name: event.name,
            privacyClassification: privacyClassification,
            values: convertedValues
        )
    }

    /// Adapts existing metric recording to TelemetryCore.
    public func recordMetric(
        name: String,
        value: Double,
        dimensions: [String: String] = [:],
        correlationId: String? = nil
    ) async {
        var convertedValues: [String: TelemetryCore.TelemetryValue] = [
            "metric_value": .double(value)
        ]

        // Convert dimensions to hashed tokens for privacy
        for (key, dimensionValue) in dimensions {
            convertedValues["dimension_\(key)"] = .hashedToken(TelemetryHash(input: dimensionValue))
        }

        if let correlationId = correlationId {
            convertedValues["correlation_id"] = .hashedToken(TelemetryHash(input: correlationId))
        }

        _ = await telemetryClient.emit(
            category: .performance,
            name: name,
            privacyClassification: .internal,  // Metrics are typically internal
            values: convertedValues
        )
    }

    /// Adapts workflow completion events.
    public func recordWorkflowComplete(
        module: String,
        workflowName: String,
        durationMs: Double,
        success: Bool
    ) async {
        _ = await telemetryClient.emitTrace(
            module: module,
            action: workflowName,
            durationMs: durationMs,
            privacyClassification: .internal,
            additionalValues: [
                "success": .boolean(success),
                "workflow_name": .hashedToken(TelemetryHash(input: workflowName))
            ]
        )
    }

    // MARK: - Private Conversion Methods

    /// Converts existing TelemetryValue to TelemetryCore version.
    private func convertTelemetryValue(_ oldValue: TelemetryValue) -> TelemetryCore.TelemetryValue? {
        switch oldValue {
        case .string(let stringValue):
            // Convert strings to hashed tokens for privacy
            return .hashedToken(TelemetryHash(input: stringValue))

        case .int(let intValue):
            return .integer(intValue)

        case .double(let doubleValue):
            return .double(doubleValue)

        case .bool(let boolValue):
            return .boolean(boolValue)

        case .date(let dateValue):
            return .double(dateValue.timeIntervalSince1970 * 1000)  // Convert to ms timestamp

        case .array(let arrayValue):
            // Convert array elements recursively
            let converted = arrayValue.compactMap { convertTelemetryValue($0) }
            if converted.isEmpty { return nil }
            // Convert array to count since TelemetryCore doesn't support arrays
            return .integer(converted.count)

        case .dictionary(let dictValue):
            // Convert dictionary to hashed key-value pairs
            var converted: [String: TelemetryCore.TelemetryValue] = [:]
            for (key, value) in dictValue {
                if let convertedValue = convertTelemetryValue(value) {
                    converted[key] = convertedValue
                }
            }
            // Convert dictionary to count for telemetry
            return .integer(converted.count)

        case .null:
            return nil  // Skip null values in telemetry
        }
    }

    /// Converts event type to category.
    private func convertEventType(_ eventType: TelemetryEventType) -> TelemetryCategory {
        switch eventType {
        case .systemStart, .systemStop, .systemHealth:
            return .system

        case .performanceTrace, .performanceSpan, .performanceLatency:
            return .performance

        case .authSuccess, .authFailure, .accessDenied, .policyViolation:
            return .security

        case .errorOccurred, .errorResolved:
            return .error

        case .workflowStart, .workflowComplete, .workflowFailed,
            .jobStart, .jobComplete, .jobFailed,
            .caseCreated, .caseUpdated, .caseClosed,
            .documentProcessed, .exportGenerated:
            return .workflow

        case .userAction, .userNavigation, .userSearch:
            return .tool  // Treat user actions as tool events
        }
    }

    /// Converts sensitivity level to privacy classification.
    private func convertSensitivity(_ sensitivity: TelemetrySensitivity) -> PrivacyClassification {
        switch sensitivity {
        case .public:
            return .public
        case .internal:
            return .internal
        case .restricted:
            return .restricted
        }
    }
}

/// Provides backward-compatible interface for gradual migration.
extension TelemetryService {
    /// Creates a TelemetryService that uses TelemetryCore internally.
    /// This enables gradual migration from ObservatoriumModule to TelemetryCore.
    public static func withTelemetryCore(
        _ telemetryClient: TelemetryClient,
        world: World,
        governance: GovernanceController,
        bufferSize: Int = 1000,
        flushInterval: TimeInterval = 60,
        sensitivityFilter: TelemetrySensitivity = .restricted
    ) -> TelemetryServiceWithCore {
        return TelemetryServiceWithCore(
            telemetryClient: telemetryClient,
            world: world,
            governance: governance,
            bufferSize: bufferSize,
            flushInterval: flushInterval,
            sensitivityFilter: sensitivityFilter
        )
    }
}

/// TelemetryService implementation backed by TelemetryCore.
/// Provides backward compatibility while routing through new privacy-enforced pipeline.
public actor TelemetryServiceWithCore {
    private let adapter: ObservatoriumTelemetryAdapter
    private let world: World
    private let governance: GovernanceController
    private let bufferSize: Int
    private let flushInterval: TimeInterval
    private let sensitivityFilter: TelemetrySensitivity

    // Statistics tracking
    private var eventsReceived: Int = 0
    private var eventsDropped: Int = 0
    private var metricsReceived: Int = 0

    public init(
        telemetryClient: TelemetryClient,
        world: World,
        governance: GovernanceController,
        bufferSize: Int = 1000,
        flushInterval: TimeInterval = 60,
        sensitivityFilter: TelemetrySensitivity = .restricted
    ) {
        self.adapter = ObservatoriumTelemetryAdapter(telemetryClient: telemetryClient)
        self.world = world
        self.governance = governance
        self.bufferSize = bufferSize
        self.flushInterval = flushInterval
        self.sensitivityFilter = sensitivityFilter
    }

    /// Records a telemetry event through TelemetryCore.
    public func record(_ event: TelemetryEventComponent) async {
        eventsReceived += 1

        // Filter by sensitivity
        guard event.sensitivityLevel <= sensitivityFilter else {
            eventsDropped += 1
            return
        }

        // Route through TelemetryCore adapter
        await adapter.recordTelemetryEvent(event)
    }

    /// Records a performance trace through TelemetryCore.
    public func recordTrace(
        module: String,
        action: String,
        durationMs: Double,
        properties: [String: TelemetryValue] = [:],
        correlationId: String? = nil
    ) async {
        let event = TelemetryEventComponent.performanceTrace(
            module: module,
            action: action,
            durationMs: durationMs,
            properties: properties,
            correlationId: correlationId
        )
        await record(event)
    }

    /// Records a workflow completion through TelemetryCore.
    public func recordWorkflowComplete(
        module: String,
        workflowName: String,
        durationMs: Double,
        success: Bool
    ) async {
        await adapter.recordWorkflowComplete(
            module: module,
            workflowName: workflowName,
            durationMs: durationMs,
            success: success
        )
    }

    /// Records a metric through TelemetryCore.
    public func recordMetric(
        name: String,
        value: Double,
        dimensions: [String: String] = [:],
        correlationId: String? = nil
    ) async {
        metricsReceived += 1

        await adapter.recordMetric(
            name: name,
            value: value,
            dimensions: dimensions,
            correlationId: correlationId
        )
    }

    /// Returns service statistics.
    public func getStatistics() -> TelemetryStatistics {
        return TelemetryStatistics(
            eventsReceived: eventsReceived,
            eventsDropped: eventsDropped,
            eventBufferSize: 0,  // TelemetryCore handles buffering
            metricsReceived: metricsReceived,
            metricBufferSize: 0,  // TelemetryCore handles buffering
            registeredMetrics: 0,  // Not tracked in this adapter
            lastFlush: Date()  // TelemetryCore handles flushing
        )
    }
}
