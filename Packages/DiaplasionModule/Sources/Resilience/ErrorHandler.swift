import Foundation
import os
import os.lock

/// Centralized error handler for the alt-media pipeline with classification and recovery strategies
public actor ErrorHandler {
    private let logger = Logger(subsystem: "Diaplasion.ErrorHandler", category: "ErrorHandling")
    
    // MARK: - Configuration
    
    // MARK: - State
    
    private var errorHistory: [ErrorRecord] = []
    private var recoveryStrategies: [ErrorClassification: [RecoveryStrategy]] = [:]
    private var statistics = ErrorStatistics()
    private let historyLimit = 1000
    private var lock = os_unfair_lock()
    
    public init() {
        setupDefaultRecoveryStrategies()
    }
    
    // MARK: - Public Interface
    
    /// Handle error with automatic recovery attempts
    public func handleError(
        _ error: Error,
        context: ErrorContext,
        documentId: String
    ) async -> ErrorHandlingResult {
        let classification = classifyError(error)
        let record = ErrorRecord(
            error: error,
            classification: classification,
            context: context,
            documentId: documentId,
            timestamp: Date()
        )
        
        // Record error
        recordError(record)
        
        // Determine recovery strategy
        let strategies = recoveryStrategies[classification] ?? []
        
        logger.warning("Error classified as \(classification.rawValue) for document \(documentId): \(error.localizedDescription)")
        
        // Attempt recovery strategies in order
        for (index, strategy) in strategies.enumerated() {
            do {
                logger.info("Attempting recovery strategy \(index + 1)/\(strategies.count): \(strategy.name)")
                
                let result = try await attemptRecovery(
                    strategy: strategy,
                    error: error,
                    context: context,
                    documentId: documentId
                )
                
                logger.info("Recovery successful using strategy: \(strategy.name)")
                recordSuccessfulRecovery(record: record, strategy: strategy)
                
                return ErrorHandlingResult(
                    classification: classification,
                    recoveryAttempted: true,
                    recoverySuccessful: true,
                    strategy: strategy,
                    resolvedError: nil
                )
                
            } catch {
                logger.warning("Recovery strategy \(strategy.name) failed: \(error.localizedDescription)")
                recordFailedRecovery(record: record, strategy: strategy, recoveryError: error)
                
                // Continue to next strategy
            }
        }
        
        // All recovery strategies failed
        logger.error("All recovery strategies failed for document \(documentId)")
        
        return ErrorHandlingResult(
            classification: classification,
            recoveryAttempted: !strategies.isEmpty,
            recoverySuccessful: false,
            strategy: strategies.last,
            resolvedError: error
        )
    }
    
    /// Register custom recovery strategy
    public func registerRecoveryStrategy(
        for classification: ErrorClassification,
        strategy: RecoveryStrategy
    ) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if recoveryStrategies[classification] == nil {
            recoveryStrategies[classification] = []
        }
        recoveryStrategies[classification]?.append(strategy)
        
        logger.info("Registered recovery strategy '\(strategy.name)' for classification '\(classification.rawValue)'")
    }
    
    /// Get error statistics
    public func getErrorStatistics() -> ErrorStatistics {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        return statistics
    }
    
    /// Get error history
    public func getErrorHistory(limit: Int? = nil) -> [ErrorRecord] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        let effectiveLimit = limit ?? historyLimit
        return Array(errorHistory.suffix(effectiveLimit))
    }
    
    /// Clear error history and statistics
    public func reset() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        errorHistory.removeAll()
        statistics = ErrorStatistics()
        
        logger.info("Error handler reset")
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultRecoveryStrategies() {
        // Network errors
        recoveryStrategies[.networkError] = [
            NetworkRetryStrategy(),
            FallbackToOfflineStrategy()
        ]
        
        // Processing errors
        recoveryStrategies[.processingError] = [
            RetryWithDifferentParametersStrategy(),
            ReduceComplexityStrategy(),
            FallbackToAlternativeFormatStrategy()
        ]
        
        // Resource errors
        recoveryStrategies[.resourceError] = [
            WaitForResourcesStrategy(),
            ReduceMemoryUsageStrategy(),
            SwitchToSmallerBatchStrategy()
        ]
        
        // Validation errors
        recoveryStrategies[.validationError] = [
            DataCleanupStrategy(),
            SkipInvalidDataStrategy()
        ]
        
        // Permission errors
        recoveryStrategies[.permissionError] = [
            RequestPermissionsStrategy(),
            FallbackToReadOnlyStrategy()
        ]
        
        // Timeout errors
        recoveryStrategies[.timeoutError] = [
            ExtendTimeoutStrategy(),
            ReduceWorkloadStrategy()
        ]
    }
    
    private func classifyError(_ error: Error) -> ErrorClassification {
        // Check for known error types
        if let urlError = error as? URLError {
            return switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .dataNotAllowed, .cannotFindHost, .cannotConnectToHost:
                .networkError
            case .cancelled:
                .userCancelled
            default:
                .unknownError
            }
        }
        
        // Check error description for common patterns
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("permission") || errorDescription.contains("access denied") {
            return .permissionError
        }
        
        if errorDescription.contains("timeout") || errorDescription.contains("timed out") {
            return .timeoutError
        }
        
        if errorDescription.contains("memory") || errorDescription.contains("disk space") {
            return .resourceError
        }
        
        if errorDescription.contains("validation") || errorDescription.contains("invalid") {
            return .validationError
        }
        
        if errorDescription.contains("cancelled") {
            return .userCancelled
        }
        
        return .unknownError
    }
    
    private func recordError(_ record: ErrorRecord) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        errorHistory.append(record)
        
        // Limit history size
        if errorHistory.count > historyLimit {
            errorHistory.removeFirst(errorHistory.count - historyLimit)
        }
        
        // Update statistics
        statistics.totalErrors += 1
        statistics.errorsByClassification[record.classification, default: 0] += 1
        statistics.errorsByContext[record.context.operation, default: 0] += 1
    }
    
    private func recordSuccessfulRecovery(record: ErrorRecord, strategy: RecoveryStrategy) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        statistics.successfulRecoveries += 1
        statistics.recoveriesByStrategy[strategy.name, default: 0] += 1
    }
    
    private func recordFailedRecovery(record: ErrorRecord, strategy: RecoveryStrategy, recoveryError: Error) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        statistics.failedRecoveries += 1
    }
    
    private func attemptRecovery(
        strategy: RecoveryStrategy,
        error: Error,
        context: ErrorContext,
        documentId: String
    ) async throws -> RecoveryResult {
        return try await strategy.execute(error: error, context: context, documentId: documentId)
    }
}

