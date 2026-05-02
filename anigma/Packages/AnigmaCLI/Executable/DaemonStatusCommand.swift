//
//  DaemonStatusCommand.swift
//  AnigmaCLIExecutable
//
//  Command to check daemon health and status.
//

import AnigmaCLIEventing
import AnigmaSidecar
import ArgumentParser
import Foundation

struct DaemonStatusCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "daemon-status",
            abstract: "Check daemon health and connection status.",
            discussion: """
            Shows detailed information about the daemon connection including:
            - Health status (healthy/unhealthy/unavailable)
            - Connection configuration
            - Local fallback availability
            - Version compatibility
            """
        )
    }

    @OptionGroup var daemonOptions: DaemonOptions
    @OptionGroup var output: OutputOptions

    mutating func run() async throws {
        let eventStream = CLIEventStream()
        let orchestrator = makeDaemonFirstOrchestrator(
            daemonOptions: daemonOptions,
            eventStream: eventStream
        )

        let status = await orchestrator.getDaemonStatus()

        switch output.format {
        case .text:
            print("Daemon Status:")
            print("==============")
            
            if let health = status["health"] as? String {
                let healthIcon = health == "healthy" ? "✅" : health == "unhealthy" ? "⚠️" : "❌"
                print("Health: \(healthIcon) \(health)")
            }
            
            if let reason = status["reason"] as? String {
                print("Reason: \(reason)")
            }
            
            print("Use Daemon: \(status["useDaemon"] as? Bool == true ? "Yes" : "No")")
            print("Initialized: \(status["initialized"] as? Bool == true ? "Yes" : "No")")
            print("Local Fallback: \(status["localFallback"] as? Bool == true ? "Enabled" : "Disabled")")
            
            if let socketPath = status["socketPath"] as? String {
                print("Socket Path: \(socketPath)")
            }
            
            if let daemonURL = status["daemonURL"] as? String {
                print("Daemon URL: \(daemonURL)")
            }
            
            print()
            print("Configuration:")
            print("--------------")
            print("To force local execution: anigma --local <command>")
            print("To disable local fallback: anigma --no-local-fallback <command>")
            print("To specify daemon URL: anigma --daemon-url <url> <command>")
            
        case .json:
            let data = try JSONSerialization.data(
                withJSONObject: status,
                options: [.prettyPrinted, .sortedKeys]
            )
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        }
    }
}
