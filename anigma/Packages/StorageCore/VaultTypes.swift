//
//  VaultTypes.swift
//  StorageCore
//
//  Core types for vault-backed artifact storage.
//

import Foundation

/// Artifact kinds stored in the vault.
public enum VaultArtifactKind: String, Codable, Sendable {
    case original
    case derived
    case receipt
    case preview
    case export
    case temp
}

/// Lightweight reference to a vault artifact.
public struct VaultArtifactRef: Codable, Sendable {
    /// Cryptographic hash of the artifact content (BLAKE3).
    public let hashHex: String
    public let byteLen: Int
    public let mime: String
    public let kind: VaultArtifactKind
    public let keyId: String
    public let objectRelpath: String
    public let previousReceiptHash: String?
    public let createdAt: Date

    public init(
        hashHex: String,
        byteLen: Int,
        mime: String,
        kind: VaultArtifactKind,
        keyId: String,
        objectRelpath: String,
        previousReceiptHash: String? = nil,
        createdAt: Date
    ) {
        self.hashHex = hashHex
        self.byteLen = byteLen
        self.mime = mime
        self.kind = kind
        self.keyId = keyId
        self.objectRelpath = objectRelpath
        self.previousReceiptHash = previousReceiptHash
        self.createdAt = createdAt
    }
}

/// Ticket describing a quarantined artifact awaiting promotion.
public struct QuarantineTicket: Codable, Sendable {
    public let ticketId: String
    public let hashHex: String
    public let byteLen: Int
    public let createdAt: Date

    public init(ticketId: String, hashHex: String, byteLen: Int, createdAt: Date) {
        self.ticketId = ticketId
        self.hashHex = hashHex
        self.byteLen = byteLen
        self.createdAt = createdAt
    }
}

/// Access decisions emitted by the vault authority.
public enum VaultDecision: String, Codable, Sendable {
    case allow
    case deny
}

/// CoreReceipt emitted for vault actions.
public struct VaultReceipt: Codable, Sendable {
    public let action: String
    public let decision: VaultDecision
    public let reason: String?
    public let hashHex: String?
    public let actorId: String?
    public let occurredAt: Date

    public init(
        action: String,
        decision: VaultDecision,
        reason: String?,
        hashHex: String?,
        actorId: String?,
        occurredAt: Date
    ) {
        self.action = action
        self.decision = decision
        self.reason = reason
        self.hashHex = hashHex
        self.actorId = actorId
        self.occurredAt = occurredAt
    }
}

/// CoreReceipt writer for vault actions.
public protocol VaultReceiptWriter: Sendable {
    func write(_ receipt: VaultReceipt) async throws -> String
}

/// No-op receipt writer for tests or bootstrap flows.
public struct NullVaultReceiptWriter: VaultReceiptWriter {
    public init() {}

    public func write(_ receipt: VaultReceipt) async throws -> String {
        return "noop"
    }
}

/// Errors emitted by vault operations.
public enum VaultError: Error, LocalizedError {
    case invalidHash
    case missingArtifact
    case integrityMismatch
    case quarantineNotFound
    case fileIOFailure(String)
    case cryptoFailure(String)
    case accessDenied(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHash:
            return "Invalid artifact hash."
        case .missingArtifact:
            return "Artifact not found in vault."
        case .integrityMismatch:
            return "Artifact integrity check failed."
        case .quarantineNotFound:
            return "Quarantined artifact not found."
        case .fileIOFailure(let detail):
            return "Vault file IO error: \(detail)"
        case .cryptoFailure(let detail):
            return "Vault cryptography error: \(detail)"
        case .accessDenied(let detail):
            return "Vault access denied: \(detail)"
        }
    }
}
