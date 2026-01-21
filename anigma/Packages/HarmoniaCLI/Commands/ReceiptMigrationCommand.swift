//
//  ReceiptMigrationCommand.swift
//  HarmoniaCLI
//
//  CLI command for migrating receipts to canonical BLAKE3(JCS(payload)) IDs
//

import Foundation
import ArgumentParser
import ExecutionCore

struct ReceiptMigrationCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "receipt-migrate",
        abstract: "Migrate receipts to canonical BLAKE3(JCS(payload)) ID derivation",
        subcommands: [
            AnalyzeSubcommand.self,
            MigrateSubcommand.self,
            VerifySubcommand.self
        ]
    )
}

// MARK: - Analyze Subcommand

struct AnalyzeSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analyze",
        abstract: "Analyze migration impact without making changes"
    )

    @Option(help: "Path to JSON file containing receipts array")
    var input: String

    @Flag(help: "Output analysis as JSON")
    var json = false

    func run() throws {
        // Read receipts
        let data = try Data(contentsOf: URL(fileURLWithPath: input))
        let receipts = try JSONDecoder().decode([ReceiptWire].self, from: data)

        // Analyze
        let analysis = ReceiptMigrator.analyzeImpact(receipts)

        if json {
            let output = try JSONSerialization.data(withJSONObject: analysis, options: .prettyPrinted)
            print(String(data: output, encoding: .utf8) ?? "")
        } else {
            let total = analysis["total_receipts"] ?? 0
            let needsMigration = analysis["needs_migration"] ?? 0
            let alreadyCorrect = analysis["already_correct"] ?? 0

            print("Receipt Migration Analysis")
            print("==========================")
            print("Total receipts: \(total)")
            print("Needs migration: \(needsMigration)")
            print("Already correct: \(alreadyCorrect)")
            if let percentage = analysis["migration_percentage"] as? Double {
                print(String(format: "Migration percentage: %.1f%%", percentage))
            }
        }
    }
}

// MARK: - Migrate Subcommand

struct MigrateSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate",
        abstract: "Perform receipt migration to canonical IDs"
    )

    @Option(help: "Path to JSON file containing receipts array")
    var input: String

    @Option(help: "Output file path for migrated receipts")
    var output: String?

    @Option(help: "Authority performing the migration")
    var authority: String = "harmonia-cli"

    @Flag(help: "Dry-run mode (no changes)")
    var dryRun = false

    func run() throws {
        // Read receipts
        let data = try Data(contentsOf: URL(fileURLWithPath: input))
        let receipts = try JSONDecoder().decode([ReceiptWire].self, from: data)

        print("Migrating \\(receipts.count) receipts...")

        // Migrate
        let results = try ReceiptMigrator.migrateReceipts(receipts)

        // Count changes
        let changedCount = results.filter { $0.oldID != $0.newID }.count
        print("Migration complete: \(changedCount) receipts changed, \(results.count - changedCount) already canonical")

        // Output results if requested
        if let outputPath = output, !dryRun {
            let migratedReceipts = results.map { $0.receipt }
            let encoded = try JSONEncoder().encode(migratedReceipts)
            try encoded.write(to: URL(fileURLWithPath: outputPath))
            print("Migrated receipts written to: \\(outputPath)")
        }

        // Log migration results
        for result in results {
            if result.oldID != result.newID {
                print("  [CHANGED] \\(result.oldID) → \\(result.newID)")
            } else {
                print("  [OK] \\(result.newID)")
            }
        }
    }
}

// MARK: - Verify Subcommand

struct VerifySubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Verify that receipts have canonical IDs"
    )

    @Option(help: "Path to JSON file containing receipts array")
    var input: String

    func run() throws {
        // Read receipts
        let data = try Data(contentsOf: URL(fileURLWithPath: input))
        let receipts = try JSONDecoder().decode([ReceiptWire].self, from: data)

        print("Verifying \\(receipts.count) receipts...")

        var valid = 0
        var invalid = 0

        for receipt in receipts {
            do {
                try receipt.verifyReceiptID()
                valid += 1
            } catch {
                invalid += 1
                print("  [INVALID] \\(receipt.receiptID): \\(error.localizedDescription)")
            }
        }

        print("Verification complete: \\(valid) valid, \\(invalid) invalid")

        if invalid > 0 {
            throw ExitCode.failure
        }
    }
}

// MARK: - Exit Code

enum ExitCode: Error {
    case failure
}
