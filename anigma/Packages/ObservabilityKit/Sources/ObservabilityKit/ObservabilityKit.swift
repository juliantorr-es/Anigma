//
//  ObservabilityKit.swift
//  ObservabilityKit
//
//  Structured logging and tracing.
//

import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import os

public protocol Logger: Sendable {
    func log(level: LogLevel, message: String, fields: [String: String])
}

public enum LogLevel: Sendable {
    case debug, info, warn, error, critical

    var native: anigma_log_level_t {
        switch self {
        case .debug: return ANIGMA_LOG_DEBUG
        case .info: return ANIGMA_LOG_INFO
        case .warn: return ANIGMA_LOG_WARN
        case .error: return ANIGMA_LOG_ERROR
        case .critical: return ANIGMA_LOG_CRITICAL
        }
    }
}

public protocol Tracer: Sendable {
    func startSpan(name: String) -> Any
}

/// Thread-safe logger backed by native observability shim.
/// Uses internal synchronization via OSAllocatedUnfairLock for thread safety.
public final class NativeObservability: Logger, Sendable {
    public static let shared = NativeObservability()

    private let lock = OSAllocatedUnfairLock()

    public init() {
        // Init with default stdout
        _ = anigma_log_init(nil, true)
    }

    public func log(level: LogLevel, message: String, fields: [String: String]) {
        lock.withLock {
            // Simplified safe call - fields are not passed to C for now
            anigma_log_write(level.native, message, nil, 0)
        }
    }
}
