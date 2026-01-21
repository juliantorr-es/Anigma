//
//  RateLimiter.swift
//  AnigmaDaemonCore
//
//  Token bucket rate limiter for API requests.
//

import Foundation

public actor RateLimiter {
    private struct TokenBucket {
        var tokens: Double
        var lastRefill: Date
    }

    private var buckets: [String: TokenBucket] = [:]
    private let capacity: Double
    private let refillRate: Double // Tokens per second

    /// Initialize the rate limiter
    /// - Parameters:
    ///   - capacity: Maximum burst capacity (default: 100)
    ///   - refillRate: Tokens refilled per second (default: 10.0)
    public init(capacity: Int = 100, refillRate: Double = 10.0) {
        self.capacity = Double(capacity)
        self.refillRate = refillRate
    }

    /// Check if a request should be allowed for the given client ID
    /// - Parameter clientId: The client identifier
    /// - Returns: True if allowed, false if rate limited
    public func allow(clientId: String) -> Bool {
        let now = Date()
        var bucket = buckets[clientId] ?? TokenBucket(tokens: capacity, lastRefill: now)

        // Refill tokens
        let elapsed = now.timeIntervalSince(bucket.lastRefill)
        let newTokens = elapsed * refillRate
        bucket.tokens = min(capacity, bucket.tokens + newTokens)
        bucket.lastRefill = now

        // Consume token
        if bucket.tokens >= 1.0 {
            bucket.tokens -= 1.0
            buckets[clientId] = bucket
            return true
        } else {
            // Update state even if denied (to update lastRefill)
            buckets[clientId] = bucket
            return false
        }
    }

    /// Cleanup old buckets to prevent memory leak
    public func cleanup(olderThan: TimeInterval = 3600) {
        let now = Date()
        buckets = buckets.filter { _, bucket in
            now.timeIntervalSince(bucket.lastRefill) < olderThan
        }
    }
}
