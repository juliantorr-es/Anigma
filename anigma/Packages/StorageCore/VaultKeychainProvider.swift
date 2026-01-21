//
//  VaultKeychainProvider.swift
//  StorageCore
//
//  Keychain-backed key provider for vault encryption.
//

import Foundation

#if canImport(Security)
import Security

/// Keychain-backed key provider for vault encryption.
public actor KeychainVaultKeyProvider: VaultKeyProvider {
    private let service: String
    private let account: String
    private let keyId: String

    public init(
        service: String = "AnigmaVault",
        account: String = "default",
        keyId: String = "keychain-default"
    ) {
        self.service = service
        self.account = account
        self.keyId = keyId
    }

    public func currentKeyMaterial() async throws -> VaultKeyMaterial {
        let keyData = try loadOrCreateKey()
        return VaultKeyMaterial(keyId: keyId, masterKeyData: keyData)
    }

    public func keyMaterial(for keyId: String) async throws -> VaultKeyMaterial {
        guard keyId == self.keyId else {
            throw VaultError.cryptoFailure("Unknown keyId: \(keyId)")
        }
        let keyData = try loadOrCreateKey()
        return VaultKeyMaterial(keyId: keyId, masterKeyData: keyData)
    }

    private func loadOrCreateKey() throws -> Data {
        if let existing = try loadKey() {
            return existing
        }
        let key = Self.randomKey()
        try storeKey(key)
        if let stored = try loadKey() {
            return stored
        }
        throw VaultError.cryptoFailure("Failed to persist keychain key")
    }

    private func loadKey() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess {
            return item as? Data
        }
        if status == errSecItemNotFound {
            return nil
        }
        throw VaultError.cryptoFailure("Keychain read failed: \(status)")
    }

    private func storeKey(_ key: Data) throws {
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess || status == errSecDuplicateItem {
            return
        }
        throw VaultError.cryptoFailure("Keychain write failed: \(status)")
    }

    private static func randomKey() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}
#else

/// File-backed key provider for non-Apple platforms.
public actor KeychainVaultKeyProvider: VaultKeyProvider {
    private let keyId: String
    private let keyURL: URL

    public init(
        service: String = "AnigmaVault",
        account: String = "default",
        keyId: String = "keychain-default"
    ) {
        self.keyId = keyId
        let safeService = Self.sanitize(service)
        let safeAccount = Self.sanitize(account)
        let baseDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".anigma", isDirectory: true)
            .appendingPathComponent("vault", isDirectory: true)
            .appendingPathComponent("keys", isDirectory: true)
        self.keyURL = baseDir.appendingPathComponent("\(safeService)_\(safeAccount).key")
    }

    public func currentKeyMaterial() async throws -> VaultKeyMaterial {
        let keyData = try loadOrCreateKey()
        return VaultKeyMaterial(keyId: keyId, masterKeyData: keyData)
    }

    public func keyMaterial(for keyId: String) async throws -> VaultKeyMaterial {
        guard keyId == self.keyId else {
            throw VaultError.cryptoFailure("Unknown keyId: \(keyId)")
        }
        let keyData = try loadOrCreateKey()
        return VaultKeyMaterial(keyId: keyId, masterKeyData: keyData)
    }

    private func loadOrCreateKey() throws -> Data {
        if let existing = try loadKey() {
            return existing
        }
        let key = Self.randomKey()
        try storeKey(key)
        if let stored = try loadKey() {
            return stored
        }
        throw VaultError.cryptoFailure("Failed to persist vault key")
    }

    private func loadKey() throws -> Data? {
        if FileManager.default.fileExists(atPath: keyURL.path) {
            return try Data(contentsOf: keyURL)
        }
        return nil
    }

    private func storeKey(_ key: Data) throws {
        let dir = keyURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try key.write(to: keyURL, options: [.atomic])
    }

    private static func randomKey() -> Data {
        var bytes = [UInt8]()
        bytes.reserveCapacity(32)
        for _ in 0..<32 {
            bytes.append(UInt8.random(in: UInt8.min...UInt8.max))
        }
        return Data(bytes)
    }

    private static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let filtered = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        return String(filtered)
    }
}
#endif

/// Default key provider selector that falls back to in-memory keys when needed.
public struct DefaultVaultKeyProvider {
    public static func make() -> VaultKeyProvider {
        #if canImport(Security)
        return KeychainVaultKeyProvider()
        #else
        return InMemoryVaultKeyProvider()
        #endif
    }
}
