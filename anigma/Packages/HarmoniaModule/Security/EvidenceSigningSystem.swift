//
//  EvidenceSigningSystem.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import AnigmaCore
import ContractsCore
import CryptoKit
import DatabaseCore
import Foundation

/// Cryptographic signing and key management for evidence authenticity
/// Turns "unchanged since captured" into "captured correctly by authorized actor"
public actor EvidenceSigningSystem {
    private let dbActor: any DatabaseExecutor
    private var keyProvider: SigningKeyProvider
    private var keyRotationSchedule: KeyRotationSchedule
    private var keyMetadata: SigningKeyMetadata

    public init(dbActor: any DatabaseExecutor) throws {
        self.dbActor = dbActor
        self.keyProvider = try Self.loadOrCreateSigningKeyProvider()
        self.keyRotationSchedule = KeyRotationSchedule.default
        self.keyMetadata = try Self.loadKeyMetadata()
    }

    // MARK: - Evidence Head Signing

    /// Sign current evidence chain head to establish authenticity
    public func signEvidenceHead(
        signerIdentity: String,
        signerRole: String,
        authorizationReference: String? = nil,
        hardwareAttestation: String? = nil
    ) async throws -> ContractsCore.EvidenceSignature {
        // Get current evidence chain head
        let headInfo = try await getEvidenceHead()

        // Create signature payload
        let signaturePayload = SignaturePayload(
            evidenceHead: headInfo,
            signerIdentity: signerIdentity,
            signerRole: signerRole,
            signingTimestamp: Int(Date().timeIntervalSince1970),
            authorizationReference: authorizationReference,
            hardwareAttestation: hardwareAttestation,
            keyFingerprint: keyProvider.fingerprint
        )

        // Generate digital signature
        let payloadData = try JSONEncoder().encode(signaturePayload)
        let signature = try keyProvider.sign(payloadData)
        let signatureHex = hexString(from: signature)

        // Create signature record
        let evidenceSignature = ContractsCore.EvidenceSignature(
            signatureId: UUID().uuidString.lowercased(),
            evidenceHeadHash: headInfo.headHash,
            signerIdentity: signerIdentity,
            signerRole: signerRole,
            signingTimestamp: signaturePayload.signingTimestamp,
            authorizationReference: authorizationReference,
            keyFingerprint: keyProvider.fingerprint,
            signatureData: signatureHex,
            verificationStatus: .verified
        )

        // Store signature
        try await storeSignature(evidenceSignature)

        return evidenceSignature
    }

    /// Sign evidence bundle manifest for export authenticity
    public func signBundleManifest(
        bundleId: String,
        manifestData: Data,
        signerIdentity: String,
        signerRole: String,
        exportPurpose: String
    ) async throws -> ContractsCore.BundleSignature {
        let bundlePayload = BundleSignaturePayload(
            bundleId: bundleId,
            manifestHash: sha256Hex(manifestData),
            signerIdentity: signerIdentity,
            signerRole: signerRole,
            exportPurpose: exportPurpose,
            signingTimestamp: Int(Date().timeIntervalSince1970),
            keyFingerprint: keyProvider.fingerprint
        )

        let payloadData = try JSONEncoder().encode(bundlePayload)
        let signature = try keyProvider.sign(payloadData)
        let signatureHex = hexString(from: signature)

        let bundleSignature = ContractsCore.BundleSignature(
            signatureId: UUID().uuidString.lowercased(),
            bundleId: bundleId,
            manifestHash: bundlePayload.manifestHash,
            signerIdentity: signerIdentity,
            signerRole: signerRole,
            exportPurpose: exportPurpose,
            signingTimestamp: bundlePayload.signingTimestamp,
            keyFingerprint: keyProvider.fingerprint,
            signatureData: signatureHex
        )

        try await storeBundleSignature(bundleSignature)

        return bundleSignature
    }

    /// Verify evidence chain authenticity
    public func verifyEvidenceAuthenticity(
        evidenceHeadHash: String,
        signature: ContractsCore.EvidenceSignature
    ) async throws -> ContractsCore.VerificationResult {
        // Recreate signature payload from stored evidence
        let headInfo = try await getEvidenceHeadInfo(hash: evidenceHeadHash)
        let recreatedPayload = SignaturePayload(
            evidenceHead: headInfo,
            signerIdentity: signature.signerIdentity,
            signerRole: signature.signerRole,
            signingTimestamp: signature.signingTimestamp,
            authorizationReference: signature.authorizationReference,
            hardwareAttestation: signature.hardwareAttestation,
            keyFingerprint: signature.keyFingerprint
        )

        // Verify signature using stored public key
        let payloadData = try JSONEncoder().encode(recreatedPayload)
        let publicKey = try getPublicKey(for: signature.keyFingerprint)
        let signatureData = try dataFromHexString(signature.signatureData)

        let isValid = publicKey.isValidSignature(signatureData, for: payloadData)

        // Check key revocation status
        let keyStatus = try await getKeyStatus(fingerprint: signature.keyFingerprint)

        return ContractsCore.VerificationResult(
            isValid: isValid && keyStatus.isActive,
            signerIdentity: signature.signerIdentity,
            signerRole: signature.signerRole,
            keyFingerprint: signature.keyFingerprint,
            keyStatus: keyStatus,
            verificationTimestamp: Int(Date().timeIntervalSince1970),
            verificationDetails: isValid
                ? "Signature valid and key active" : "Invalid signature or revoked key"
        )
    }

    /// Verify bundle manifest authenticity
    public func verifyBundleAuthenticity(
        bundleId: String,
        manifestData: Data,
        signature: ContractsCore.BundleSignature
    ) async throws -> ContractsCore.VerificationResult {
        // Recreate bundle signature payload
        let recreatedPayload = BundleSignaturePayload(
            bundleId: bundleId,
            manifestHash: sha256Hex(manifestData),
            signerIdentity: signature.signerIdentity,
            signerRole: signature.signerRole,
            exportPurpose: signature.exportPurpose,
            signingTimestamp: signature.signingTimestamp,
            keyFingerprint: signature.keyFingerprint
        )

        // Verify signature
        let payloadData = try JSONEncoder().encode(recreatedPayload)
        let publicKey = try getPublicKey(for: signature.keyFingerprint)
        let signatureData = try dataFromHexString(signature.signatureData)

        let isValid = publicKey.isValidSignature(signatureData, for: payloadData)
        let keyStatus = try await getKeyStatus(fingerprint: signature.keyFingerprint)

        return ContractsCore.VerificationResult(
            isValid: isValid && keyStatus.isActive,
            signerIdentity: signature.signerIdentity,
            signerRole: signature.signerRole,
            keyFingerprint: signature.keyFingerprint,
            keyStatus: keyStatus,
            verificationTimestamp: Int(Date().timeIntervalSince1970),
            verificationDetails: isValid ? "Bundle signature valid" : "Invalid bundle signature"
        )
    }

    // MARK: - Key Management

    /// Rotate signing key according to schedule
    public func rotateSigningKey(reason: String, authorizedBy: String) async throws {
        let newPrivateKey = P256.Signing.PrivateKey()
        let newProvider = try P256SigningKeyProvider(privateKey: newPrivateKey)
        let newFingerprint = newProvider.fingerprint

        try await deprecateCurrentKey(reason: reason, authorizedBy: authorizedBy)

        let newKeyMetadata = SigningKeyMetadata(
            keyFingerprint: newFingerprint,
            algorithm: "P256",
            created: Int(Date().timeIntervalSince1970),
            createdBy: authorizedBy,
            status: .active,
            rotationReason: reason,
            lastRotationAt: Int(Date().timeIntervalSince1970)
        )

        try await storeKeyMetadata(newKeyMetadata)
        try Self.persistPrivateKey(newPrivateKey, to: ".accessum-artifacts/evidence_signing_key")

        self.keyMetadata = newKeyMetadata
        self.keyProvider = newProvider

        _ = try await signEvidenceHead(
            signerIdentity: authorizedBy,
            signerRole: "key_administrator",
            authorizationReference: "key_rotation_\(newFingerprint)"
        )
    }

    /// Revoke compromised key
    public func revokeKey(
        fingerprint: String,
        reason: String,
        authorizedBy: String,
        incidentReference: String? = nil
    ) async throws {
        try await markKeyRevoked(
            fingerprint: fingerprint,
            reason: reason,
            authorizedBy: authorizedBy,
            incidentReference: incidentReference
        )

        // Log revocation event
        try await logKeyOperation(
            operation: "key_revocation",
            keyFingerprint: fingerprint,
            reason: reason,
            authorizedBy: authorizedBy,
            incidentReference: incidentReference
        )
    }

    // MARK: - Private Methods

    private static func loadOrCreateSigningKeyProvider() throws -> SigningKeyProvider {
        let keyPath = ".accessum-artifacts/evidence_signing_key"
        let keyURL = URL(fileURLWithPath: keyPath)

        if FileManager.default.fileExists(atPath: keyPath) {
            let keyData = try Data(contentsOf: keyURL)
            return try P256SigningKeyProvider(rawRepresentation: keyData)
        }

        let privateKey = P256.Signing.PrivateKey()
        try persistPrivateKey(privateKey, to: keyPath)
        return try P256SigningKeyProvider(privateKey: privateKey)
    }

    private static func persistPrivateKey(_ privateKey: P256.Signing.PrivateKey, to path: String)
        throws {
        let directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        let keyData = privateKey.rawRepresentation
        try keyData.write(to: URL(fileURLWithPath: path))

        let attributes: [FileAttributeKey: Any] = [
            FileAttributeKey.posixPermissions: 0o400,
            FileAttributeKey.immutable: true
        ]
        try? FileManager.default.setAttributes(attributes, ofItemAtPath: path)
    }

    private static func loadKeyMetadata() throws -> SigningKeyMetadata {
        let metadataPath = ".accessum-artifacts/key_metadata.json"

        if FileManager.default.fileExists(atPath: metadataPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: metadataPath))
            return try JSONDecoder().decode(SigningKeyMetadata.self, from: data)
        } else {
            // Create default metadata
            return SigningKeyMetadata(
                keyFingerprint: "default",
                algorithm: "P256",
                created: Int(Date().timeIntervalSince1970),
                createdBy: "system",
                status: .active,
                rotationReason: "initial_key",
                lastRotationAt: Int(Date().timeIntervalSince1970)
            )
        }
    }

    private func getEvidenceHead() async throws -> ContractsCore.EvidenceHeadInfo {
        let rows = try await dbActor.query(
            """
                SELECT event_id, head_hash, timestamp, actor
                FROM evidence_chain
                ORDER BY sequence_number DESC
                LIMIT 1
            """)

        guard let row = rows.first else {
            throw SigningError.evidenceChainEmpty
        }

        return ContractsCore.EvidenceHeadInfo(
            eventId: row["event_id"]?.asString ?? "",
            headHash: row["head_hash"]?.asString ?? "",
            timestamp: row["timestamp"]?.asInt ?? 0,
            lastActor: row["actor"]?.asString ?? ""
        )
    }

    private func getEvidenceHeadInfo(hash: String) async throws -> ContractsCore.EvidenceHeadInfo {
        let rows = try await dbActor.query(
            """
                SELECT event_id, head_hash, timestamp, actor
                FROM evidence_chain
                WHERE head_hash = ?
                LIMIT 1
            """, parameters: [dbp(hash)])

        guard let row = rows.first else {
            throw SigningError.evidenceHeadNotFound
        }

        return ContractsCore.EvidenceHeadInfo(
            eventId: row["event_id"]?.asString ?? "",
            headHash: row["head_hash"]?.asString ?? "",
            timestamp: row["timestamp"]?.asInt ?? 0,
            lastActor: row["actor"]?.asString ?? ""
        )
    }

    private func getPublicKey(for fingerprint: String) throws -> SigningKeyPublic {
        guard fingerprint == keyProvider.fingerprint else {
            throw SigningError.signatureVerificationFailed
        }

        return try keyProvider.publicKey()
    }

    private func getKeyStatus(fingerprint: String) async throws -> SigningKeyStatus {
        let rows = try await dbActor.query(
            """
                SELECT status, revoked_at, revocation_reason
                FROM signing_keys
                WHERE fingerprint = ?
                ORDER BY created DESC
                LIMIT 1
            """, parameters: [dbp(fingerprint)])

        guard let row = rows.first else {
            return SigningKeyStatus(
                status: .revoked, revokedAt: nil, revocationReason: "Key not found")
        }

        let statusString = row["status"]?.asString ?? KeyStatusEnum.revoked.rawValue
        let status = KeyStatusEnum(rawValue: statusString) ?? .revoked
        let revokedAt = row["revoked_at"]?.asInt
        let revocationReason = row["revocation_reason"]?.asString

        return SigningKeyStatus(
            status: status,
            revokedAt: revokedAt,
            revocationReason: revocationReason
        )
    }

    private func storeSignature(_ signature: ContractsCore.EvidenceSignature) async throws {
        try await dbActor.execute(
            """
                INSERT INTO evidence_signatures (
                    signature_id, evidence_head_hash, signer_identity, signer_role,
                    signing_timestamp, authorization_reference, key_fingerprint,
                    signature_data, verification_status, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                dbp(signature.signatureId),
                dbp(signature.evidenceHeadHash),
                dbp(signature.signerIdentity),
                dbp(signature.signerRole),
                dbp(signature.signingTimestamp),
                dbp(signature.authorizationReference),
                dbp(signature.keyFingerprint),
                dbp(signature.signatureData),
                dbp(signature.verificationStatus.rawValue),
                dbp(Int(Date().timeIntervalSince1970))
            ])
    }

    private func storeBundleSignature(_ signature: ContractsCore.BundleSignature) async throws {
        try await dbActor.execute(
            """
                INSERT INTO bundle_signatures (
                    signature_id, bundle_id, manifest_hash, signer_identity, signer_role,
                    export_purpose, signing_timestamp, key_fingerprint, signature_data
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                dbp(signature.signatureId),
                dbp(signature.bundleId),
                dbp(signature.manifestHash),
                dbp(signature.signerIdentity),
                dbp(signature.signerRole),
                dbp(signature.exportPurpose),
                dbp(signature.signingTimestamp),
                dbp(signature.keyFingerprint),
                dbp(signature.signatureData)
            ])
    }

    private func deprecateCurrentKey(reason: String, authorizedBy: String) async throws {
        try await dbActor.execute(
            """
                UPDATE signing_keys
                SET status = 'deprecated', deprecated_at = ?, deprecation_reason = ?
                WHERE status = 'active'
            """, parameters: [dbp(Int(Date().timeIntervalSince1970)), dbp(reason)])
    }

    private func markKeyRevoked(
        fingerprint: String,
        reason: String,
        authorizedBy: String,
        incidentReference: String?
    ) async throws {
        try await dbActor.execute(
            """
                UPDATE signing_keys
                SET status = 'revoked', revoked_at = ?, revocation_reason = ?, incident_reference = ?
                WHERE fingerprint = ?
            """,
            parameters: [
                dbp(Int(Date().timeIntervalSince1970)),
                dbp(reason),
                dbp(incidentReference),
                dbp(fingerprint)
            ])
    }

    private func storeKeyMetadata(_ metadata: SigningKeyMetadata) async throws {
        try await dbActor.execute(
            """
                INSERT INTO signing_keys (
                    fingerprint, algorithm, created, created_by, status,
                    rotation_reason, last_rotation_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                dbp(metadata.keyFingerprint),
                dbp(metadata.algorithm),
                dbp(metadata.created),
                dbp(metadata.createdBy),
                dbp(metadata.status.rawValue),
                dbp(metadata.rotationReason),
                dbp(metadata.lastRotationAt)
            ])
    }

    private func logKeyOperation(
        operation: String,
        keyFingerprint: String,
        reason: String,
        authorizedBy: String,
        incidentReference: String?
    ) async throws {
        try await dbActor.execute(
            """
                INSERT INTO key_management_events (
                    operation, key_fingerprint, reason, authorized_by,
                    incident_reference, timestamp
                ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                dbp(operation),
                dbp(keyFingerprint),
                dbp(reason),
                dbp(authorizedBy),
                dbp(incidentReference),
                dbp(Int(Date().timeIntervalSince1970))
            ])
    }

    // MARK: - Signing Key Abstractions

    protocol SigningKeyProvider {
        var fingerprint: String { get }
        func sign(_ data: Data) throws -> Data
        func publicKey() throws -> SigningKeyPublic
    }

    protocol SigningKeyPublic {
        var rawRepresentation: Data { get }
        func isValidSignature(_ signature: Data, for data: Data) -> Bool
    }

    struct P256SigningKeyProvider: SigningKeyProvider {
        private let privateKey: P256.Signing.PrivateKey
        let fingerprint: String

        init(privateKey: P256.Signing.PrivateKey) throws {
            self.privateKey = privateKey
            self.fingerprint = Self.fingerprint(for: privateKey.publicKey)
        }

        init(rawRepresentation: Data) throws {
            let privateKey = try P256.Signing.PrivateKey(rawRepresentation: rawRepresentation)
            try self.init(privateKey: privateKey)
        }

        func sign(_ data: Data) throws -> Data {
            return try privateKey.signature(for: data).derRepresentation
        }

        func publicKey() throws -> SigningKeyPublic {
            return P256SigningPublicKey(publicKey: privateKey.publicKey)
        }

        private static func fingerprint(for publicKey: P256.Signing.PublicKey) -> String {
            let digest = SHA256.hash(data: publicKey.rawRepresentation)
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        }
    }

    struct P256SigningPublicKey: SigningKeyPublic {
        let publicKey: P256.Signing.PublicKey

        var rawRepresentation: Data {
            publicKey.rawRepresentation
        }

        func isValidSignature(_ signature: Data, for data: Data) -> Bool {
            guard let ecdsa = try? P256.Signing.ECDSASignature(derRepresentation: signature) else {
                return false
            }

            return publicKey.isValidSignature(ecdsa, for: data)
        }
    }

    struct KeyRotationSchedule {
        let maxAgeDays: Int
        let maxSignatures: Int
        let automaticRotation: Bool

        static let `default` = KeyRotationSchedule(
            maxAgeDays: 365,
            maxSignatures: 100000,
            automaticRotation: true
        )
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private func dataFromHexString(_ hex: String) throws -> Data {
        var data = Data()
        var index = hex.startIndex

        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            guard nextIndex > index else {
                throw SigningError.signatureVerificationFailed
            }

            let byteString = hex[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else {
                throw SigningError.signatureVerificationFailed
            }

            data.append(byte)
            index = nextIndex
        }

        return data
    }
}

