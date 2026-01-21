//
//  BLAKE3Digest.swift
//  AnigmaPrimitives
//
//  Helper utilities for computing hex-encoded BLAKE3 digests.
//

import Foundation
import BLAKE3

public enum BLAKE3Digest {
    /// Compute a hex-encoded BLAKE3 digest for the given data.
    public static func hex(of data: Data) -> String {
        let bytes = BLAKE3.hash(contentsOf: data)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Compute a hex-encoded BLAKE3 digest for the given string using UTF-8.
    public static func hex(of string: String) -> String {
        return hex(of: Data(string.utf8))
    }
}
