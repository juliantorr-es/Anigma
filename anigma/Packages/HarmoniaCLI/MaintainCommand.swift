//
//  MaintainCommand.swift
//  HarmoniaCLI
//
//  Database maintenance operations (WAL, VACUUM, ANALYZE).
//

import AnigmaCore
import ArgumentParser
import DatabaseCore
import Foundation

struct Maintain: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "maintain",
            abstract: "Perform database housekeeping operations",
            discussion: """
                Database maintenance includes WAL checkpoint, VACUUM for defragmentation,
                and ANALYZE for query optimization.

                Operations can run automatically or be triggered manually to manage
                storage growth and maintain query performance.
                """
        )
    }

    @OptionGroup var output: OutputOptions

    @Flag(
        name: .shortAndLong,
        help: "Only show what would be done without making changes."
    )
    var dryRun: Bool = false

    @Flag(
        name: .long,
        help: "Run WAL checkpoint to compact write-ahead log."
    )
    var checkpoint: Bool = false

    @Flag(
        name: .long,
        help: "Run VACUUM to defragment database."
    )
    var vacuum: Bool = false

    @Flag(
        name: .long,
        help: "Run ANALYZE to update query statistics."
    )
    var analyze: Bool = false

    @Flag(
        name: .long,
        help: "Run all maintenance operations."
    )
    var all: Bool = false

    @Option(
        name: .long,
        help: "VACUUM mode: 'full' or 'incremental'."
    )
    var vacuumMode: String = "full"

    func run() async throws {
        // Initialize database
        let dbPath = getDatabasePath()
        let db = DatabaseActor(dbPath: dbPath)
        try await db.open()

        var report = MaintenanceReport(startTime: Date())

        // Determine which operations to run
        let runCheckpoint = all || checkpoint
        let runVacuum = all || vacuum
        let runAnalyze = all || analyze

        if !runCheckpoint && !runVacuum && !runAnalyze {
            // Default: run all
            print("⚠️  No operations specified. Running all maintenance operations.")
            print("   Use --checkpoint, --vacuum, --analyze, or --all to specify.")
            return
        }

        // Run requested operations
        if runCheckpoint {
            print("📝 WAL Checkpoint...")
            let walManager = WALManager(database: db)
            let result = try await walManager.performCheckpoint()
            print("   Checkpoint completed: \(formatBytes(result.bytesFreed)) freed")
            report.checkpointResult = result
        }

        if runVacuum {
            print("🗑️  Running VACUUM...")
            let mode: VacuumMode = vacuumMode == "incremental" ? .incremental : .full
            let maintenance = DatabaseMaintenance(database: db)
            let result = try await maintenance.performVacuum(mode: mode)
            print("   VACUUM completed: \(String(format: "%.2f", result.spaceSavedMb))MB saved")
            report.vacuumResult = result
        }

        if runAnalyze {
            print("📊 Running ANALYZE...")
            let maintenance = DatabaseMaintenance(database: db)
            let result = try await maintenance.analyzeDatabase()
            print("   ANALYZE completed in \(String(format: "%.2f", result.duration))s")
            report.analyzeResult = result
        }

        report.endTime = Date()

        // Emit results
        try emitMaintenanceReport(report, format: output.format, dryRun: dryRun)

        print("\n✅ Database maintenance completed")
    }

    private func getDatabasePath() -> String {
        if let dbPath = ProcessInfo.processInfo.environment["HARMONIA_DB_PATH"] {
            return dbPath
        }
        return FileManager.default.currentDirectoryPath + "/harmonia.db"
    }

    private func emitMaintenanceReport(
        _ report: MaintenanceReport, format: OutputFormat, dryRun: Bool
    ) throws {
        switch format {
        case .json:
            try OutputWriter.emit(
                command: "maintain",
                payload: report,
                format: format
            )
        case .text:
            emitTextReport(report)
        }
    }

    private func emitTextReport(_ report: MaintenanceReport) {
        print("\n📊 Database Maintenance Report")
        print(String(repeating: "=", count: 50))
        print("Duration: \(String(format: "%.2f", report.duration ?? 0))s")

        if let checkpoint = report.checkpointResult {
            print("\n📝 WAL Checkpoint:")
            print("  Performed: \(checkpoint.checkpointPerformed ? "Yes" : "No")")
            print("  Bytes Freed: \(formatBytes(checkpoint.bytesFreed))")
            print("  Duration: \(String(format: "%.2f", checkpoint.duration))s")
        }

        if let vacuum = report.vacuumResult {
            print("\n🗑️  VACUUM:")
            print("  Performed: \(vacuum.vacuumPerformed ? "Yes" : "No")")
            print("  Space Saved: \(String(format: "%.2f", vacuum.spaceSavedMb))MB")
            print("  Duration: \(String(format: "%.2f", vacuum.duration))s")
            print("  Fragmentation: \(String(format: "%.1f", vacuum.fragmentationRatio * 100))%")
        }

        if let analyze = report.analyzeResult {
            print("\n📊 ANALYZE:")
            print("  Performed: \(analyze.analyzed ? "Yes" : "No")")
            print("  Duration: \(String(format: "%.2f", analyze.duration))s")
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

// MARK: - Report Types

struct MaintenanceReport: Codable, Sendable {
    let startTime: Date
    var endTime: Date?
    var checkpointResult: WALCheckpointResult?
    var vacuumResult: VacuumResult?
    var analyzeResult: AnalyzeResult?

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }
}
