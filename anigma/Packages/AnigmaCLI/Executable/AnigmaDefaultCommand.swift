//
//  AnigmaDefaultCommand.swift
//  AnigmaCLIExecutable
//
//  Default command with daemon-first execution logic.
//

import AnigmaCLIEventing
import AnigmaCLIOrchestrator
import ArgumentParser
import Foundation

struct AnigmaDefaultCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "anigma",
            abstract: "Execute a task with daemon-first logic or launch interactive TUI.",
            discussion: """
            Executes a single task via the Anigma Daemon with automatic local fallback.
            If no task is provided, launches the interactive TUI.
            
            Examples:
              anigma "fix the bug in Main.swift"      # Execute via daemon
              anigma --local "run tests"              # Force local execution
              anigma --health                         # Check daemon health
              anigma                                  # Launch interactive TUI
            """
        )
    }

    @Argument(help: "Task to execute (launches TUI if omitted).")
    var task: String?

    @Flag(name: .shortAndLong, help: "Show verbose output.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Output in JSON format.")
    var json: Bool = false

    @OptionGroup var daemonOptions: DaemonOptions

    mutating func run() async throws {
        if daemonOptions.health {
            // Show daemon health status
            let eventStream = CLIEventStream()
            let orchestrator = makeDaemonFirstOrchestrator(
                daemonOptions: daemonOptions,
                eventStream: eventStream
            )
            
            let status = await orchestrator.getDaemonStatus()
            
            print("Daemon Health Check:")
            print("===================")
            
            if let health = status["health"] as? String {
                let healthIcon = health == "healthy" ? "✅" : health == "unhealthy" ? "⚠️" : "❌"
                print("Status: \(healthIcon) \(health)")
            }
            
            if let reason = status["reason"] as? String {
                print("Details: \(reason)")
            }
            
            print("Use Daemon: \(status["useDaemon"] as? Bool == true ? "Yes" : "No")")
            print("Local Fallback: \(status["localFallback"] as? Bool == true ? "Enabled" : "Disabled")")
            return
        }

        if let taskDescription = task {
            // Execute task with daemon-first logic
            let eventStream = CLIEventStream()
            let shouldStream = verbose || !json
            let streamTask = startEventStreamPrinter(enabled: shouldStream, stream: eventStream)
            
            let orchestrator = makeDaemonFirstOrchestrator(
                daemonOptions: daemonOptions,
                eventStream: eventStream
            )
            
            let context = makeContext()
            let result = await orchestrator.executeTask(
                taskDescription,
                context: context,
                mode: .run,
                dryRun: false
            )
            
            await eventStream.finish()
            if let streamTask {
                _ = await streamTask.value
            }
            
            switch result {
            case .daemonSuccess(let outcome):
                if json {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode([
                        "source": "daemon",
                        "status": outcome.status.rawValue,
                        "message": outcome.message,
                        "governance": outcome.governance.allowed ? "approved" : "denied"
                    ])
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print(jsonString)
                    }
                } else {
                    print("✅ Task executed via daemon")
                    print("Status: \(outcome.status.rawValue)")
                    print("Message: \(outcome.message)")
                    print("Governance: \(outcome.governance.allowed ? "approved" : "denied")")
                }
                
            case .localFallback(let outcome):
                if json {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode([
                        "source": "local-fallback",
                        "status": outcome.status.rawValue,
                        "message": outcome.message,
                        "governance": outcome.governance.allowed ? "approved" : "denied"
                    ])
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print(jsonString)
                    }
                } else {
                    print("⚠️ Task executed locally (daemon unavailable)")
                    print("Status: \(outcome.status.rawValue)")
                    print("Message: \(outcome.message)")
                    print("Governance: \(outcome.governance.allowed ? "approved" : "denied")")
                }
                
            case .daemonFailure(let error):
                if json {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode([
                        "source": "daemon",
                        "status": "failed",
                        "error": error.localizedDescription
                    ])
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print(jsonString)
                    }
                } else {
                    print("❌ Daemon execution failed: \(error.localizedDescription)")
                }
                
            case .localFailure(let error):
                if json {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode([
                        "source": "local",
                        "status": "failed",
                        "error": error.localizedDescription
                    ])
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print(jsonString)
                    }
                } else {
                    print("❌ Local execution failed: \(error.localizedDescription)")
                }
            }
        } else {
            // Launch interactive TUI
            try await runTUISession(
                summary: nil,
                details: nil,
                options: TUISessionOptions(mode: .plan, dryRun: true, enableMcp: true)
            )
        }
    }
}