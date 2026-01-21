//
//  CryptographicSecurity.swift
//  AnigmaCore
//
//  Cryptographic security infrastructure for the Anigma platform.
//  Provides secure key management, encryption, and cryptographic verification.
//
//  This addresses cryptographic best practices:
//  - FIPS 140-2 compatible operations where possible
//  - Secure key derivation and storage
//  - Cryptographic audit trails
//  - Hardware security module (HSM) integration points
//
//  Note: Full FIPS 140-2 Level 3 compliance requires hardware HSMs.
//  This implementation provides software-based cryptographic operations
//  using Apple's CryptoKit framework, which uses FIPS-validated modules
//  on supported hardware.
//

import Foundation
import ContractsCore
import CryptoKit

// MARK: - Key Types

/// Types of cryptographic keys.
public enum KeyType: String, Sendable, Codable {
    /// Master encryption key.
    case masterKey = "MASTER_KEY"

    /// Data encryption key.
    case dataKey = "DATA_KEY"

    /// Signing key.
    case signingKey = "SIGNING_KEY"

    /// Key encryption key (for wrapping other keys).
    case keyEncryptionKey = "KEK"

    /// Session key (temporary).
    case sessionKey = "SESSION_KEY"
}

/// Key usage constraints.
public struct KeyUsage: OptionSet, Sendable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let encrypt = KeyUsage(rawValue: 1 << 0)
    public static let decrypt = KeyUsage(rawValue: 1 << 1)
    public static let sign = KeyUsage(rawValue: 1 << 2)
    public static let verify = KeyUsage(rawValue: 1 << 3)
    public static let wrapKey = KeyUsage(rawValue: 1 << 4)
    public static let unwrapKey = KeyUsage(rawValue: 1 << 5)
    public static let derive = KeyUsage(rawValue: 1 << 6)

    public static let encryptDecrypt: KeyUsage = [.encrypt, .decrypt]
    public static let signVerify: KeyUsage = [.sign, .verify]
    public static let all: KeyUsage = [.encrypt, .decrypt, .sign, .verify, .wrapKey, .unwrapKey, .derive]
}

// MARK: - Key Metadata

/// Metadata for a managed key.
public struct KeyMetadata: Sendable, Codable, Identifiable {
    public let id: UUID

    /// Human-readable name.
    public let name: String

    /// Type of key.
    public let keyType: KeyType

    /// Allowed usages.
    public let usage: KeyUsage

    /// Algorithm used.
    public let algorithm: String

    /// Key size in bits.
    public let keySizeBits: Int

    /// When the key was created.
    public let createdAt: Date

    /// When the key expires (nil = no expiration).
    public let expiresAt: Date?

    /// Who created the key.
    public let createdBy: String

    /// Version number for key rotation.
    public let version: Int

    /// Whether the key is currently active.
    public var isActive: Bool

    /// Hash of the public key (for asymmetric keys) or key ID.
    public let keyFingerprint: String

    /// Parent key ID (for derived keys).
    public let parentKeyId: UUID?

    public init(
        id: UUID = UUID(),
        name: String,
        keyType: KeyType,
        usage: KeyUsage,
        algorithm: String,
        keySizeBits: Int,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        createdBy: String,
        version: Int = 1,
        isActive: Bool = true,
        keyFingerprint: String,
        parentKeyId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.keyType = keyType
        self.usage = usage
        self.algorithm = algorithm
        self.keySizeBits = keySizeBits
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.createdBy = createdBy
        self.version = version
        self.isActive = isActive
        self.keyFingerprint = keyFingerprint
        self.parentKeyId = parentKeyId
    }

    public var isExpired: Bool {
        if let expiresAt = expiresAt {
            return Date() >= expiresAt
        }
        return false
    }
}

// MARK: - Encryption Result

/// Result of an encryption operation.
public struct EncryptionResult: Sendable {
    /// The encrypted ciphertext.
    public let ciphertext: Data

