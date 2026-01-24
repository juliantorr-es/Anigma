//
//  Main.swift
//  AnigmaCLIExecutable
//
//  Entry point for the Anigma CLI modular monolith.
//

import AnigmaCLICore
import AnigmaCLIEventing
import AnigmaCLIMCP
import AnigmaCLIOnboarding
import AnigmaCLIOrchestrator
import AnigmaCLIProviders
import ArgumentParser
import Foundation
import AnigmaSidecar

public enum OutputFormat: String, CaseIterable, ExpressibleByArgument, Codable {
    case text
    case json
}

extension ExecutionMode: ExpressibleByArgument {}

public struct OutputOptions: ParsableArguments {
    @Option(name: .long, help: "Output format (text|json).")
    var format: OutputFormat = .json

    public init() {
    }
}

struct OutputEnvelope<P: Encodable>: Encodable {
    let status: String
    let timestamp: String
    let command: String
    let payload: P
    let contractVersion: Int

    enum CodingKeys: String, CodingKey {
        case status
        case timestamp
        case command
        case payload
        case contractVersion
    }
}

struct OutputWriter {
    static func emit<P: Encodable>(
        command: String,
        payload: P,
        format: OutputFormat,
        status: String = "ok"
    ) throws {
        let envelope = OutputEnvelope(
            status: status,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            command: command,
            payload: payload,
            contractVersion: 1
        )

        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(envelope)
            if let string = String(data: data, encoding: .utf8) {
                print(string)
            }
        case .text:
            print("status: \(status)")
            print("command: \(command)")
            print("payload: \(payload)")
        }
    }
}

private struct EventPrinter {
    static func consume(stream: CLIEventStream) async {
        let events = await stream.subscribe()
        for await event in events {
            write(event)
        }
    }

    static func write(_ event: CLIEvent) {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: event.timestamp)
        var line = "[\(timestamp)] [\(event.kind.rawValue)] \(event.message)"
        if !event.metadata.isEmpty {
            let details = event.metadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            line += " \(details)"
        }
        fputs(line + "\n", stderr)
    }
}

private func makeContext() -> TaskContext {
    let rootPath = FileManager.default.currentDirectoryPath
    let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
    return TaskContext(repoRoot: rootURL, worktreeRoot: rootURL)
}

private func makeOrchestrator(
    eventStream: CLIEventStream,
    enableMcp: Bool,
    registry: ProviderRegistry
) -> AnigmaCLIOrchestrator {
    let fallback = LocalContractBuilder()

    guard enableMcp else {
        return AnigmaCLIOrchestrator(
            registry: registry,
            contractBuilder: fallback,
            eventStream: eventStream
        )
    }

    let baseConfig = MCPContractBuilderConfiguration.fromEnvironment()
    let config = MCPContractBuilderConfiguration(
        enabled: baseConfig.enabled && enableMcp,
        includeDigest: baseConfig.includeDigest,
        maxTokens: baseConfig.maxTokens,
        temperature: baseConfig.temperature
    )
    let mcpBuilder = MCPContractBuilder(
        configuration: config,
        eventStream: eventStream,
        fallback: fallback
    )

    return AnigmaCLIOrchestrator(
        registry: registry,
        contractBuilder: mcpBuilder,
        eventStream: eventStream
    )
}

private func startEventStreamPrinter(enabled: Bool, stream: CLIEventStream) -> Task<Void, Never>? {
    guard enabled else {
        return nil
    }

    return Task {
        await EventPrinter.consume(stream: stream)
    }
}

private struct TUISessionOptions {
    var mode: ExecutionMode
    var dryRun: Bool
    var enableMcp: Bool
}

private actor TUIRenderer {
    private let maxLogs: Int
    private var logs: [String] = []
    private var mode: ExecutionMode
    private var status: String
    private var dryRun: Bool

    init(mode: ExecutionMode, dryRun: Bool, maxLogs: Int = 24) {
        self.mode = mode
        self.dryRun = dryRun
        self.status = "idle"
        self.maxLogs = maxLogs
    }

    func setMode(_ mode: ExecutionMode) {
        self.mode = mode
        render()
    }

    func setDryRun(_ dryRun: Bool) {
        self.dryRun = dryRun
        render()
    }

    func setStatus(_ status: String) {
        self.status = status
        render()
    }

    func appendEvent(_ event: CLIEvent) {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: event.timestamp)
        var line = "\(timestamp) [\(event.kind.rawValue)] \(event.message)"
        if !event.metadata.isEmpty {
            let details = event.metadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            line += " \(details)"
        }
        appendLog(line)
    }

    func appendLog(_ line: String) {
        logs.append(line)
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        render()
    }

    func render() {
        let separator = String(repeating: "-", count: 72)
        var output: [String] = []
        // Move to top-left (H) and clear to end of screen (J) to reduce flickering
        output.append("\u{001B}[H\u{001B}[J")
        output.append("Anigma CLI")
        output.append("Mode: \(mode.rawValue)  Dry-run: \(dryRun ? "yes" : "no")  Status: \(status)")
        output.append("Commands: :plan :run :dry-run :execute :quit :help")
        output.append(separator)
        output.append("Logs:")
        output.append(contentsOf: logs)
        output.append(separator)
        output.append("Enter task summary:")
        output.append("")

        let text = output.joined(separator: "\n")
        if let data = text.data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }
}

