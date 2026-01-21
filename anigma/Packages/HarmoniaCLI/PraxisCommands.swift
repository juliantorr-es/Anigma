//
//  PraxisCommands.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import ArgumentParser
import Foundation
import PraxisCore

private struct PraxisEnvelope<Payload: Encodable>: Encodable {
    let status: String
    let timestamp: String
    let command: String
    let payload: Payload
}

/// Root `praxis` command for Harmonia CLI extensions.
struct PraxisCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "praxis",
            abstract: "Inspect Praxis sessions and emit boundary tickets.",
            subcommands: [PraxisDiagnoseCommand.self, PraxisBoundaryTicketCommand.self],
            defaultSubcommand: PraxisDiagnoseCommand.self
        )
    }
}

private protocol PraxisCommon {
    func repositoryRoot() -> URL
}

extension PraxisCommon {
    func repositoryRoot() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    func defaultSessionIndex() throws -> PraxisSessionIndex {
        let root = repositoryRoot()
        let ledgerURL = root.appendingPathComponent(".opencode/ledger/workflow.jsonl")
        return try PraxisSessionIndex(ledgerURL: ledgerURL)
    }
}

/// Diagnose command that summarizes existing Praxis sessions deterministically.
struct PraxisDiagnoseCommand: AsyncParsableCommand, PraxisCommon {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "diagnose",
            abstract: "Emit a JSON snapshot of session receipt chains."
        )
    }

    @Option(help: "Specific session ID to diagnose.")
    var sessionID: String?

    mutating func run() async throws {
        let index = try defaultSessionIndex()
        let module = PraxisModuleEnvironment(
            rulepack: Rulepack(hardInvariants: [], policies: [:]),
            workflow: WorkflowSpec(name: "praxis", steps: []),
            sessionIndex: index,
            ticketService: BoundaryTicketService()
        )
        let diagnosis = module.diagnose(sessionID: sessionID)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let envelope = PraxisEnvelope(
            status: "ok", timestamp: isoFormatter.string(from: Date()),
            command: "harmonia praxis diagnose", payload: diagnosis)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    }
}

/// Generate a boundary ticket from a blocking event.
struct PraxisBoundaryTicketCommand: AsyncParsableCommand, PraxisCommon {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "boundary-ticket",
            abstract: "Emit a boundary ticket given a blockage event."
        )
    }

    @Option(help: "Session ID referencing the blocked workflow.")
    var sessionID: String

    @Option(help: "Patch hash under scrutiny (optional).")
    var patchHash: String?

    @Option(help: "Comma-separated rule IDs that were violated.")
    var ruleIDs: String

    @Option(help: "Gate name that reported the block (optional).")
    var gateName: String?

    @Option(help: "Human-readable reason for the block.")
    var reason: String

    mutating func run() async throws {
        let index = try defaultSessionIndex()
        let module = PraxisModuleEnvironment(
            rulepack: Rulepack(hardInvariants: [], policies: [:]),
            workflow: WorkflowSpec(name: "praxis", steps: []),
            sessionIndex: index,
            ticketService: BoundaryTicketService()
        )

        let receipts =
            index.session(withID: sessionID)?
            .patchChains
            .first { $0.patchHash == patchHash }
            .map { $0.records.compactMap { $0.receiptID } } ?? []

        let session = index.session(withID: sessionID)
        let targetChain =
            session?.patchChains.first { $0.patchHash == patchHash }
            ?? session?.patchChains.first
        let acceptanceRefs = targetChain?.acceptanceRefs ?? []
        let event = BlockageEvent(
            sessionID: sessionID,
            patchHash: patchHash,
            violatedRuleIDs: ruleIDs.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            },
            gateName: gateName,
            receiptIDs: receipts,
            reason: reason,
            phaseId: targetChain?.phaseId,
            acceptanceRefs: acceptanceRefs,
            stopState: .blocked
        )

        let ticket = try module.createBoundaryTicket(for: event)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let envelope = PraxisEnvelope(
            status: "ok", timestamp: isoFormatter.string(from: Date()),
            command: "harmonia praxis boundary-ticket", payload: ticket)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    }
}
