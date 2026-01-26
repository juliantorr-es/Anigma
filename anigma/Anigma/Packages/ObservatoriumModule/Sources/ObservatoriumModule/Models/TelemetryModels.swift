import Foundation

// MARK: - Telemetry Event Types
public enum TelemetryEventType: String, Codable, CaseIterable, Sendable {
    case systemStartup = "system_startup"
    case systemShutdown = "system_shutdown"
    case performanceMetric = "performance_metric"
    case error = "error"
    case userAction = "user_action"
    case resourceUsage = "resource_usage"
    case networkActivity = "network_activity"
    case databaseOperation = "database_operation"
}

// MARK: - Telemetry Event
public struct TelemetryEvent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: TelemetryEventType
    public let source: String
    public let data: [String: any Codable & Sendable]
    public let severity: TelemetrySeverity
    
    public init(
        type: TelemetryEventType,
        source: String,
        data: [String: any Codable & Sendable],
        severity: TelemetrySeverity = .info
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.source = source
        self.data = data
        self.severity = severity
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, timestamp, type, source, data, severity
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        type = try container.decode(TelemetryEventType.self, forKey: .type)
        source = try container.decode(String.self, forKey: .source)
        severity = try container.decode(TelemetrySeverity.self, forKey: .severity)
        
        // Decode data as a flexible structure
        let dataContainer = try container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .data)
        var decodedData: [String: any Codable & Sendable] = [:]
        
        for key in dataContainer.allKeys {
            if let value = try? dataContainer.decodeIfPresent(String.self, forKey: key) {
                decodedData[key.stringValue] = value
            } else if let value = try? dataContainer.decodeIfPresent(Int.self, forKey: key) {
                decodedData[key.stringValue] = value
            } else if let value = try? dataContainer.decodeIfPresent(Double.self, forKey: key) {
                decodedData[key.stringValue] = value
            } else if let value = try? dataContainer.decodeIfPresent(Bool.self, forKey: key) {
                decodedData[key.stringValue] = value
            }
        }
        
        data = decodedData
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(type, forKey: .type)
        try container.encode(source, forKey: .source)
        try container.encode(severity, forKey: .severity)
        
        // Encode data as flexible structure
        var dataContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .data)
        for (key, value) in data {
            let codingKey = DynamicCodingKeys(stringValue: key)!
            
            if let stringValue = value as? String {
                try dataContainer.encode(stringValue, forKey: codingKey)
            } else if let intValue = value as? Int {
                try dataContainer.encode(intValue, forKey: codingKey)
            } else if let doubleValue = value as? Double {
                try dataContainer.encode(doubleValue, forKey: codingKey)
            } else if let boolValue = value as? Bool {
                try dataContainer.encode(boolValue, forKey: codingKey)
            }
        }
    }
}

// MARK: - Performance Metrics
public struct PerformanceMetrics: Codable, Sendable {
    public let cpuUsage: Double
    public let memoryUsage: UInt64
    public let diskUsage: UInt64
    public let networkIO: NetworkIO
    public let timestamp: Date
    
    public init(cpuUsage: Double, memoryUsage: UInt64, diskUsage: UInt64, networkIO: NetworkIO) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.diskUsage = diskUsage
        self.networkIO = networkIO
        self.timestamp = Date()
    }
}

public struct NetworkIO: Codable, Sendable {
    public let bytesIn: UInt64
    public let bytesOut: UInt64
    public let connections: Int
    
    public init(bytesIn: UInt64, bytesOut: UInt64, connections: Int) {
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.connections = connections
    }
}

// MARK: - Telemetry Severity
public enum TelemetrySeverity: String, Codable, CaseIterable, Sendable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    public var level: Int {
        switch self {
        case .debug: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        case .critical: return 5
        }
    }
}

// MARK: - Time Range
public enum TimeRange: Sendable {
    case lastHour
    case lastDay
    case lastWeek
    case lastMonth
    case custom(Date, Date)
    
    public var dateInterval: DateInterval {
        let now = Date()
        switch self {
        case .lastHour:
            return DateInterval(start: now.addingTimeInterval(-3600), end: now)
        case .lastDay:
            return DateInterval(start: now.addingTimeInterval(-86400), end: now)
        case .lastWeek:
            return DateInterval(start: now.addingTimeInterval(-604800), end: now)
        case .lastMonth:
            return DateInterval(start: now.addingTimeInterval(-2592000), end: now)
        case .custom(let start, let end):
            return DateInterval(start: start, end: end)
        }
    }
}

// MARK: - Dynamic Coding Keys for Flexible Data
private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
