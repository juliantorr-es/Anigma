//
//  VaultCrypto.swift
//  StorageCore
//
//  Cryptographic helpers for envelope encryption.
//

import CryptoKit
import Foundation
import Security

/// Key material for vault encryption.
public struct VaultKeyMaterial: Sendable {
    public let keyId: String
    public let masterKeyData: Data

    public init(keyId: String, masterKeyData: Data) {
        self.keyId = keyId
        self.masterKeyData = masterKeyData
    }
}

/// Key provider used by vault encryption.
public protocol VaultKeyProvider: Sendable {
    func currentKeyMaterial() async throws -> VaultKeyMaterial
    func keyMaterial(for keyId: String) async throws -> VaultKeyMaterial
}

/// In-memory key provider for tests or local mock mode.
public actor InMemoryVaultKeyProvider: VaultKeyProvider {
    private var keys: [String: Data]
    private let currentKeyId: String

    public init() {
        let keyId = "vault-key-1"
        self.currentKeyId = keyId
        self.keys = [keyId: Self.randomKey()]
    }

    public func currentKeyMaterial() async throws -> VaultKeyMaterial {
        guard let keyData = keys[currentKeyId] else {
            throw VaultError.cryptoFailure("Missing current key material")
        }
        return VaultKeyMaterial(keyId: currentKeyId, masterKeyData: keyData)
    }

    public func keyMaterial(for keyId: String) async throws -> VaultKeyMaterial {
        guard let keyData = keys[keyId] else {
            throw VaultError.cryptoFailure("Unknown keyId: \(keyId)")
        }
        return VaultKeyMaterial(keyId: keyId, masterKeyData: keyData)
    }

    private static func randomKey() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}

struct VaultEnvelopeHeader: Codable {
    let version: Int
    let algorithm: String
    let keyId: String
    let nonce: Data
    let plaintextSize: Int
}

/// Envelope encryption helpers for vault blobs.
public enum VaultCrypto {
    public static func encrypt(
        plaintext: Data,
        hashHex: String,
        keyMaterial: VaultKeyMaterial
    ) throws -> Data {
        let key = deriveKey(masterKeyData: keyMaterial.masterKeyData, hashHex: hashHex)
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
        guard let combined = sealed.combined else {
            throw VaultError.cryptoFailure("Missing sealed payload")
        }

        let header = VaultEnvelopeHeader(
            version: 1,
            algorithm: "AES-GCM",
            keyId: keyMaterial.keyId,
            nonce: Data(nonce),
            plaintextSize: plaintext.count
        )
        let headerData = try JSONEncoder().encode(header)
        var output = Data()
        var headerLength = UInt32(headerData.count).bigEndian
        withUnsafeBytes(of: &headerLength) { output.append(contentsOf: $0) }
        output.append(headerData)
        output.append(combined)
        return output
    }

    public static func decrypt(
        envelope: Data,
        hashHex: String,
        keyMaterial: VaultKeyMaterial
    ) throws -> Data {
        guard envelope.count > 4 else {
            throw VaultError.cryptoFailure("Invalid envelope length")
        }
        let headerLength = envelope.withUnsafeBytes { buffer -> UInt32 in
            guard let base = buffer.baseAddress else { return 0 }
            return base.load(as: UInt32.self).bigEndian
        }
        let headerStart = 4
        let headerEnd = headerStart + Int(headerLength)
        guard envelope.count > headerEnd else {
            throw VaultError.cryptoFailure("Envelope header out of bounds")
        }
        let headerData = envelope.subdata(in: headerStart..<headerEnd)
        let header = try JSONDecoder().decode(VaultEnvelopeHeader.self, from: headerData)
        guard header.keyId == keyMaterial.keyId else {
            throw VaultError.cryptoFailure("Key mismatch for envelope")
        }
        let combined = envelope.subdata(in: headerEnd..<envelope.count)
        let key = deriveKey(masterKeyData: keyMaterial.masterKeyData, hashHex: hashHex)
        let sealed = try AES.GCM.SealedBox(combined: combined)
        let plaintext = try AES.GCM.open(sealed, using: key)
        if plaintext.count != header.plaintextSize {
            throw VaultError.cryptoFailure("Plaintext size mismatch")
        }
        return plaintext
    }

    private static func deriveKey(masterKeyData: Data, hashHex: String) -> SymmetricKey {
        let salt = Data(hashHex.utf8)
        let masterKey = SymmetricKey(data: masterKeyData)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            salt: salt,
            info: Data("anigma-vault".utf8),
            outputByteCount: 32
        )
    }
}
