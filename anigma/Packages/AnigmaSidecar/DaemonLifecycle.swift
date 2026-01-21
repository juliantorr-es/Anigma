//
//  DaemonLifecycle.swift
//  AnigmaSidecar
//
//  Manages the lifecycle of the anigmad daemon process.
//  Provides governed commands for starting, stopping, checking status,
//  and restarting the daemon with proper error handling.
//

import AnigmaDaemonCore
import Foundation

/// Manages the lifecycle of the anigmad daemon process.
public actor DaemonLifecycle {

    // MARK: - Public API

    /// Starts the anigmad daemon process.
    ///
    /// - Parameters:
    ///   - socketPath: Optional custom Unix socket path. Defaults to standard location.
    ///   - binaryPath: Optional custom path to anigmad binary. Defaults to .build/debug/anigmad.
    /// - Returns: A handle to the running daemon process.
    /// - Throws: `DaemonLifecycleError` if daemon fails to start.
    public static func start(
        socketPath: String? = nil,
        binaryPath: String? = nil
    ) async throws -> DaemonHandle {
        let socket = socketPath ?? DaemonConfig.defaultUnixSocketPath()
        let binary = binaryPath ?? defaultBinaryPath()

        // Check if daemon is already running
        if let existingStatus = try? await status(socketPath: socket),
            case .running = existingStatus {
            throw DaemonLifecycleError.alreadyRunning(socket)
        }

        // Ensure socket directory exists
        try createSocketDirectory(for: socket)

        // Remove stale socket file if it exists
        try? FileManager.default.removeItem(atPath: socket)

        // Spawn the daemon process
        let process = try spawnDaemon(binaryPath: binary, socketPath: socket)

        // Wait for daemon to become responsive
        try await waitForDaemonReady(socketPath: socket, timeout: 5.0)

        let handle = DaemonHandle(
            processId: process.processIdentifier,
            socketPath: socket,
            startedAt: Date(),
            process: process
        )

        return handle
    }

    /// Stops the daemon gracefully.
    ///
    /// - Parameters:
    ///   - handle: The daemon handle returned from `start()`.
    ///   - timeout: Maximum time to wait for graceful shutdown. Defaults to 5 seconds.
    /// - Throws: `DaemonLifecycleError` if daemon cannot be stopped.
    public static func stop(handle: DaemonHandle, timeout: TimeInterval = 5.0) async throws {
        guard handle.process.isRunning else {
            // Already stopped
            return
        }

        // Send SIGTERM for graceful shutdown
        handle.process.terminate()

        // Wait for process to exit
        let deadline = Date().addingTimeInterval(timeout)
        while handle.process.isRunning && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        // Force kill if still running
        if handle.process.isRunning {
            kill(handle.processId, SIGKILL)
            throw DaemonLifecycleError.forcedKill(handle.processId)
        }

        // Clean up socket file and PID file
        try? FileManager.default.removeItem(atPath: handle.socketPath)
        try? FileManager.default.removeItem(atPath: handle.socketPath + ".pid")
    }

    /// Checks the current status of the daemon.
    ///
    /// - Parameter socketPath: Optional custom Unix socket path.
    /// - Returns: The current daemon status.
    public static func status(socketPath: String? = nil) async -> DaemonStatus {
        let socket = socketPath ?? DaemonConfig.defaultUnixSocketPath()

        // Check if socket file exists
        guard FileManager.default.fileExists(atPath: socket) else {
            return .stopped
        }

        // Try to connect and ping the daemon
        do {
            let bridge = try await SidecarBridge.create(socketPath: socket)
            let isHealthy = try await bridge.healthCheck()

            if isHealthy {
                // Get process info if possible
                let pid = try? getProcessId(for: socket)
                let uptime = try? getUptime(for: socket)
                return .running(pid: pid, uptime: uptime)
            } else {
                return .unresponsive(pid: nil)
            }
        } catch {
            // Daemon not responsive, but socket exists
            return .unresponsive(pid: nil)
        }
    }

    /// Restarts the daemon (stop + start).
    ///
    /// - Parameter handle: The current daemon handle.
    /// - Returns: A new handle to the restarted daemon.
    /// - Throws: `DaemonLifecycleError` if restart fails.
    public static func restart(handle: DaemonHandle) async throws -> DaemonHandle {
        try await stop(handle: handle)

        // Brief pause to ensure clean shutdown
        try await Task.sleep(for: .milliseconds(500))

        return try await start(socketPath: handle.socketPath)
    }

    // MARK: - Private Helpers

    private static func defaultBinaryPath() -> String {
        // 1. Check for bundled helper in App/Contents/Helpers (production)
        if let helperPath = Bundle.main.path(forAuxiliaryExecutable: "anigmad"),
           FileManager.default.fileExists(atPath: helperPath) {
            return helperPath
        }

        // 2. Check current working directory build artifacts (development)
        let releasePath = ".build/release/anigmad"
        let debugPath = ".build/debug/anigmad"

        if FileManager.default.fileExists(atPath: releasePath) {
            return releasePath
        }
        return debugPath
    }

    private static func createSocketDirectory(for socketPath: String) throws {
        let directory = (socketPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private static func spawnDaemon(binaryPath: String, socketPath: String) throws -> Process {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw DaemonLifecycleError.binaryNotFound(binaryPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["--socket", socketPath]

        // Redirect output to /dev/null (daemon should log to its own files)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()

        // Write PID file
        let pidPath = socketPath + ".pid"
        let pid = process.processIdentifier
        try "\(pid)".write(toFile: pidPath, atomically: true, encoding: .utf8)

        return process
    }

    private static func waitForDaemonReady(socketPath: String, timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            // Check if socket file exists
            if FileManager.default.fileExists(atPath: socketPath) {
                // Try to connect
                do {
                    let bridge = try await SidecarBridge.create(socketPath: socketPath)
                    let isHealthy = try await bridge.healthCheck()
                    if isHealthy {
                        return  // Daemon is ready!
                    }
                } catch {
                    // Not ready yet, continue waiting
                }
            }

            try await Task.sleep(for: .milliseconds(200))
        }

        throw DaemonLifecycleError.startupTimeout(timeout)
    }

    private static func getProcessId(for socketPath: String) throws -> pid_t? {
        let pidPath = socketPath + ".pid"
        guard FileManager.default.fileExists(atPath: pidPath) else { return nil }

        let pidData = try String(contentsOfFile: pidPath, encoding: .utf8)
        let pidString = pidData.trimmingCharacters(in: .whitespacesAndNewlines)
        if let pid = Int32(pidString) {
             return pid_t(pid)
        }
        return nil
    }

    private static func getUptime(for socketPath: String) throws -> TimeInterval? {
        let pidPath = socketPath + ".pid"
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: pidPath),
              let creationDate = attrs[.creationDate] as? Date else {
            return nil
        }
        return Date().timeIntervalSince(creationDate)
    }
}

// MARK: - Supporting Types

/// A handle to a running daemon process.
public struct DaemonHandle: Sendable {
    /// The process ID of the daemon.
    public let processId: pid_t

    /// The Unix socket path the daemon is listening on.
    public let socketPath: String

    /// When the daemon was started.
    public let startedAt: Date

    /// The underlying Process object (not Sendable, but we manage it carefully).
    fileprivate let process: Process

    /// How long the daemon has been running.
    public var uptime: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }
}

