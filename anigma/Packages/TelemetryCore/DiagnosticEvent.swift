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
    /// Custom tags for filtering and analysis
    public let tags: [String: String]

    public init(
        timestamp: Date = Date(),
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String,
        spanID: String? = nil,
        parentSpanID: String? = nil,
        duration: TimeInterval? = nil,
        tags: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.correlationID = correlationID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
        self.duration = duration
        self.tags = tags
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

    enum CodingKeys: String, CodingKey {
        case timestamp
        case level
        case category
        case message
        case correlationID
        case spanID
        case parentSpanID
        case duration
        case tags
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
