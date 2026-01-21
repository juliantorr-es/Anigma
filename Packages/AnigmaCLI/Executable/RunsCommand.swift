//
//  RunsCommand.swift
//  AnigmaCLIExecutable
//
//  Commands for viewing and managing run history.
//

import AnigmaCLICore
import AnigmaCLIDatabase
import ArgumentParser
import Foundation

struct AnigmaRunsCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "runs",
            abstract: "View and manage run history.",
            subcommands: [
                RunsListCommand.self,
                RunsShowCommand.self,
                RunsReceiptsCommand.self
            ]
        )
    }
}

// MARK: - Runs List

struct RunsListCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "list",
            abstract: "List recent runs."
        )
    }

    @Option(name: .long, help: "Maximum number of runs to show.")
    var limit: Int = 20

    @Option(name: .long, help: "Filter by status (pending/running/completed/failed/cancelled).")
    var status: String?

    @Flag(name: .long, help: "Show verbose output with more details.")
    var verbose: Bool = false

    @OptionGroup var output: OutputOptions

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        defer { db.close() }

        let receiptManager = CLIReceiptManager(database: db)
        let runManager = CLIRunManager(database: db, receiptManager: receiptManager)

        // Parse status filter
        var statusFilter: RunStatus?
        if let statusStr = status {
            guard let parsed = RunStatus(rawValue: statusStr.lowercased()) else {
                print("❌ Invalid status: \(statusStr)")
                print("   Valid options: pending, running, completed, failed, cancelled")
                throw ExitCode.failure
            }
            statusFilter = parsed
        }

        let runs = try await runManager.listRuns(limit: limit, status: statusFilter)

        if runs.isEmpty {
            print("No runs found")
            return
        }

        print("📋 Recent Runs (\(runs.count)):\n")

        for run in runs {
            let statusIcon = getStatusIcon(run.status)
            let modeStr = run.dryRun ? "\(run.mode.rawValue)-dry" : run.mode.rawValue

            let createdDate = Date(timeIntervalSince1970: run.createdAt)
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let dateStr = formatter.string(from: createdDate)

            print("\(statusIcon) [\(run.runID.prefix(8))] \(run.taskSummary)")
            print("   Mode: \(modeStr) | Status: \(run.status.rawValue) | Created: \(dateStr)")

            if verbose {
                if let worktree = run.worktreePath {
                    print("   Worktree: \(worktree)")
                }
                if let commit = run.baseCommit {
                    print("   Commit: \(commit.prefix(12))")
                }
                if let completedAt = run.completedAt {
                    let duration = completedAt - run.createdAt
                    print("   Duration: \(String(format: "%.2f", duration))s")
                }
                print("   Spec Hash: \(run.specHash.prefix(12))...")
            }

            print("")
        }
    }

    private func getStatusIcon(_ status: RunStatus) -> String {
        switch status {
        case .pending: return "⏳"
        case .running: return "🏃"
        case .completed: return "✅"
        case .failed: return "❌"
        case .cancelled: return "🚫"
        }
    }
}

// MARK: - Runs Show

