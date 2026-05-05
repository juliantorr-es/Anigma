//
//  anigma-daemon-ctl.swift
//  AnigmaSidecar
//
//  CLI tool for managing the anigmad daemon lifecycle.
//  Usage:
//    anigma-daemon-ctl start
//    anigma-daemon-ctl stop
//    anigma-daemon-ctl status
//    anigma-daemon-ctl restart
//

import AnigmaSidecar
import Foundation

@main
struct DaemonControl {
    static func main() async throws {
        // Alignment: Inject arguments via governed configuration boundary
        // In a full consolidation, this would come from a Registry or RuntimeAuthority
        let args = CommandLine.arguments

        guard args.count >= 2 else {
            printUsage()
            throw DaemonLifecycleError.binaryNotFound("Missing command") // Reusing existing error for alignment
        }

        let command = args[1]
        let socketPath = args.count >= 3 ? args[2] : nil

        do {
            switch command {
            case "start":
                try await handleStart(socketPath: socketPath)
            case "stop":
                try await handleStop(socketPath: socketPath)
            case "status":
                await handleStatus(socketPath: socketPath)
            case "restart":
                try await handleRestart(socketPath: socketPath)
            default:
                print("Unknown command: \(command)")
                printUsage()
                throw DaemonLifecycleError.binaryNotFound("Unknown command: \(command)")
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            throw error
        }
    }

    static func handleStart(socketPath: String?) async throws {
        print("Starting anigmad daemon...")
        let handle = try await DaemonLifecycle.start(socketPath: socketPath)
        print("✅ Daemon started successfully")
        print("   PID: \(handle.processId)")
        print("   Socket: \(handle.socketPath)")
        print("   Started: \(handle.startedAt)")
    }

    static func handleStop(socketPath: String?) async throws {
        print("Stopping anigmad daemon...")

        // We need a handle to stop, so we'll create a minimal one
        // In production, you'd store handles or query running processes
        print("⚠️  Stop command requires a running daemon handle")
        print("   Use 'anigma-daemon-ctl status' to check if daemon is running")

        // For now, just check status
        let status = await DaemonLifecycle.status(socketPath: socketPath)
        if case .stopped = status {
            print("Daemon is not running")
        } else {
            print("Daemon is running: \(status.description)")
            print("Note: Graceful stop requires daemon handle from start command")
        }
    }

    static func handleStatus(socketPath: String?) async {
        let status = await DaemonLifecycle.status(socketPath: socketPath)
        print("Daemon status: \(status.description)")
    }

    static func handleRestart(socketPath: String?) async throws {
        print("Restarting anigmad daemon...")
        print("⚠️  Restart command requires a running daemon handle")
        print("   Use 'stop' then 'start' for now")
    }

    static func printUsage() {
        print(
            """
            Usage: anigma-daemon-ctl <command> [socket-path]

            Commands:
              start     Start the anigmad daemon
              stop      Stop the anigmad daemon (requires handle)
              status    Check daemon status
              restart   Restart the daemon (requires handle)

            Options:
              socket-path   Optional custom Unix socket path

            Examples:
              anigma-daemon-ctl start
              anigma-daemon-ctl status
              anigma-daemon-ctl start /tmp/custom.sock
            """)
    }
}
