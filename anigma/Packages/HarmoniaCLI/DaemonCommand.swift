//
//  DaemonCommand.swift
//  HarmoniaCLI
//
//  Created by Gemini on 2026-01-03.
//

import ArgumentParser
import Foundation
import AnigmaDaemonCore

struct DaemonCommand: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "daemon",
        abstract: "Manage the anigmad sidecar daemon.",
        subcommands: [Start.self, Stop.self, Status.self]
    )

    private static var pidFilePath: String {
        let socketPath = DaemonConfig.defaultUnixSocketPath()
        let socketDir = URL(fileURLWithPath: socketPath).deletingLastPathComponent()
        return socketDir.appendingPathComponent("anigmad.pid").path
    }

    private static var executablePath: String? {
        let fm = FileManager.default
        let possiblePaths = [
            ".build/debug/anigmad",
            ".build/release/anigmad",
            "../.build/debug/anigmad",
            ".build/arm64-apple-macosx/debug/anigmad"
        ]

        for path in possiblePaths {
            if fm.fileExists(atPath: path) {
                return path
            }
        }
        if let buildDir = ProcessInfo.processInfo.environment["SWIFT_PBUILD_DIR"] {
            let path = "\(buildDir)/anigmad"
            if fm.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    struct Start: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(abstract: "Start the anigmad daemon in the background.")

        @Flag(name: .long, help: "Run the daemon in the foreground for debugging.")
        var foreground: Bool = false

        func run() async throws {
            // 1. Check if already running
            if let pid = readPid() {
                if isProcessRunning(pid: pid) {
                    print("anigmad is already running with PID \(pid).")
                    return
                } else {
                    print("Found stale PID file. Cleaning up.")
                    try? FileManager.default.removeItem(atPath: pidFilePath)
                }
            }

            // 2. Find executable
            guard let exe = executablePath else {
                print("Error: Could not find the 'anigmad' executable. Please build it first.")
                throw ExitCode.failure
            }

            // 3. Ensure socket directory exists
            let socketPath = DaemonConfig.defaultUnixSocketPath()
            let socketDir = URL(fileURLWithPath: socketPath).deletingLastPathComponent()
            try FileManager.default.createDirectory(at: socketDir, withIntermediateDirectories: true)

            print("Starting anigmad daemon...")

            if foreground {
                // Not a true daemon, just execute and wait.
                let process = Process()
                process.executableURL = URL(fileURLWithPath: exe)
                try process.run()
                process.waitUntilExit()
            } else {
                // This is a basic daemonization. For a production system, a more
                // robust solution like using a launch agent/service would be better.
                let process = Process()
                process.executableURL = URL(fileURLWithPath: exe)

                // Detach from the controlling terminal
                process.standardInput = nil
                process.standardOutput = nil
                process.standardError = nil

                try process.run()

                // Write the PID file
                let pid = process.processIdentifier
                try String(pid).write(toFile: pidFilePath, atomically: true, encoding: .utf8)

                print("anigmad started successfully with PID \(pid).")
            }
        }
    }

    struct Stop: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(abstract: "Stop the anigmad daemon.")

        func run() async throws {
            print("Stopping anigmad daemon...")
            guard let pid = readPid() else {
                print("anigmad does not appear to be running (no PID file found).")
                return
            }

            if isProcessRunning(pid: pid) {
                if kill(pid, SIGTERM) == 0 {
                    print("Sent stop signal to anigmad (PID \(pid)).")
                } else {
                    print("Error sending signal to process \(pid). It may already be stopped.")
                }
            } else {
                print("Process with PID \(pid) not found. Cleaning up stale PID file.")
            }

            // Clean up PID file
            try? FileManager.default.removeItem(atPath: pidFilePath)
        }
    }

    struct Status: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(abstract: "Check the status of the anigmad daemon.")

        func run() async throws {
            guard let pid = readPid() else {
                print("anigmad is stopped (no PID file).")
                return
            }

            if isProcessRunning(pid: pid) {
                print("anigmad is running with PID \(pid).")
            } else {
                print("anigmad is stopped (stale PID file found).")
            }
        }
    }

    // Helper functions
    private static func readPid() -> pid_t? {
        guard let pidString = try? String(contentsOfFile: pidFilePath) else {
            return nil
        }
        return pid_t(pidString.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func isProcessRunning(pid: pid_t) -> Bool {
        // kill with signal 0 is a standard way to check if a process exists.
        return kill(pid, 0) == 0
    }
}
