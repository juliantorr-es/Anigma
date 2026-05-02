//
//  ColorKit.swift
//  ColorKit
//
//  Color management and transforms (stub implementation).
//

import Foundation
import AnigmaNativeShims

public protocol ColorTransform: Sendable {
    func transform(pixelData: Data, from sourceProfile: Data, to destProfile: Data) throws -> Data
}

/// Thread-safe color transform - stub implementation.
/// Real implementation will use native ICC profile handling.
public final class NativeColorTransform: ColorTransform, @unchecked Sendable {
    public init() {}

    public func transform(pixelData: Data, from sourceProfile: Data, to destProfile: Data) throws -> Data {
        // Stub: return unmodified data
        // Real implementation would call native color transform functions
        return pixelData
    }
}
