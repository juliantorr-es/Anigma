//
//  VaultAuthorityTests.swift
//  StorageCoreTests
//

import ContractsCore
import DatabaseCore
import GovernanceCore
import StorageCore
import XCTest

final class VaultAuthorityTests: XCTestCase {
    func testIngestAndOpenRoundTrip() async throws {
        let (vault, layout) = try await makeVault()
        defer { try? FileManager.default.removeItem(at: layout.rootURL) }
        let payload = Data("vault-roundtrip".utf8)
        let ref = try await vault.ingest(data: payload, kind: .original, mime: "text/plain")

        let opened = try await vault.open(hash: ref.sha256Hex)
        XCTAssertEqual(opened, payload)

        let objectURL = try layout.objectURL(forSHA256Hex: ref.sha256Hex)
        XCTAssertTrue(FileManager.default.fileExists(atPath: objectURL.path))
    }

    func testQuarantinePromotion() async throws {
        let (vault, layout) = try await makeVault()
        defer { try? FileManager.default.removeItem(at: layout.rootURL) }
        let payload = Data("quarantine-payload".utf8)
        let ticket = try await vault.quarantine(data: payload)
        let ref = try await vault.promote(ticket: ticket, kind: .original, mime: "text/plain")

        let opened = try await vault.open(hash: ref.sha256Hex)
        XCTAssertEqual(opened, payload)

        let objectURL = try layout.objectURL(forSHA256Hex: ref.sha256Hex)
        XCTAssertTrue(FileManager.default.fileExists(atPath: objectURL.path))
    }

    func testExportBundleIncludesReceiptsAndSignature() async throws {
        let (vault, layout) = try await makeVault()
        defer { try? FileManager.default.removeItem(at: layout.rootURL) }
        let payload = Data("export-bundle".utf8)
        let ref = try await vault.ingest(data: payload, kind: .original, mime: "text/plain")

        let exportRoot = layout.rootURL.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)
        let bundle = try await vault.exportBundle(
            request: VaultExportRequest(hashes: [ref.sha256Hex], outputDirectory: exportRoot)
        )

        let manifestData = try Data(contentsOf: bundle.manifestURL)
        let manifest = try JSONDecoder().decode(TestExportManifest.self, from: manifestData)
        XCTAssertEqual(manifest.entries.first?.plaintextSha256, ref.sha256Hex)
        XCTAssertNotNil(manifest.entries.first?.receipt)
        XCTAssertNotNil(manifest.bundleReceipt)
        XCTAssertFalse(manifest.signature.signature.isEmpty)
        XCTAssertFalse(manifest.entries.first?.envelopeSha256.isEmpty ?? true)
    }

    func testRetentionLedgerRecordsDeletion() async throws {
        var currentDate = Date()
        let clock: () -> Date = { currentDate }
        let (vault, layout) = try await makeVault(clock: clock)
        defer { try? FileManager.default.removeItem(at: layout.rootURL) }

        currentDate = Date(timeIntervalSinceNow: -60 * 60 * 48)
        let payload = Data("gc-payload".utf8)
        let ref = try await vault.ingest(data: payload, kind: .original, mime: "text/plain")

        currentDate = Date()
        let policy = RetentionPolicy(
            version: "test",
            classes: [
                "default": RetentionPolicyClass(name: "Default", ttlHours: 1),
                "original": RetentionPolicyClass(name: "Original", ttlHours: 1)
            ],
            segments: SegmentationPolicy(maxSegmentSizeMB: 1, rotationIntervalDays: 1),
            hotRuns: HotRunPolicy(maxKept: 1, cooldownDays: 1)
        )

        let report = try await vault.gc(policy: policy, dryRun: false)
        XCTAssertEqual(report.deleted, 1)

        let ledgerURL = layout.ledgerURL.appendingPathComponent(
            "vault_retention.jsonl", isDirectory: false)
        let ledgerContents = try String(contentsOf: ledgerURL, encoding: .utf8)
        let line = try XCTUnwrap(ledgerContents.split(separator: "\n").first)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(
            TestRetentionLedgerEntry.self,
            from: Data(line.utf8)
        )
        XCTAssertEqual(entry.deletedHashes, [ref.sha256Hex])
        XCTAssertEqual(entry.deleted, 1)
        XCTAssertFalse(entry.dryRun)
        XCTAssertEqual(entry.policyHash, report.policyHash)
    }

    private func makeVault(
        clock: @escaping () -> Date = Date.init
    ) async throws -> (VaultAuthority, VaultLayout) {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("anigma-vault-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let db = DatabaseActor(dbPath: ":memory:")
        try await db.open()
        let keyProvider = InMemoryVaultKeyProvider()
        let signer = InMemoryVaultSigner()
        let vault = try await VaultAuthority(
            rootURL: tempRoot,
            database: db,
            keyProvider: keyProvider,
            signer: signer,
            clock: clock
        )
        return (vault, VaultLayout(rootURL: tempRoot))
    }
}

private struct TestExportManifest: Codable {
    let entries: [TestExportEntry]
    let bundleReceipt: VaultReceipt
    let signature: TestExportSignature
}

private struct TestExportEntry: Codable {
    let plaintextSha256: String
    let envelopeSha256: String
    let receipt: VaultReceipt
}

private struct TestExportSignature: Codable {
    let signature: String
}

private struct TestRetentionLedgerEntry: Codable {
    let recordedAt: Date
    let policyHash: String
    let policyVersion: String
    let scanned: Int
    let deleted: Int
    let bytesFreed: Int64
    let dryRun: Bool
    let deletedHashes: [String]
}
