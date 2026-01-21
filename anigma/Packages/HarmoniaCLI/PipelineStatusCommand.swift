//
//  PipelineStatusCommand.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import AnigmaCore  // To access PipelineRunner, PipelinePlan, etc.
import ArgumentParser
import ContractsCore  // For ContractReceipt, ContractID, etc.
import Foundation

struct PipelineStatusCommand: AsyncParsableCommand {
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
        print("🔍 Analyzing pipeline status...")

        // Assume AnigmaCore.initialize has been called externally
        // and provides a way to get a PipelineRunner instance.
        // For now, we'll instantiate one with a mock MLWorkerPath.
        // In a real application, this would come from a global service locator or DI.
        let mlWorkerPath = "/usr/local/bin/ml-worker"  // Placeholder path

        // It's not ideal to instantiate PipelineRunner here like this, as it implies
        // creating new DB connections etc. A real CLI would likely connect to an
        // already running service or use a well-defined persistent store.
        // However, for demonstrating the 'flashlight' concept, this works.
        let runner = try await ModulePipelineFactory.createRunner(mlWorkerPath: mlWorkerPath)

        let receipts = await runner.allReceipts(sessionID: sessionID)

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
