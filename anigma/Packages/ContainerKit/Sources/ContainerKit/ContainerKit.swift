//
//  ContainerKit.swift
//  ContainerKit
//
//  Safe container I/O abstraction.
//

import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import os

public protocol ContainerInterface: Sendable {
    func open(path: String) throws
    func readEntry(name: String) throws -> Data
    func writeEntry(name: String, data: Data) throws
    func close()
}

/// Thread-safe container wrapper using native ZIP/archive operations.
/// Uses internal synchronization via OSAllocatedUnfairLock for thread safety.
public final class NativeContainer: ContainerInterface, Sendable {
    private struct Handle: @unchecked Sendable {
        var ptr: anigma_container_t?
    }

    private let state = OSAllocatedUnfairLock(initialState: Handle(ptr: nil))

    public init() {}

    public func open(path: String) throws {
        try state.withLock { handle in
            var ctx = anigma_ctx_t()
            var hPtr: anigma_container_t?

            try path.withCString { cPath in
                let res = anigma_container_open(&ctx, cPath, false, &hPtr)
                if res.status != ANIGMA_OK {
                    throw NativeError(status: Int32(res.status.rawValue), message: res.error_message.map { String(cString: $0) } ?? "Open failed", context: "container_open")
                }
            }

            handle.ptr = hPtr
        }
    }

    public func readEntry(name: String) throws -> Data {
        try state.withLock { handle in
            guard let h = handle.ptr else { throw NativeError(status: -1, message: "Not open", context: "read") }

            var ctx = anigma_ctx_t()
            return try name.withCString { cName in
                var outBuf: UnsafeMutablePointer<UInt8>?
                var outLen: Int = 0

                let res = anigma_container_read_entry(h, &ctx, cName, &outBuf, &outLen)
                if res.status != ANIGMA_OK {
                    throw NativeError(status: Int32(res.status.rawValue), context: "read_entry")
                }

                guard let buf = outBuf else { return Data() }
                defer { anigma_free_buffer(buf) }
                return Data(bytes: buf, count: outLen)
            }
        }
    }

    public func writeEntry(name: String, data: Data) throws {
        try state.withLock { handle in
            guard let h = handle.ptr else { throw NativeError(status: -1, message: "Not open", context: "write") }

            var ctx = anigma_ctx_t()
            try name.withCString { cName in
                try data.withUnsafeNativeBytes { ptr, len in
                    let res = anigma_container_write_entry(h, &ctx, cName, ptr, len)
                    if res.status != ANIGMA_OK {
                        throw NativeError(status: Int32(res.status.rawValue), context: "write_entry")
                    }
                }
            }
        }
    }

    public func close() {
        state.withLock { handle in
            if let hVal = handle.ptr {
                anigma_container_close(hVal)
                handle.ptr = nil
            }
        }
    }

    deinit {
        state.withLock { handle in
            if let hVal = handle.ptr {
                anigma_container_close(hVal)
            }
        }
    }
}
