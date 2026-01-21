//
//  BLAKE3Hasher.swift
//  HarmoniaModule
//
//  Lightweight wrapper around BLAKE3Digest to provide a consistent hashing interface.
//

import Foundation
import AnigmaPrimitives

public struct BLAKE3Hasher: Sendable {
    /// Compute hex-encoded BLAKE3 digest for provided data.
    public func hash(_ data: Data) throws -> String {
        return BLAKE3Digest.hex(of: data)
    }
}