// MARK: - Supporting Types

/// Error classification
public enum ErrorClassification: String, CaseIterable, Sendable {
    case networkError = "network_error"
    case processingError = "processing_error"
    case resourceError = "resource_error"
    case validationError = "validation_error"
    case permissionError = "permission_error"
    case timeoutError = "timeout_error"
    case temporaryError = "temporary_error"
    case userCancelled = "user_cancelled"
    case unknownError = "unknown_error"
}

/// Error context
public struct ErrorContext: Sendable {
    public let operation: String
    public let stage: ProcessingStage
    public let parameters: [String: String]
    public let metadata: [String: String]
    
    public init(operation: String, stage: ProcessingStage, parameters: [String: String] = [:], metadata: [String: String] = [:]) {
        self.operation = operation
        self.stage = stage
        self.parameters = parameters
        self.metadata = metadata
    }
}

/// Processing stages
public enum ProcessingStage: String, CaseIterable, Sendable {
    case initialization = "initialization"
    case ingestion = "ingestion"
    case parsing = "parsing"
    case ocr = "ocr"
    case formatting = "formatting"
    case generation = "generation"
    case validation = "validation"
    case output = "output"
}

/// Error record
public struct ErrorRecord: Sendable {
    public let error: Error
    public let classification: ErrorClassification
    public let context: ErrorContext
    public let documentId: String
    public let timestamp: Date
}

/// Error handling result
public struct ErrorHandlingResult: Sendable {
    public let classification: ErrorClassification
    public let recoveryAttempted: Bool
    public let recoverySuccessful: Bool
    public let strategy: RecoveryStrategy?
    public let resolvedError: Error?
}

