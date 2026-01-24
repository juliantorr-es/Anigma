//
//  BLAKE3Digest.swift
//  AnigmaPrimitives
//
//  Helper utilities for computing hex-encoded digests.
//  Transitioned to SHA256 for build stability and hardware acceleration.
//

import Foundation
import Crypto

public enum BLAKE3Digest {
    /// Compute a hex-encoded SHA256 digest for the given data.
    /// Note: Keeps BLAKE3Digest name for temporary API compatibility.
    public static func hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Compute a hex-encoded digest for the given string using UTF-8.
    public static func hex(of string: String) -> String {
        return hex(of: Data(string.utf8))
    }
}
