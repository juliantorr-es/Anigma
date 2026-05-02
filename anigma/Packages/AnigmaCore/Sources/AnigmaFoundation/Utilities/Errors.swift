//
//  Errors.swift
//  AnigmaCore
//
//  Common error types for AnigmaCore.
//  Domain modules should define their own specific errors.
//

import AnigmaPrimitives
import ContractsCore
import Foundation

// MARK: - Anigma Error Protocol

/// Base protocol for all Anigma errors.
/// Provides consistent error handling and categorization.
public protocol CoreErrorProtocol: Error, LocalizedError, Sendable {
    /// Error category for grouping/filtering.
    var category: CoreErrorCategory { get }

    /// Whether this error is recoverable.
    var isRecoverable: Bool { get }

    /// Suggested action to resolve the error.
    var suggestedAction: String? { get }
}

/// Default implementations.
public extension CoreErrorProtocol {
    var isRecoverable: Bool { true }
    var suggestedAction: String? { nil }
}

// MARK: - Error Categories

/// Categories for error classification.
public enum CoreErrorCategory: String, Sendable {
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
public struct GenericCoreError: CoreErrorProtocol {
    public let message: String
    public let category: CoreErrorCategory
    public let isRecoverable: Bool
    public let suggestedAction: String?
    public let underlyingError: Error?

    public init(
        _ message: String,
        category: CoreErrorCategory = .internal,
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
    public static func configuration(_ message: String, suggestedAction: String? = nil) -> GenericCoreError {
        GenericCoreError(message, category: .configuration, suggestedAction: suggestedAction)
    }

    /// Creates an I/O error.
    public static func io(_ message: String, underlyingError: Error? = nil) -> GenericCoreError {
        GenericCoreError(message, category: .io, underlyingError: underlyingError)
    }

    /// Creates a validation error.
    public static func validation(_ message: String) -> GenericCoreError {
        GenericCoreError(message, category: .validation, isRecoverable: true)
    }

    /// Creates an internal error (non-recoverable).
    public static func `internal`(_ message: String, underlyingError: Error? = nil) -> GenericCoreError {
        GenericCoreError(message, category: .internal, isRecoverable: false, underlyingError: underlyingError)
    }

    /// Compatibility alias for legacy enum.
    public static func internalError(_ message: String) -> GenericCoreError {
        GenericCoreError(message, category: .internal, isRecoverable: false)
    }
}

// MARK: - Result Extensions

/// Convenience extensions for Result with CoreError.
public extension Result where Failure: CoreErrorProtocol {
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
public func wrapError(_ error: Error, category: CoreErrorCategory = .internal) -> GenericCoreError {
    if let anigmaError = error as? CoreErrorProtocol {
        return GenericCoreError(
            anigmaError.localizedDescription,
            category: anigmaError.category,
            underlyingError: error
        )
    }
    return GenericCoreError(
        error.localizedDescription,
        category: category,
        underlyingError: error
    )
}