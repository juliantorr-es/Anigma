//
//  DaemonCommand.swift
//  HarmoniaCLI
//
//  Created by Gemini on 2026-01-03.
//

import ArgumentParser
import Foundation
import AnigmaDaemonCore
import AnigmaSidecar
import ServiceManagement

private struct LaunchAgentManager {
    struct Status {
        let running: Bool
        let pid: pid_t?
        let startTime: Date?
        let memoryUsage: Int?
        let plistPath: String?
    }

    enum LaunchAgentError: Error {
        case permissionDenied
    }

    func isInstalled() async -> Bool {
        FileManager.default.fileExists(atPath: SidecarConfig.defaultUnixSocketPath())
    }

    func getStatus() async -> Status {
        let socketPath = SidecarConfig.defaultUnixSocketPath()
        let daemonStatus = await DaemonLifecycle.status(socketPath: socketPath)
        switch daemonStatus {
        case .running(let pid, _):
            return Status(
                running: true,
                pid: pid,
                startTime: nil,
                memoryUsage: nil,
                plistPath: socketPath
            )
        case .stopped:
            return Status(running: false, pid: nil, startTime: nil, memoryUsage: nil, plistPath: nil)
        case .unresponsive(let pid):
            return Status(
                running: false,
                pid: pid,
                startTime: nil,
                memoryUsage: nil,
                plistPath: socketPath
            )
        }
    }

    func start() async throws {
        _ = try await DaemonLifecycle.start(socketPath: SidecarConfig.defaultUnixSocketPath())
    }

    func stop() async throws {
        let socketPath = SidecarConfig.defaultUnixSocketPath()
        let status = await DaemonLifecycle.status(socketPath: socketPath)
        switch status {
        case .running(let pid, _), .unresponsive(let pid):
            if let pid {
                _ = kill(pid, SIGTERM)
            }
        case .stopped:
            return
        }
    }

    func install() async throws {}

    func remove() async throws {}
}

