//
//  VaultAuthority.swift
//  StorageCore
//
//  Authority-owned vault for artifact storage.
//

import CryptoKit
import AnigmaPrimitives
import DatabaseCore
import Foundation
import FoundationContracts
import GovernanceContracts

/// Request for exporting a bundle of vault artifacts.
public struct VaultExportRequest: Sendable {
    public let hashes: [String]
    public let outputDirectory: URL
    public let bundleId: String

    public init(hashes: [String], outputDirectory: URL, bundleId: String = UUID().uuidString) {
        self.hashes = hashes
        self.outputDirectory = outputDirectory
        self.bundleId = bundleId
    }
}

/// Exported vault bundle metadata.
public struct VaultExportBundle: Sendable {
    public let bundleId: String
    public let manifestURL: URL
    public let artifactURLs: [URL]
}

/// Result of a vault retention run.
public struct VaultGCReport: Sendable {
    public let scanned: Int
    public let deleted: Int
    public let bytesFreed: Int64
    public let dryRun: Bool
    public let deletedHashes: [String]
    public let policyHash: String
    public let policyVersion: String
}

/// Authority-owned vault for immutable artifacts.
public actor VaultAuthority {
    private let layout: VaultLayout
    private let keyProvider: VaultKeyProvider
    private let indexStore: VaultIndexStore
    private let receiptWriter: VaultReceiptWriter
    private let signer: VaultSigner
    private let clock: () -> Date
    private let fileManager: FileManager

    public init(
        rootURL: URL,
        database: any DatabaseExecutor,
        keyProvider: VaultKeyProvider,
        signer: VaultSigner = DefaultVaultSigner.make(),
        receiptWriter: VaultReceiptWriter = NullVaultReceiptWriter(),
        clock: @escaping () -> Date = Date.init,
        fileManager: FileManager = .default
    ) async throws {
        self.layout = VaultLayout(rootURL: rootURL)
        self.keyProvider = keyProvider
        self.indexStore = try await VaultIndexStore(database: database)
        self.receiptWriter = receiptWriter
        self.signer = signer
        self.clock = clock
        self.fileManager = fileManager
        try prepareLayout()
    }

    /// Ingest trusted bytes into the vault and return a canonical artifact reference.
    public func ingest(
        data: Data,
        kind: VaultArtifactKind,
        mime: String,
        actorId: String? = nil
    ) async throws -> VaultArtifactRef {
        let now = clock()
        let hash = blake3Hex(data)
        try validateHash(hash)
        let objectURL = try layout.objectURL(forHash: hash)

        if fileManager.fileExists(atPath: objectURL.path) {
            if let existing = try await indexStore.fetchArtifact(hash: hash) {
                try await recordAccess(
                    action: "ingest", hash: hash, decision: .allow, reason: "dedupe",
                    actorId: actorId)
                return existing
            }
        }

        let keyMaterial = try await keyProvider.currentKeyMaterial()
        let encrypted = try VaultCrypto.encrypt(
            plaintext: data, hashHex: hash, keyMaterial: keyMaterial)
        try writeObject(encrypted, to: objectURL)

        let ref = VaultArtifactRef(
            hashHex: hash,
            byteLen: data.count,
            mime: mime,
            kind: kind,
            keyId: keyMaterial.keyId,
            objectRelpath: relpath(for: objectURL),
            createdAt: now
        )
        try await indexStore.upsertArtifact(ref)
        try await recordAccess(
            action: "ingest", hash: hash, decision: .allow, reason: nil, actorId: actorId)
        return ref
    }

    /// Open an artifact by hash and return decrypted bytes.
    public func open(hash: String, actorId: String? = nil) async throws -> Data {
        try validateHash(hash)
        guard let record = try await indexStore.fetchArtifact(hash: hash) else {
            try await recordAccess(
                action: "open", hash: hash, decision: .deny, reason: "missing_record",
                actorId: actorId)
            throw VaultError.missingArtifact
        }
        let objectURL = layout.rootURL.appendingPathComponent(
            record.objectRelpath, isDirectory: false)
        guard fileManager.fileExists(atPath: objectURL.path) else {
            try await recordAccess(
                action: "open", hash: hash, decision: .deny, reason: "missing_object",
                actorId: actorId)
            throw VaultError.missingArtifact
        }
        let envelope = try Data(contentsOf: objectURL)
        let keyMaterial = try await keyProvider.keyMaterial(for: record.keyId)
        let plaintext = try VaultCrypto.decrypt(
            envelope: envelope, hashHex: hash, keyMaterial: keyMaterial)
        if blake3Hex(plaintext) != hash {
            try await recordAccess(
                action: "open", hash: hash, decision: .deny, reason: "integrity_mismatch",
                actorId: actorId)
            throw VaultError.integrityMismatch
        }
        try await recordAccess(
            action: "open", hash: hash, decision: .allow, reason: nil, actorId: actorId)
        return plaintext
    }
    /// List all artifacts stored in the vault.
    public func listArtifacts(actorId: String? = nil) async throws -> [VaultArtifactRef] {
        let artifacts = try await indexStore.listAllArtifacts()
        try await recordAccess(
            action: "list",
            hash: "",
            decision: .allow,
            reason: "count: \(artifacts.count)",
            actorId: actorId
        )
        return artifacts
    }

    /// Record a provenance edge between artifacts.
    public func recordEdge(
        parentHash: String,
        childHash: String,
        relation: String,
        runId: String? = nil,
        stepId: String? = nil
    ) async throws {
        try validateHash(parentHash)
        try validateHash(childHash)
        try await indexStore.recordEdge(
            parentHash: parentHash,
            childHash: childHash,
            relation: relation,
            runId: runId,
            stepId: stepId
        )
    }
    /// Ingest a receipt into the vault with chain linking.
    public func ingestReceipt(
        data: Data,
        hash: String,
        previousReceiptHash: String? = nil,
        actorId: String? = nil
    ) async throws -> VaultArtifactRef {
        let now = clock()
        try validateHash(hash)
        if let previous = previousReceiptHash {
            try validateHash(previous)
        }

        let objectURL = try layout.objectURL(forHash: hash)

        if fileManager.fileExists(atPath: objectURL.path) {
            if let existing = try await indexStore.fetchArtifact(hash: hash) {
                try await recordAccess(
                    action: "ingest_receipt", hash: hash, decision: .allow, reason: "dedupe",
                    actorId: actorId)
                return existing
            }
        }

        let keyMaterial = try await keyProvider.currentKeyMaterial()
        let encrypted = try VaultCrypto.encrypt(
            plaintext: data, hashHex: hash, keyMaterial: keyMaterial)
        try writeObject(encrypted, to: objectURL)

        let ref = VaultArtifactRef(
            hashHex: hash,
            byteLen: data.count,
            mime: "application/json",
            kind: .receipt,
            keyId: keyMaterial.keyId,
            objectRelpath: relpath(for: objectURL),
            previousReceiptHash: previousReceiptHash,
            createdAt: now
        )
        try await indexStore.upsertArtifact(ref)
        try await recordAccess(
            action: "ingest_receipt", hash: hash, decision: .allow, reason: nil, actorId: actorId)
        return ref
    }

    /// Verifies the integrity of a receipt chain stored in the vault.
    public func verifyChain(receiptHashes: [String]) async throws -> Bool {
        guard !receiptHashes.isEmpty else { return true }

        var previousHash: String?
        for hash in receiptHashes {
            guard let record = try await indexStore.fetchArtifact(hash: hash) else {
                return false
            }
            guard record.kind == .receipt else {
                return false
            }
            if record.previousReceiptHash != previousHash {
                return false
            }
            previousHash = hash
        }
        return true
    }

    /// Place bytes into quarantine for inspection prior to promotion.
    public func quarantine(data: Data, actorId: String? = nil) async throws -> QuarantineTicket {
        let now = clock()
        let hash = blake3Hex(data)
        try validateHash(hash)
        let ticketId = UUID().uuidString
        let ticketURL = layout.quarantineTicketURL(ticketId)
        try ensureDirectory(ticketURL)

        let keyMaterial = try await keyProvider.currentKeyMaterial()
        let encrypted = try VaultCrypto.encrypt(
            plaintext: data, hashHex: hash, keyMaterial: keyMaterial)
        let payloadURL = ticketURL.appendingPathComponent("payload.enc", isDirectory: false)
        try writeFile(encrypted, to: payloadURL)

        let metadata = QuarantineMetadata(
            ticketId: ticketId,
            hashHex: hash,
            byteLen: data.count,
            createdAt: now,
            keyId: keyMaterial.keyId
        )
        let metadataURL = ticketURL.appendingPathComponent("meta.json", isDirectory: false)
        let metaData = try JSONEncoder().encode(metadata)
        try writeFile(metaData, to: metadataURL)

        try await recordAccess(
            action: "quarantine", hash: hash, decision: .allow, reason: nil, actorId: actorId)
        return QuarantineTicket(
            ticketId: ticketId, hashHex: hash, byteLen: data.count, createdAt: now)
    }

    /// Promote a quarantined artifact into the immutable object store.
    public func promote(
        ticket: QuarantineTicket,
        kind: VaultArtifactKind,
        mime: String,
        actorId: String? = nil
    ) async throws -> VaultArtifactRef {
        let ticketURL = layout.quarantineTicketURL(ticket.ticketId)
        let metadataURL = ticketURL.appendingPathComponent("meta.json", isDirectory: false)
        let payloadURL = ticketURL.appendingPathComponent("payload.enc", isDirectory: false)
        guard fileManager.fileExists(atPath: metadataURL.path),
            fileManager.fileExists(atPath: payloadURL.path)
        else {
            try await recordAccess(
                action: "promote", hash: ticket.hashHex, decision: .deny,
                reason: "missing_quarantine", actorId: actorId)
            throw VaultError.quarantineNotFound
        }

        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(QuarantineMetadata.self, from: metadataData)
        let encrypted = try Data(contentsOf: payloadURL)
        let keyMaterial = try await keyProvider.keyMaterial(for: metadata.keyId)
        let plaintext = try VaultCrypto.decrypt(
            envelope: encrypted, hashHex: metadata.hashHex, keyMaterial: keyMaterial)
        if blake3Hex(plaintext) != metadata.hashHex {
            try await recordAccess(
                action: "promote", hash: metadata.hashHex, decision: .deny,
                reason: "integrity_mismatch", actorId: actorId)
            throw VaultError.integrityMismatch
        }

        let objectURL = try layout.objectURL(forHash: metadata.hashHex)
        if !fileManager.fileExists(atPath: objectURL.path) {
            try ensureDirectory(objectURL.deletingLastPathComponent())
            try fileManager.moveItem(at: payloadURL, to: objectURL)
            try setFilePermissions(objectURL, mode: 0o600)
        }

        let ref = VaultArtifactRef(
            hashHex: metadata.hashHex,
            byteLen: metadata.byteLen,
            mime: mime,
            kind: kind,
            keyId: metadata.keyId,
            objectRelpath: relpath(for: objectURL),
            createdAt: metadata.createdAt
        )
        try await indexStore.upsertArtifact(ref)
        try fileManager.removeItem(at: ticketURL)
        try await recordAccess(
            action: "promote", hash: metadata.hashHex, decision: .allow, reason: nil,
            actorId: actorId)
        return ref
    }

    /// Export encrypted artifacts and a manifest for offline verification.
    public func exportBundle(
        request: VaultExportRequest,
        actorId: String? = nil
    ) async throws -> VaultExportBundle {
        let bundleURL = request.outputDirectory.appendingPathComponent(
            request.bundleId, isDirectory: true)
        try ensureDirectory(bundleURL)

        var entries: [VaultExportEntry] = []
        var copiedURLs: [URL] = []
        for hash in request.hashes {
            guard let record = try await indexStore.fetchArtifact(hash: hash) else {
                try await recordAccess(
                    action: "export", hash: hash, decision: .deny, reason: "missing_record",
                    actorId: actorId)
                throw VaultError.missingArtifact
            }
            let objectURL = layout.rootURL.appendingPathComponent(
                record.objectRelpath, isDirectory: false)
            guard fileManager.fileExists(atPath: objectURL.path) else {
                try await recordAccess(
                    action: "export", hash: hash, decision: .deny, reason: "missing_object",
                    actorId: actorId)
                throw VaultError.missingArtifact
            }
            let plaintext = try await open(hash: record.hashHex, actorId: actorId)
            let plaintextHash = blake3Hex(plaintext)
            let envelopeData = try Data(contentsOf: objectURL)
            let envelopeHash = blake3Hex(envelopeData)
            let destinationURL = bundleURL.appendingPathComponent(
                "\(record.hashHex).enc", isDirectory: false)
            if !fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.copyItem(at: objectURL, to: destinationURL)
                try setFilePermissions(destinationURL, mode: 0o600)
            }
            let receipt = try await recordAccess(
                action: "export_artifact",
                hash: record.hashHex,
                decision: .allow,
                reason: nil,
                actorId: actorId
            )
            entries.append(
                VaultExportEntry(
                    hashHex: record.hashHex,
                    plaintextHash: plaintextHash,
                    envelopeHash: envelopeHash,
                    mime: record.mime,
                    kind: record.kind,
                    byteLen: record.byteLen,
                    filename: destinationURL.lastPathComponent,
                    receipt: receipt
                )
            )
            copiedURLs.append(destinationURL)
        }

        let bundleReceipt = try await recordAccess(
            action: "export_bundle",
            hash: request.bundleId,
            decision: .allow,
            reason: nil,
            actorId: actorId
        )
        let payload = try manifestPayload(
            entries: entries,
            bundleId: request.bundleId,
            bundleReceipt: bundleReceipt
        )
        let manifest = VaultExportManifest(
            bundleId: request.bundleId,
            generatedAt: clock(),
            entries: entries,
            bundleReceipt: bundleReceipt,
            signature: try await signer.sign(payload: payload)
        )
        let manifestURL = bundleURL.appendingPathComponent("manifest.json", isDirectory: false)
        let manifestEncoder = JSONEncoder()
        manifestEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        manifestEncoder.dateEncodingStrategy = .iso8601
        let manifestData = try manifestEncoder.encode(manifest)
        try writeFile(manifestData, to: manifestURL)
        return VaultExportBundle(
            bundleId: request.bundleId, manifestURL: manifestURL, artifactURLs: copiedURLs)
    }

    /// Apply retention policy to vault artifacts.
    public func gc(
        policy: RetentionPolicy,
        dryRun: Bool,
        actorId: String? = nil
    ) async throws -> VaultGCReport {
        let now = clock()
        let allArtifacts = try await indexStore.listArtifacts(olderThan: now)
        var deletedHashes: [String] = []
        var bytesFreed: Int64 = 0

        let minAgeCutoff = now.addingTimeInterval(-TimeInterval(24 * 3600))

        for artifact in allArtifacts {
            if artifact.createdAt > minAgeCutoff {
                continue
            }

            guard
                let policyClass = policy.classes[artifact.kind.rawValue]
                    ?? policy.classes["default"]
            else {
                continue
            }
            if policyClass.keepForever {
                continue
            }
            let ttlHours = policyClass.ttlHours
            let cutoff = now.addingTimeInterval(TimeInterval(-ttlHours * 3600))
            if artifact.createdAt > cutoff {
                continue
            }

            let objectURL = layout.rootURL.appendingPathComponent(
                artifact.objectRelpath, isDirectory: false)
            if !dryRun {
                if fileManager.fileExists(atPath: objectURL.path) {
                    try fileManager.removeItem(at: objectURL)
                    bytesFreed += Int64(artifact.byteLen)
                }
                try await indexStore.deleteArtifact(hash: artifact.hashHex)
                try await recordAccess(
                    action: "gc", hash: artifact.hashHex, decision: .allow, reason: nil,
                    actorId: actorId)
            }
            deletedHashes.append(artifact.hashHex)
        }

        let policyHash = policy.policyHash
        let report = VaultGCReport(
            scanned: allArtifacts.count,
            deleted: deletedHashes.count,
            bytesFreed: bytesFreed,
            dryRun: dryRun,
            deletedHashes: deletedHashes,
            policyHash: policyHash,
            policyVersion: policy.version
        )

        if !dryRun {
            try await indexStore.recordRetentionEvent(report: report)
        }
        try appendRetentionLedger(report: report)
        return report
    }

    private func prepareLayout() throws {
        try ensureDirectory(layout.rootURL)
        try ensureDirectory(layout.objectsURL)
        try ensureDirectory(layout.manifestsURL)
        try ensureDirectory(layout.manifestsURL.appendingPathComponent("runs", isDirectory: true))
        try ensureDirectory(layout.quarantineURL)
        try ensureDirectory(layout.tempURL)
        try ensureDirectory(layout.ledgerURL)
    }

    private func ensureDirectory(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) { return }
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func writeObject(_ data: Data, to url: URL) throws {
        try ensureDirectory(url.deletingLastPathComponent())
        let tempURL = layout.tempURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
        try writeFile(data, to: tempURL)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: tempURL)
            return
        }
        try fileManager.moveItem(at: tempURL, to: url)
        try setFilePermissions(url, mode: 0o600)
    }

    private func writeFile(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: .atomic)
            try setFilePermissions(url, mode: 0o600)
        } catch {
            throw VaultError.fileIOFailure(error.localizedDescription)
        }
    }

    private func setFilePermissions(_ url: URL, mode: Int) throws {
        try fileManager.setAttributes([.posixPermissions: mode], ofItemAtPath: url.path)
    }

    private func validateHash(_ hash: String) throws {
        guard hash.count == 64, hash.range(of: "^[0-9a-f]+$", options: .regularExpression) != nil
        else {
            throw VaultError.invalidHash
        }
    }

    private func blake3Hex(_ data: Data) -> String {
        return BLAKE3Digest.hex(of: data)
    }

    private func relpath(for url: URL) -> String {
        let rootPath = layout.rootURL.standardizedFileURL.path
        let fullPath = url.standardizedFileURL.path
        if fullPath.hasPrefix(rootPath + "/") {
            return String(fullPath.dropFirst(rootPath.count + 1))
        }
        return fullPath
    }

    @discardableResult
    private func recordAccess(
        action: String,
        hash: String,
        decision: VaultDecision,
        reason: String?,
        actorId: String?
    ) async throws -> VaultReceipt {
        let receipt = VaultReceipt(
            action: action,
            decision: decision,
            reason: reason,
            hashHex: hash.isEmpty ? nil : hash,
            actorId: actorId,
            occurredAt: clock()
        )
        _ = try await receiptWriter.write(receipt)
        try await indexStore.recordAccess(
            at: clock(),
            actorId: actorId,
            action: action,
            hashHex: hash.isEmpty ? "unknown" : hash,
            decision: decision,
            reason: reason
        )
        return receipt
    }

    private func manifestPayload(
        entries: [VaultExportEntry],
        bundleId: String,
        bundleReceipt: VaultReceipt
    ) throws -> Data {
        let payload = VaultExportManifestPayload(
            bundleId: bundleId,
            generatedAt: clock(),
            entries: entries,
            bundleReceipt: bundleReceipt
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    private func appendRetentionLedger(report: VaultGCReport) throws {
        let ledgerURL = layout.ledgerURL.appendingPathComponent(
            "vault_retention.jsonl", isDirectory: false)
        let entry = VaultRetentionLedgerEntry(
            recordedAt: clock(),
            policyHash: report.policyHash,
            policyVersion: report.policyVersion,
            scanned: report.scanned,
            deleted: report.deleted,
            bytesFreed: report.bytesFreed,
            dryRun: report.dryRun,
            deletedHashes: report.deletedHashes
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let line = try encoder.encode(entry)
        var data = line
        data.append(0x0A)
        if fileManager.fileExists(atPath: ledgerURL.path) {
            if let handle = try? FileHandle(forWritingTo: ledgerURL) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                return
            }
        }
        try writeFile(data, to: ledgerURL)
    }
}

private struct QuarantineMetadata: Codable {
    let ticketId: String
    let hashHex: String
    let byteLen: Int
    let createdAt: Date
    let keyId: String
}

private struct VaultExportManifest: Codable {
    let bundleId: String
    let generatedAt: Date
    let entries: [VaultExportEntry]
    let bundleReceipt: VaultReceipt
    let signature: VaultSignature
}

private struct VaultExportManifestPayload: Codable {
    let bundleId: String
    let generatedAt: Date
    let entries: [VaultExportEntry]
    let bundleReceipt: VaultReceipt
}

private struct VaultExportEntry: Codable {
    let hashHex: String
    let plaintextHash: String
    let envelopeHash: String
    let mime: String
    let kind: VaultArtifactKind
    let byteLen: Int
    let filename: String
    let receipt: VaultReceipt
}

private struct VaultRetentionLedgerEntry: Codable {
    let recordedAt: Date
    let policyHash: String
    let policyVersion: String
    let scanned: Int
    let deleted: Int
    let bytesFreed: Int64
    let dryRun: Bool
    let deletedHashes: [String]
}
