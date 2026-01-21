//
//  VaultCommand.swift
//  HarmoniaCLI
//
//  Vault inspection and maintenance commands.
//

import ArgumentParser
import DatabaseCore
import Foundation
import GovernanceCore
import HarmoniaModule
import StorageCore

struct VaultCLIDependencies: @unchecked Sendable {
    var makeKeyProvider: () -> VaultKeyProvider
    var makeReceiptWriter: (URL) -> VaultReceiptWriter
    var makeTimestamping: (DatabaseActor) -> BundleTimestamping
}

enum VaultCLIEnvironment {
    @MainActor static var dependencies = VaultCLIDependencies(
        makeKeyProvider: { DefaultVaultKeyProvider.make() },
        makeReceiptWriter: { VaultFileReceiptWriter(rootURL: $0) },
        makeTimestamping: { TrustedTimestampingSystem(dbActor: $0) }
    )
}

struct VaultCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "vault",
            abstract: "Inspect and manage the storage vault",
            subcommands: [VaultStatus.self, VaultVerify.self, VaultExport.self, VaultGC.self],
            defaultSubcommand: VaultStatus.self
        )
    }
}

struct VaultOptions: ParsableArguments {
    @OptionGroup var output: OutputOptions

    @Option(name: .long, help: "Vault root directory override.")
    var vaultRoot: String?

    @Option(name: .long, help: "Database path override.")
    var dbPath: String?
}

extension TimestampingLevel: ExpressibleByArgument {}

private struct VaultStatusReport: Codable {
    let vaultRoot: String
    let databasePath: String
    let totalArtifacts: Int
    let totalBytes: Int64
}

private struct VaultVerifyReport: Codable {
    let vaultRoot: String
    let databasePath: String
    let checked: Int
    let verified: Int
    let failed: Int
    let failures: [VaultVerifyFailure]
}

private struct VaultVerifyFailure: Codable {
    let hash: String
    let error: String
}

private struct VaultExportReport: Codable {
    let bundleId: String
    let manifestPath: String
    let artifactPaths: [String]
    let timestampClaimPath: String?
}

private struct VaultGCReportPayload: Codable {
    let scanned: Int
    let deleted: Int
    let bytesFreed: Int64
    let dryRun: Bool
    let deletedHashes: [String]
    let policyHash: String
    let policyVersion: String
}

struct VaultStatus: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "status",
            abstract: "Summarize vault inventory"
        )
    }

    @OptionGroup var options: VaultOptions

    func run() async throws {
        let db = DatabaseActor(dbPath: resolveDatabasePath(options.dbPath))
        try await db.open()
        let index = try await VaultIndexStore(database: db)
        let artifacts = try await index.listAllArtifacts()
        let totalBytes = artifacts.reduce(Int64(0)) { $0 + Int64($1.byteLen) }
        let report = VaultStatusReport(
            vaultRoot: resolveVaultRoot(options.vaultRoot).path,
            databasePath: resolveDatabasePath(options.dbPath),
            totalArtifacts: artifacts.count,
            totalBytes: totalBytes
        )
        try OutputWriter.emit(
            command: "vault.status", payload: report, format: options.output.format)
    }
}

struct VaultVerify: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "verify",
            abstract: "Verify vault integrity by re-reading stored artifacts"
        )
    }

    @OptionGroup var options: VaultOptions

    @Option(name: .long, help: "Maximum number of artifacts to verify.")
    var limit: Int?

    func run() async throws {
        let db = DatabaseActor(dbPath: resolveDatabasePath(options.dbPath))
        try await db.open()
        let vault = try await makeVault(db: db, vaultRoot: options.vaultRoot)
        let index = try await VaultIndexStore(database: db)
        let artifacts = try await index.listAllArtifacts()
        let slice = limit.map { Array(artifacts.prefix($0)) } ?? artifacts
        var failures: [VaultVerifyFailure] = []
        var verified = 0

        for artifact in slice {
            do {
                _ = try await vault.open(hash: artifact.sha256Hex)
                verified += 1
            } catch {
                failures.append(
                    VaultVerifyFailure(hash: artifact.sha256Hex, error: error.localizedDescription))
            }
        }

        let report = VaultVerifyReport(
            vaultRoot: resolveVaultRoot(options.vaultRoot).path,
            databasePath: resolveDatabasePath(options.dbPath),
            checked: slice.count,
            verified: verified,
            failed: failures.count,
            failures: failures
        )
        try OutputWriter.emit(
            command: "vault.verify", payload: report, format: options.output.format)
    }
}

