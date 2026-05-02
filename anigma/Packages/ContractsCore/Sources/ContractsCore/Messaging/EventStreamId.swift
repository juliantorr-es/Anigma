import Foundation

/// Unique identifier for an event stream
public protocol EventStreamId: Hashable, Codable, Sendable {
  /// Topic/category name (e.g., "daemon_events", "agent_traces", "iot_telemetry")
  var topic: String { get }
  
  /// Optional partition key for future multi-shard deployments
  /// If nil, stream is single-partition (local implementation ignores)
  var partitionKey: String? { get }
  
  /// Project scope (for multi-tenant governance)
  var projectId: String { get }
  
  /// Display name for dashboards
  var displayName: String { get }

  /// Helper for equality check on existentials
  func isEqual(to other: any EventStreamId) -> Bool
}

/// Default concrete implementation of EventStreamId
public struct AnigmaEventStreamId: EventStreamId, Hashable, Codable, Sendable {
  public var topic: String
  public var partitionKey: String?
  public var projectId: String
  public var displayName: String
  
  public init(topic: String, partitionKey: String? = nil, projectId: String, displayName: String? = nil) {
    self.topic = topic
    self.partitionKey = partitionKey
    self.projectId = projectId
    self.displayName = displayName ?? topic
  }
  
  // Hashable conformance
  public func hash(into hasher: inout Hasher) {
    hasher.combine(topic)
    hasher.combine(partitionKey)
    hasher.combine(projectId)
  }
  
  public static func == (lhs: AnigmaEventStreamId, rhs: AnigmaEventStreamId) -> Bool {
    lhs.topic == rhs.topic &&
    lhs.partitionKey == rhs.partitionKey &&
    lhs.projectId == rhs.projectId
  }

  public func isEqual(to other: any EventStreamId) -> Bool {
    guard let other = other as? AnigmaEventStreamId else { return false }
    return self == other
  }
}
