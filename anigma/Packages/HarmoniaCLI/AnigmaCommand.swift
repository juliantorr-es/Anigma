//
//  AnigmaCommand.swift
//  HarmoniaCLI
//
//  Anigma CLI entrypoints inside the Harmonia binary.
//

import AnigmaCLICore
import AnigmaCLIOrchestrator
import AnigmaCLIProviders
import ArgumentParser
import Foundation

struct AnigmaCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "anigma",
            abstract: "Anigma CLI orchestration commands.",
            subcommands: [AnigmaProvidersCommand.self, AnigmaPlanCommand.self]
        )
    }
}

private struct ProviderListPayload: Encodable {
    let providers: [ProviderStatus]
}

struct AnigmaProvidersCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "providers",
            abstract: "List discovered Anigma providers."
        )
    }

    @OptionGroup var output: OutputOptions

    func run() throws {
        let registry = ProviderRegistry()
        let statuses = registry.statuses()

        switch output.format {
        case .text:
            for status in statuses {
                let availability = status.available ? "available" : "unavailable"
                print("- \(status.descriptor.displayName) [\(status.descriptor.kind.rawValue)] \(availability)")
                if let reason = status.reason {
                    print("  reason: \(reason)")
                }
                if let path = status.resolvedPath {
                    print("  path: \(path)")
                }
            }
        case .json:
            let payload = ProviderListPayload(providers: statuses)
            try OutputWriter.emit(
                command: "anigma.providers",
                payload: payload,
                format: output.format
            )
        }
    }
}

private struct PlanPayload: Encodable {
    let task: TaskIntent
    let plan: PlanOutcome
}

struct AnigmaPlanCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "plan",
            abstract: "Generate a contract and route for a task."
        )
    }

    @Argument(help: "Task summary to plan.")
    var summary: String

    @Option(name: .long, help: "Optional task details.")
    var details: String?

    @OptionGroup var output: OutputOptions

    mutating func run() async throws {
        let task = TaskIntent(summary: summary, details: details)
        let rootPath = FileManager.default.currentDirectoryPath
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        let context = TaskContext(repoRoot: rootURL, worktreeRoot: rootURL)

        let orchestrator = AnigmaCLIOrchestrator()
        let outcome = try await orchestrator.plan(task: task, context: context)

        switch output.format {
        case .text:
            print("task: \(task.summary)")
            print("contract: \(outcome.contract.id.uuidString)")
            print("objective: \(outcome.contract.objective)")
            print("acceptance:")
            for criterion in outcome.contract.acceptanceCriteria {
                print("  - \(criterion)")
            }
            if let selected = outcome.route.selected {
                print("route: \(selected.displayName) (\(selected.id))")
            } else {
                print("route: none")
            }
            print("reason: \(outcome.route.reason)")
        case .json:
            let payload = PlanPayload(task: task, plan: outcome)
            try OutputWriter.emit(
                command: "anigma.plan",
                payload: payload,
                format: output.format
            )
        }
    }
}
