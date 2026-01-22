import Foundation
import os.lock

/// Retry manager for the alt-media pipeline with exponential backoff and circuit breaker support
public actor RetryManager {
    private let logger = Logger(subsystem: "Diaplasion.RetryManager", category: "Retry")
    
    // MARK: - Configuration
    
    /// Default retry policy
    public static let defaultPolicy = RetryPolicy(
        maxAttempts: 3,
        baseDelay: .seconds(1),
        maxDelay: .seconds(30),
        multiplier: 2.0,
        jitter: true,
        retryableErrors: [
            .networkError, .processingError, .temporaryError, .rateLimitError
        ]
    )
    
    // MARK: - State
    
    private var circuitBreakers: [String: CircuitBreakerState] = [:]
    private var retryAttempts: [String: Int] = [:]
    private var lock = os_unfair_lock()
    
    // MARK: - Public Interface
    
    /// Execute operation with retry logic
    public func execute<T>(
        operation: String,
        policy: RetryPolicy = defaultPolicy,
        body: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...policy.maxAttempts {
            // Check circuit breaker
            if let circuitBreaker = circuitBreakers[operation] {
                if circuitBreaker.state == .open {
                    if circuitBreaker.shouldAttemptReset() {
                        circuitBreaker.setState(.halfOpen)
                        logger.info("Circuit breaker for \(operation) transitioning to half-open")
                    } else {
                        throw RetryError.circuitBreakerOpen(
                            operation: operation,
                            remainingTime: circuitBreaker.remainingTime()
                        )
                    }
                }
            }
            
            do {
                let result = try await body()
                
                // Record success
                recordSuccess(for: operation)
                return result
                
            } catch {
                lastError = error
                
                logger.warning("Operation \(operation) failed on attempt \(attempt): \(error.localizedDescription)")
                
                // Check if error is retryable
                guard isRetryableError(error, policy: policy) else {
                    recordFailure(for: operation, error: error)
                    throw error
                }
                
                // Check if this is the last attempt
                if attempt == policy.maxAttempts {
                    recordFailure(for: operation, error: error)
                    throw RetryError.maxAttemptsExceeded(
                        operation: operation,
                        attempts: attempt,
                        lastError: error
                    )
                }
                
                // Calculate delay and wait
                let delay = calculateDelay(
                    attempt: attempt,
                    policy: policy,
                    lastError: error
                )
                
                logger.info("Retrying operation \(operation) in \(Int(delay.rounded())) seconds (attempt \(attempt)/\(policy.maxAttempts))")
                try await Task.sleep(for: .seconds(delay))
            }
        }
        
        // This should never be reached
        throw RetryError.unknownError(operation: operation)
    }
    
    /// Reset circuit breaker for operation
    public func resetCircuitBreaker(for operation: String) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if var circuitBreaker = circuitBreakers[operation] {
            circuitBreaker.setState(.closed)
            circuitBreakers[operation] = circuitBreaker
            
            logger.info("Circuit breaker reset for operation: \(operation)")
        }
    }
    
    /// Get circuit breaker state for operation
    public func getCircuitBreakerState(for operation: String) -> CircuitBreakerState? {
        return circuitBreakers[operation]
    }
    
    /// Get retry statistics
    public func getRetryStatistics() -> RetryStatistics {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        return RetryStatistics(
            activeCircuitBreakers: circuitBreakers.values.filter { $0.state != .closed }.count,
            totalOperations: circuitBreakers.count,
            retryAttempts: retryAttempts.values.reduce(0, +)
        )
    }
    
    /// Clear all circuit breakers and retry statistics
    public func reset() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        circuitBreakers.removeAll()
        retryAttempts.removeAll()
        
        logger.info("Retry manager reset")
    }
    
    // MARK: - Private Methods
    
    private func recordSuccess(for operation: String) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        // Update circuit breaker
        var circuitBreaker = circuitBreakers[operation] ?? CircuitBreakerState(operation: operation)
        circuitBreaker.recordSuccess()
        circuitBreakers[operation] = circuitBreaker
        
        // Clear retry attempts
        retryAttempts.removeValue(forKey: operation)
    }
    
    private func recordFailure(for operation: String, error: Error) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        // Update circuit breaker
        var circuitBreaker = circuitBreakers[operation] ?? CircuitBreakerState(operation: operation)
        circuitBreaker.recordFailure()
        circuitBreakers[operation] = circuitBreaker
        
        // Update retry attempts
        retryAttempts[operation, default: 0] += 1
    }
    
    private func isRetryableError(_ error: Error, policy: RetryPolicy) -> Bool {
        // Check against policy's retryable errors
        if let retryError = error as? RetryError {
            return policy.retryableErrors.contains(retryError.category)
        }
        
        // Check for common retryable error types
        if let urlError = error as? URLError {
            return switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .dataNotAllowed, .cannotFindHost, .cannotConnectToHost:
                true
            default:
                false
            }
        }
        
        // Default to true for unknown errors (conservative approach)
        return true
    }
    
    private func calculateDelay(
        attempt: Int,
        policy: RetryPolicy,
        lastError: Error
    ) -> Double {
        // Base exponential backoff
        var delay = Double(policy.baseDelay.components.seconds) * pow(policy.multiplier, Double(attempt - 1))
        
        // Cap at maximum delay
        delay = min(delay, Double(policy.maxDelay.components.seconds))
        
        // Add jitter if enabled
        if policy.jitter {
            let jitterRange = delay * 0.1 // 10% jitter
            let jitterAmount = Double.random(in: -jitterRange...jitterRange)
            delay += jitterAmount
        }
        
        // Adjust for specific error types
        if let urlError = lastError as? URLError {
            switch urlError.code {
            case .timedOut:
                delay *= 1.5 // Longer delay for timeouts
            case .dataNotAllowed:
                delay *= 2.0 // Even longer delay for rate limits
            default:
                break
            }
        }
        
        return max(0, delay) // Ensure non-negative
    }
}

