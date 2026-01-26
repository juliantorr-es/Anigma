// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation
import ObservatoriumModule

// MARK: - Observatorium Service Adapter

/// ServiceHandler adapter for ObservatoriumModule
/// Provides telemetry, metrics, and alerting capabilities to HarmoniaModule's workflow orchestration
public actor ObservatoriumServiceAdapter: ServiceHandler {
    // MARK: - Properties
    
    public let serviceId: String = "observatorium-service"
    private let coordinator: ObservatoriumCoordinator
    
    public private(set) var descriptor: ServiceDescriptor
    private var healthStatus: HealthStatus = .unknown
    
    // MARK: - Initialization
    
    /// Initialize ObservatoriumServiceAdapter with optional custom coordinator
    /// - Parameter coordinator: Custom ObservatoriumCoordinator instance (defaults to new instance)
    public init(coordinator: ObservatoriumCoordinator = ObservatoriumCoordinator()) {
        self.coordinator = coordinator
        self.descriptor = ServiceDescriptor(
            id: serviceId,
            name: "Observatorium Service",
            version: "1.0.0",
            capabilities: Self.defaultCapabilities(),
            healthStatus: .unknown,
            lastHealthCheck: nil
        )
    }
    
    // MARK: - ServiceHandler Protocol Implementation
    
    /// Execute an action on the observatorium service
    /// - Parameters:
    ///   - action: The action to perform (recordEvent, recordMetric, getMetrics, createAlert, getActiveAlerts)
    ///   - input: Input parameters for the action
    /// - Returns: Action output as AnyCodable dictionary
    public func execute(action: String, input: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        switch action {
        case "recordEvent":
            return try await recordEvent(input: input)
            
        case "recordMetric":
            return try await recordMetric(input: input)
            
        case "getMetrics":
            return try await getMetrics(input: input)
            
        case "createAlert":
            return try await createAlert(input: input)
            
        case "getActiveAlerts":
            return try await getActiveAlerts(input: input)
            
        default:
            throw ObservatoriumAdapterError.unknownAction(action)
        }
    }
    
    /// Check the health status of the observatorium service
    public func getHealth() async throws -> HealthStatus {
        do {
            let systemHealth = await coordinator.getSystemHealth()
            
            let status: HealthStatus = switch systemHealth.overallStatus {
            case .excellent, .good:
                .healthy
            case .fair:
                .degraded
            case .poor, .critical:
                .unhealthy
            }
            
            healthStatus = status
            updateDescriptorHealth(status)
            return status
        } catch {
            healthStatus = .unhealthy
            updateDescriptorHealth(.unhealthy)
            return .unhealthy
        }
    }
    
    // MARK: - Action Implementations
    
    /// Record a telemetry event
    /// Input: { "type": String, "source": String, "data": [dict], "severity": String? }
    /// Output: { "eventId": String, "recorded": Bool, "timestamp": String }
    private func recordEvent(input: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        guard let typeValue = input["type"],
              case .string(let typeStr) = typeValue else {
            throw ObservatoriumAdapterError.missingRequiredParameter("type")
        }
        
        guard let sourceValue = input["source"],
              case .string(let source) = sourceValue else {
            throw ObservatoriumAdapterError.missingRequiredParameter("source")
        }
        
        // Parse event type
        guard let eventType = TelemetryEventType(rawValue: typeStr) else {
            throw ObservatoriumAdapterError.invalidEventType(typeStr)
        }
        
        // Extract data dictionary
        var eventData: [String: any Codable & Sendable] = [:]
        if let dataValue = input["data"],
           case .dictionary(let dataDict) = dataValue {
            eventData = convertAnyCodableToCodable(dataDict)
        }
        
        // Extract severity
        var severity = TelemetrySeverity.info
        if let sevValue = input["severity"],
           case .string(let sevStr) = sevValue {
            severity = parseTelemetrySeverity(sevStr)
        }
        
        let event = TelemetryEvent(
            type: eventType,
            source: source,
            data: eventData,
            severity: severity
        )
        
        await coordinator.telemetryService.recordEvent(event)
        
        return [
            "eventId": .string(event.id.uuidString),
            "recorded": .bool(true),
            "timestamp": .string(ISO8601DateFormatter().string(from: event.timestamp))
        ]
    }
    
    /// Record a performance metric
    /// Input: { "name": String, "value": Double, "unit": String?, "tags": [dict]? }
    /// Output: { "metricId": String, "recorded": Bool, "timestamp": String }
    private func recordMetric(input: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        guard let nameValue = input["name"],
              case .string(let name) = nameValue else {
            throw ObservatoriumAdapterError.missingRequiredParameter("name")
        }
        
        guard let valueValue = input["value"],
              case .double(let value) = valueValue else {
            throw ObservatoriumAdapterError.missingRequiredParameter("value")
        }
        
        let unit = extractString(from: input["unit"]) ?? "count"
        
        let metric = PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: value, // Use value for CPU for simplicity
            memoryUsage: UInt64(value),
            diskUsage: 0,
            networkIO: NetworkIO(bytesIn: 0, bytesOut: 0),
            duration: 0,
            tags: extractStringDictionary(from: input["tags"])
        )
        
        await coordinator.telemetryService.recordMetric(metric)
        
        return [
            "metricId": .string(UUID().uuidString),
            "recorded": .bool(true),
            "name": .string(name),
            "value": .double(value),
            "unit": .string(unit),
            "timestamp": .string(ISO8601DateFormatter().string(from: metric.timestamp))
        ]
    }
    
    /// Get aggregated metrics for a time period
    /// Input: { "timeRange": String? ("lastHour", "lastDay", "lastWeek") }
    /// Output: { "metrics": [dict], "eventCount": Int, "errorCount": Int, "avgResponseTime": Double }
    private func getMetrics(input: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        var timeRange = TimeRange.lastDay
        
        if let rangeValue = input["timeRange"],
           case .string(let rangeStr) = rangeValue {
            timeRange = parseTimeRange(rangeStr)
        }
        
        let metrics = await coordinator.telemetryService.getAggregatedMetrics(for: timeRange)
        
        return [
            "timeRange": .string(encodeTimeRange(timeRange)),
            "eventCount": .int(metrics?.eventCount ?? 0),
            "errorCount": .int(metrics?.errorCount ?? 0),
            "avgResponseTime": .double(metrics?.avgResponseTime ?? 0.0),
            "peakMemoryUsage": .double(Double(metrics?.peakMemoryUsage ?? 0)),
            "hasData": .bool(metrics != nil)
        ]
    }
    
    /// Create an alert rule
    /// Input: { "name": String, "condition": String, "severity": String, "message": String? }
    /// Output: { "ruleId": String, "created": Bool, "createdAt": String }
    private func createAlert(input: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        guard let nameValue = input["name"],
              case .string(let name) = nameValue else {
            throw ObservatoriumAdapterError.missingRequiredParameter("name")
        }
        
        guard let conditionValue = input["condition"],
              case .string(let condition) = conditionValue else {
            throw ObservatoriumAdapterError.missingRequiredParameter("condition")
        }
        
        guard let severityValue = input["severity"],
              case .string(let severityStr) = severityValue else {
            throw ObservatoriumAdapterError.missingRequiredParameter("severity")
        }
        
        let severity = parseAlertSeverity(severityStr)
        let message = extractString(from: input["message"]) ?? name
        
        let alert = Alert(
            ruleId: UUID(),
            ruleName: name,
            type: .metric,
            severity: severity,
            title: name,
            message: message,
            metadata: [
                "condition": condition
            ]
        )
        
        await coordinator.alertService.createRule(alert)
        
        return [
            "ruleId": .string(alert.ruleId.uuidString),
            "created": .bool(true),
            "name": .string(name),
            "createdAt": .string(ISO8601DateFormatter().string(from: Date()))
        ]
    }
    
    /// Get active alerts
    /// Input: { "severity": String? }
    /// Output: { "alerts": [array of alert data], "count": Int, "critical": Int }
    private func getActiveAlerts(input: [String: AnyCodable]) async throws -> [String: AnyCodable] {
        let alerts = await coordinator.alertService.getActiveAlerts()
        
        var filteredAlerts = alerts
        if let sevValue = input["severity"],
           case .string(let sevStr) = sevValue {
            let severity = parseAlertSeverity(sevStr)
            filteredAlerts = alerts.filter { $0.severity == severity }
        }
        
        let criticalCount = alerts.filter { $0.severity == .critical }.count
        
        var alertsArray: [AnyCodable] = []
        for alert in filteredAlerts {
            alertsArray.append(.dictionary([
                "ruleId": .string(alert.ruleId.uuidString),
                "name": .string(alert.ruleName),
                "severity": .string(alert.severity.rawValue),
                "title": .string(alert.title),
                "message": .string(alert.message)
            ]))
        }
        
        return [
            "alerts": .array(alertsArray),
            "count": .int(filteredAlerts.count),
            "critical": .int(criticalCount),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ]
    }
    
    // MARK: - Helper Methods
    
    /// Default service capabilities
    private static func defaultCapabilities() -> [ServiceCapability] {
        [
            ServiceCapability(
                action: "recordEvent",
                inputType: "[String: AnyCodable]",
                outputType: "[String: AnyCodable]",
                timeout: 5.0
            ),
            ServiceCapability(
                action: "recordMetric",
                inputType: "[String: AnyCodable]",
                outputType: "[String: AnyCodable]",
                timeout: 5.0
            ),
            ServiceCapability(
                action: "getMetrics",
                inputType: "[String: AnyCodable]",
                outputType: "[String: AnyCodable]",
                timeout: 10.0
            ),
            ServiceCapability(
                action: "createAlert",
                inputType: "[String: AnyCodable]",
                outputType: "[String: AnyCodable]",
                timeout: 5.0
            ),
            ServiceCapability(
                action: "getActiveAlerts",
                inputType: "[String: AnyCodable]",
                outputType: "[String: AnyCodable]",
                timeout: 10.0
            )
        ]
    }
    
    /// Update the descriptor with new health status
    private func updateDescriptorHealth(_ status: HealthStatus) {
        self.descriptor = ServiceDescriptor(
            id: descriptor.id,
            name: descriptor.name,
            version: descriptor.version,
            capabilities: descriptor.capabilities,
            healthStatus: status,
            lastHealthCheck: Date()
        )
    }
    
    /// Parse telemetry severity string
    private func parseTelemetrySeverity(_ severity: String) -> TelemetrySeverity {
        switch severity.lowercased() {
        case "critical":
            return .critical
        case "error":
            return .error
        case "warning":
            return .warning
        case "info":
            return .info
        default:
            return .info
        }
    }
    
    /// Parse alert severity string
    private func parseAlertSeverity(_ severity: String) -> AlertSeverity {
        switch severity.lowercased() {
        case "critical":
            return .critical
        case "high":
            return .high
        case "medium":
            return .medium
        case "low":
            return .low
        default:
            return .medium
        }
    }
    
    /// Parse time range string
    private func parseTimeRange(_ rangeStr: String) -> TimeRange {
        switch rangeStr.lowercased() {
        case "lasthour":
            return .lastHour
        case "lastday":
            return .lastDay
        case "lastweek":
            return .lastWeek
        default:
            return .lastDay
        }
    }
    
    /// Encode time range to string
    private func encodeTimeRange(_ timeRange: TimeRange) -> String {
        switch timeRange {
        case .lastHour:
            return "lastHour"
        case .lastDay:
            return "lastDay"
        case .lastWeek:
            return "lastWeek"
        case .custom:
            return "custom"
        }
    }
    
    /// Extract string from AnyCodable
    private func extractString(from value: AnyCodable?) -> String? {
        guard let value = value, case .string(let str) = value else {
            return nil
        }
        return str
    }
    
    /// Extract string dictionary from AnyCodable
    private func extractStringDictionary(from value: AnyCodable?) -> [String: String] {
        guard let value = value, case .dictionary(let dict) = value else {
            return [:]
        }
        
        var result: [String: String] = [:]
        for (key, codableValue) in dict {
            if case .string(let str) = codableValue {
                result[key] = str
            }
        }
        return result
    }
    
    /// Convert AnyCodable dictionary to [String: Codable & Sendable]
    private func convertAnyCodableToCodable(_ dict: [String: AnyCodable]) -> [String: any Codable & Sendable] {
        var result: [String: any Codable & Sendable] = [:]
        for (key, value) in dict {
            switch value {
            case .null:
                continue
            case .bool(let bool):
                result[key] = bool
            case .int(let int):
                result[key] = int
            case .double(let double):
                result[key] = double
            case .string(let string):
                result[key] = string
            case .array, .dictionary:
                result[key] = key // Fallback: use key as value for complex types
            }
        }
        return result
    }
}

// MARK: - Adapter Error Types

public enum ObservatoriumAdapterError: LocalizedError, Sendable {
    case unknownAction(String)
    case missingRequiredParameter(String)
    case invalidEventType(String)
    case invalidInput(String)
    case recordingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .unknownAction(let action):
            return "Unknown action: \(action)"
        case .missingRequiredParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidEventType(let type):
            return "Invalid event type: \(type)"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .recordingFailed(let reason):
            return "Failed to record data: \(reason)"
        }
    }
}
