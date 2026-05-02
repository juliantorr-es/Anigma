import HarmoniaWorkflowContracts

import ContractsCore

//
//  MigrationCircuitBreaker.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
@preconcurrency import Foundation

/// Circuit breaker for migration verification failures and rollbacks.
/// Implements the circuit breaker pattern to stop pathological loops:
/// - After N failures in a window, fail fast
/// - Require cooldown or operator intervention
/// - Avoid cascading failures
public actor MigrationCircuitBreaker {
    private let maxFailures: Int
    private let failureWindow: TimeInterval
    private let cooldownDuration: TimeInterval

    private var failureTimestamps: [Date] = []
    private var isOpen: Bool = false
    private var openedAt: Date?

    /// Initialize a circuit breaker.
    /// - Parameters:
    ///   - maxFailures: Maximum number of failures allowed in the window (default: 3)
    ///   - failureWindow: Time window for counting failures in seconds (default: 60)
    ///   - cooldownDuration: Cooldown duration after circuit opens in seconds (default: 300)
    public init(maxFailures: Int = 3, failureWindow: TimeInterval = 60, cooldownDuration: TimeInterval = 300) {
        self.maxFailures = maxFailures
        self.failureWindow = failureWindow
        self.cooldownDuration = cooldownDuration
    }

    /// Record a verification failure or rollback.
    /// - Returns: true if operation should proceed, false if circuit is open
    public func recordFailure() -> Bool {
        cleanupOldFailures()

        let now = Date()
        failureTimestamps.append(now)

        // Check if we should open the circuit
        if !isOpen && failureTimestamps.count >= maxFailures {
            isOpen = true
            openedAt = now
            return false
        }

        // Check if circuit is open but cooldown has expired
        if isOpen, let openedAt = openedAt {
            let timeSinceOpen = now.timeIntervalSince(openedAt)
            if timeSinceOpen >= cooldownDuration {
                // Cooldown expired, reset circuit
                reset()
                return true
            }
            return false
        }

        return true
    }

    /// Record a successful operation (helps with half-open state).
    public func recordSuccess() {
        if isOpen {
            // If circuit is open and we get a success (e.g., from manual intervention),
            // we can consider resetting
            reset()
        } else {
            // Clean up old failures but don't add to successes
            cleanupOldFailures()
        }
    }

    /// Manually reset the circuit breaker.
    public func reset() {
        failureTimestamps.removeAll()
        isOpen = false
        openedAt = nil
    }

    /// Get current circuit breaker state.
    public func getState() -> CircuitBreakerState {
        cleanupOldFailures()

        if isOpen, let openedAt = openedAt {
            let timeSinceOpen = Date().timeIntervalSince(openedAt)
            let remainingCooldown = max(0, cooldownDuration - timeSinceOpen)
            return .open(remainingCooldown: remainingCooldown, failureCount: failureTimestamps.count)
        } else {
            return .closed(failureCount: failureTimestamps.count, maxFailures: maxFailures)
        }
    }

    /// Clean up failures outside the window.
    private func cleanupOldFailures() {
        let cutoff = Date().addingTimeInterval(-failureWindow)
        failureTimestamps = failureTimestamps.filter { $0 > cutoff }
    }
}

/// Circuit breaker state.
public enum CircuitBreakerState {
    /// Circuit is closed (normal operation).
    case closed(failureCount: Int, maxFailures: Int)

    /// Circuit is open (failing fast).
    case open(remainingCooldown: TimeInterval, failureCount: Int)

    /// Whether operations should proceed.
    public var shouldProceed: Bool {
        switch self {
        case .closed:
            return true
        case .open:
            return false
        }
    }

    /// Description for logging.
    public var description: String {
        switch self {
        case .closed(let failureCount, let maxFailures):
            return "Circuit closed (\(failureCount)/\(maxFailures) failures in window)"
        case .open(let remainingCooldown, let failureCount):
            return "Circuit open (\(failureCount) failures, \(Int(remainingCooldown))s cooldown remaining)"
        }
    }
}
