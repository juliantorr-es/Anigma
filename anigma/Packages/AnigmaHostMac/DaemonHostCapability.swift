//
//  DaemonHostCapability.swift
//  AnigmaHostMac
//
//  Phase 8: Daemon lifecycle as a host capability, not UI concern.
//  Now integrated with Harmonia CLI for daemon management.
//

import AnigmaSidecar
import Foundation

/// Host capability for daemon lifecycle management.
/// This keeps the macOS client from owning daemon semantics.
/// Now uses HarmoniaClient for CLI-based daemon control.
@MainActor
public final class DaemonHostCapability {
    private var daemonHandle: DaemonHandle?
    private let harmoniaClient: HarmoniaClient

    private var consecutiveFailures = 0
    private let failureThreshold = 3
    private var lastFailureTime: Date?
    private let circuitResetInterval: TimeInterval = 60  // 1 minute

    public enum DaemonCapabilityError: Error {
        case daemonUnavailable
        case harmoniaNotFound
    }

    public init(harmoniaClient: HarmoniaClient? = nil) {
        self.harmoniaClient = harmoniaClient ?? HarmoniaClient()
    }

    /// Ensures daemon is running, starting it if necessary.
    /// Now uses Harmonia CLI for daemon management.
    public func ensureDaemonRunning() async throws -> DaemonStatus {
        // Circuit breaker check
        if consecutiveFailures >= failureThreshold {
            if let lastFailure = lastFailureTime,
                Date().timeIntervalSince(lastFailure) < circuitResetInterval {
                throw DaemonCapabilityError.daemonUnavailable
            }
            // Reset after interval
            consecutiveFailures = 0
        }

        do {
            // Use Harmonia CLI to check daemon status
            let statusResponse = try await harmoniaClient.daemonStatus()

            if statusResponse.running {
                consecutiveFailures = 0
                return .alreadyRunning
            } else {
                // Start daemon via Harmonia CLI
                try await harmoniaClient.daemonStart()
                consecutiveFailures = 0
                return .started
            }
        } catch {
            consecutiveFailures += 1
            lastFailureTime = Date()
            throw error
        }
    }

    /// Stops the daemon if it's running.
    /// Now uses Harmonia CLI for daemon management.
    public func stopDaemon() async throws {
        try await harmoniaClient.daemonStop()
        daemonHandle = nil
    }

    /// Restarts the daemon.
    /// Now uses Harmonia CLI for daemon management.
    public func restartDaemon() async throws {
        try await stopDaemon()
        _ = try await ensureDaemonRunning()
    }

    /// Gets current daemon status.
    /// Now uses Harmonia CLI for daemon management.
    public func getDaemonStatus() async -> DaemonStatus {
        do {
            let statusResponse = try await harmoniaClient.daemonStatus()
            return statusResponse.running ? .running : .stopped
        } catch {
            return .stopped
        }
    }

    /// Get the Harmonia client for direct CLI access.
    public var harmonia: HarmoniaClient {
        harmoniaClient
    }
}

/// Daemon status from host perspective.
public enum DaemonStatus: Sendable {
    case running
    case stopped
    case started
    case alreadyRunning

    public var description: String {
        switch self {
        case .running: return "Running"
        case .stopped: return "Stopped"
        case .started: return "Started"
        case .alreadyRunning: return "Already Running"
        }
    }
}