private func runTUISession(
    summary: String?,
    details: String?,
    options: TUISessionOptions
) async throws {
    let context = makeContext()
    let eventStream = CLIEventStream()
    let renderer = TUIRenderer(mode: options.mode, dryRun: options.dryRun)
    let registry = await ProviderRegistry.createDefault()
    let orchestrator = makeOrchestrator(
        eventStream: eventStream,
        enableMcp: options.enableMcp,
        registry: registry
    )

    let eventTask = Task {
        let events = await eventStream.subscribe()
        for await event in events {
            await renderer.appendEvent(event)
        }
    }

    await renderer.render()

    var mode = options.mode
    var dryRun = options.dryRun

    let runTask: (String) async throws -> Void = { taskSummary in
        let task = TaskIntent(summary: taskSummary, details: details)
        await renderer.setStatus("running")

        switch mode {
        case .plan:
            let outcome = try await orchestrator.plan(task: task, context: context)
            await renderer.appendLog("Contract: \(outcome.contract.id.uuidString)")
            await renderer.appendLog("Route: \(outcome.route.selected?.id ?? "none")")
        case .run:
            let outcome = try await orchestrator.run(
                task: task,
                context: context,
                dryRun: dryRun
            )
            await renderer.appendLog("Run status: \(outcome.status.rawValue)")
            if !outcome.governance.issues.isEmpty {
                let issueText = outcome.governance.issues
                    .map { "\($0.severity.rawValue): \($0.message)" }
                    .joined(separator: " | ")
                await renderer.appendLog("Governance: \(issueText)")
            }
        }

        await renderer.setStatus("idle")
    }

    if let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        try await runTask(summary)
    } else {
        while true {
            let line = readLine(strippingNewline: true) ?? ""
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

            let lowercased = trimmed.lowercased()
            switch lowercased {
            case ":quit", ":exit":
                await renderer.appendLog("Exiting TUI.")
                await eventStream.finish()
                eventTask.cancel()
                return
            case ":help":
                await renderer.appendLog("Commands: :plan :run :dry-run :execute :quit")
                continue
            case ":plan":
                mode = .plan
                await renderer.setMode(.plan)
                continue
            case ":run":
                mode = .run
                await renderer.setMode(.run)
                continue
            case ":dry-run":
                dryRun = true
                await renderer.setDryRun(true)
                continue
            case ":execute":
                dryRun = false
                await renderer.setDryRun(false)
                continue
            default:
                break
            }

            try await runTask(trimmed)
        }
    }

    await eventStream.finish()
    eventTask.cancel()
}

@main
struct AnigmaCLI: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "anigma",
            abstract: "Anigma CLI - A self-contained coding assistant with embedded MCP server, ML inference, and code intelligence.",
            version: "1.0.0",
            subcommands: [
                AnigmaInitCommand.self,
                AnigmaChatCommand.self,
                AnigmaMCPServerCommand.self,
                AnigmaProvidersCommand.self,
                AnigmaModelsCommand.self,
                AnigmaPlanCommand.self,
                AnigmaRunCommand.self,
                AnigmaTUICommand.self,
                AnigmaIndexCommand.self,
                IndexCodebaseCommand.self,
                SearchCommand.self,
                AnigmaWorktreeCommand.self,
                AnigmaRunsCommand.self,
                AnigmaLoopBreakerCommand.self,
                AnigmaToolsCommand.self,
                AnigmaStatusCommand.self,
                AnigmaPolicyCommand.self,
                AnigmaMaturityCommand.self,
                RAGCommand.self,
                ModelsUICommand.self
            ],
            helpNames: [.long, .customShort("h")]
        )
    }

    @Argument(help: "Task to execute (launches TUI if omitted).")
    var task: String?

    @Flag(name: .shortAndLong, help: "Show verbose output.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Output in JSON format.")
    var json: Bool = false

    mutating func run() async throws {
        // 1. Daemon Guardian - Ensure background services are active
        let socketPath = ProcessInfo.processInfo.environment["ANIGMA_SOCKET"]
        let guardian = DaemonGuardian(socketPath: socketPath)
        
        do {
            try await guardian.ensureDaemonRunning()
        } catch {
            fputs("❌ Error: Could not start or connect to anigma daemon.\n", stderr)
            throw exit(1)
        }

        if let taskDescription = task {
            // 2. One-Shot Path (Remote Daemon Execution)
            
            // Connect to Sidecar
            let bridge = try await SidecarBridge.create(clientName: "anigma-cli-oneshot")
            
            // Execute Remote Runner
            let runner = RemoteOneShotRunner(bridge: bridge)
            let context = makeContext() // Still needed for local repo awareness if we upload artifacts
            
            try await runner.execute(
                task: taskDescription, 
                context: context, 
                options: RemoteOneShotRunner.RunOptions(verbose: verbose, json: json)
            )
        } else {
            // 3. Interactive TUI Path (Default)
            try await runTUISession(
                summary: nil,
                details: nil,
                options: TUISessionOptions(mode: .plan, dryRun: true, enableMcp: true)
            )
        }
    }
}

