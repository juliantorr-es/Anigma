//
//  DocumentRenderKit.swift
//  DocumentRenderKit
//
//  Vector and PDF rendering interface.
//

import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import os

public protocol RenderEngine: Sendable {
    func render(page: Int, scale: Double) throws -> Data
}

/// Thread-safe document renderer using native bitmap rendering.
public final class NativeDocumentRenderer: RenderEngine, Sendable {
    private struct Handle: @unchecked Sendable {
        var ptr: anigma_renderer_t?
    }

    private let state: OSAllocatedUnfairLock<Handle>

    public init() throws {
        var ctx = anigma_ctx_t()
        var handlePtr: anigma_renderer_t?
        let res = anigma_renderer_create(&ctx, &handlePtr)
        guard res.status == ANIGMA_OK, let ptr = handlePtr else {
            throw NativeError(status: Int32(res.status.rawValue), message: res.error_message.map { String(cString: $0) } ?? "Init failed", context: "renderer_create")
        }
        self.state = OSAllocatedUnfairLock(initialState: Handle(ptr: ptr))
    }

    public func render(page: Int, scale: Double) throws -> Data {
        try state.withLock { handle in
            guard let h = handle.ptr else {
                throw NativeError(status: -1, message: "Renderer not initialized", context: "render")
            }

            // Use the provided Document IR data to render
            // For demonstration we will pass a small IR header if data is empty, 
            // but in production this should be passed from the caller.
            let irData = Data([0x41, 0x4E, 0x49, 0x47]) // "ANIG" header

            return try irData.withUnsafeBytes { irRawBuffer in
                let irPtr = irRawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
                let irLen = irRawBuffer.count

                var outW: UInt32 = 0
                var outH: UInt32 = 0
                var outBuf: UnsafeMutablePointer<UInt8>?
                var outLen: Int = 0

                var ctx = anigma_ctx_t()
                let res = anigma_renderer_render_bitmap(
                    h,
                    &ctx,
                    irPtr,
                    irLen,
                    scale,
                    &outW,
                    &outH,
                    &outBuf,
                    &outLen
                )

                guard res.status == ANIGMA_OK, let buf = outBuf else {
                    throw NativeError(status: Int32(res.status.rawValue), message: res.error_message.map { String(cString: $0) } ?? "Render failed", context: "render_bitmap")
                }

                defer { anigma_free_buffer(buf) }
                return Data(bytes: buf, count: outLen)
            }
        }
    }

    deinit {
        state.withLock { handle in
            if let h = handle.ptr {
                anigma_renderer_destroy(h)
            }
        }
    }
}