struct VaultExport: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "export",
            abstract: "Export encrypted vault artifacts and manifest bundle"
        )
    }

    @OptionGroup var options: VaultOptions

    @Option(name: .long, help: "Output directory for the export bundle.")
    var outputDir: String

    @Argument(help: "Artifact hashes to export.")
    var hashes: [String]

    @Option(
        name: .long,
        help: "Timestamping level for bundle export (basic|standard|enhanced|legal|blockchain).")
    var timestampLevel: TimestampingLevel = .legal

    @Option(name: .long, help: "Optional legal hold reference for timestamping.")
    var legalHold: String?

    func run() async throws {
        let db = DatabaseActor(dbPath: resolveDatabasePath(options.dbPath))
        try await db.open()
        let vault = try await makeVault(db: db, vaultRoot: options.vaultRoot)
        let bundle = try await vault.exportBundle(
            request: VaultExportRequest(
                hashes: hashes,
                outputDirectory: URL(fileURLWithPath: outputDir)
            )
        )

        let manifestData = try Data(contentsOf: bundle.manifestURL)
        let manifestHash = ContentHashing.computeSHA256(manifestData)
        let dependencies = await VaultCLIEnvironment.dependencies
        let timestamping = dependencies.makeTimestamping(db)

        // Capture options locally to avoid data race
        let level = timestampLevel
        let hold = legalHold

        let claim = try await timestamping.timestampBundleExport(
            bundleId: bundle.bundleId,
            bundleHash: manifestHash,
            exportPath: bundle.manifestURL.path,
            timestampingLevel: level,
            legalHoldReference: hold,
            retentionPeriod: nil
        )
        let claimURL = bundle.manifestURL.deletingPathExtension().appendingPathExtension(
            "timestamp.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let claimData = try encoder.encode(claim)
        try claimData.write(to: claimURL, options: .atomic)
        let timestampClaimPath = claimURL.path
        let report = VaultExportReport(
            bundleId: bundle.bundleId,
            manifestPath: bundle.manifestURL.path,
            artifactPaths: bundle.artifactURLs.map(\.path),
            timestampClaimPath: timestampClaimPath
        )
        try OutputWriter.emit(
            command: "vault.export", payload: report, format: options.output.format)
    }
}

struct VaultGC: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "gc",
            abstract: "Apply retention policy to vault artifacts"
        )
    }

    @OptionGroup var options: VaultOptions

    @Flag(name: .long, help: "Dry run without deleting artifacts.")
    var dryRun: Bool = false

    @Option(name: .long, help: "Path to retention policy file (JSON or TOML).")
    var policyFile: String?

    func run() async throws {
        let db = DatabaseActor(dbPath: resolveDatabasePath(options.dbPath))
        try await db.open()
        let vault = try await makeVault(db: db, vaultRoot: options.vaultRoot)
        let policy = try loadPolicy(path: policyFile)
        let report = try await vault.gc(policy: policy, dryRun: dryRun)
        let payload = VaultGCReportPayload(
            scanned: report.scanned,
            deleted: report.deleted,
            bytesFreed: report.bytesFreed,
            dryRun: report.dryRun,
            deletedHashes: report.deletedHashes,
            policyHash: report.policyHash,
            policyVersion: report.policyVersion
        )
        try OutputWriter.emit(command: "vault.gc", payload: payload, format: options.output.format)
    }
}

private func makeVault(db: DatabaseActor, vaultRoot: String?) async throws -> VaultAuthority {
    let rootURL = resolveVaultRoot(vaultRoot)
    let dependencies = await VaultCLIEnvironment.dependencies
    let keyProvider = dependencies.makeKeyProvider()
    return try await VaultAuthority(
        rootURL: rootURL,
        database: db,
        keyProvider: keyProvider,
        receiptWriter: dependencies.makeReceiptWriter(rootURL)
    )
}

private func resolveVaultRoot(_ override: String?) -> URL {
    if let override, !override.isEmpty {
        return URL(fileURLWithPath: override)
    }
    return VaultConfiguration.defaultVaultRoot()
}

private func resolveDatabasePath(_ override: String?) -> String {
    if let override, !override.isEmpty {
        return override
    }
    if let envPath = ProcessInfo.processInfo.environment["HARMONIA_DB_PATH"] {
        return envPath
    }
    return DatabaseConfiguration.defaultDatabasePath()
}

private func loadPolicy(path: String?) throws -> GovernanceCore.RetentionPolicy {
    if let path, !path.isEmpty {
        return try GovernanceCore.RetentionPolicy.load(from: URL(fileURLWithPath: path))
    }
    return GovernanceCore.RetentionPolicy.production
}
