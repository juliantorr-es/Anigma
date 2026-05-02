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
    
    /// Unique identifier for the span this event belongs to
    public let spanID: String?
    
    /// Identifier for the parent span
    public let parentSpanID: String?
    
    /// Optional duration for events representing time-bounded work
    public let duration: TimeInterval?
    
    /// Custom metadata for filtering and analysis
    public let metadata: [String: String]
    
    public init(
        timestamp: Date = Date(),
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String,
        spanID: String? = nil,
        parentSpanID: String? = nil,
        duration: TimeInterval? = nil,
        metadata: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.correlationID = correlationID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
        self.duration = duration
        self.metadata = metadata
    }
    
    /// Serialize to JSON dictionary (structure, not string)
    public func toJSON() -> [String: Any] {
        guard let data = try? CustomJSONEncoder.shared.encode(self),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let dict = jsonObject as? [String: Any] else {
            return [:]
        }

        return dict
    }
    
    /// Encode the event to JSON data using the canonical encoder
    public func toJSONData() -> Data? {
        try? CustomJSONEncoder.shared.encode(self)
    }
    
    // MARK: - Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case level
        case category
        case message
        case correlationID
        case spanID
        case parentSpanID
        case duration
        case metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Use default decoding which will respect the decoder's dateDecodingStrategy
        // (e.g., .iso8601 in CustomJSONDecoder)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        self.level = try container.decode(DiagnosticLevel.self, forKey: .level)
        self.category = try container.decode(String.self, forKey: .category)
        self.message = try container.decode(String.self, forKey: .message)
        self.correlationID = try container.decode(String.self, forKey: .correlationID)
        self.spanID = try container.decodeIfPresent(String.self, forKey: .spanID)
        self.parentSpanID = try container.decodeIfPresent(String.self, forKey: .parentSpanID)
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        self.metadata = try container.decode([String: String].self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Use default encoding which will respect the encoder's dateEncodingStrategy
        try container.encode(timestamp, forKey: .timestamp)
        
        try container.encode(level, forKey: .level)
        try container.encode(category, forKey: .category)
        try container.encode(message, forKey: .message)
        try container.encode(correlationID, forKey: .correlationID)
        try container.encodeIfPresent(spanID, forKey: .spanID)
        try container.encodeIfPresent(parentSpanID, forKey: .parentSpanID)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(metadata, forKey: .metadata)
    }
}

/// Canonical JSON encoder for diagnostic events
public enum CustomJSONEncoder {
    public static let shared: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

/// Canonical JSON decoder for diagnostic events
public enum CustomJSONDecoder {
    public static let shared: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
