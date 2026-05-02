// CapsuleCoreStub.swift
// Minimal stub for CapsuleCore to enable RendererKit testing

import Foundation

// Minimal error type to satisfy RendererKit dependencies
public enum CapsuleError: Error, Sendable {
    case operationFailed(code: Int, message: String, context: [String: String])
    case invalidState(message: String)
    case resourceUnavailable(resource: String)
    case unsupportedOperation(operation: String)
    case timeout(operation: String, timeout: TimeInterval)
}

// Minimal extensions to make it work with RendererKit
public struct CapsuleErrorContext: Sendable {
    public let code: Int
    public let message: String
    public let context: [String: String]
    
    public init(code: Int, message: String, context: [String: String] = [:]) {
        self.code = code
        self.message = message
        self.context = context
    }
}

// Extend Error for compatibility
extension CapsuleError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .operationFailed(let code, let message, _):
            return "Operation failed (code: \(code)): \(message)"
        case .invalidState(let message):
            return "Invalid state: \(message)"
        case .resourceUnavailable(let resource):
            return "Resource unavailable: \(resource)"
        case .unsupportedOperation(let operation):
            return "Unsupported operation: \(operation)"
        case .timeout(let operation, let timeout):
            return "Timeout after \(timeout)s: \(operation)"
        }
    }
}
