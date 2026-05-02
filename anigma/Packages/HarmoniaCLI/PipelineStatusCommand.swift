//
//  PipelineStatusCommand.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import ArgumentParser
import ContractsCore  // For ContractReceipt, ContractID, etc.
import Foundation

private enum PipelineStatusRunner {
    static func run(sessionID: String?, verbose: Bool) {
        print("🔍 Analyzing pipeline status...")

        print("Pipeline runner integration is not wired in this build.")
        let receipts: [ContractReceipt] = []

        guard !receipts.isEmpty else {
            print("No pipeline sessions found.")
            return
        }

        print("\n--- Pipeline Sessions Status ---")

        let sessions = Set(receipts.map { $0.sessionID }).sorted()
        for session in sessions {
            print("\nSession ID: \(session)")
            var sessionReceipts: [ContractReceipt] = []
            for receipt in receipts where receipt.sessionID == session {
                sessionReceipts.append(receipt)
            }
            sessionReceipts.sort { $0.startedAt < $1.startedAt }

            var activeReceipts: [ContractReceipt] = []
            var failedReceipts: [ContractReceipt] = []
            var satisfiedReceipts: [ContractReceipt] = []
            for receipt in sessionReceipts {
                switch receipt.status {
                case .failed, .rejected, .quarantined:
                    failedReceipts.append(receipt)
                case .satisfied:
                    satisfiedReceipts.append(receipt)
                @unknown default:
                    activeReceipts.append(receipt)
                }
            }

            print("  Total Contracts: \(sessionReceipts.count)")
            print("  Satisfied: \(satisfiedReceipts.count)")
            print("  Active/Pending: \(activeReceipts.count)")
            print("  Failed/Rejected/Quarantined: \(failedReceipts.count)")

            if !activeReceipts.isEmpty {
                print("  Active Contracts:")
                for receipt in activeReceipts {
                    print(
                        "    - \(receipt.contractID.name) (Status: \(receipt.status.rawValue), Started: \(receipt.startedAt))"
                    )
                }
            }

            if !failedReceipts.isEmpty {
                print("  Problematic Contracts:")
                for receipt in failedReceipts {
                    print(
                        "    - \(receipt.contractID.name) (Status: \(receipt.status.rawValue), Run ID: \(receipt.runID))"
                    )
                }
            }

            if verbose {
                print("  All Receipts (Verbose):")
                for receipt in sessionReceipts {
                    print(
                        "    - Contract: \(receipt.contractID.name), Status: \(receipt.status.rawValue), Run ID: \(receipt.runID)"
                    )
                    print("      Started: \(receipt.startedAt), Ended: \(receipt.endedAt)")
                    if !receipt.inputRefs.isEmpty {
                        print("      Inputs: \(receipt.inputRefs.joined(separator: ", "))")
                    }
                    if !receipt.outputRefs.isEmpty {
                        print("      Outputs: \(receipt.outputRefs.joined(separator: ", "))")
                    }
                    print(
                        "      Metrics: WallTime=\(receipt.metrics.wallTimeMs)ms, CacheHit=\(receipt.metrics.cacheHit)"
                    )
                }
            }

            if sessionID != nil {
                let statusCounts = Dictionary(grouping: sessionReceipts) { $0.status }
                    .mapValues { $0.count }
                let statusSummary = ContractStatus.allCases
                    .map { status in
                        "\(status.rawValue)=\(statusCounts[status, default: 0])"
                    }
                    .joined(separator: ", ")
                print("  Status Summary: \(statusSummary)")
            }
        }
    }
}

struct PipelineCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "pipeline",
            abstract: "Pipeline operations.",
            subcommands: [PipelineStatusSubcommand.self]
        )
    }
}

struct PipelineStatusSubcommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "status",
            abstract: "Check the status of the Anigma pipeline.",
            discussion: "Displays current pipeline health and recent runs."
        )
    }

    @Argument(help: "The session ID to inspect (optional, inspects all if omitted).")
    var sessionID: String?

    @Flag(help: "Show detailed information about all receipts.")
    var verbose: Bool = false

    mutating func run() async throws {
        PipelineStatusRunner.run(sessionID: sessionID, verbose: verbose)
    }
}

struct PipelineStatusCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "status",
            abstract: "Legacy alias for `pipeline status`."
        )
    }

    @Argument(help: "The session ID to inspect (optional, inspects all if omitted).")
    var sessionID: String?

    @Flag(help: "Show detailed information about all receipts.")
    var verbose: Bool = false

    mutating func run() async throws {
        print("ℹ️ Legacy command detected: `harmonia status` → use `harmonia pipeline status`.")
        PipelineStatusRunner.run(sessionID: sessionID, verbose: verbose)
    }
}
