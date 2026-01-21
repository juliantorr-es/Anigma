//
//  AnimationKit.swift
//  AnimationKit
//
//  Animation runtime interface.
//

import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import os

public protocol AnimationRuntime: Sendable {
    func load(data: Data) throws
    func advance(delta: Double)
    func render(width: Int, height: Int) throws -> Data
}

/// Thread-safe animation runtime using native Lottie/animation rendering.
/// Uses internal synchronization via OSAllocatedUnfairLock for thread safety.
public final class NativeAnimation: AnimationRuntime, Sendable {
    private struct Handle: @unchecked Sendable {
        var ptr: anigma_animation_t?
    }

    private let state = OSAllocatedUnfairLock(initialState: Handle(ptr: nil))

    public init() {}

    public func load(data: Data) throws {
        try state.withLock { handle in
            var ctx = anigma_ctx_t()
            var hPtr: anigma_animation_t?

            try data.withUnsafeNativeBytes { ptr, len in
                let res = anigma_animation_load(&ctx, ptr, len, &hPtr)
                if res.status != ANIGMA_OK {
                    throw NativeError(status: Int32(res.status.rawValue), context: "anim_load")
                }
            }

            handle.ptr = hPtr
        }
    }

    public func advance(delta: Double) {
        state.withLock { handle in
            guard let h = handle.ptr else { return }
            var ctx = anigma_ctx_t()
            _ = anigma_animation_advance(h, &ctx, delta)
        }
    }

    public func render(width: Int, height: Int) throws -> Data {
        try state.withLock { handle in
            guard let h = handle.ptr else { throw NativeError(status: -1, message: "Not loaded", context: "render") }
            var ctx = anigma_ctx_t()
            var outBuf: UnsafeMutablePointer<UInt8>?
            var outLen: Int = 0

            let res = anigma_animation_render(
                h,
                &ctx,
                UInt32(width),
                UInt32(height),
                &outBuf,
                &outLen
            )

            if res.status != ANIGMA_OK { throw NativeError(status: Int32(res.status.rawValue), context: "anim_render") }

            guard let buf = outBuf else { return Data() }
            defer { anigma_free_buffer(buf) }
            return Data(bytes: buf, count: outLen)
        }
    }

    deinit {
        state.withLock { handle in
            if let hVal = handle.ptr {
                anigma_animation_destroy(hVal)
            }
        }
    }
}