private func exit(_ code: Int32) -> Error {
    Darwin.exit(code)
}


private struct ProviderListPayload: Encodable {
    let providers: [ProviderStatus]
}

struct AnigmaProvidersCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "providers",
            abstract: "List discovered Anigma providers."
        )
    }

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let registry = await ProviderRegistry.createDefault()
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

    @Flag(name: .long, help: "Disable MCP contract builder.")
    var noMcp: Bool = false

    @Flag(name: .long, help: "Stream progress events to stderr.")
    var stream: Bool = false

    @OptionGroup var output: OutputOptions

    mutating func run() async throws {
        let task = TaskIntent(summary: summary, details: details)
        let context = makeContext()
        let eventStream = CLIEventStream()
        let shouldStream = stream || output.format == .text

        let streamTask = startEventStreamPrinter(enabled: shouldStream, stream: eventStream)
        let registry = await ProviderRegistry.createDefault()
        let orchestrator = makeOrchestrator(
            eventStream: eventStream,
            enableMcp: !noMcp,
            registry: registry
        )

        let outcome = try await orchestrator.plan(task: task, context: context)
        await eventStream.finish()
        if let streamTask {
            _ = await streamTask.value
        }

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

private struct RunPayload: Encodable {
    let task: TaskIntent
    let outcome: RunOutcome
}

struct AnigmaRunCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "run",
            abstract: "Run a task with governance checks (dry-run only)."
        )
    }

    @Argument(help: "Task summary to run.")
    var summary: String

    @Option(name: .long, help: "Optional task details.")
    var details: String?

    @Flag(name: .long, inversion: .prefixedNo, help: "Perform a dry-run only (default).")
    var dryRun: Bool = true

    @Flag(name: .long, help: "Disable MCP contract builder.")
    var noMcp: Bool = false

    @Flag(name: .long, help: "Stream progress events to stderr.")
    var stream: Bool = false

    @OptionGroup var output: OutputOptions

    mutating func run() async throws {
        let task = TaskIntent(summary: summary, details: details)
        let context = makeContext()
        let eventStream = CLIEventStream()
        let shouldStream = stream || output.format == .text

        let streamTask = startEventStreamPrinter(enabled: shouldStream, stream: eventStream)
        let registry = await ProviderRegistry.createDefault()
        let orchestrator = makeOrchestrator(
            eventStream: eventStream,
            enableMcp: !noMcp,
            registry: registry
        )

        let outcome = try await orchestrator.run(
            task: task,
            context: context,
            dryRun: dryRun
        )

        await eventStream.finish()
        if let streamTask {
            _ = await streamTask.value
        }

        switch output.format {
        case .text:
            print("task: \(task.summary)")
            print("status: \(outcome.status.rawValue)")
            print("message: \(outcome.message)")
            print("governance: \(outcome.governance.allowed ? "approved" : "denied")")
            if !outcome.governance.issues.isEmpty {
                print("issues:")
                for issue in outcome.governance.issues {
                    print("  - \(issue.severity.rawValue): \(issue.message)")
                }
            }
        case .json:
            let payload = RunPayload(task: task, outcome: outcome)
            try OutputWriter.emit(
                command: "anigma.run",
                payload: payload,
                format: output.format
            )
        }
    }
}

struct AnigmaTUICommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "tui",
            abstract: "Stream live progress and logs while planning or running a task."
        )
    }

    @Argument(help: "Task summary (optional).")
    var summary: String?

    @Option(name: .long, help: "Optional task details.")
    var details: String?

    @Option(name: .long, help: "Mode (plan|run).")
    var mode: ExecutionMode = .plan

    @Flag(name: .long, inversion: .prefixedNo, help: "Perform a dry-run only (default).")
    var dryRun: Bool = true

    @Flag(name: .long, help: "Disable MCP contract builder.")
    var noMcp: Bool = false

    mutating func run() async throws {
        try await runTUISession(
            summary: summary,
            details: details,
            options: TUISessionOptions(mode: mode, dryRun: dryRun, enableMcp: !noMcp)
        )
    }
}