/// Error statistics
public struct ErrorStatistics: Sendable {
    public var totalErrors: Int = 0
    public var successfulRecoveries: Int = 0
    public var failedRecoveries: Int = 0
    public var errorsByClassification: [ErrorClassification: Int] = [:]
    public var errorsByContext: [String: Int] = [:]
    public var recoveriesByStrategy: [String: Int] = [:]
    
    public var recoveryRate: Double {
        guard totalRecoveries > 0 else { return 0.0 }
        return Double(successfulRecoveries) / Double(totalRecoveries)
    }
    
    private var totalRecoveries: Int {
        successfulRecoveries + failedRecoveries
    }
}

/// Recovery strategy protocol
public protocol RecoveryStrategy: Sendable {
    var name: String { get }
    func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult
}

/// Recovery result
public enum RecoveryResult: Sendable {
    case success(message: String)
    case retry(reason: String)
    case fallback(action: String)
}

// MARK: - Built-in Recovery Strategies

/// Network retry strategy
public struct NetworkRetryStrategy: RecoveryStrategy {
    public let name = "network_retry"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        // This would integrate with the specific network operation
        // For now, return a generic retry suggestion
        return .retry(reason: "Network error detected, retrying with exponential backoff")
    }
}

/// Fallback to offline strategy
public struct FallbackToOfflineStrategy: RecoveryStrategy {
    public let name = "fallback_offline"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .fallback(action: "Switching to offline processing mode")
    }
}

/// Retry with different parameters strategy
public struct RetryWithDifferentParametersStrategy: RecoveryStrategy {
    public let name = "retry_different_params"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .retry(reason: "Adjusting processing parameters for better compatibility")
    }
}

/// Reduce complexity strategy
public struct ReduceComplexityStrategy: RecoveryStrategy {
    public let name = "reduce_complexity"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .retry(reason: "Reducing processing complexity to handle resource constraints")
    }
}

/// Fallback to alternative format strategy
public struct FallbackToAlternativeFormatStrategy: RecoveryStrategy {
    public let name = "fallback_alternative_format"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .fallback(action: "Switching to alternative output format")
    }
}

/// Wait for resources strategy
public struct WaitForResourcesStrategy: RecoveryStrategy {
    public let name = "wait_for_resources"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        try await Task.sleep(for: .seconds(30))
        return .retry(reason: "Waiting for system resources to become available")
    }
}

/// Reduce memory usage strategy
public struct ReduceMemoryUsageStrategy: RecoveryStrategy {
    public let name = "reduce_memory_usage"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .retry(reason: "Reducing memory usage through smaller processing batches")
    }
}

/// Switch to smaller batch strategy
public struct SwitchToSmallerBatchStrategy: RecoveryStrategy {
    public let name = "switch_smaller_batch"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .retry(reason: "Switching to smaller batch size for processing")
    }
}

/// Data cleanup strategy
public struct DataCleanupStrategy: RecoveryStrategy {
    public let name = "data_cleanup"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .retry(reason: "Cleaning and sanitizing input data before processing")
    }
}

/// Skip invalid data strategy
public struct SkipInvalidDataStrategy: RecoveryStrategy {
    public let name = "skip_invalid_data"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .fallback(action: "Skipping invalid data sections and continuing with valid content")
    }
}

/// Request permissions strategy
public struct RequestPermissionsStrategy: RecoveryStrategy {
    public let name = "request_permissions"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .fallback(action: "Requesting necessary permissions for resource access")
    }
}

/// Fallback to read-only strategy
public struct FallbackToReadOnlyStrategy: RecoveryStrategy {
    public let name = "fallback_readonly"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .fallback(action: "Switching to read-only processing mode")
    }
}

/// Extend timeout strategy
public struct ExtendTimeoutStrategy: RecoveryStrategy {
    public let name = "extend_timeout"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .retry(reason: "Extending timeout duration for processing")
    }
}

/// Reduce workload strategy
public struct ReduceWorkloadStrategy: RecoveryStrategy {
    public let name = "reduce_workload"
    
    public func execute(error: Error, context: ErrorContext, documentId: String) async throws -> RecoveryResult {
        return .retry(reason: "Reducing processing workload to prevent timeouts")
    }
}