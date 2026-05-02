import Foundation

/// Rate limit policy for coordination
public struct RateLimitPolicy: Codable, Sendable {
  /// Maximum requests per window
  public var maxRequests: Int
  
  /// Time window in seconds
  public var windowSeconds: Int
  
  public init(maxRequests: Int = 100, windowSeconds: Int = 60) {
    self.maxRequests = maxRequests
    self.windowSeconds = windowSeconds
  }
}

/// Result of rate limit check
public struct RateLimitDecision: Codable, Sendable {
  /// Whether request is allowed
  public var allowed: Bool
  
  /// Remaining tokens in current window
  public var remainingTokens: Int
  
  /// If rate limited, how long to wait before retrying (milliseconds)
  public var retryAfterMs: Int
  
  /// The policy that was applied
  public var policy: RateLimitPolicy
  
  public init(allowed: Bool, remainingTokens: Int = 0, retryAfterMs: Int = 0,
              policy: RateLimitPolicy = RateLimitPolicy()) {
    self.allowed = allowed
    self.remainingTokens = remainingTokens
    self.retryAfterMs = retryAfterMs
    self.policy = policy
  }
}

/// Lease granted by coordinator
public struct CoordinatorLease: Codable, Sendable {
  /// Unique lease ID
  public var leaseId: UUID
  
  /// Resource key being locked
  public var key: String
  
  /// Holder of the lease (workerId or other identifier)
  public var holder: String
  
  /// When lease was granted
  public var grantedAt: Date
  
  /// When lease expires
  public var expiresAt: Date
  
  /// Number of refreshes
  public var refreshCount: Int
  
  public init(leaseId: UUID = UUID(), key: String, holder: String,
              grantedAt: Date = Date(), ttlSeconds: Int = 30, refreshCount: Int = 0) {
    self.leaseId = leaseId
    self.key = key
    self.holder = holder
    self.grantedAt = grantedAt
    self.expiresAt = grantedAt.addingTimeInterval(TimeInterval(ttlSeconds))
    self.refreshCount = refreshCount
  }
  
  /// Check if lease is still valid
  public var isValid: Bool {
    Date() < expiresAt
  }
  
  /// Time remaining before expiry
  public var timeRemainingSeconds: Int {
    max(0, Int(expiresAt.timeIntervalSince(Date())))
  }
}

/// Worker presence status
public enum PresenceStatus: String, Codable, Sendable {
  case alive = "alive"        // Heartbeat recent
  case stale = "stale"        // Heartbeat stale (>30s)
  case dead = "dead"          // Heartbeat not found or explicitly exited
  case unknown = "unknown"    // Never seen
}

/// Worker presence record
public struct WorkerPresence: Codable, Sendable {
  /// Worker ID
  public var workerId: WorkerId
  
  /// Current status
  public var status: PresenceStatus
  
  /// Timestamp of last heartbeat
  public var lastHeartbeat: Date
  
  /// When this record was created
  public var registeredAt: Date
  
  public init(workerId: WorkerId, status: PresenceStatus = .alive,
              lastHeartbeat: Date = Date(), registeredAt: Date = Date()) {
    self.workerId = workerId
    self.status = status
    self.lastHeartbeat = lastHeartbeat
    self.registeredAt = registeredAt
  }
  
  /// Check if worker is stale (no heartbeat in 30 seconds)
  public var isStale: Bool {
    Date().timeIntervalSince(lastHeartbeat) > 30
  }
}

/// Receipt for coordination operations
public struct CoordinationReceipt: Codable, Sendable {
  /// Operation type
  public var operation: CoordinationOperation
  
  /// Resource key
  public var key: String
  
  /// Lease ID if applicable
  public var leaseId: UUID?
  
  /// Timestamp of operation
  public var operatedAt: Date
  
  /// Signature for audit trail
  public var signature: String
  
  public init(operation: CoordinationOperation, key: String, leaseId: UUID? = nil,
              operatedAt: Date = Date(), signature: String = "") {
    self.operation = operation
    self.key = key
    self.leaseId = leaseId
    self.operatedAt = operatedAt
    self.signature = signature
  }
}

/// Coordination operation types
public enum CoordinationOperation: String, Codable, Sendable {
  case acquireLease = "acquire_lease"
  case refreshLease = "refresh_lease"
  case releaseLease = "release_lease"
  case checkPresence = "check_presence"
  case heartbeat = "heartbeat"
  case rateLimit = "rate_limit"
}
