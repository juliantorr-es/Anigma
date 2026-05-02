//
//  DefaultReceiptSigner.swift
//  AnigmaDaemonCore
//

import AnigmaPrimitives
import CryptoKit
import ExecutionCore
import Foundation

/// Default ReceiptSigner implementation using local BLAKE3
public struct DefaultReceiptSigner: ReceiptSigner {
    public init() {}

    public var signerID: String {
        return "local-daemon-default"
    }

    public func sign(data: Data) async throws -> String {
        // For Saturated Architecture, we use BLAKE3 for deterministic signatures
        // In production, this would use a private key from Secure Enclave
        return BLAKE3Digest.hex(of: data)
    }

    public func verify(data: Data, signature: String) async throws -> Bool {
        let expected = BLAKE3Digest.hex(of: data)
        return expected == signature
    }
}
