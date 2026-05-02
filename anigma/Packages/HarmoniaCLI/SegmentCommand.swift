//
//  SegmentCommand.swift
//  HarmoniaCLI
//
//  Master ledger segmentation management.
//

import AnigmaCore
import ArgumentParser
import DatabaseCore
import Foundation

struct Segment: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "segment",
            abstract: "Manage master ledger segmentation",
            discussion: """
                Master ledger segmentation divides the event log into time-based segments
                to prevent unbounded growth and improve query performance.

                Operations include rotation, archival, and viewing statistics.
                """
        )
    }

    @OptionGroup var output: OutputOptions

    @Flag(
        name: .long,
        help: "Show current segmentation statistics."
    )
    var stats: Bool = false

    @Flag(
        name: .long,
        help: "Rotate to new segment if thresholds are exceeded."
    )
    var rotate: Bool = false

    @Flag(
        name: .long,
        help: "Migrate from legacy master ledger to segmented design."
    )
    var migrate: Bool = false

    @Flag(
        name: .long,
        help: "List all existing segments."
    )
    var list: Bool = false

    @Option(
        name: .long,
        help: "Archive segments older than N days."
    )
    var archiveOlderThan: Int?

    func run() async throws {
        let dbPath = getDatabasePath()
        let db: any DatabaseExecutor = DatabaseActor(path: dbPath)
        try await db.open()

        if migrate {
            print("📦 Migrating master ledger to segmentation...")
            let store = try await MasterLedgerStore(database: db)
            let result = try await store.migrateToSegmentation()

            print("✅ Migration complete:")
            print("   Events migrated: \(result.migratedEvents)")
            print("   Segments created: \(result.createdSegments)")
            print("   Duration: \(String(format: "%.2f", result.duration))s")

            return
        }

        if stats {
            print("📊 Ledger Segmentation Statistics")
            print(String(repeating: "=", count: 50))

            let store = try await MasterLedgerStore(database: db)
            if let segStats = try await store.getSegmentationStats() {
                print("Total Segments: \(segStats.totalSegments)")
                print("Active Segments: \(segStats.activeSegments)")
                print("Closed Segments: \(segStats.closedSegments)")
                print("Archived Segments: \(segStats.archivedSegments)")
                print("Total Events: \(segStats.totalEvents)")
                print("Total Size: \(formatBytes(Int64(segStats.totalBytes)))")
            } else {
                print("No segmentation statistics available.")
            }
            print(String(repeating: "=", count: 50))

            return
        }

        if list {
            print("📋 Master Ledger Segments")
            print(String(repeating: "=", count: 50))

            let segmentManager = MasterLedgerSegmentationManager(database: db)
            let segments = try await segmentManager.getSegments(limit: 100)

            if segments.isEmpty {
                print("No segments found.")
            } else {
                for segment in segments {
                    let status = segment.isClosed ? "closed" : "active"
                    let createdStr = ISO8601DateFormatter().string(from: segment.createdAt)
                    print("  \(segment.segmentId) [\(status)] created: \(createdStr)")
                }
            }

            print(String(repeating: "=", count: 50))

            return
        }

        if rotate {
            print("🔄 Checking segment rotation...")
            let segmentManager = MasterLedgerSegmentationManager(database: db)
            let result = try await segmentManager.rotateIfNeeded()

            if result.rotationPerformed {
                print("✅ Rotation performed:")
                print("   Previous segment: \(result.previousSegmentId)")
                print("   New segment: \(result.newSegmentId)")
                print("   Events migrated: \(result.eventsMigrated)")
                print("   Duration: \(String(format: "%.2f", result.duration))s")
            } else {
                print("ℹ️  No rotation needed (thresholds not exceeded)")
                print("   Current segment: \(result.previousSegmentId)")
            }

            return
        }

        if let daysOld = archiveOlderThan {
            print("🗂️  Archiving segments older than \(daysOld) days...")
            let cutoffDate = Date().addingTimeInterval(-TimeInterval(daysOld * 86400))

            let segmentManager = MasterLedgerSegmentationManager(database: db)
            let result = try await segmentManager.archiveSegments(olderThan: cutoffDate)

            print("✅ Archival complete:")
            print("   Segments archived: \(result.segmentsArchived)")
            print("   Bytes archived: \(formatBytes(result.bytesArchived))")
            print("   Duration: \(String(format: "%.2f", result.duration))s")

            return
        }

        // If no specific operation, show stats by default
        print(
            "ℹ️  Use --stats, --rotate, --migrate, --list, or --archive-older-than to perform operations"
        )
    }

    private func getDatabasePath() -> String {
        // PostgreSQL is now the first-class database - SQLite is deprecated
        if let dbPath = ProcessInfo.processInfo.environment["HARMONIA_DB_PATH"] {
            return dbPath
        }
        if let dbURL = ProcessInfo.processInfo.environment["ANIGMA_DB_URL"] {
            return dbURL
        }
        return DatabaseConfiguration.defaultDatabasePath()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
