//
//  AuthConductor.swift
//  AnigmaCore
//
//  Manages multiple provider accounts, load balancing, and credential lifecycle.
//  Inspired by CLIProxyAPI.
//

import Foundation

public struct InferenceAccount: Codable, Sendable, Identifiable {
    public let id: String
    public let provider: String
    public let format: InferenceFormat
    public var apiKey: String?
    public var baseURL: String?
    public var weight: Int = 1
    public var isEnabled: Bool = true
    public var metadata: [String: String] = [:]
}

/// Strategy for selecting the next available account.
public protocol AccountSelector: Sendable {
    mutating func select(from accounts: [InferenceAccount]) -> InferenceAccount?
}

public struct RoundRobinSelector: AccountSelector, Sendable {
    private var lastIndex: Int = -1

    public init() {}

    public mutating func select(from accounts: [InferenceAccount]) -> InferenceAccount? {
        let enabled = accounts.filter { $0.isEnabled }
        guard !enabled.isEmpty else { return nil }

        lastIndex = (lastIndex + 1) % enabled.count
        return enabled[lastIndex]
    }
}

/// Selector that respects account weights for load balancing.
public struct WeightedSelector: AccountSelector, Sendable {
    public init() {}

    public func select(from accounts: [InferenceAccount]) -> InferenceAccount? {
        let enabled = accounts.filter { $0.isEnabled }
        let totalWeight = enabled.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return enabled.first }

        let random = Int.random(in: 0..<totalWeight)
        var currentSum = 0
        for account in enabled {
            currentSum += account.weight
            if random < currentSum {
                return account
            }
        }
        return enabled.last
    }
}

/// Conductor for managing inference credentials and routing.
public actor AuthConductor {
    private var accounts: [String: InferenceAccount] = [:]
    private var selector: any AccountSelector
    private var healthStatus: [String: AccountHealth] = [:]

    public init(selector: any AccountSelector = RoundRobinSelector()) {
        self.selector = selector
    }

    private struct AccountHealth {
        var lastError: Error?
        var errorCount: Int = 0
        var lastSuccess: Date?
        var rateLimiter = TokenBucketRateLimiter(capacity: 100, refillRate: 10)
    }

    /// Rate limiter using the token bucket algorithm.
    public struct TokenBucketRateLimiter: Sendable {
        let capacity: Double
        let refillRate: Double // tokens per second
        var tokens: Double
        var lastRefill: Date

        init(capacity: Double, refillRate: Double) {
            self.capacity = capacity
            self.refillRate = refillRate
            self.tokens = capacity
            self.lastRefill = Date()
        }

        mutating func consume(amount: Double = 1.0) -> Bool {
            refill()
            if tokens >= amount {
                tokens -= amount
                return true
            }
            return false
        }

        private mutating func refill() {
            let now = Date()
            let delta = now.timeIntervalSince(lastRefill)
            tokens = min(capacity, tokens + delta * refillRate)
            lastRefill = now
        }
    }

    public func pickAccount(for provider: String) throws -> InferenceAccount {
        let candidates = accounts.values.filter { account in
            var status = healthStatus[account.id] ?? AccountHealth()
            let isHealthly = status.errorCount < 5
            let isNotRateLimited = status.rateLimiter.consume(amount: 1.0)

            // Update health status with potentially mutated rate limiter
            healthStatus[account.id] = status

            return account.provider == provider && account.isEnabled && isHealthly && isNotRateLimited
        }

        guard let account = selector.select(from: Array(candidates)) else {
            throw AuthError.noAvailableAccounts(provider: provider)
        }
        return account
    }

    public func reportSuccess(accountId: String) {
        healthStatus[accountId] = AccountHealth(lastError: nil, errorCount: 0, lastSuccess: Date())
    }

    public func reportError(accountId: String, error: Error) {
        var status = healthStatus[accountId] ?? AccountHealth()
        status.lastError = error
        status.errorCount += 1
        healthStatus[accountId] = status
    }
}

public enum AuthError: Error, LocalizedError {
    case noAvailableAccounts(provider: String)

    public var errorDescription: String? {
        switch self {
        case .noAvailableAccounts(let provider):
            return "No enabled accounts found for provider: \(provider)"
        }
    }
}
