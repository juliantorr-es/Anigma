import Foundation

/// Automatically manages the anigmad daemon for the CLI.
/// Ensures the daemon is running, healthy, and persists in the background.
public actor DaemonGuardian {
    private let socketPath: String
    private let binaryPath: String?
    
    public init(socketPath: String? = nil, binaryPath: String? = nil) {
        self.socketPath = socketPath ?? SidecarConfig.defaultUnixSocketPath()
        self.binaryPath = binaryPath
    }
    
    /// Ensures the daemon is running and healthy.
    /// Spawns a new detached process if necessary.
    public func ensureDaemonRunning() async throws {
        let status = await DaemonLifecycle.status(socketPath: socketPath)
        
        switch status {
        case .running:
            // Daemon is already running and healthy
            return
        case .stopped, .unresponsive:
            // Try to start/restart
            try await startDetachedDaemon()
        }
    }
    
    private func startDetachedDaemon() async throws {
        // Use DaemonLifecycle to start
        // In one-shot mode, we fail if this fails.
        do {
            _ = try await DaemonLifecycle.start(socketPath: socketPath, binaryPath: binaryPath)
        } catch {
            print("❌ Error: Failed to start anigma daemon.")
            throw error
        }
    }
}
