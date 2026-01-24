//
//  VaultSigning.swift
//  StorageCore
//
//  Signing support for vault export manifests.
//

import CryptoKit
import Foundation
import AnigmaPrimitives

#if canImport(Security)
import Security
#endif

/// Signature metadata for vault bundles.
public struct VaultSignature: Codable, Sendable {
    public let algorithm: String
    public let keyId: String
    public let publicKey: String
    public let signature: String
    public let payloadHash: String
    public let signedAt: Date

    public init(
        algorithm: String,
        keyId: String,
        publicKey: String,
        signature: String,
        payloadHash: String,
        signedAt: Date
    ) {
        self.algorithm = algorithm
        self.keyId = keyId
        self.publicKey = publicKey
        self.signature = signature
        self.payloadHash = payloadHash
        self.signedAt = signedAt
    }
}

/// Signs vault exports for offline verification.
public protocol VaultSigner: Sendable {
    func sign(payload: Data) async throws -> VaultSignature
}

/// In-memory signer for tests or mock mode.
public final class InMemoryVaultSigner: VaultSigner {
    private let key: P256.Signing.PrivateKey
    private let keyId: String

    public init(keyId: String = "memory-key") {
        self.key = P256.Signing.PrivateKey()
        self.keyId = keyId
    }

    public func sign(payload: Data) async throws -> VaultSignature {
        let payloadHash = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        let signature = try key.signature(for: payload)
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
        return VaultSignature(
            algorithm: "P256-SHA256",
            keyId: keyId,
            publicKey: publicKey,
            signature: signature.rawRepresentation.base64EncodedString(),
            payloadHash: payloadHash,
            signedAt: Date()
        )
    }
}

/// Keychain-backed signer for production use.
public final class KeychainVaultSigner: VaultSigner {
    private let service: String
    private let account: String
    private let keyId: String
    private let authority: any SecretAuthority

    public init(
        service: String = "AnigmaVaultSigning",
        account: String = "default",
        keyId: String = "vault-signing-key",
        authority: (any SecretAuthority)? = nil
    ) {
        self.service = service
        self.account = account
        self.keyId = keyId
        
        #if os(macOS) || os(iOS)
        self.authority = authority ?? KeychainSecretAuthority(service: service)
        #else
        self.authority = authority ?? CompositeSecretAuthority(service: service)
        #endif
    }

    public func sign(payload: Data) async throws -> VaultSignature {
        let privateKey = try await loadOrCreateKey()
        let payloadHash = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        let signature = try privateKey.signature(for: payload)
        let publicKey = privateKey.publicKey.rawRepresentation.base64EncodedString()
        return VaultSignature(
            algorithm: "P256-SHA256",
            keyId: keyId,
            publicKey: publicKey,
            signature: signature.rawRepresentation.base64EncodedString(),
            payloadHash: payloadHash,
            signedAt: Date()
        )
    }

    private func loadOrCreateKey() async throws -> P256.Signing.PrivateKey {
        if let data = try await authority.retrieve(for: account) {
            return try P256.Signing.PrivateKey(rawRepresentation: data)
        }
        let key = P256.Signing.PrivateKey()
        try await authority.store(secret: key.rawRepresentation, for: account)
        return key
    }
}

/// Default signer selector that falls back to in-memory when keychain is unavailable.
public struct DefaultVaultSigner {
    public static func make() -> VaultSigner {
        return KeychainVaultSigner()
    }
}
