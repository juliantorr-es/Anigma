//
//  ArtifactStore.swift
//  HarmoniaModule
//
//  Content-addressed artifact storage with deduplication.
//  Stores large payloads by hash with optional compression.
//

import AnigmaCore
@preconcurrency import CryptoKit
import DatabaseCore
@preconcurrency import Foundation
import StorageCore

/// Artifact storage manager with deduplication.
public actor ArtifactStore {
    private let db: any DatabaseCore.DatabaseExecutor
    private let rootURL: URL
    private var vault: VaultAuthority?
    private var indexStore: VaultIndexStore?
    private let artifactAuthority: (any ArtifactAuthority)?
    
    /// Legacy initializer using VaultAuthority and VaultIndexStore.
    public init(db: any DatabaseCore.DatabaseExecutor, vaultRoot: URL? = nil) {
        self.db = db
        self.rootURL = vaultRoot ?? VaultConfiguration.defaultVaultRoot()
        self.artifactAuthority = nil
    }
    
    /// New initializer using ArtifactAuthority (three-tier architecture).
    /// - Parameters:
    ///   - artifactAuthority: The ArtifactAuthority to use for storage operations.
    ///   - db: DatabaseExecutor for linking and metadata (optional).
    ///   - vaultRoot: Legacy vault root (optional, used only if artifactAuthority is nil).
    public init(artifactAuthority: any ArtifactAuthority, db: (any DatabaseCore.DatabaseExecutor)? = nil, vaultRoot: URL? = nil) {
        self.artifactAuthority = artifactAuthority
        self.db = db ?? (artifactAuthority as? any DatabaseCore.DatabaseExecutor) ?? DummyDatabaseExecutor()
        self.rootURL = vaultRoot ?? VaultConfiguration.defaultVaultRoot()
    }
    
    /// Store artifact data with deduplication.
    /// Returns artifact hash and whether it was newly stored.
    public func storeArtifact(
        data: Data,
        type: String,
        compressionHint: Bool? = nil
    ) async throws -> (hash: String, isNew: Bool) {
        if let artifactAuthority = artifactAuthority {
            // Use ArtifactAuthority
            let artifact = Artifact(
                id: ArtifactID(data),
                mimeType: type,
                size: Int64(data.count),
                createdAt: Date(),
                tags: [],
                metadata: [:],
                content: data
            )
            let systemContext = ExecutionContext(principal: .system)
            let (id, _) = try await artifactAuthority.store(artifact, context: systemContext)
            // For now assume it's always new (ArtifactAuthority may deduplicate internally)
            return (id.hash, true)
        } else {
            // Legacy path
            let hashString = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let index = try await loadIndexStore()
            let isNew = (try await index.fetchArtifact(hash: hashString)) == nil
            let vault = try await loadVault()
            _ = try await vault.ingest(data: data, kind: .derived, mime: type)
            return (hashString, isNew)
        }
    }
    
    /// Retrieve artifact data.
    public func getArtifact(hash: String) async throws -> ArtifactInfo? {
        if let artifactAuthority = artifactAuthority {
            let artifactId = ArtifactID(hash: hash)
            let artifact = try await artifactAuthority.retrieve(artifactId, principal: .system)
            guard let content = artifact.content else {
                throw NSError(domain: "ArtifactStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Artifact content missing"])
            }
            return ArtifactInfo(
                hash: artifact.id.hash,
                byteLength: artifact.size,
                compressionType: "none",
                compressedLength: nil,
                storedAt: artifact.createdAt,
                lastReferencedAt: nil,
                referenceCount: 0,
                data: content
            )
        } else {
            let index = try await loadIndexStore()
            guard let record = try await index.fetchArtifact(hash: hash) else { return nil }
            let vault = try await loadVault()
            let data = try await vault.open(hash: hash)
            return ArtifactInfo(
                hash: record.sha256Hex,
                byteLength: Int64(record.byteLen),
                compressionType: "none",
                compressedLength: nil,
                storedAt: record.createdAt,
                lastReferencedAt: nil,
                referenceCount: 0,
                data: data
            )
        }
    }
    
    /// Link artifact to evidence.
    public func linkArtifact(
        evidenceId: String,
        artifactHash: String,
        referenceType: String
    ) async throws {
        // Linking is a metadata operation; we still need database for legacy compatibility.
        // If using ArtifactAuthority, we could store relationship as tags or metadata.
        // For now, we keep using indexStore if available, else ignore.
        guard let indexStore = try? await loadIndexStore() else { return }
        try await indexStore.recordEdge(
            parentHash: artifactHash,
            childHash: artifactHash,
            relation: "evidence:\(referenceType)",
            runId: evidenceId,
            stepId: nil
        )
    }
    
    /// Get artifacts eligible for deletion based on retention policy.
    public func getEligibleArtifacts(
        olderThanDays: Int,
        limit: Int = 1000
    ) async throws -> [EligibleArtifact] {
        if let artifactAuthority = artifactAuthority {
            let cutoffTime = Date().addingTimeInterval(-TimeInterval(olderThanDays * 24 * 60 * 60))
            let filter = ArtifactFilter(createdBefore: cutoffTime)
            let metadataList = try await artifactAuthority.list(filter: filter, principal: .system)
            return metadataList.prefix(limit).map { meta in
                EligibleArtifact(
                    hash: meta.id.hash,
                    byteLength: meta.size,
                    compressedLength: nil,
                    storedAt: meta.createdAt,
                    lastReferencedAt: nil,
                    referenceCount: 0,
                    evidenceReferences: 0
                )
            }
        } else {
            let cutoffTime = Date().addingTimeInterval(-TimeInterval(olderThanDays * 24 * 60 * 60))
            let index = try await loadIndexStore()
            let artifacts = try await index.listArtifacts(olderThan: cutoffTime)
            return artifacts.prefix(limit).map { record in
                EligibleArtifact(
                    hash: record.sha256Hex,
                    byteLength: Int64(record.byteLen),
                    compressedLength: nil,
                    storedAt: record.createdAt,
                    lastReferencedAt: nil,
                    referenceCount: 0,
                    evidenceReferences: 0
                )
            }
        }
    }
    
    /// Delete artifact by hash (creates retention record).
    public func deleteArtifact(hash: String) async throws -> Int64 {
        if let artifactAuthority = artifactAuthority {
            let artifactId = ArtifactID(hash: hash)
            let systemContext = ExecutionContext(principal: .system)
            _ = try await artifactAuthority.delete(artifactId, context: systemContext)
            // We don't know the size; return 0 for now.
            return 0
        } else {
            let index = try await loadIndexStore()
            guard let record = try await index.fetchArtifact(hash: hash) else { return 0 }
            let objectURL = rootURL.appendingPathComponent(record.objectRelpath, isDirectory: false)
            if FileManager.default.fileExists(atPath: objectURL.path) {
                try FileManager.default.removeItem(at: objectURL)
            }
            try await index.deleteArtifact(hash: hash)
            return Int64(record.byteLen)
        }
    }
    
    /// Get storage statistics.
    public func getStorageStats() async throws -> StorageStats {
        if let artifactAuthority = artifactAuthority {
            // TODO: Implement stats via ArtifactAuthority.list with no filter (may be expensive).
            // For now, return placeholder.
            return StorageStats(
                totalArtifacts: 0,
                totalBytes: 0,
                compressedBytes: 0,
                compressedArtifacts: 0,
                avgReferenceCount: 0.0
            )
        } else {
            let index = try await loadIndexStore()
            let artifacts = try await index.listAllArtifacts()
            let totalBytes = artifacts.reduce(Int64(0)) { $0 + Int64($1.byteLen) }
            return StorageStats(
                totalArtifacts: artifacts.count,
                totalBytes: totalBytes,
                compressedBytes: 0,
                compressedArtifacts: 0,
                avgReferenceCount: 0.0
            )
        }
    }
    
    private func loadVault() async throws -> VaultAuthority {
        if let vault {
            return vault
        }
        let vault = try await VaultAuthority(
            rootURL: rootURL,
            database: db,
            keyProvider: DefaultVaultKeyProvider.make(),
            receiptWriter: VaultFileReceiptWriter(rootURL: rootURL)
        )
        self.vault = vault
        return vault
    }
    
    private func loadIndexStore() async throws -> VaultIndexStore {
        if let indexStore {
            return indexStore
        }
        let store = try await VaultIndexStore(database: db)
        self.indexStore = store
        return store
    }
}

// MARK: - Supporting Types

public struct ArtifactInfo: Sendable {
    public let hash: String
    public let byteLength: Int64
    public let compressionType: String?
    public let compressedLength: Int64?
    public let storedAt: Date
    public let lastReferencedAt: Date?
    public let referenceCount: Int
    public let data: Data
}

public struct EligibleArtifact: Sendable {
    public let hash: String
    public let byteLength: Int64
    public let compressedLength: Int64?
    public let storedAt: Date
    public let lastReferencedAt: Date?
    public let referenceCount: Int
    public let evidenceReferences: Int
}

public struct StorageStats: Sendable {
    public let totalArtifacts: Int
    public let totalBytes: Int64
    public let compressedBytes: Int64
    public let compressedArtifacts: Int
    public let avgReferenceCount: Double
}

// Dummy DatabaseExecutor for when db is not provided and artifactAuthority is not a DatabaseExecutor.
private actor DummyDatabaseExecutor: DatabaseCore.DatabaseExecutor {
    func execute(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int { 0 }
    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow] { [] }
    func executeAsync(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int { 0 }
    func transaction(_ block: @Sendable () async throws -> Void) async throws { try await block() }
    func open() throws {}
    func close() {}
    var path: String { "" }
}
