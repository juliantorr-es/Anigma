import Foundation

/// Position in an event stream, supports replay range queries
public protocol EventCursor: Comparable, Codable, Hashable, Sendable {
  /// Absolute position in stream (0-indexed)
  var position: UInt64 { get }
  
  /// Stream this cursor refers to
  var streamId: any EventStreamId { get }
  
  /// Optional checkpoint label (for recovery)
  var checkpointId: UUID? { get }

  /// Helper for equality check on existentials
  func isEqual(to other: any EventCursor) -> Bool
}

/// Default concrete implementation of EventCursor
public struct AnigmaEventCursor: EventCursor, Comparable, Codable, Hashable, Sendable {
  public var position: UInt64
  public var streamIdConcrete: AnigmaEventStreamId
  public var checkpointId: UUID?

  public var streamId: any EventStreamId { streamIdConcrete }
  
  public init(position: UInt64, streamId: any EventStreamId, checkpointId: UUID? = nil) {
    self.position = position
    if let concrete = streamId as? AnigmaEventStreamId {
      self.streamIdConcrete = concrete
    } else {
      // Fallback for other implementations if any
      self.streamIdConcrete = AnigmaEventStreamId(topic: streamId.topic, partitionKey: streamId.partitionKey, projectId: streamId.projectId, displayName: streamId.displayName)
    }
    self.checkpointId = checkpointId
  }

  public init(position: UInt64, streamId: AnigmaEventStreamId, checkpointId: UUID? = nil) {
    self.position = position
    self.streamIdConcrete = streamId
    self.checkpointId = checkpointId
  }
  
  // Comparable conformance
  public static func < (lhs: AnigmaEventCursor, rhs: AnigmaEventCursor) -> Bool {
    guard lhs.streamIdConcrete == rhs.streamIdConcrete else {
      // Different streams not comparable, but we need a total order
      return String(describing: lhs.streamIdConcrete) < String(describing: rhs.streamIdConcrete)
    }
    return lhs.position < rhs.position
  }
  
  // Hashable conformance
  public func hash(into hasher: inout Hasher) {
    hasher.combine(position)
    hasher.combine(streamIdConcrete)
  }
  
  public static func == (lhs: AnigmaEventCursor, rhs: AnigmaEventCursor) -> Bool {
    lhs.position == rhs.position && lhs.streamIdConcrete == rhs.streamIdConcrete
  }

  public func isEqual(to other: any EventCursor) -> Bool {
    guard let other = other as? AnigmaEventCursor else { return false }
    return self == other
  }

  // Explicit Codable implementation to match the protocol and use concrete types internally
  enum CodingKeys: String, CodingKey {
    case position, streamId, checkpointId
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    position = try container.decode(UInt64.self, forKey: .position)
    streamIdConcrete = try container.decode(AnigmaEventStreamId.self, forKey: .streamId)
    checkpointId = try container.decodeIfPresent(UUID.self, forKey: .checkpointId)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(position, forKey: .position)
    try container.encode(streamIdConcrete, forKey: .streamId)
    try container.encodeIfPresent(checkpointId, forKey: .checkpointId)
  }
}

/// Metadata about event provenance
public struct EventProvenance: Codable, Sendable {
  /// Source that emitted this event (e.g., "daemon", "agent:summarizer", "device:sensor-123")
  public var source: String
  
  /// Source capability ID (for governance linkage)
  public var sourceCapabilityId: String?
  
  /// Optional causality chain (parent event ID)
  public var parentEventId: UUID?
  
  /// Hardware lane if applicable ("cpu", "gpu", "ane")
  public var hardwareLane: String?
  
  /// Timestamp when event was created (UTC)
  public var createdAt: Date
  
  public init(source: String, sourceCapabilityId: String? = nil, 
              parentEventId: UUID? = nil, hardwareLane: String? = nil, 
              createdAt: Date = Date()) {
    self.source = source
    self.sourceCapabilityId = sourceCapabilityId
    self.parentEventId = parentEventId
    self.hardwareLane = hardwareLane
    self.createdAt = createdAt
  }
}

/// Standard event envelope for all EventLog subsystem messages
public struct EventEnvelope: Codable, Sendable {
  /// Unique event ID
  public var eventId: UUID
  
  /// Stream this event belongs to
  public var streamId: any EventStreamId
  
