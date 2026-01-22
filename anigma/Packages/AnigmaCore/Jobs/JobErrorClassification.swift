//
//  JobErrorClassification.swift
//  AnigmaCore
//
//  Comprehensive error classification and recovery patterns for job scheduling.
//

import Foundation

/// Classification of job errors for intelligent retry and recovery decisions.
public enum JobErrorClassification: String, Codable, Sendable, CaseIterable {
    /// Transient network or connectivity issues.
    case networkTransient
    
    /// Persistent network configuration or authentication issues.
    case networkPermanent
    
    /// Temporary resource exhaustion (memory, CPU, disk).
    case resourceTransient
    
    /// Insufficient quota or permissions (persistent).
    case resourcePermanent
    
    /// Temporary system overload or throttling.
    case systemOverload
    
    /// Invalid input data or parameters (user error).
    case invalidInput
    
    /// Missing dependencies or configuration.
    case missingDependencies
    
    /// External service unavailable (temporary).
    case serviceUnavailable
    
    /// External service deprecated or permanently unavailable.
    case serviceDecommissioned
    
    /// Security or authorization issues.
    case securityViolation
    
    /// System bugs or unexpected conditions.
    case systemBug
    
    /// Job execution timeout.
    case timeout
    
    /// Unknown or unclassified error.
    case unknown
    
    /// Whether this error type is typically retryable.
    public var isRetryable: Bool {
        switch self {
        case .networkTransient, .resourceTransient, .systemOverload, 
             .serviceUnavailable, .systemBug, .timeout:
            return true
        case .networkPermanent, .resourcePermanent, .invalidInput,
             .missingDependencies, .serviceDecommissioned, .securityViolation:
            return false
        case .unknown:
            return true // Default to retryable for safety
        }
    }
    
    /// Suggested backoff multiplier for retries.
    public var backoffMultiplier: Double {
        switch self {
        case .networkTransient, .resourceTransient:
            return 1.5
        case .systemOverload, .serviceUnavailable:
            return 2.0
        case .systemBug, .timeout:
            return 1.2
        case .unknown:
            return 1.5
        default:
            return 0 // Not retryable
        }
    }
    
    /// Maximum recommended retry attempts.
    public var maxRetries: Int {
        switch self {
        case .networkTransient:
            return 5
        case .resourceTransient, .systemOverload:
            return 3
        case .serviceUnavailable:
            return 4
        case .systemBug, .timeout:
            return 2
        case .unknown:
            return 3
        default:
            return 0 // Not retryable
        }
    }
    
    /// Whether this error should trigger circuit breaker.
    public var shouldTriggerCircuitBreaker: Bool {
        switch self {
        case .serviceUnavailable, .systemOverload:
            return true
        default:
            return false
        }
    }
}

