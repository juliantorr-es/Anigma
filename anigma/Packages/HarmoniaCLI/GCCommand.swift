//
//  GCCommand.swift
//  HarmoniaCLI
//
//  Garbage collection command for database housekeeping.
//

import AnigmaCore
import ArgumentParser
import DatabaseCore
import ContractsCore
import Foundation

struct GC: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "gc",
            abstract: "Run garbage collection with retention policy",
            discussion: """
                Garbage collection enforces retention policies to bound storage growth
                while maintaining auditable evidence trails.

                The system uses a content-addressed artifact store with deduplication,
                so payload bytes can be expired while preserving hashes for audit.
                """
        )
    }

    @OptionGroup var output: OutputOptions

    @Flag(
        name: .shortAndLong,
        help: "Show what would be deleted without making changes."
    )
    var dryRun: Bool = false

    @Option(
        name: .long,
        help: "Path to retention policy file (TOML format)."
    )
    var policyFile: String?

    @Option(
        name: .long,
        help: "Maximum artifacts to delete in this run."
    )
    var maxDelete: Int?

    @Option(
        name: .long,
        help: "Minimum age in hours for artifacts to be eligible."
    )
    var minAgeHours: Int?

    func run() async throws {
        // Load retention policy
        let policy: ContractsCore.RetentionPolicy
        if let policyFile = policyFile {
            let policyUrl = URL(fileURLWithPath: policyFile)
            policy = try ContractsCore.RetentionPolicy.load(from: policyUrl)
            print("📋 Loaded retention policy from: \(policyFile)")
        } else {
            policy = ContractsCore.RetentionPolicy.production
            print("📋 Using production retention policy")
        }

        // Initialize database
        let dbPath = getDatabasePath()
        let masterDb: any DatabaseExecutor = DatabaseActor(path: dbPath)
        try await masterDb.open()

        // Create policy manager and GC engine
        let policyManager = try await RetentionPolicyManager(database: masterDb)
        let gc = GarbageCollectorEngine(database: masterDb, policyManager: policyManager)

        // Run garbage collection
        let maxDelete = self.maxDelete ?? 1000
        let result = try await gc.runGarbageCollection(
            dryRun: dryRun,
            policy: policy,
            maxItemsToDelete: maxDelete
        )

        // Emit results
        try emitGCResult(result, format: output.format)

        if dryRun {
            print("\n🔍 DRY RUN MODE - No changes made")
            print("   Run without --dry-run to execute cleanup")
        } else {
            print("\n✅ Garbage collection completed")
            print("   Artifacts deleted: \(result.deletionResult.artifactsDeleted)")
            print("   Storage freed: \(formatBytes(result.deletionResult.bytesFreed))")
        }
    }

    private func getDatabasePath() -> String {
        // PostgreSQL is now the first-class database - SQLite is deprecated
        // Check environment variable first
        if let dbPath = ProcessInfo.processInfo.environment["HARMONIA_DB_PATH"] {
            return dbPath
        }
        if let dbURL = ProcessInfo.processInfo.environment["ANIGMA_DB_URL"] {
            return dbURL
        }

        // Default to PostgreSQL
        return DatabaseConfiguration.defaultDatabasePath()
    }

    private func emitGCResult(_ result: GarbageCollectionResult, format: OutputFormat) throws {
        switch format {
        case .json:
            try OutputWriter.emit(
                command: "gc",
                payload: result,
                format: format
            )
        case .text:
            emitTextResult(result)
        }
    }

    private func emitTextResult(_ result: GarbageCollectionResult) {
        print("\n📊 Garbage Collection Report")
        print(String(repeating: "=", count: 50))
        print("Policy Hash: \(result.policyHash)")
        print("Dry Run: \(result.dryRun ? "Yes" : "No")")
        print("Duration: \(String(format: "%.2f", result.duration))s")
        print("Eligible Count: \(result.eligibleCount)")
        print("Verified Count: \(result.verifiedCount)")
        print("\n🗑️  Artifacts Deleted: \(result.deletionResult.artifactsDeleted)")
        print("  Bytes Freed: \(formatBytes(result.deletionResult.bytesFreed))")
        if !result.deletionResult.deletedHashes.isEmpty {
            print(
                "  Deleted Hashes: \(result.deletionResult.deletedHashes.prefix(5).joined(separator: ", "))"
            )
            if result.deletionResult.deletedHashes.count > 5 {
                print("    ... and \(result.deletionResult.deletedHashes.count - 5) more")
            }
        }

        if let housekeeping = result.housekeepingResult {
            print("\n📄 Housekeeping:")
            if housekeeping.checkpointResult.checkpointPerformed {
                print(
                    "  WAL Checkpoint: ✅ (​Bytes freed: \(formatBytes(housekeeping.checkpointResult.bytesFreed)))"
                )
            }
            if let vacuum = housekeeping.maintenanceResult.vacuumResult {
                if vacuum.vacuumPerformed {
                    print(
                        "  VACUUM: ✅ (Space saved: \(String(format: "%.2f", vacuum.spaceSavedMb))MB)"
                    )
                }
            }
            if let analyze = housekeeping.maintenanceResult.analyzeResult {
                if analyze.analyzed {
                    print("  ANALYZE: ✅")
                }
            }
        }

        print(String(repeating: "=", count: 50))
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// GCResult is directly emitted as JSON payload