    /// The nonce/IV used.
    public let nonce: Data

    /// Authentication tag (for AEAD).
    public let tag: Data

    /// ID of the key used.
    public let keyId: UUID

    /// Algorithm used.
    public let algorithm: String

    public init(
        ciphertext: Data,
        nonce: Data,
        tag: Data,
        keyId: UUID,
        algorithm: String
    ) {
        self.ciphertext = ciphertext
        self.nonce = nonce
        self.tag = tag
        self.keyId = keyId
        self.algorithm = algorithm
    }

    /// Serializes to a combined format.
    public func serialize() -> Data {
        var data = Data()

        // Format: keyId (16 bytes) + nonce length (4 bytes) + nonce + tag length (4 bytes) + tag + ciphertext
        withUnsafeBytes(of: keyId.uuid) { data.append(contentsOf: $0) }

        var nonceLen = UInt32(nonce.count)
        withUnsafeBytes(of: &nonceLen) { data.append(contentsOf: $0) }
        data.append(nonce)

        var tagLen = UInt32(tag.count)
        withUnsafeBytes(of: &tagLen) { data.append(contentsOf: $0) }
        data.append(tag)

        data.append(ciphertext)

        return data
    }

    /// Deserializes from combined format.
    public static func deserialize(_ data: Data) throws -> (keyId: UUID, nonce: Data, tag: Data, ciphertext: Data) {
        guard data.count >= 24 else {  // 16 + 4 + 4 minimum
            throw CryptoError.invalidFormat("Data too short")
        }

        var offset = 0

        // Read key ID
        let uuidBytes = data.subdata(in: offset..<(offset + 16))
        let uuid = uuidBytes.withUnsafeBytes { $0.load(as: uuid_t.self) }
        let keyId = UUID(uuid: uuid)
        offset += 16

        // Read nonce
        let nonceLen = data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: UInt32.self) }
        offset += 4
        let nonce = data.subdata(in: offset..<(offset + Int(nonceLen)))
        offset += Int(nonceLen)

        // Read tag
        let tagLen = data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: UInt32.self) }
        offset += 4
        let tag = data.subdata(in: offset..<(offset + Int(tagLen)))
        offset += Int(tagLen)

        // Rest is ciphertext
        let ciphertext = data.subdata(in: offset..<data.count)

        return (keyId, nonce, tag, ciphertext)
    }
}

// MARK: - Signature Result

/// Result of a signing operation.
public struct SignatureResult: Sendable {
    /// The signature.
    public let signature: Data

    /// ID of the key used.
    public let keyId: UUID

    /// Algorithm used.
    public let algorithm: String

    /// Timestamp of signing.
    public let signedAt: Date

    public init(
        signature: Data,
        keyId: UUID,
        algorithm: String,
        signedAt: Date = Date()
    ) {
        self.signature = signature
        self.keyId = keyId
        self.algorithm = algorithm
        self.signedAt = signedAt
    }
}

// MARK: - Key Manager