/// Pattern-based error classifier.
public actor JobErrorClassifier {
    private var classificationRules: [ErrorPattern: JobErrorClassification] = [:]
    
    public init() {
        setupDefaultRules()
    }
    
    /// Classify an error based on patterns and rules.
    public func classify(_ error: Error) -> JobErrorClassification {
        let errorMessage = error.localizedDescription.lowercased()
        
        // Check specific patterns first
        for (pattern, classification) in classificationRules {
            if pattern.matches(error: error, message: errorMessage) {
                return classification
            }
        }
        
        // Default classification based on error type
        return classifyByErrorType(error)
    }
    
    /// Add a custom classification rule.
    public func addRule(pattern: ErrorPattern, classification: JobErrorClassification) {
        classificationRules[pattern] = classification
    }
    
    private func setupDefaultRules() {
        // Network errors
        classificationRules[.contains("connection lost")] = .networkTransient
        classificationRules[.contains("timeout")] = .networkTransient
        classificationRules[.contains("connection refused")] = .networkPermanent
        classificationRules[.contains("dns resolution failed")] = .networkPermanent
        classificationRules[.contains("ssl/tls")] = .networkPermanent
        classificationRules[.contains("authentication failed")] = .securityViolation
        classificationRules[.contains("unauthorized")] = .securityViolation
        
        // Resource errors
        classificationRules[.contains("out of memory")] = .resourceTransient
        classificationRules[.contains("disk full")] = .resourcePermanent
        classificationRules[.contains("quota exceeded")] = .resourcePermanent
        classificationRules[.contains("rate limit")] = .systemOverload
        classificationRules[.contains("throttled")] = .systemOverload
        
        // System errors
        classificationRules[.contains("service unavailable")] = .serviceUnavailable
        classificationRules[.contains("maintenance mode")] = .serviceUnavailable
        classificationRules[.contains("deprecated")] = .serviceDecommissioned
        classificationRules[.contains("not found")] = .missingDependencies
        
        // Input errors
        classificationRules[.contains("invalid")] = .invalidInput
        classificationRules[.contains("malformed")] = .invalidInput
        classificationRules[.contains("required field")] = .invalidInput
        
        // Specific Anigma errors
        classificationRules[.contains("executiontimeout")] = .timeout
        classificationRules[.contains("job not found")] = .missingDependencies
        classificationRules[.contains("invalid state")] = .systemBug
    }
    
    private func classifyByErrorType(_ error: Error) -> JobErrorClassification {
        switch error {
        case is JobError.executionTimeout:
            return .timeout
        case is JobError.jobNotFound:
            return .missingDependencies
        case is JobError.invalidState:
            return .systemBug
        case is JobError.queueFull:
            return .systemOverload
        case is WorkflowError.executionTimeout:
            return .timeout
        case is WorkflowError.noWorkflowFound:
            return .missingDependencies
        case is WorkflowError.systemNotFound:
            return .missingDependencies
        case is URLError:
            return classifyURLError(error as! URLError)
        default:
            return .unknown
        }
    }
    
    private func classifyURLError(_ error: URLError) -> JobErrorClassification {
        switch error.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet:
            return .networkTransient
        case .cannotConnectToServer, .dnsLookupFailed:
            return .networkPermanent
        case .badServerResponse, .serverCertificateUntrusted:
            return .securityViolation
        default:
            return .networkTransient
        }
    }
}

/// Pattern for matching errors.
public struct ErrorPattern: Hashable, Codable, Sendable {
    public enum PatternType: String, Codable, Sendable {
        case contains
        case startsWith
        case endsWith
        case regex
        case exact
    }
    
    public let type: PatternType
    public let pattern: String
    
    public init(_ type: PatternType, pattern: String) {
        self.type = type
        self.pattern = pattern
    }
    
    public func matches(error: Error, message: String) -> Bool {
        switch type {
        case .contains:
            return message.contains(pattern)
        case .startsWith:
            return message.hasPrefix(pattern)
        case .endsWith:
            return message.hasSuffix(pattern)
        case .exact:
            return message == pattern
        case .regex:
            return message.range(of: pattern, options: .regularExpression) != nil
        }
    }
}

extension ErrorPattern {
    public static func contains(_ pattern: String) -> ErrorPattern {
        return ErrorPattern(.contains, pattern: pattern)
    }
    
    public static func startsWith(_ pattern: String) -> ErrorPattern {
        return ErrorPattern(.startsWith, pattern: pattern)
    }
    
    public static func endsWith(_ pattern: String) -> ErrorPattern {
        return ErrorPattern(.endsWith, pattern: pattern)
    }
    
    public static func exact(_ pattern: String) -> ErrorPattern {
        return ErrorPattern(.exact, pattern: pattern)
    }
    
    public static func regex(_ pattern: String) -> ErrorPattern {
        return ErrorPattern(.regex, pattern: pattern)
    }
}

/// Recovery strategy for classified errors.
public struct RecoveryStrategy: Sendable {
    public let classification: JobErrorClassification
    public let action: RecoveryAction
    public let delay: TimeInterval
    public let maxAttempts: Int
    
    public init(
        classification: JobErrorClassification,
        action: RecoveryAction = .retry,
        delay: TimeInterval = 30,
        maxAttempts: Int? = nil
    ) {
        self.classification = classification
        self.action = action
        self.delay = delay
        self.maxAttempts = maxAttempts ?? classification.maxRetries
    }
    
