//
//  CorporateError.swift
//  AnigmaCorporate
//
//  Created by Anigma Agent.
//

import Foundation
import AnigmaCore

public enum CorporateError: AnigmaError {
    case authenticationFailed(String)
    case unauthorized(String)
    case notFound(String)
    case accessDenied(String)
    case networkError(String)
    case invalidConfiguration(String)
    case internalError(String)
    case unsupportedOperation(String)

    public var category: ErrorCategory {
        switch self {
        case .authenticationFailed, .unauthorized, .accessDenied:
            return .validation // Or security if available, but validation fits "check failed"
        case .notFound:
            return .validation
        case .networkError:
            return .network
        case .invalidConfiguration:
            return .configuration
        case .internalError, .unsupportedOperation:
            return .internal
        }
    }

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed(let msg): return "Authentication Failed: \(msg)"
        case .unauthorized(let msg): return "Unauthorized: \(msg)"
        case .notFound(let msg): return "Not Found: \(msg)"
        case .accessDenied(let msg): return "Access Denied: \(msg)"
        case .networkError(let msg): return "Network Error: \(msg)"
        case .invalidConfiguration(let msg): return "Invalid Configuration: \(msg)"
        case .internalError(let msg): return "Internal Error: \(msg)"
        case .unsupportedOperation(let msg): return "Unsupported Operation: \(msg)"
        }
    }
}
