//
//  ColorKit.swift
//  ColorKit
//
//  Color management and transforms.
//

import Foundation
import AnigmaNativeShims
import AnigmaPrimitives

public protocol ColorTransform: Sendable {
    func transform(pixelData: Data, from sourceProfile: Data, to destProfile: Data) throws -> Data
}

/// Thread-safe color transform using native ICC profile handling.
public final class NativeColorTransform: ColorTransform, @unchecked Sendable {
    public init() {}

    public func transform(pixelData: Data, from sourceProfile: Data, to destProfile: Data) throws -> Data {
        var ctx = anigma_ctx_t()

        // 1. Create Transform
        var tPtr: anigma_transform_t?
        try sourceProfile.withUnsafeNativeBytes { srcPtr, srcLen in
            try destProfile.withUnsafeNativeBytes { dstPtr, dstLen in
                let res = anigma_transform_create(&ctx, srcPtr, srcLen, dstPtr, dstLen, &tPtr)
                if res.status != ANIGMA_OK { throw NativeError(status: Int32(res.status.rawValue), context: "transform_create") }
            }
        }

        guard let transformHandle = tPtr else { throw NativeError(status: -1, context: "transform_create_null") }
        defer {
            anigma_transform_destroy(transformHandle)
        }

        // 2. Apply (in-place)
        var mutableData = pixelData
        try mutableData.withUnsafeMutableBytes { buf in
            guard let base = buf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let res = anigma_transform_apply(transformHandle, &ctx, base, buf.count / 4, 4)
            if res.status != ANIGMA_OK { throw NativeError(status: Int32(res.status.rawValue), context: "transform_apply") }
        }

        return mutableData
    }
}
