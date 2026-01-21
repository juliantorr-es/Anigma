//
//  NativeInterop.swift
//  AnigmaPrimitives
//
//  Safety wrappers for C API interaction.
//

import Foundation

/// Safe wrapper for a managed native pointer.
/// Handles ownership and destruction via a deinit closure.
/// Thread-safe via @unchecked Sendable - callers must ensure proper synchronization.
public final class NativeHandle<T>: @unchecked Sendable {
    public let raw: OpaquePointer
    private let cleanup: @Sendable (OpaquePointer) -> Void

    public init(raw: OpaquePointer, cleanup: @escaping @Sendable (OpaquePointer) -> Void) {
        self.raw = raw
        self.cleanup = cleanup
    }

    deinit {
        cleanup(raw)
    }
}

/// Generic error for native operations.
public struct NativeError: Error, LocalizedError, Sendable {
    public let status: Int
    public let message: String
    public let context: String

    public init(status: Int32, message: String? = nil, context: String = "") {
        self.status = Int(status)
        self.message = message ?? "Unknown native error"
        self.context = context
    }

    public var errorDescription: String? {
        return "NativeError(status: \(status), ctx: \(context)): \(message)"
    }
}

/// Helper to bridge Data to C-style bytes.
public extension Data {
    func withUnsafeNativeBytes<Result>(_ body: (UnsafePointer<UInt8>, Int) throws -> Result) rethrows -> Result {
        return try self.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else {
                return try body(UnsafePointer<UInt8>(bitPattern: 1)!, 0)
            }
            let typed = base.assumingMemoryBound(to: UInt8.self)
            return try body(typed, rawBuffer.count)
        }
    }
}