// MARK: - Supporting Types

/// Retry policy configuration
public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let baseDelay: Duration
    public let maxDelay: Duration
    public let multiplier: Double
    public let jitter: Bool
    public let retryableErrors: [RetryError.ErrorCategory]
    
    public init(
        maxAttempts: Int = 3,
        baseDelay: Duration = .seconds(1),
        maxDelay: Duration = .seconds(30),
        multiplier: Double = 2.0,
        jitter: Bool = true,
        retryableErrors: [RetryError.ErrorCategory] = [.networkError, .processingError, .temporaryError]
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.jitter = jitter
        self.retryableErrors = retryableErrors
    }
}

/// Circuit breaker state
public class CircuitBreakerState: @unchecked Sendable {
    public let operation: String
    public private(set) var state: CircuitBreakerStateEnum
    private var failureCount: Int = 0
    private var lastFailureTime: Date?
    private var lastSuccessTime: Date?
    private let stateLock = NSLock()
    
    // Configuration
    private let failureThreshold = 5
    private let timeoutDuration: TimeInterval = 60 // 1 minute
    private let halfOpenMaxCalls = 3
    private var halfOpenCallCount = 0
    
    public init(operation: String) {
        self.operation = operation
        self.state = .closed
    }
    
    public func recordSuccess() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        failureCount = 0
        lastSuccessTime = Date()
        halfOpenCallCount = 0
        
        if state == .halfOpen {
            state = .closed
        }
    }
    
    public func recordFailure() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        failureCount += 1
        lastFailureTime = Date()
        
        switch state {
        case .closed:
            if failureCount >= failureThreshold {
                state = .open
            }
        case .halfOpen:
            state = .open
            halfOpenCallCount = 0
        case .open:
            // Already open, just update failure time
            break
        }
    }
    
    public func setState(_ newState: CircuitBreakerStateEnum) {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        state = newState
        if newState == .halfOpen {
            halfOpenCallCount = 0
        }
    }
    
    public func shouldAttemptReset() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        guard state == .open,
              let lastFailure = lastFailureTime else {
            return false
        }
        
        return Date().timeIntervalSince(lastFailure) >= timeoutDuration
    }
    
    public func remainingTime() -> TimeInterval {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        guard state == .open,
              let lastFailure = lastFailureTime else {
            return 0
        }
        
        return max(0, timeoutDuration - Date().timeIntervalSince(lastFailure))
    }
    
    public var statistics: CircuitBreakerStatistics {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        return CircuitBreakerStatistics(
            operation: operation,
            state: state,
            failureCount: failureCount,
            lastFailureTime: lastFailureTime,
            lastSuccessTime: lastSuccessTime
        )
    }
}

/// Circuit breaker states
public enum CircuitBreakerStateEnum: String, CaseIterable, Sendable {
    case closed = "closed"
    case open = "open"
    case halfOpen = "half_open"
}

/// Retry errors
public enum RetryError: LocalizedError, Sendable {
    case maxAttemptsExceeded(operation: String, attempts: Int, lastError: Error)
    case circuitBreakerOpen(operation: String, remainingTime: TimeInterval)
    case unknownError(operation: String)
    
    public var errorDescription: String? {
        switch self {
        case .maxAttemptsExceeded(let operation, let attempts, let lastError):
            return "Operation '\(operation)' failed after \(attempts) attempts. Last error: \(lastError.localizedDescription)"
        case .circuitBreakerOpen(let operation, let remainingTime):
            return "Circuit breaker open for operation '\(operation)'. Retry in \(Int(remainingTime)) seconds"
        case .unknownError(let operation):
            return "Unknown error occurred during operation '\(operation)'"
        }
    }
    
    public var category: ErrorCategory {
        switch self {
        case .maxAttemptsExceeded, .circuitBreakerOpen:
            return .retryExhausted
        case .unknownError:
            return .unknownError
        }
    }
    
    public enum ErrorCategory: CaseIterable, Sendable {
        case networkError
        case processingError
        case temporaryError
        case rateLimitError
        case retryExhausted
        case unknownError
    }
}

/// Retry statistics
public struct RetryStatistics: Sendable {
    public let activeCircuitBreakers: Int
    public let totalOperations: Int
    public let retryAttempts: Int
}

/// Circuit breaker statistics
public struct CircuitBreakerStatistics: Sendable {
    public let operation: String
    public let state: CircuitBreakerStateEnum
    public let failureCount: Int
    public let lastFailureTime: Date?
    public let lastSuccessTime: Date?
}