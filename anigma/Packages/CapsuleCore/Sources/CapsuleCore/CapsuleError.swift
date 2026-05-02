// CapsuleError.swift
// CapsuleCore - Canonical error model for all Anigma capsules
// Part of the Anigma remediation plan

import Foundation
import AnigmaNativeShims

// MARK: - CapsuleError

/// The canonical error type for all capsule operations.
/// 
/// This enum represents all possible failure modes that can occur during capsule execution.
/// Every capsule MUST map its native errors to these canonical cases for consistent error handling
/// across the Anigma ecosystem.
///
/// Conformances:
/// - `Error`: Standard Swift error protocol
/// - `Sendable`: Safe for use across concurrency boundaries
/// - `Codable`: Serializable for daemon logs and inter-process communication
/// - `LocalizedError`: User-facing error messages
public enum CapsuleError: Error, Sendable, Codable {
    
    /// Configuration validation failed before operation
    /// - Associated value: reason for failure
    case invalidConfiguration(reason: String)
    
    /// Runtime operation failed with recoverable state
    /// - Associated values: error code, human-readable message, and metadata context
    case operationFailed(code: UInt32, message: String, context: [String: String])
    
    /// Resource exhausted (memory, handles, connections, disk)
    /// - Associated values: resource name and the limit that was reached
    case resourceExhausted(resource: String, limit: String)
    
    /// Input data format or constraints violated
    /// - Associated values: field name and the constraint that was violated
    case invalidInput(field: String, constraint: String)
    
    /// Underlying native library returned error
    /// - Associated values: error code and the name of the library
    case nativeError(code: Int32, libraryName: String)
    
    /// Timeout or deadline exceeded
    /// - Associated values: operation name and the deadline duration (or remaining time)
    case timeout(operation: String, deadline: TimeInterval)
    
    /// Internal consistency error (indicates a bug)
    /// - Associated value: brief description of the assertion failure
    case internalError(details: String)
    
    /// The canonical error code for this error case.
    public var errorCode: CapsuleErrorCode {
        switch self {
        case .invalidConfiguration:
            return .invalidConfig
        case .operationFailed:
            return .operationFailed
        case .resourceExhausted:
            return .resourceExhausted
        case .invalidInput:
            return .invalidInput
        case .nativeError:
            return .nativeError
        case .timeout:
            return .timeout
        case .internalError:
            return .internalError
        }
    }
}

// MARK: - LocalizedError Conformance

extension CapsuleError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
            
        case .operationFailed(let code, let message, _):
            return "Operation failed (code \(code)): \(message)"
            
        case .resourceExhausted(let resource, let limit):
            return "Resource exhausted: \(resource) (limit: \(limit))"
            
        case .invalidInput(let field, let constraint):
            return "Invalid input for '\(field)': \(constraint)"
            
        case .nativeError(let code, let libraryName):
            return "Native error in \(libraryName) (code \(code))"
            
        case .timeout(let operation, let deadline):
            return "Operation '\(operation)' timed out (deadline: \(String(format: "%.1f", deadline))s)"
            
        case .internalError(let details):
            return "Internal error: \(details)"
        }
    }
}

// MARK: - CustomStringConvertible

extension CapsuleError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .invalidConfiguration(let reason):
            return "CapsuleError.invalidConfiguration(reason: \(reason))"
            
        case .operationFailed(let code, let message, let context):
            return "CapsuleError.operationFailed(code: \(code), message: \(message), context: \(context))"
            
        case .resourceExhausted(let resource, let limit):
            return "CapsuleError.resourceExhausted(resource: \(resource), limit: \(limit))"
            
        case .invalidInput(let field, let constraint):
            return "CapsuleError.invalidInput(field: \(field), constraint: \(constraint))"
            
        case .nativeError(let code, let libraryName):
            return "CapsuleError.nativeError(code: \(code), libraryName: \(libraryName))"
            
        case .timeout(let operation, let deadline):
            return "CapsuleError.timeout(operation: \(operation), deadline: \(deadline)s)"
            
        case .internalError(let details):
            return "CapsuleError.internalError(details: \(details))"
        }
    }
}

// MARK: - Equatable

extension CapsuleError: Equatable {
    public static func == (lhs: CapsuleError, rhs: CapsuleError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidConfiguration(let l), .invalidConfiguration(let r)):
            return l == r
        case (.operationFailed(let c1, let m1, let ctx1), .operationFailed(let c2, let m2, let ctx2)):
            return c1 == c2 && m1 == m2 && ctx1 == ctx2
        case (.resourceExhausted(let r1, let l1), .resourceExhausted(let r2, let l2)):
            return r1 == r2 && l1 == l2
        case (.invalidInput(let f1, let c1), .invalidInput(let f2, let c2)):
            return f1 == f2 && c1 == c2
        case (.nativeError(let c1, let l1), .nativeError(let c2, let l2)):
            return c1 == c2 && l1 == l2
        case (.timeout(let o1, let d1), .timeout(let o2, let d2)):
            return o1 == o2 && d1 == d2
        case (.internalError(let d1), .internalError(let d2)):
            return d1 == d2
        default:
            return false
        }
    }
}
