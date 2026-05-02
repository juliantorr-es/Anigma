//
//  VaultKeychainProvider.swift
//  StorageCore
//
//  Keychain-backed key provider for vault encryption.
//

import Foundation
import AnigmaPrimitives

#if canImport(Security)
import Security
#endif

/// Keychain-backed key provider for vault encryption.
public actor KeychainVaultKeyProvider: VaultKeyProvider {
    private let service: String
    private let account: String
    private let keyId: String
    private let authority: any SecretAuthority

    public init(
        service: String = "AnigmaVault",
        account: String = "default",
        keyId: String = "keychain-default",
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

    public func currentKeyMaterial() async throws -> VaultKeyMaterial {
        let keyData = try await loadOrCreateKey()
        return VaultKeyMaterial(keyId: keyId, masterKeyData: keyData)
    }

    public func keyMaterial(for keyId: String) async throws -> VaultKeyMaterial {
        guard keyId == self.keyId else {
            throw VaultError.cryptoFailure("Unknown keyId: \(keyId)")
        }
        let keyData = try await loadOrCreateKey()
        return VaultKeyMaterial(keyId: keyId, masterKeyData: keyData)
    }

    private func loadOrCreateKey() async throws -> Data {
        if let existing = try await authority.retrieve(for: account) {
            return existing
        }
        let key = randomKey()
        try await authority.store(secret: key, for: account)
        if let stored = try await authority.retrieve(for: account) {
            return stored
        }
        throw VaultError.cryptoFailure("Failed to persist keychain key")
    }

    private func randomKey() -> Data {
        #if canImport(Security)
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
        #else
        var bytes = [UInt8]()
        bytes.reserveCapacity(32)
        for _ in 0..<32 {
            bytes.append(UInt8.random(in: UInt8.min...UInt8.max))
        }
        return Data(bytes)
        #endif
    }
}

/// Default key provider selector that falls back to in-memory keys when needed.
public struct DefaultVaultKeyProvider {
    public static func make() -> VaultKeyProvider {
        return KeychainVaultKeyProvider()
    }
}
