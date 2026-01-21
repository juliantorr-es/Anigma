//
//  VaultSigning.swift
//  StorageCore
//
//  Signing support for vault export manifests.
//

import CryptoKit
import Foundation

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
    func sign(payload: Data) throws -> VaultSignature
}

/// In-memory signer for tests or mock mode.
public final class InMemoryVaultSigner: VaultSigner {
    private let key: P256.Signing.PrivateKey
    private let keyId: String

    public init(keyId: String = "memory-key") {
        self.key = P256.Signing.PrivateKey()
        self.keyId = keyId
    }

    public func sign(payload: Data) throws -> VaultSignature {
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

#if canImport(Security)
/// Keychain-backed signer for production use.
public final class KeychainVaultSigner: VaultSigner {
    private let service: String
    private let account: String
    private let keyId: String

    public init(
        service: String = "AnigmaVaultSigning",
        account: String = "default",
        keyId: String = "vault-signing-key"
    ) {
        self.service = service
        self.account = account
        self.keyId = keyId
    }

    public func sign(payload: Data) throws -> VaultSignature {
        let privateKey = try loadOrCreateKey()
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

    private func loadOrCreateKey() throws -> P256.Signing.PrivateKey {
        if let stored = try loadKey() {
            return stored
        }
        let key = P256.Signing.PrivateKey()
        try storeKey(key.rawRepresentation)
        if let stored = try loadKey() {
            return stored
        }
        throw VaultError.cryptoFailure("Failed to persist signing key")
    }

    private func loadKey() throws -> P256.Signing.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return try P256.Signing.PrivateKey(rawRepresentation: data)
        }
        if status == errSecItemNotFound {
            return nil
        }
        throw VaultError.cryptoFailure("Keychain read failed: \(status)")
    }

    private func storeKey(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultError.cryptoFailure("Keychain write failed: \(status)")
        }
    }
}
#else

public final class KeychainVaultSigner: VaultSigner {
    public init(
        service: String = "AnigmaVaultSigning",
        account: String = "default",
        keyId: String = "vault-signing-key"
    ) {}

    public func sign(payload: Data) throws -> VaultSignature {
        throw VaultError.cryptoFailure("Keychain not available")
    }
}
#endif

/// Default signer selector that falls back to in-memory when keychain is unavailable.
public struct DefaultVaultSigner {
    public static func make() -> VaultSigner {
        #if canImport(Security)
        return KeychainVaultSigner()
        #else
        return InMemoryVaultSigner()
        #endif
    }
}
