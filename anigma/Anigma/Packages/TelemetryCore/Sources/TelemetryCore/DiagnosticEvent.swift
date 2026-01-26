import Foundation

/// A structured diagnostic event with correlated metadata
public struct DiagnosticEvent: Codable, Sendable {
    /// When this event occurred
    public let timestamp: Date
    
    /// Severity level of the event
    public let level: DiagnosticLevel
    
    /// Category for grouping (e.g., "textpipeline.unicode", "network.http")
    public let category: String
    
    /// The event message (automatically redacted for secrets)
    public let message: String
    
    /// Correlation ID for tracing across spans and services
    public let correlationID: String
    
    /// Optional duration for events representing time-bounded work
    public let duration: TimeInterval?
    
    /// Custom tags for filtering and analysis
    public let tags: [String: String]
    
    public init(
        timestamp: Date = Date(),
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String,
        duration: TimeInterval? = nil,
        tags: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.correlationID = correlationID
        self.duration = duration
        self.tags = tags
    }
    
    /// Serialize to JSON dictionary (structure, not string)
    public func toJSON() -> [String: Any] {
        var dict: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "level": level.rawValue,
            "category": category,
            "message": message,
            "correlationID": correlationID,
            "tags": tags
        ]
        
        if let duration = duration {
            dict["duration"] = duration
        }
        
        return dict
    }
    
    /// Encode the event to JSON data
    public func toJSONData() -> Data? {
        guard let jsonObject = try? JSONSerialization.data(
            withJSONObject: toJSON(),
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return nil
        }
        return jsonObject
    }
    
    // MARK: - Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case level
        case category
        case message
        case correlationID
        case duration
        case tags
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode timestamp with support for ISO8601 format
        let timestampString = try container.decode(String.self, forKey: .timestamp)
        if let timestamp = ISO8601DateFormatter().date(from: timestampString) {
            self.timestamp = timestamp
        } else {
            // Fallback to legacy date format if needed
            throw DecodingError.dataCorruptedError(
                forKey: .timestamp,
                in: container,
                debugDescription: "Date string does not match ISO8601 format"
            )
        }
        
        self.level = try container.decode(DiagnosticLevel.self, forKey: .level)
        self.category = try container.decode(String.self, forKey: .category)
        self.message = try container.decode(String.self, forKey: .message)
        self.correlationID = try container.decode(String.self, forKey: .correlationID)
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.tags = try container.decode([String: String].self, forKey: .tags)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(ISO8601DateFormatter().string(from: timestamp), forKey: .timestamp)
        try container.encode(level, forKey: .level)
        try container.encode(category, forKey: .category)
        try container.encode(message, forKey: .message)
        try container.encode(correlationID, forKey: .correlationID)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(tags, forKey: .tags)
    }
}
