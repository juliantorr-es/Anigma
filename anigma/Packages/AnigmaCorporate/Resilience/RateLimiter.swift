import Foundation

public actor RateLimiter {
    private var buckets: [String: TokenBucket] = [:] // Key -> Bucket

    public struct Configuration {
        public let maxRequests: Int
        public let interval: TimeInterval

        public init(maxRequests: Int, interval: TimeInterval) {
            self.maxRequests = maxRequests
            self.interval = interval
        }
    }

    private class TokenBucket {
        let config: Configuration
        var tokens: Double
        var lastRefill: Date

        init(config: Configuration) {
            self.config = config
            self.tokens = Double(config.maxRequests)
            self.lastRefill = Date()
        }

        func consume() -> Bool {
            refill()
            if tokens >= 1.0 {
                tokens -= 1.0
                return true
            }
            return false
        }

        func timeToWait() -> TimeInterval {
            refill()
            if tokens >= 1.0 { return 0 }
            let needed = 1.0 - tokens
            let rate = Double(config.maxRequests) / config.interval
            return needed / rate
        }

        private func refill() {
            let now = Date()
            let elapsed = now.timeIntervalSince(lastRefill)
            let rate = Double(config.maxRequests) / config.interval
            let newTokens = elapsed * rate

            tokens = min(Double(config.maxRequests), tokens + newTokens)
            lastRefill = now
        }
    }

    public init() {}

    public func shouldAllow(key: String, config: Configuration) -> Bool {
        if buckets[key] == nil {
            buckets[key] = TokenBucket(config: config)
        }
        return buckets[key]!.consume()
    }

    public func waitForToken(key: String, config: Configuration) async {
        var waitTime: TimeInterval = 0

        if buckets[key] == nil {
            buckets[key] = TokenBucket(config: config)
        }
        waitTime = buckets[key]!.timeToWait()
        _ = buckets[key]!.consume() // Consume assuming we wait

        if waitTime > 0 {
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
    }
}