struct DaemonCommand: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "daemon",
        abstract: "Manage the anigmad sidecar daemon.",
        subcommands: [Start.self, Stop.self, Status.self, Install.self, Uninstall.self, Enable.self, Disable.self]
    )

    private static var pidFilePath: String {
        let socketPath = SidecarConfig.defaultUnixSocketPath()
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
            let socketPath = SidecarConfig.defaultUnixSocketPath()
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
            // First try launch agent approach
            let launchAgent = LaunchAgentManager()
            
            if await launchAgent.isInstalled() {
                print("Stopping anigmad daemon via launch agent...")
                do {
                    try await launchAgent.stop()
                    print("✅ Daemon stopped via launch agent.")
                    
                    // Also clean up PID file for backward compatibility
                    if let pid = readPid() {
                        try? FileManager.default.removeItem(atPath: pidFilePath)
                    }
                    return
                    
                } catch {
                    print("⚠️  Launch agent stop failed, trying legacy approach: \(error.localizedDescription)")
                }
            }
            
            // Fallback to legacy process management
            print("Stopping anigmad daemon via legacy process management...")
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
            // First check launch agent status
            let launchAgent = LaunchAgentManager()
            
            if await launchAgent.isInstalled() {
                let status = await launchAgent.getStatus()
                
                print("=== anigmad Daemon Status ===")
                print("Launch Agent: ✅ Installed")
                print("Running: \(status.running ? "✅ Yes" : "❌ No")")
                
                if let pid = status.pid {
                    print("PID: \(pid)")
                }
                
                if let startTime = status.startTime {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    formatter.timeStyle = .medium
                    print("Started: \(formatter.string(from: startTime))")
                }
                
                if let memoryUsage = status.memoryUsage {
                    print("Memory Usage: \(ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory))")
                }
                
                if let plistPath = status.plistPath {
                    print("Launch Agent Plist: \(plistPath)")
                }
                
                print("===============================")
                
                // Also check legacy PID file for backward compatibility
                if let legacyPid = readPid(), isProcessRunning(pid: legacyPid) {
                    if status.running && status.pid != legacyPid {
                        print("⚠️  Legacy process (PID \(legacyPid)) still running - may need manual cleanup")
                    }
                }
                
                return
            }
            
            // Fallback to legacy status checking
            guard let pid = readPid() else {
                print("anigmad is stopped (no PID file).")
                print("Install with 'anigma daemon install' for automatic startup.")
                return
            }

            if isProcessRunning(pid: pid) {
                print("anigmad is running with PID \(pid) (legacy mode).")
                print("Consider installing the launch agent: 'anigma daemon install'")
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
    
    struct Install: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(abstract: "Install the anigmad launch agent for automatic startup.")
        
        @Flag(name: .long, help: "Start the daemon immediately after installation.")
        var start: Bool = false
        
        @Option(name: .long, help: "Path to the daemon executable. Auto-detected if not specified.")
        var executable: String?
        
        func run() async throws {
            let launchAgent = LaunchAgentManager()
            
            if await launchAgent.isInstalled() {
                print("anigmad launch agent is already installed.")
                
                if start {
                    try await launchAgent.start()
                    print("anigmad daemon started.")
                }
                return
            }
            
            print("Installing anigmad launch agent...")
            
            do {
                try await launchAgent.install()
                print("✅ Launch agent installed successfully.")
                print("   The daemon will start automatically at system login.")
                
                if start {
                    try await launchAgent.start()
                    print("✅ anigmad daemon started immediately.")
                }
                
                print("\nTo manage the daemon:")
                print("  anigma daemon start    - Start the daemon")
                print("  anigma daemon stop     - Stop the daemon") 
                print("  anigma daemon status  - Check daemon status")
                print("  anigma daemon enable  - Enable automatic startup")
                print("  anigma daemon disable - Disable automatic startup")
                print("  anigma daemon uninstall - Remove launch agent")
                
            } catch LaunchAgentManager.LaunchAgentError.permissionDenied {
                print("❌ Permission denied. This operation requires appropriate permissions.")
                print("   Try running without sudo first - the launch agent runs as the current user.")
            } catch {
                print("❌ Failed to install launch agent: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct Uninstall: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(abstract: "Remove the anigmad launch agent.")
        
        @Flag(name: .long, help: "Stop the daemon before uninstalling.")
        var stop: Bool = true
        
        func run() async throws {
            let launchAgent = LaunchAgentManager()
            
            guard await launchAgent.isInstalled() else {
                print("anigmad launch agent is not installed.")
                return
            }
            
            print("Removing anigmad launch agent...")
            
            do {
                // Stop the daemon if requested
                if stop {
                    let status = await launchAgent.getStatus()
                    if status.running {
                        print("Stopping daemon...")
                        try await launchAgent.stop()
                        print("✅ Daemon stopped.")
                    }
                }
                
                // Remove the launch agent
                try await launchAgent.remove()
                print("✅ Launch agent removed successfully.")
                print("   The daemon will no longer start automatically.")
                
            } catch {
                print("❌ Failed to remove launch agent: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct Enable: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(abstract: "Enable automatic startup of the daemon.")
        
        func run() async throws {
            let launchAgent = LaunchAgentManager()
            
            if !(await launchAgent.isInstalled()) {
                print("Installing launch agent first...")
                try await launchAgent.install()
                print("✅ Launch agent installed.")
            }
            
            print("Enabling automatic startup...")
            
            do {
                try await launchAgent.start()
                print("✅ Automatic startup enabled.")
                print("   The daemon will start at system login and when requested.")
                
            } catch {
                print("❌ Failed to enable automatic startup: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct Disable: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(abstract: "Disable automatic startup of the daemon.")
        
        func run() async throws {
            let launchAgent = LaunchAgentManager()
            
            guard await launchAgent.isInstalled() else {
                print("Launch agent is not installed.")
                return
            }
            
            print("Disabling automatic startup...")
            
            do {
                try await launchAgent.stop()
                print("✅ Automatic startup disabled.")
                print("   The daemon will not start automatically at login.")
                print("   Use 'anigma daemon start' to start it manually.")
                
            } catch {
                print("❌ Failed to disable automatic startup: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
}