  /// Position in stream (assigned by EventLog)
  public var cursor: (any EventCursor)?
  
  /// Event creation timestamp (UTC)
  public var timestamp: Date
  
  /// Schema version for payload compatibility (e.g., "daemon.event.v1", "agent.trace.v2")
  public var schemaVersion: String
  
  /// Provenance: source, capability, causality
  public var provenance: EventProvenance
  
  /// Payload as inline data (for small payloads, < 1KB recommended)
  public var payload: Data?
  
  /// Optional backpressure hint for high-frequency ingest
  public var backpressureHint: BackpressureHint?
  
  public init(eventId: UUID = UUID(), streamId: any EventStreamId, schemaVersion: String,
              provenance: EventProvenance, payload: Data? = nil, timestamp: Date = Date()) {
    self.eventId = eventId
    self.streamId = streamId
    self.timestamp = timestamp
    self.schemaVersion = schemaVersion
    self.provenance = provenance
    self.payload = payload
    self.cursor = nil
    self.backpressureHint = nil
  }

  enum CodingKeys: String, CodingKey {
    case eventId, streamId, cursor, timestamp, schemaVersion, provenance, payload, backpressureHint
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    eventId = try container.decode(UUID.self, forKey: .eventId)
    streamId = try container.decode(AnigmaEventStreamId.self, forKey: .streamId)
    cursor = try container.decodeIfPresent(AnigmaEventCursor.self, forKey: .cursor)
    timestamp = try container.decode(Date.self, forKey: .timestamp)
    schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
    provenance = try container.decode(EventProvenance.self, forKey: .provenance)
    payload = try container.decodeIfPresent(Data.self, forKey: .payload)
    backpressureHint = try container.decodeIfPresent(BackpressureHint.self, forKey: .backpressureHint)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(eventId, forKey: .eventId)
    if let concrete = streamId as? AnigmaEventStreamId {
      try container.encode(concrete, forKey: .streamId)
    } else {
      let concrete = AnigmaEventStreamId(topic: streamId.topic, partitionKey: streamId.partitionKey, projectId: streamId.projectId, displayName: streamId.displayName)
      try container.encode(concrete, forKey: .streamId)
    }
    if let cursor = cursor {
      if let concrete = cursor as? AnigmaEventCursor {
        try container.encode(concrete, forKey: .cursor)
      } else {
        let concrete = AnigmaEventCursor(position: cursor.position, streamId: cursor.streamId, checkpointId: cursor.checkpointId)
        try container.encode(concrete, forKey: .cursor)
      }
    }
    try container.encode(timestamp, forKey: .timestamp)
    try container.encode(schemaVersion, forKey: .schemaVersion)
    try container.encode(provenance, forKey: .provenance)
    try container.encodeIfPresent(payload, forKey: .payload)
    try container.encodeIfPresent(backpressureHint, forKey: .backpressureHint)
  }
}

/// Backpressure hint for subscribers
public struct BackpressureHint: Codable, Sendable {
  public var queueDepth: Int
  public var estimatedDelayMs: Int
  public var recommendedBackoffMs: Int
  
  public init(queueDepth: Int, estimatedDelayMs: Int, recommendedBackoffMs: Int) {
    self.queueDepth = queueDepth
    self.estimatedDelayMs = estimatedDelayMs
    self.recommendedBackoffMs = recommendedBackoffMs
  }
}

/// Stream retention policy metadata
public struct StreamRetentionPolicy: Codable, Sendable {
  /// How many days to retain events (0 = infinite)
  public var retentionDays: Int
  
  /// Maximum event count before pruning (0 = no limit)
  public var maxEventCount: Int
  
  /// Backpressure policy (drop behavior when full)
  public var backpressurePolicy: BackpressurePolicy
  
  public init(retentionDays: Int = 90, maxEventCount: Int = 0,
              backpressurePolicy: BackpressurePolicy = .block) {
    self.retentionDays = retentionDays
    self.maxEventCount = maxEventCount
    self.backpressurePolicy = backpressurePolicy
  }
}

/// Backpressure drop behavior
public enum BackpressurePolicy: String, Codable, Sendable {
  /// Block subscribers (wait for drain)
  case block
  /// Drop newest events silently
  case dropNewest
  /// Drop oldest events (FIFO eviction)
  case dropOldest
  /// Raise error to subscriber
  case error
}