    /// Get recovery strategy for a classified error.
    public static func forClassification(_ classification: JobErrorClassification) -> RecoveryStrategy {
        switch classification {
        case .networkTransient:
            return RecoveryStrategy(classification: classification, action: .retry, delay: 10, maxAttempts: 5)
        case .networkPermanent:
            return RecoveryStrategy(classification: classification, action: .escalate, delay: 0, maxAttempts: 0)
        case .resourceTransient:
            return RecoveryStrategy(classification: classification, action: .retry, delay: 60, maxAttempts: 3)
        case .resourcePermanent:
            return RecoveryStrategy(classification: classification, action: .escalate, delay: 0, maxAttempts: 0)
        case .systemOverload:
            return RecoveryStrategy(classification: classification, action: .backoff, delay: 120, maxAttempts: 3)
        case .invalidInput:
            return RecoveryStrategy(classification: classification, action: .fail, delay: 0, maxAttempts: 0)
        case .missingDependencies:
            return RecoveryStrategy(classification: classification, action: .escalate, delay: 0, maxAttempts: 1)
        case .serviceUnavailable:
            return RecoveryStrategy(classification: classification, action: .backoff, delay: 300, maxAttempts: 4)
        case .serviceDecommissioned:
            return RecoveryStrategy(classification: classification, action: .escalate, delay: 0, maxAttempts: 0)
        case .securityViolation:
            return RecoveryStrategy(classification: classification, action: .escalate, delay: 0, maxAttempts: 0)
        case .systemBug:
            return RecoveryStrategy(classification: classification, action: .retry, delay: 30, maxAttempts: 2)
        case .timeout:
            return RecoveryStrategy(classification: classification, action: .retry, delay: 15, maxAttempts: 2)
        case .unknown:
            return RecoveryStrategy(classification: classification, action: .retry, delay: 30, maxAttempts: 3)
        }
    }
}

/// Recovery actions for classified errors.
public enum RecoveryAction: String, Codable, Sendable, CaseIterable {
    case retry
    case backoff
    case escalate
    case fail
    case manualIntervention
}

/// Enhanced retry policy that considers error classification.
public struct IntelligentRetryPolicy: Codable, Sendable {
    public let basePolicy: RetryPolicy
    public let classificationStrategies: [JobErrorClassification: RecoveryStrategy]
    
    public init(
        basePolicy: RetryPolicy = .default,
        customStrategies: [JobErrorClassification: RecoveryStrategy] = [:]
    ) {
        self.basePolicy = basePolicy
        self.classificationStrategies = Self.defaultStrategies.merging(customStrategies) { _, new in new }
    }
    
    private static let defaultStrategies: [JobErrorClassification: RecoveryStrategy] = {
        Dictionary(uniqueKeysWithValues: 
            JobErrorClassification.allCases.map { classification in
                (classification, RecoveryStrategy.forClassification(classification))
            }
        )
    }()
    
    /// Get recovery strategy for an error.
    public func getStrategy(for error: Error, classifier: JobErrorClassifier) async -> RecoveryStrategy {
        let classification = await classifier.classify(error)
        return classificationStrategies[classification] ?? RecoveryStrategy.forClassification(classification)
    }
    
    /// Calculate retry delay based on error classification and attempt number.
    public func calculateDelay(
        for error: Error,
        attempt: Int,
        classifier: JobErrorClassifier
    ) async -> TimeInterval {
        let strategy = await getStrategy(for: error, classifier: classifier)
        
        switch strategy.action {
        case .retry, .backoff:
            let baseDelay = strategy.delay
            let multiplier = strategy.classification.backoffMultiplier
            return baseDelay * pow(multiplier, Double(attempt))
        case .escalate, .fail, .manualIntervention:
            return 0 // No retry
        }
    }
    
    /// Determine if error should be retried.
    public func shouldRetry(
        for error: Error,
        attempt: Int,
        classifier: JobErrorClassifier
    ) async -> Bool {
        let strategy = await getStrategy(for: error, classifier: classifier)
        
        guard strategy.action != .fail && strategy.action != .escalate else {
            return false
        }
        
        return attempt < strategy.maxAttempts
    }
}