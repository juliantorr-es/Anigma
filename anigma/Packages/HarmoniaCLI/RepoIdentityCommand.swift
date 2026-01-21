//
//  RepoIdentityCommand.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import ArgumentParser
import Foundation
import PraxisCore
import PraxisModule

struct RepoIdentityCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "repo-identity",
            abstract: "Preflight gate ensuring current worktree matches the approved repo identity."
        )
    }

    @Option(name: .long, help: "Path to repo identity policy JSON.")
    var policy: String = ".anigma/repo-identity.json"

    @Option(name: .long, help: "Phase ID to attach to a ticket if blocked.")
    var phaseID: String = "PHASE-REPO-IDENTITY"

    @Option(
        name: .customLong("acceptance-ref"), parsing: .upToNextOption,
        help: "AcceptanceRefs to attach to tickets when blocked.")
    var acceptanceRefs: [String] = []

    @Flag(name: .long, help: "Emit a Praxis boundary ticket when gate blocks.")
    var emitTicket: Bool = true

    mutating func run() async throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let policyURL = URL(fileURLWithPath: policy, relativeTo: cwd).standardizedFileURL

        let gate = PraxisModule.RepoIdentityGate()
        let policyValue = try PraxisModule.RepoIdentityPolicy.load(from: policyURL)
        let result = gate.evaluate(policy: policyValue, cwd: cwd)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = try encoder.encode(result)
        FileHandle.standardOutput.write(payload)
        FileHandle.standardOutput.write(Data("\n".utf8))

        if emitTicket && !result.ok {
            let artifactsDir = cwd.appendingPathComponent("Artifacts", isDirectory: true)
            await gate.emitTicketIfBlocked(
                result: result,
                phaseID: phaseID,
                acceptanceRefs: acceptanceRefs,
                ticketService: BoundaryTicketService(),
                artifactsDir: artifactsDir
            )
            throw ExitCode.failure
        }

        if !result.ok {
            throw ExitCode.failure
        }

        if !result.ok {
            throw ExitCode.failure
        }
    }
}