/// Checkpoint for cursor recovery
public struct EventCheckpoint: Codable, Sendable {
  /// Unique checkpoint ID
  public var checkpointId: UUID
  
  /// Stream this checkpoint refers to
  public var streamId: any EventStreamId
  
  /// Last successfully processed cursor
  public var cursor: any EventCursor
  
  /// Human-readable label (e.g., "last_observatorium_dashboard_update")
  public var label: String
  
  /// When checkpoint was created
  public var createdAt: Date
  
  /// When checkpoint was last updated
  public var updatedAt: Date
  
  public init(checkpointId: UUID = UUID(), streamId: any EventStreamId, cursor: any EventCursor,
              label: String, createdAt: Date = Date()) {
    self.checkpointId = checkpointId
    self.streamId = streamId
    self.cursor = cursor
    self.label = label
    self.createdAt = createdAt
    self.updatedAt = createdAt
  }

  enum CodingKeys: String, CodingKey {
    case checkpointId, streamId, cursor, label, createdAt, updatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    checkpointId = try container.decode(UUID.self, forKey: .checkpointId)
    streamId = try container.decode(AnigmaEventStreamId.self, forKey: .streamId)
    cursor = try container.decode(AnigmaEventCursor.self, forKey: .cursor)
    label = try container.decode(String.self, forKey: .label)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(checkpointId, forKey: .checkpointId)
    if let concrete = streamId as? AnigmaEventStreamId {
      try container.encode(concrete, forKey: .streamId)
    } else {
      let concrete = AnigmaEventStreamId(topic: streamId.topic, partitionKey: streamId.partitionKey, projectId: streamId.projectId, displayName: streamId.displayName)
      try container.encode(concrete, forKey: .streamId)
    }
    if let concrete = cursor as? AnigmaEventCursor {
      try container.encode(concrete, forKey: .cursor)
    } else {
      let concrete = AnigmaEventCursor(position: cursor.position, streamId: cursor.streamId, checkpointId: cursor.checkpointId)
      try container.encode(concrete, forKey: .cursor)
    }
    try container.encode(label, forKey: .label)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(updatedAt, forKey: .updatedAt)
  }
}

/// Receipt emitted when event is successfully appended
public struct EventAppendReceipt: Codable, Sendable {
  /// The appended event's ID
  public var eventId: UUID
  
  /// The assigned cursor position
  public var cursor: any EventCursor
  
  /// Stream ID
  public var streamId: any EventStreamId
  
  /// Timestamp of append
  public var appendedAt: Date
  
  /// Signature for audit trail
  public var signature: String
  
  public init(eventId: UUID, cursor: any EventCursor, streamId: any EventStreamId,
              appendedAt: Date = Date(), signature: String = "") {
    self.eventId = eventId
    self.cursor = cursor
    self.streamId = streamId
    self.appendedAt = appendedAt
    self.signature = signature
  }

  enum CodingKeys: String, CodingKey {
    case eventId, cursor, streamId, appendedAt, signature
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    eventId = try container.decode(UUID.self, forKey: .eventId)
    cursor = try container.decode(AnigmaEventCursor.self, forKey: .cursor)
    streamId = try container.decode(AnigmaEventStreamId.self, forKey: .streamId)
    appendedAt = try container.decode(Date.self, forKey: .appendedAt)
    signature = try container.decode(String.self, forKey: .signature)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(eventId, forKey: .eventId)
    if let concrete = cursor as? AnigmaEventCursor {
      try container.encode(concrete, forKey: .cursor)
    } else {
      let concrete = AnigmaEventCursor(position: cursor.position, streamId: cursor.streamId, checkpointId: cursor.checkpointId)
      try container.encode(concrete, forKey: .cursor)
    }
    if let concrete = streamId as? AnigmaEventStreamId {
      try container.encode(concrete, forKey: .streamId)
    } else {
      let concrete = AnigmaEventStreamId(topic: streamId.topic, partitionKey: streamId.partitionKey, projectId: streamId.projectId, displayName: streamId.displayName)
      try container.encode(concrete, forKey: .streamId)
    }
    try container.encode(appendedAt, forKey: .appendedAt)
    try container.encode(signature, forKey: .signature)
  }
}
