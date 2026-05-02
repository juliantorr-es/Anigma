import Combine
import Foundation
import AnigmaHostMac
import OSLog

/// Monitors daemon connectivity independently of other operations.
@MainActor
public final class ConnectionMonitor: ObservableObject {
    private static let logger = Logger(subsystem: "com.anigma.AnigmaAppMac", category: "ConnectionMonitor")
    @Published public private(set) var isOnline: Bool = false
    @Published public private(set) var lastRecoveryAttempt: Date?
    @Published public private(set) var consecutiveFailures: Int = 0

    private let capability: DaemonHostCapability
    private var timer: AnyCancellable?
    private let maxConsecutiveFailures = 3  // Try recovery after 3 failed checks
    private let recoveryBackoffSeconds: TimeInterval = 30  // Wait 30s between recovery attempts

    public init(capability: DaemonHostCapability) {
        self.capability = capability
    }

    /// Starts periodic connectivity checks.
    public func start() {
        timer = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkConnection()
                }
            }

        // Initial check
        Task {
            await checkConnection()
        }
    }

    /// Stops periodic checks.
    public func stop() {
        timer?.cancel()
        timer = nil
    }

    private func checkConnection() async {
        let status = await capability.getDaemonStatus()
        let newStatus = (status == .running)

        // Detect state changes
        if isOnline != newStatus {
            let previousStatus = isOnline
            isOnline = newStatus

            if newStatus {
                // Daemon came back online
                Self.logger.info("Daemon reconnected")
                consecutiveFailures = 0
                NotificationCenter.default.post(name: .daemonReconnected, object: nil)
            } else {
                // Daemon went offline
                Self.logger.warning("Daemon went offline")
                NotificationCenter.default.post(name: .daemonDisconnected, object: nil)
            }
        }

        // Track consecutive failures and attempt recovery
        if !newStatus {
            consecutiveFailures += 1

            // Attempt recovery if we've failed enough times and backoff period has elapsed
            if consecutiveFailures >= maxConsecutiveFailures {
                let shouldAttemptRecovery: Bool
                if let lastAttempt = lastRecoveryAttempt {
                    shouldAttemptRecovery = Date().timeIntervalSince(lastAttempt) >= recoveryBackoffSeconds
                } else {
                    shouldAttemptRecovery = true
                }

                if shouldAttemptRecovery {
                    await attemptRecovery()
                }
            }
        } else {
            // Daemon is online, reset failure count
            consecutiveFailures = 0
        }
    }

    /// Attempts to restart the daemon
    private func attemptRecovery() async {
        lastRecoveryAttempt = Date()
        Self.logger.info("Attempting daemon recovery after \(self.consecutiveFailures, privacy: .public) consecutive failures")

        do {
            try await capability.ensureDaemonRunning()
            Self.logger.info("Daemon recovery successful")
            // Don't reset consecutiveFailures here - let checkConnection() do it on next successful check
        } catch {
            Self.logger.error("Daemon recovery failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// Notification names for daemon connection events
extension Notification.Name {
    static let daemonReconnected = Notification.Name("DaemonReconnected")
    static let daemonDisconnected = Notification.Name("DaemonDisconnected")
}
