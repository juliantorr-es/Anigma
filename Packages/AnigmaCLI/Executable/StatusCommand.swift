//
//  StatusCommand.swift
//  AnigmaCLIExecutable
//
//  Enhanced status display with live updates.
//

import AnigmaCLICore
import AnigmaCLIDatabase
import ArgumentParser
import Foundation
import AnigmaCLITUI

struct AnigmaStatusCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "status",
            abstract: "Show enhanced CLI status display.",
            subcommands: [
                StatusShowCommand.self,
                StatusWatchCommand.self
            ]
        )
    }
}

// MARK: - Status Show

struct StatusShowCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "show",
            abstract: "Show current status snapshot."
        )
    }

    @Flag(name: .long, help: "Show verbose output with more details.")
    var verbose: Bool = false

    mutating func run() async throws {
        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()

        let receiptManager = CLIReceiptManager(database: db)
        let runManager = CLIRunManager(database: db, receiptManager: receiptManager)
        let indexManager = CLIIndexManager(database: db)
        let worktreeManager = CLIWorktreeManager(database: db)

        let tuiManager = CLITUIManager(
            database: db,
            indexManager: indexManager,
            worktreeManager: worktreeManager,
            runManager: runManager
        )

        try await tuiManager.refreshState()
        let display = await tuiManager.formatDisplay()
        print(display)
    }
}

// MARK: - Status Watch

struct StatusWatchCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "watch",
            abstract: "Watch status with live updates."
        )
    }

    @Option(name: .long, help: "Refresh interval in seconds.")
    var interval: Int = 1 // Faster update for responsiveness

    mutating func run() async throws {
        let engine = TUIEngine()
        let view = DiagnosticsView(engine: engine)
        let inputHandler = InputHandler()

        try await engine.enableRawMode()

        // Ensure cleanup on exit
        defer {
            // Since defer is synchronous, we rely on the loop's exit path to clean up
            // or we use a top-level task for cleanup if we crash? 
            // In a CLI, OS cleans up raw mode usually on exit, but we should be nice.
        }

        let config = CLIDatabaseConfig()
        let db = CLIDatabaseActor(config: config)
        try await db.open()

        // Define Event type
        enum Event: Sendable {
            case input(InputHandler.Key)
            case tick
        }

        // Create Timer Stream
        let timerStream = AsyncStream<Event> { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second fixed tick
                    continuation.yield(.tick)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }

        // Map Input Stream
        let inputStream = inputHandler.events.map { Event.input($0) }

        // Merge streams (using a simple TaskGroup loop approach effectively acts as merge)
        // or just race them? No, we want a unified loop.
        // We'll use a wrapper loop that pulls from a merged channel.

        let mergedStream = AsyncStream<Event> { continuation in
            Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await event in timerStream {
                            continuation.yield(event)
                        }
                    }
                    group.addTask {
                        for await event in inputStream {
                            continuation.yield(event)
                        }
                    }
                }
                continuation.finish()
            }
        }

        // Initial Render
        await renderStatus(view: view)

        // Main Event Loop
        for await event in mergedStream {
            switch event {
            case .input(let key):
                switch key {
                case .char("q"), .char("Q"), .ctrlC:
                    await engine.disableRawMode()
                    await engine.clearScreen()
                    print("👋 Exiting watch mode.")
                    return
                case .char("r"), .char("R"):
                    await renderStatus(view: view) // Force refresh
                default:
                    break
                }

            case .tick:
                await renderStatus(view: view)
            }
        }
    }

    private func renderStatus(view: DiagnosticsView) async {
        // Mock Data for Animation
        let time = Date().timeIntervalSince1970
        let sineWave = (sin(time) + 1) / 2 // 0.0 to 1.0

        let system = DiagnosticsView.SystemStatus(
            cpuUsage: 0.1 + (sineWave * 0.2), // Animate CPU
            memoryUsage: 0.4,
            diskUsage: 0.45,
            gpuAvailable: true,
            mlxAvailable: true,
            llamaCppAvailable: true
        )

        let services = [
            DiagnosticsView.ServiceStatus(name: "Database", status: .running, uptime: 3600),
            DiagnosticsView.ServiceStatus(name: "ML Worker", status: .running, uptime: 1200 + time.remainder(dividingBy: 100)),
            DiagnosticsView.ServiceStatus(name: "MCP Server", status: .stopped),
            DiagnosticsView.ServiceStatus(name: "Indexer", status: .running, uptime: 450)
        ]

        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let log = "Status updated at \(formatter.string(from: Date()))"

        await view.render(system: system, services: services, logs: [log, "System Nominal", "Monitoring..."])
    }
}