/// The current status of the daemon.
public enum DaemonStatus: Sendable {
    /// Daemon is running and responsive.
    case running(pid: pid_t?, uptime: TimeInterval?)

    /// Daemon is not running.
    case stopped

    /// Daemon process exists but is not responding to health checks.
    case unresponsive(pid: pid_t?)

    public var description: String {
        switch self {
        case .running(let pid, let uptime):
            var desc = "Running"
            if let pid = pid {
                desc += " (PID: \(pid))"
            }
            if let uptime = uptime {
                desc += " (Uptime: \(String(format: "%.1f", uptime))s)"
            }
            return desc
        case .stopped:
            return "Stopped"
        case .unresponsive(let pid):
            if let pid = pid {
                return "Unresponsive (PID: \(pid))"
            }
            return "Unresponsive"
        }
    }
}

/// Errors that can occur during daemon lifecycle management.
public enum DaemonLifecycleError: Error, LocalizedError {
    case binaryNotFound(String)
    case alreadyRunning(String)
    case startupTimeout(TimeInterval)
    case forcedKill(pid_t)
    case connectionFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            return "Daemon binary not found at: \(path)"
        case .alreadyRunning(let socket):
            return "Daemon is already running on socket: \(socket)"
        case .startupTimeout(let timeout):
            return "Daemon failed to become responsive within \(timeout) seconds"
        case .forcedKill(let pid):
            return "Daemon did not stop gracefully, forced kill (PID: \(pid))"
        case .connectionFailed(let error):
            return "Failed to connect to daemon: \(error.localizedDescription)"
        }
    }
}
