//
//  CircuitBreaker.swift
//  AnigmaAppMac
//
//  Circuit breaker pattern for resilient backend communication
//

import Foundation

/// Circuit breaker state machine for preventing cascade failures
public actor CircuitBreaker {
    public enum State: Equatable {
        case closed       // Normal operation
        case open         // Failing, rejecting requests
        case halfOpen     // Testing if service recovered
    }

    public enum CircuitBreakerError: LocalizedError {
        case circuitOpen(serviceName: String, failureCount: Int, nextRetryAt: Date)

        public var errorDescription: String? {
            switch self {
            case .circuitOpen(let service, let failures, let retryAt):
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Circuit breaker open for '\(service)' after \(failures) failures. Will retry at \(formatter.string(from: retryAt))."
            }
        }
    }

    // Configuration
    private let serviceName: String
    private let failureThreshold: Int
    private let successThreshold: Int
    private let timeout: TimeInterval

    // State
    private var state: State = .closed
    private var failureCount: Int = 0
    private var successCount: Int = 0
    private var lastFailureTime: Date?
    private var nextRetryTime: Date?

    /// Initialize circuit breaker with configuration
    /// - Parameters:
    ///   - serviceName: Name of the service being protected
    ///   - failureThreshold: Number of consecutive failures before opening circuit (default: 5)
    ///   - successThreshold: Number of successes in half-open state before closing (default: 2)
    ///   - timeout: Time to wait before transitioning from open to half-open (default: 30s)
    public init(
        serviceName: String,
        failureThreshold: Int = 5,
        successThreshold: Int = 2,
        timeout: TimeInterval = 30.0
    ) {
        self.serviceName = serviceName
        self.failureThreshold = failureThreshold
        self.successThreshold = successThreshold
        self.timeout = timeout
    }

    /// Execute an operation through the circuit breaker
    public func execute<T>(_ operation: @Sendable () async throws -> T) async throws -> T {
        // Check if circuit is open
        if state == .open {
            // Check if we should transition to half-open
            if let nextRetry = nextRetryTime, Date() >= nextRetry {
                print("🔄 [CircuitBreaker:\(serviceName)] Transitioning to half-open, testing recovery...")
                state = .halfOpen
                successCount = 0
            } else {
                // Circuit is still open, reject request
                throw CircuitBreakerError.circuitOpen(
                    serviceName: serviceName,
                    failureCount: failureCount,
                    nextRetryAt: nextRetryTime ?? Date().addingTimeInterval(timeout)
                )
            }
        }

        do {
            // Execute the operation
            let result = try await operation()

            // Record success
            await recordSuccess()

            return result
        } catch {
            // Record failure
            await recordFailure()

            throw error
        }
    }

    /// Get current state for monitoring
    public func getState() -> (state: State, failures: Int, successes: Int) {
        return (state, failureCount, successCount)
    }

    /// Manually reset the circuit breaker (for testing or manual intervention)
    public func reset() {
        print("🔧 [CircuitBreaker:\(serviceName)] Manual reset")
        state = .closed
        failureCount = 0
        successCount = 0
        lastFailureTime = nil
        nextRetryTime = nil
    }

    // MARK: - Private Helpers

    private func recordSuccess() {
        switch state {
        case .closed:
            // Normal operation, reset failure count on success
            failureCount = 0

        case .halfOpen:
            // In half-open state, count successes
            successCount += 1
            print("✅ [CircuitBreaker:\(serviceName)] Success in half-open (\(successCount)/\(successThreshold))")

            if successCount >= successThreshold {
                // Enough successes, close the circuit
                print("✅ [CircuitBreaker:\(serviceName)] Closing circuit after \(successCount) successes")
                state = .closed
                failureCount = 0
                successCount = 0
                lastFailureTime = nil
                nextRetryTime = nil
            }

        case .open:
            // Shouldn't happen, but handle gracefully
            print("⚠️ [CircuitBreaker:\(serviceName)] Unexpected success in open state")
        }
    }

    private func recordFailure() {
        lastFailureTime = Date()

        switch state {
        case .closed:
            failureCount += 1
            print("❌ [CircuitBreaker:\(serviceName)] Failure \(failureCount)/\(failureThreshold)")

            if failureCount >= failureThreshold {
                // Too many failures, open the circuit
                openCircuit()
            }

        case .halfOpen:
            // Failed while testing recovery, reopen circuit
            print("❌ [CircuitBreaker:\(serviceName)] Failed in half-open, reopening circuit")
            failureCount += 1
            successCount = 0
            openCircuit()

        case .open:
            // Already open, just increment count
            failureCount += 1
        }
    }

    private func openCircuit() {
        state = .open
        nextRetryTime = Date().addingTimeInterval(timeout)

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        print("🔴 [CircuitBreaker:\(serviceName)] Circuit OPEN after \(failureCount) failures. Will retry at \(formatter.string(from: nextRetryTime!))")
    }
}