/// Manages cryptographic keys with secure storage.
public actor KeyManager {
    private var keys: [UUID: SymmetricKey] = [:]
    private var metadata: [UUID: KeyMetadata] = [:]
    private var signingKeys: [UUID: Curve25519.Signing.PrivateKey] = [:]
    private var verifyingKeys: [UUID: Curve25519.Signing.PublicKey] = [:]
    private var auditLog: (any AuditLogging)?

    public init() {}

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Generates a new symmetric key.
    public func generateSymmetricKey(
        name: String,
        keyType: KeyType = .dataKey,
        usage: KeyUsage = .encryptDecrypt,
        expiresAt: Date? = nil,
        createdBy: String
    ) async -> KeyMetadata {
        let key = SymmetricKey(size: .bits256)
        let id = UUID()

        // Compute fingerprint
        let fingerprint = key.withUnsafeBytes { bytes in
            let hash = SHA256.hash(data: bytes)
            return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16)
        }

        let meta = KeyMetadata(
            id: id,
            name: name,
            keyType: keyType,
            usage: usage,
            algorithm: "AES-256-GCM",
            keySizeBits: 256,
            expiresAt: expiresAt,
            createdBy: createdBy,
            keyFingerprint: String(fingerprint)
        )

        keys[id] = key
        metadata[id] = meta

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.dataCreated,
                principal: createdBy,
                module: "CryptographicSecurity",
                description: "Generated symmetric key: \(name)",
                metadata: [
                    "key_id": id.uuidString,
                    "key_type": keyType.rawValue,
                    "fingerprint": String(fingerprint)
                ]
            )
        }

        return meta
    }

    /// Generates a new signing key pair.
    public func generateSigningKeyPair(
        name: String,
        expiresAt: Date? = nil,
        createdBy: String
    ) async -> KeyMetadata {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let id = UUID()

        // Compute fingerprint from public key
        let fingerprint = SHA256.hash(data: publicKey.rawRepresentation)
            .compactMap { String(format: "%02x", $0) }.joined().prefix(16)

        let meta = KeyMetadata(
            id: id,
            name: name,
            keyType: .signingKey,
            usage: .signVerify,
            algorithm: "Ed25519",
            keySizeBits: 256,
            expiresAt: expiresAt,
            createdBy: createdBy,
            keyFingerprint: String(fingerprint)
        )

        signingKeys[id] = privateKey
        verifyingKeys[id] = publicKey
        metadata[id] = meta

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.dataCreated,
                principal: createdBy,
                module: "CryptographicSecurity",
                description: "Generated signing key pair: \(name)",
                metadata: [
                    "key_id": id.uuidString,
                    "fingerprint": String(fingerprint)
                ]
            )
        }

        return meta
    }

    /// Derives a new key from an existing key.
    public func deriveKey(
        from parentId: UUID,
        name: String,
        context: Data,
        createdBy: String
    ) async throws -> KeyMetadata {
        guard let parentKey = keys[parentId] else {
            throw CryptoError.keyNotFound(parentId)
        }

        guard let parentMeta = metadata[parentId], parentMeta.usage.contains(.derive) else {
            throw CryptoError.operationNotAllowed("Key does not allow derivation")
        }

        // Use HKDF to derive new key
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: parentKey,
            info: context,
            outputByteCount: 32
        )

        let id = UUID()
        let fingerprint = derivedKey.withUnsafeBytes { bytes in
            let hash = SHA256.hash(data: bytes)
            return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16)
        }

        let meta = KeyMetadata(
            id: id,
            name: name,
            keyType: .dataKey,
            usage: .encryptDecrypt,
            algorithm: "AES-256-GCM",
            keySizeBits: 256,
            createdBy: createdBy,
            keyFingerprint: String(fingerprint),
            parentKeyId: parentId
        )

        keys[id] = derivedKey
        metadata[id] = meta

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.dataCreated,
                principal: createdBy,
                module: "CryptographicSecurity",
                description: "Derived key from \(parentMeta.name): \(name)",
                metadata: [
                    "key_id": id.uuidString,
                    "parent_key_id": parentId.uuidString,
                    "fingerprint": String(fingerprint)
                ]
            )
        }

        return meta
    }

    /// Encrypts data using a key.
    public func encrypt(
        data: Data,
        using keyId: UUID,
        authenticatedData: Data? = nil
    ) async throws -> EncryptionResult {
        guard let key = keys[keyId] else {
            throw CryptoError.keyNotFound(keyId)
        }

        guard let meta = metadata[keyId] else {
            throw CryptoError.keyNotFound(keyId)
        }

        guard meta.usage.contains(.encrypt) else {
            throw CryptoError.operationNotAllowed("Key does not allow encryption")
        }

        guard meta.isActive && !meta.isExpired else {
            throw CryptoError.keyExpiredOrInactive(keyId)
        }

        let nonce = AES.GCM.Nonce()
        let sealedBox: AES.GCM.SealedBox

        if let aad = authenticatedData {
            sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce, authenticating: aad)
        } else {
            sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        }

        return EncryptionResult(
            ciphertext: sealedBox.ciphertext,
            nonce: Data(nonce),
            tag: sealedBox.tag,
            keyId: keyId,
            algorithm: meta.algorithm
        )
    }

    /// Decrypts data using a key.
    public func decrypt(
        ciphertext: Data,
        nonce: Data,
        tag: Data,
        using keyId: UUID,
        authenticatedData: Data? = nil
    ) async throws -> Data {
        guard let key = keys[keyId] else {
            throw CryptoError.keyNotFound(keyId)
        }

        guard let meta = metadata[keyId] else {
            throw CryptoError.keyNotFound(keyId)
        }

        guard meta.usage.contains(.decrypt) else {
            throw CryptoError.operationNotAllowed("Key does not allow decryption")
        }

        guard meta.isActive && !meta.isExpired else {
            throw CryptoError.keyExpiredOrInactive(keyId)
        }

        let gcmNonce = try AES.GCM.Nonce(data: nonce)
        let sealedBox = try AES.GCM.SealedBox(nonce: gcmNonce, ciphertext: ciphertext, tag: tag)

        if let aad = authenticatedData {
            return try AES.GCM.open(sealedBox, using: key, authenticating: aad)
        } else {
            return try AES.GCM.open(sealedBox, using: key)
        }
    }

    /// Signs data using a signing key.
    public func sign(data: Data, using keyId: UUID) async throws -> SignatureResult {
        guard let key = signingKeys[keyId] else {
            throw CryptoError.keyNotFound(keyId)
        }

        guard let meta = metadata[keyId] else {
            throw CryptoError.keyNotFound(keyId)
        }

        guard meta.usage.contains(.sign) else {
            throw CryptoError.operationNotAllowed("Key does not allow signing")
        }

        guard meta.isActive && !meta.isExpired else {
            throw CryptoError.keyExpiredOrInactive(keyId)
        }

        let signature = try key.signature(for: data)

        return SignatureResult(
            signature: signature,
            keyId: keyId,
            algorithm: meta.algorithm
        )
    }

    /// Verifies a signature.
    public func verify(
        signature: Data,
        for data: Data,
        using keyId: UUID
    ) async throws -> Bool {
        guard let key = verifyingKeys[keyId] else {
            throw CryptoError.keyNotFound(keyId)
        }

        guard let meta = metadata[keyId] else {
            throw CryptoError.keyNotFound(keyId)
        }

        guard meta.usage.contains(.verify) else {
            throw CryptoError.operationNotAllowed("Key does not allow verification")
        }

        return key.isValidSignature(signature, for: data)
    }

    /// Gets key metadata.
    public func getMetadata(_ keyId: UUID) -> KeyMetadata? {
        metadata[keyId]
    }

    /// Lists all key metadata.
    public func listKeys(type: KeyType? = nil, activeOnly: Bool = true) -> [KeyMetadata] {
        var results = Array(metadata.values)

        if let type = type {
            results = results.filter { $0.keyType == type }
        }

        if activeOnly {
            results = results.filter { $0.isActive && !$0.isExpired }
        }

        return results.sorted { $0.createdAt > $1.createdAt }
    }

    /// Rotates a key (creates new version, marks old as inactive).
    public func rotateKey(_ keyId: UUID, rotatedBy: String) async throws -> KeyMetadata {
        guard let oldMeta = metadata[keyId] else {
            throw CryptoError.keyNotFound(keyId)
        }

        // Mark old key as inactive
        var updatedOldMeta = oldMeta
        updatedOldMeta.isActive = false
        metadata[keyId] = updatedOldMeta

        // Generate new key with incremented version
        let newMeta: KeyMetadata

        if oldMeta.keyType == .signingKey {
            newMeta = await generateSigningKeyPair(
                name: oldMeta.name,
                expiresAt: oldMeta.expiresAt,
                createdBy: rotatedBy
            )
        } else {
            newMeta = await generateSymmetricKey(
                name: oldMeta.name,
                keyType: oldMeta.keyType,
                usage: oldMeta.usage,
                expiresAt: oldMeta.expiresAt,
                createdBy: rotatedBy
            )
        }

        // Update version in new metadata
        // Note: In production, we'd track version properly
        metadata[newMeta.id] = newMeta

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.dataModified,
                principal: rotatedBy,
                module: "CryptographicSecurity",
                description: "Key rotated: \(oldMeta.name)",
                metadata: [
                    "old_key_id": keyId.uuidString,
                    "new_key_id": newMeta.id.uuidString,
                    "old_fingerprint": oldMeta.keyFingerprint,
                    "new_fingerprint": newMeta.keyFingerprint
                ]
            )
        }

        return newMeta
    }

    /// Destroys a key.
    public func destroyKey(_ keyId: UUID, destroyedBy: String, reason: String) async throws {
        guard let meta = metadata[keyId] else {
            throw CryptoError.keyNotFound(keyId)
        }

        // Remove key material
        keys.removeValue(forKey: keyId)
        signingKeys.removeValue(forKey: keyId)
        verifyingKeys.removeValue(forKey: keyId)

        // Mark metadata as inactive (keep for audit)
        var destroyedMeta = meta
        destroyedMeta.isActive = false
        metadata[keyId] = destroyedMeta

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.dataDeleted,
                principal: destroyedBy,
                module: "CryptographicSecurity",
                description: "Key destroyed: \(meta.name) - \(reason)",
                metadata: [
                    "key_id": keyId.uuidString,
                    "fingerprint": meta.keyFingerprint
                ]
            )
        }
    }
}

