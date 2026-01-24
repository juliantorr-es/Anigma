//
//  Errors.swift
//  AnigmaCore
//
//  Common error types for AnigmaCore.
//  Domain modules should define their own specific errors.
//

import Foundation

// MARK: - Anigma Error Protocol

/// Base protocol for all Anigma errors.
/// Provides consistent error handling and categorization.
public protocol AnigmaError: Error, LocalizedError, Sendable {
    /// Error category for grouping/filtering.
    var category: ErrorCategory { get }

    /// Whether this error is recoverable.
    var isRecoverable: Bool { get }

    /// Suggested action to resolve the error.
    var suggestedAction: String? { get }
}

/// Default implementations.
public extension AnigmaError {
    var isRecoverable: Bool { true }
    var suggestedAction: String? { nil }
}

// MARK: - Error Categories

/// Categories for error classification.
public enum ErrorCategory: String, Sendable {
    /// Entity/component/system errors.
    case ecs = "ECS"

    /// Job/workflow/scheduling errors.
    case job = "Job"

    /// Configuration/setup errors.
    case configuration = "Configuration"

    /// I/O and file system errors.
    case io = "IO"

    /// Network and API errors.
    case network = "Network"

    /// Validation and data format errors.
    case validation = "Validation"

    /// Internal/unexpected errors.
    case `internal` = "Internal"
}

// MARK: - Core Error

/// General-purpose error for AnigmaCore.
public struct CoreError: AnigmaError {
    public let message: String
    public let category: ErrorCategory
    public let isRecoverable: Bool
    public let suggestedAction: String?
    public let underlyingError: Error?

    public init(
        _ message: String,
        category: ErrorCategory = .internal,
        isRecoverable: Bool = true,
        suggestedAction: String? = nil,
        underlyingError: Error? = nil
    ) {
        self.message = message
        self.category = category
        self.isRecoverable = isRecoverable
        self.suggestedAction = suggestedAction
        self.underlyingError = underlyingError
    }

    public var errorDescription: String? {
        if let underlying = underlyingError {
            return "\(message): \(underlying.localizedDescription)"
        }
        return message
    }

    // MARK: - Factory Methods

    /// Creates a configuration error.
    public static func configuration(_ message: String, suggestedAction: String? = nil) -> CoreError {
        CoreError(message, category: .configuration, suggestedAction: suggestedAction)
    }

    /// Creates an I/O error.
    public static func io(_ message: String, underlyingError: Error? = nil) -> CoreError {
        CoreError(message, category: .io, underlyingError: underlyingError)
    }

    /// Creates a validation error.
    public static func validation(_ message: String) -> CoreError {
        CoreError(message, category: .validation, isRecoverable: true)
    }

    /// Creates an internal error (non-recoverable).
    public static func `internal`(_ message: String, underlyingError: Error? = nil) -> CoreError {
        CoreError(message, category: .internal, isRecoverable: false, underlyingError: underlyingError)
    }
}

// MARK: - Result Extensions

/// Convenience extensions for Result with AnigmaError.
public extension Result where Failure: AnigmaError {
    /// Whether the error is recoverable.
    var isRecoverable: Bool {
        switch self {
        case .success: return true
        case .failure(let error): return error.isRecoverable
        }
    }
}

// MARK: - Error Wrapping

/// Wraps any error in a CoreError.
public func wrapError(_ error: Error, category: ErrorCategory = .internal) -> CoreError {
    if let anigmaError = error as? CoreError {
        return anigmaError
    }
    return CoreError(
        error.localizedDescription,
        category: category,
        underlyingError: error
    )
}
