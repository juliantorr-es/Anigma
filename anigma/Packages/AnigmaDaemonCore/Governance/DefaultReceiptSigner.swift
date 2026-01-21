//
//  DefaultReceiptSigner.swift
//  AnigmaDaemonCore
//

import CryptoKit
import ExecutionCore
import Foundation

/// Default ReceiptSigner implementation using local SHA256
public struct DefaultReceiptSigner: ReceiptSigner {
    public init() {}

    public var signerID: String {
        return "local-daemon-default"
    }

    public func sign(data: Data) async throws -> String {
        // For MVP, we use a deterministic hash as a "signature"
        // In production, this would use a private key from Secure Enclave
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func verify(data: Data, signature: String) async throws -> Bool {
        let digest = SHA256.hash(data: data)
        let expected = digest.map { String(format: "%02x", $0) }.joined()
        return expected == signature
    }
}