// MARK: - Crypto Errors

public enum CryptoError: Error, LocalizedError, Sendable {
    case keyNotFound(UUID)
    case keyExpiredOrInactive(UUID)
    case operationNotAllowed(String)
    case invalidFormat(String)
    case encryptionFailed(String)
    case decryptionFailed(String)
    case signatureFailed(String)
    case verificationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .keyNotFound(let id):
            return "Key not found: \(id)"
        case .keyExpiredOrInactive(let id):
            return "Key is expired or inactive: \(id)"
        case .operationNotAllowed(let reason):
            return "Operation not allowed: \(reason)"
        case .invalidFormat(let reason):
            return "Invalid format: \(reason)"
        case .encryptionFailed(let reason):
            return "Encryption failed: \(reason)"
        case .decryptionFailed(let reason):
            return "Decryption failed: \(reason)"
        case .signatureFailed(let reason):
            return "Signature failed: \(reason)"
        case .verificationFailed(let reason):
            return "Verification failed: \(reason)"
        }
    }
}

// MARK: - Secure Random

/// Secure random number generation.
public enum SecureRandom {
    /// Generates secure random bytes.
    public static func bytes(count: Int) -> Data {
        var data = Data(count: count)
        data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        return data
    }

    /// Generates a secure random UUID.
    public static func uuid() -> UUID {
        UUID()
    }

    /// Generates a secure random token string.
    public static func token(length: Int = 32) -> String {
        let data = bytes(count: length)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Hash Utilities

/// Cryptographic hash utilities.
public enum HashUtilities {
    /// Computes SHA-256 hash.
    public static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    /// Computes SHA-256 hash as hex string.
    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Computes SHA-512 hash.
    public static func sha512(_ data: Data) -> Data {
        Data(SHA512.hash(data: data))
    }

    /// Computes HMAC-SHA256.
    public static func hmacSHA256(data: Data, key: SymmetricKey) -> Data {
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(mac)
    }

    /// Verifies HMAC-SHA256.
    public static func verifyHMACSHA256(data: Data, mac: Data, key: SymmetricKey) -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: data, using: key)
    }
}
