import Foundation

/// Represents the throttle state and recommendations for a client
public struct ThrottleHint: Sendable, Codable {
    /// Current load zone
    public let loadZone: LoadZone

    /// Recommended backoff time in seconds
    public let recommendedBackoffMs: Int

    /// Whether the client should retry this request
    public let shouldRetry: Bool

    /// Load percentage (0.0 to 1.0)
    public let loadPercentage: Double

    public init(loadPercentage: Double) {
        self.loadZone = LoadZone(percentage: loadPercentage)
        self.loadPercentage = loadPercentage

        // Calculate throttle parameters based on load zone
        switch loadZone {
        case .green:
            self.recommendedBackoffMs = 0
            self.shouldRetry = false

        case .yellow:
            self.recommendedBackoffMs = Int.random(in: 10...50)
            self.shouldRetry = false

        case .red:
            self.recommendedBackoffMs = Int.random(in: 50...500)
            self.shouldRetry = true

        case .black:
            self.recommendedBackoffMs = Int.random(in: 500...2000)
            self.shouldRetry = true
        }
    }

    /// Returns HTTP retry-after header value
    public var retryAfterSeconds: Int {
        (recommendedBackoffMs + 999) / 1000  // Round up to nearest second
    }
}

/// Determines whether a request should be accepted based on load
public struct AdaptiveThrottleDecision: Sendable {
    public let accept: Bool
    public let throttleHint: ThrottleHint
    public let reason: String?

    init(accept: Bool, throttleHint: ThrottleHint, reason: String? = nil) {
        self.accept = accept
        self.throttleHint = throttleHint
        self.reason = reason
    }
}

/// Adaptive throttling engine that adjusts rate limiting based on system load
public actor AdaptiveThrottle {
    private let yellowZoneThreshold: Double = 0.70
    private let redZoneThreshold: Double = 0.85
    private let blackZoneThreshold: Double = 0.95

    public init() {}

    /// Evaluates whether to accept a request based on current load
    public func evaluateRequest(
        priority: RequestPriority,
        queueLoad: Double
    ) -> AdaptiveThrottleDecision {
        let throttleHint = ThrottleHint(loadPercentage: queueLoad)

        switch throttleHint.loadZone {
        case .green:
            // All requests accepted
            return AdaptiveThrottleDecision(accept: true, throttleHint: throttleHint)

        case .yellow:
            // All requests accepted but warn
            return AdaptiveThrottleDecision(
                accept: true,
                throttleHint: throttleHint,
                reason: "System at \(Int(queueLoad * 100))% capacity; performance may degrade"
            )

        case .red:
            // Accept high and critical, reject normal and low
            let accept = priority == .critical || priority == .high
            return AdaptiveThrottleDecision(
                accept: accept,
                throttleHint: throttleHint,
                reason: accept ? nil : "System overloaded; low-priority requests rejected"
            )

        case .black:
            // Accept only critical
            let accept = priority == .critical
            return AdaptiveThrottleDecision(
                accept: accept,
                throttleHint: throttleHint,
                reason: accept ? nil : "System severely overloaded; only health checks accepted"
            )
        }
    }

    /// Gets the load percentage recommendation thresholds
    public func getThresholds() -> (yellow: Double, red: Double, black: Double) {
        (yellowZoneThreshold, redZoneThreshold, blackZoneThreshold)
    }
}
