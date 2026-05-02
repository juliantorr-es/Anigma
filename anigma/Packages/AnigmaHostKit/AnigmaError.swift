//
//  GenericCoreError.swift
//  AnigmaHostKit
//

import Foundation

public enum GenericCoreError: Error, LocalizedError {
    case notFound(String)
    case unauthorized(String)
    case invalidIntent(String)
    case sidecarError(String)
    case configurationError(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let message): return "Not Found: \(message)"
        case .unauthorized(let message): return "Unauthorized: \(message)"
        case .invalidIntent(let message): return "Invalid Intent: \(message)"
        case .sidecarError(let message): return "Sidecar Error: \(message)"
        case .configurationError(let message): return "Configuration Error: \(message)"
        }
    }
}