// MARK: - Data Models

struct SignaturePayload: Codable {
    let evidenceHead: ContractsCore.EvidenceHeadInfo
    let signerIdentity: String
    let signerRole: String
    let signingTimestamp: Int
    let authorizationReference: String?
    let hardwareAttestation: String?
    let keyFingerprint: String
}

struct BundleSignaturePayload: Codable {
    let bundleId: String
    let manifestHash: String
    let signerIdentity: String
    let signerRole: String
    let exportPurpose: String
    let signingTimestamp: Int
    let keyFingerprint: String
}

struct SigningKeyMetadata: Codable {
    let keyFingerprint: String
    let algorithm: String
    let created: Int
    let createdBy: String
    let status: KeyStatusEnum
    let rotationReason: String
    let lastRotationAt: Int
}

// MARK: - Error Types

enum SigningError: Error, LocalizedError {
    case noSigningKey
    case evidenceChainEmpty
    case evidenceHeadNotFound
    case keyCreationFailed
    case keyRotationFailed
    case keyRevocationFailed
    case signatureVerificationFailed

    public var errorDescription: String? {
        switch self {
        case .noSigningKey:
            return "No signing key available"
        case .evidenceChainEmpty:
            return "Evidence chain is empty"
        case .evidenceHeadNotFound:
            return "Evidence head not found"
        case .keyCreationFailed:
            return "Failed to create signing key"
        case .keyRotationFailed:
            return "Key rotation failed"
        case .keyRevocationFailed:
            return "Key revocation failed"
        case .signatureVerificationFailed:
            return "Signature verification failed"
        }
    }
}
