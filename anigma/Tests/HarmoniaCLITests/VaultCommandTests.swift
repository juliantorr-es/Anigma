//
//  VaultCommandTests.swift
//  HarmoniaCLITests
//

import AnigmaPrimitives
import DatabaseCore
import HarmoniaModule
import StorageCore
import XCTest

@testable import HarmoniaCLI

@MainActor
final class VaultCommandTests: XCTestCase {
    func testVaultExportWritesTimestampClaim() async throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("anigma-harmonia-cli-\(UUID().uuidString)", isDirectory: true)
        let vaultRoot = tempRoot.appendingPathComponent("vault", isDirectory: true)
        let outputDir = tempRoot.appendingPathComponent("exports", isDirectory: true)
        let dbPath = tempRoot.appendingPathComponent("vault.sqlite").path
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: vaultRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let db = DatabaseActor(dbPath: dbPath)
        try await db.open()
        let keyProvider = InMemoryVaultKeyProvider()
        let receiptWriter = VaultFileReceiptWriter(rootURL: vaultRoot)
        let vault = try await VaultAuthority(
            rootURL: vaultRoot,
            database: db,
            keyProvider: keyProvider,
            receiptWriter: receiptWriter
        )
        let payload = Data("cli-export".utf8)
        let ref = try await vault.ingest(data: payload, kind: .original, mime: "text/plain")

        let timestamping = TestTimestamping()
        let originalDependencies = VaultCLIEnvironment.dependencies
        VaultCLIEnvironment.dependencies = VaultCLIDependencies(
            makeKeyProvider: { keyProvider },
            makeReceiptWriter: { _ in receiptWriter },
            makeTimestamping: { _ in timestamping }
        )
        defer { VaultCLIEnvironment.dependencies = originalDependencies }

        let command = try VaultExport.parse([
            "--output-dir", outputDir.path,
            "--vault-root", vaultRoot.path,
            "--db-path", dbPath,
            ref.sha256Hex
        ])
        try await command.run()

        let bundleURL = try singleBundleDirectory(in: outputDir)
        let manifestURL = bundleURL.appendingPathComponent("manifest.json", isDirectory: false)
        let claimURL = bundleURL.appendingPathComponent(
            "manifest.timestamp.json", isDirectory: false)

        XCTAssertTrue(fileManager.fileExists(atPath: manifestURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: claimURL.path))

        let manifestData = try Data(contentsOf: manifestURL)
        let manifestHash = ContentHashing.computeSHA256(manifestData)

        let claimData = try Data(contentsOf: claimURL)
        let claim = try JSONDecoder().decode(BundleTimestampClaim.self, from: claimData)
        XCTAssertEqual(claim.bundleHash, manifestHash)
        let lastHash = await timestamping.lastBundleHash
        XCTAssertEqual(lastHash, manifestHash)
    }

    private func singleBundleDirectory(in root: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let directories = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        return try XCTUnwrap(directories.first)
    }
}

private actor TestTimestamping: BundleTimestamping {
    private(set) var lastBundleHash: String?

    func timestampBundleExport(
        bundleId: String,
        bundleHash: String,
        exportPath: String,
        timestampingLevel: TimestampingLevel,
        legalHoldReference: String?,
        retentionPeriod: Int?
    ) async throws -> BundleTimestampClaim {
        lastBundleHash = bundleHash
        let claim = BundleTimestampClaim(
            claimId: "claim-\(bundleId)",
            bundleId: bundleId,
            bundleHash: bundleHash,
            masterTimestamp: 1_700_000_000,
            monotonicValue: 1,
            timeSourceClaims: [
                TimeSourceClaim(
                    source: "test",
                    timestamp: 1_700_000_000,
                    timezone: "UTC",
                    confidence: 1.0,
                    metadata: ["export": exportPath]
                )
            ],
            timestampingLevel: timestampingLevel,
            legalHoldReference: legalHoldReference,
            retentionPeriod: retentionPeriod,
            exportPath: exportPath,
            createdAt: 1_700_000_000
        )
        return claim
    }
}