struct RunsShowCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "show",
            abstract: "Show detailed information about a run."
        )
    }

    @Argument(help: "Run ID (or prefix) to show.")
    var runID: String

    @Flag(name: .long, help: "Show step details.")
    var steps: Bool = false

    @Flag(name: .long, help: "Show receipts.")
    var receipts: Bool = false

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        defer { db.close() }

        let receiptManager = CLIReceiptManager(database: db)
        let runManager = CLIRunManager(database: db, receiptManager: receiptManager)

        // Find run (support prefix matching)
        let fullRunID = try await findRunID(runManager: runManager, prefix: runID)

        guard let details = try await runManager.getRunDetails(runID: fullRunID) else {
            print("❌ Run not found: \(runID)")
            throw ExitCode.failure
        }

        let run = details.run

        // Show run details
        print("📋 Run Details\n")
        print("Run ID:        \(run.runID)")
        print("Task:          \(run.taskSummary)")
        if let taskDetails = run.taskDetails {
            print("Details:       \(taskDetails)")
        }
        print("Mode:          \(run.mode.rawValue) \(run.dryRun ? "(dry-run)" : "")")
        print("Status:        \(getStatusIcon(run.status)) \(run.status.rawValue)")

        let createdDate = Date(timeIntervalSince1970: run.createdAt)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        print("Created:       \(formatter.string(from: createdDate))")

        if let completedAt = run.completedAt {
            let completedDate = Date(timeIntervalSince1970: completedAt)
            print("Completed:     \(formatter.string(from: completedDate))")
            let duration = completedAt - run.createdAt
            print("Duration:      \(formatDuration(duration))")
        }

        if let worktree = run.worktreePath {
            print("Worktree:      \(worktree)")
        }
        if let commit = run.baseCommit {
            print("Base Commit:   \(commit)")
        }
        print("Spec Hash:     \(run.specHash)")

        // Show steps if requested
        if steps {
            print("\n📝 Steps (\(details.steps.count)):\n")
            for step in details.steps {
                let statusIcon = getStepStatusIcon(step.status)
                print("\(statusIcon) Step \(step.stepNumber): \(step.actionType)")
                print("   Status: \(step.status.rawValue)")

                if let data = step.actionData {
                    print("   Data: \(data)")
                }

                if let error = step.errorMessage {
                    print("   Error: \(error)")
                }

                if let completedAt = step.completedAt {
                    let duration = completedAt - step.createdAt
                    print("   Duration: \(String(format: "%.2f", duration))s")
                }

                print("")
            }
        } else if !details.steps.isEmpty {
            print("\nSteps:         \(details.steps.count) (use --steps to show)")
        }

        // Show receipts if requested
        if receipts {
            print("\n🧾 Receipts (\(details.receipts.count)):\n")
            for receipt in details.receipts {
                print("  [\(receipt.receiptID.prefix(8))] \(receipt.type.rawValue)")
                if let reqHash = receipt.requestHash {
                    print("    Request:  \(reqHash.prefix(16))...")
                }
                if let resHash = receipt.responseHash {
                    print("    Response: \(resHash.prefix(16))...")
                }

                let date = Date(timeIntervalSince1970: receipt.timestamp)
                formatter.dateStyle = .none
                formatter.timeStyle = .medium
                print("    Time: \(formatter.string(from: date))")
                print("")
            }
        } else if !details.receipts.isEmpty {
            print("\nReceipts:      \(details.receipts.count) (use --receipts to show)")
        }
    }

    private func findRunID(runManager: CLIRunManager, prefix: String) async throws -> String {
        // If it's a full UUID, use it directly
        if prefix.count == 36 {
            return prefix
        }

        // Otherwise, search for matching prefix
        let runs = try await runManager.listRuns(limit: 100)
        let matches = runs.filter { $0.runID.hasPrefix(prefix) }

        if matches.isEmpty {
            throw RunsCommandError.runNotFound(prefix)
        } else if matches.count > 1 {
            print("⚠️  Multiple runs match '\(prefix)':")
            for run in matches.prefix(5) {
                print("   \(run.runID.prefix(12)) - \(run.taskSummary)")
            }
            throw RunsCommandError.ambiguousRunID(prefix)
        }

        return matches[0].runID
    }

    private func getStatusIcon(_ status: RunStatus) -> String {
        switch status {
        case .pending: return "⏳"
        case .running: return "🏃"
        case .completed: return "✅"
        case .failed: return "❌"
        case .cancelled: return "🚫"
        }
    }

    private func getStepStatusIcon(_ status: StepStatus) -> String {
        switch status {
        case .pending: return "⏳"
        case .running: return "🏃"
        case .completed: return "✅"
        case .failed: return "❌"
        case .skipped: return "⏭️"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%.1fs", duration)
        }
    }
}

// MARK: - Runs Receipts

struct RunsReceiptsCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "receipts",
            abstract: "Show receipts for a run and verify chain integrity."
        )
    }

    @Argument(help: "Run ID (or prefix) to show receipts for.")
    var runID: String

    @Flag(name: .long, help: "Verify receipt chain integrity.")
    var verify: Bool = false

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()
        defer { db.close() }

        let receiptManager = CLIReceiptManager(database: db)
        let runManager = CLIRunManager(database: db, receiptManager: receiptManager)

        // Find run
        let fullRunID = try await findRunID(runManager: runManager, prefix: runID)

        // Get receipts
        let receipts = try await receiptManager.listReceipts(runID: fullRunID)

        if receipts.isEmpty {
            print("No receipts found for run \(runID)")
            return
        }

        print("🧾 Receipts for Run [\(fullRunID.prefix(8))]:\n")

        for (index, receipt) in receipts.enumerated() {
            print("[\(index + 1)] \(receipt.type.rawValue)")
            print("    ID: \(receipt.receiptID)")

            if let reqHash = receipt.requestHash {
                print("    Request Hash:  \(reqHash)")
            }
            if let resHash = receipt.responseHash {
                print("    Response Hash: \(resHash)")
            }

            if !receipt.metadata.isEmpty {
                print("    Metadata:")
                for (key, value) in receipt.metadata.sorted(by: { $0.key < $1.key }) {
                    print("      \(key): \(value)")
                }
            }

            let date = Date(timeIntervalSince1970: receipt.timestamp)
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            print("    Timestamp: \(formatter.string(from: date))")
            print("")
        }

        // Verify chain if requested
        if verify {
            print("🔍 Verifying Receipt Chain...\n")

            let verification = try await receiptManager.verifyChain(runID: fullRunID)

            if verification.valid {
                print("✅ Receipt chain is valid")
                print("   Total receipts: \(verification.receiptCount)")
            } else {
                print("❌ Receipt chain has issues:")
                for error in verification.errors {
                    print("   - \(error)")
                }
                throw ExitCode.failure
            }
        }
    }

    private func findRunID(runManager: CLIRunManager, prefix: String) async throws -> String {
        if prefix.count == 36 {
            return prefix
        }

        let runs = try await runManager.listRuns(limit: 100)
        let matches = runs.filter { $0.runID.hasPrefix(prefix) }

        if matches.isEmpty {
            throw RunsCommandError.runNotFound(prefix)
        } else if matches.count > 1 {
            throw RunsCommandError.ambiguousRunID(prefix)
        }

        return matches[0].runID
    }
}

// MARK: - Errors

enum RunsCommandError: Error, CustomStringConvertible {
    case runNotFound(String)
    case ambiguousRunID(String)

    var description: String {
        switch self {
        case .runNotFound(let id):
            return "Run not found: \(id)"
        case .ambiguousRunID(let id):
            return "Ambiguous run ID: \(id) (multiple matches)"
        }
    }
}
