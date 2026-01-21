import Foundation
import AnigmaClientKit

// MARK: - Runner Interface

protocol AgentRunner: Sendable {
    func execute(
        profile: AgentProfile,
        instruction: String,
        context: RepoWorkspace
    ) async throws -> AsyncThrowingStream<String, Error>
}

// MARK: - Local CLI Sandbox

/// Manages a constrained execution environment for external tools
actor SandboxManager {
    static let shared = SandboxManager()

    private var activeSandboxes: [UUID: URL] = [:]
    private var failedCleanups: [(url: URL, failedAt: Date, error: String)] = []
    private var backgroundCleanupTask: Task<Void, Never>?

    func createSandbox(for workspace: RepoWorkspace) throws -> URL {
        let id = UUID()
        let sandboxURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AnigmaSandbox")
            .appendingPathComponent(id.uuidString)

        try FileManager.default.createDirectory(at: sandboxURL, withIntermediateDirectories: true)

        // In a real implementation, we would use `git worktree add` here
        // For now, we'll just create a marker
        let marker = sandboxURL.appendingPathComponent(".anigma_sandbox")
        try "active".write(to: marker, atomically: true, encoding: .utf8)

        activeSandboxes[id] = sandboxURL
        print("Created sandbox at \(sandboxURL.path)")
        return sandboxURL
    }

    func destroySandbox(at url: URL) {
        do {
            // Get size before deletion for tracking
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                let sizeMB = Double(size) / 1_048_576.0
                print("🗑️ [AgentRunner] Cleaning up sandbox at \(url.lastPathComponent) (\(String(format: "%.2f", sizeMB)) MB)")
            }

            try FileManager.default.removeItem(at: url)
            print("✅ [AgentRunner] Successfully removed sandbox at \(url.lastPathComponent)")

            // Remove from active map (scan keys)
            // Optimization: Track better map
        } catch {
            print("❌ [AgentRunner] Failed to clean up sandbox at \(url.path): \(error)")

            // Track failed cleanup for retry
            failedCleanups.append((url: url, failedAt: Date(), error: error.localizedDescription))

            // Start background cleanup job if not already running
            if backgroundCleanupTask == nil {
                startBackgroundCleanup()
            }
        }
    }

    /// Start background cleanup job to retry failed deletions
    private func startBackgroundCleanup() {
        backgroundCleanupTask = Task { [weak self] in
            guard let self = self else { return }

            // Wait 60 seconds before first retry
            try? await Task.sleep(for: .seconds(60))

            while !Task.isCancelled {
                await self.retryFailedCleanups()

                // Check every 5 minutes
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    /// Retry cleaning up sandboxes that failed to delete
    private func retryFailedCleanups() async {
        guard !failedCleanups.isEmpty else {
            // No failed cleanups, cancel background task
            backgroundCleanupTask?.cancel()
            backgroundCleanupTask = nil
            return
        }

        var remainingFailures: [(url: URL, failedAt: Date, error: String)] = []

        for failure in failedCleanups {
            do {
                try FileManager.default.removeItem(at: failure.url)
                print("✅ [AgentRunner] Background cleanup succeeded for \(failure.url.lastPathComponent)")
            } catch {
                // Still failing - check if it's been more than 24 hours
                let hoursSinceFailure = Date().timeIntervalSince(failure.failedAt) / 3600
                if hoursSinceFailure < 24 {
                    // Keep trying
                    remainingFailures.append(failure)
                } else {
                    // Give up after 24 hours
                    print("⚠️ [AgentRunner] Giving up on cleanup for \(failure.url.lastPathComponent) after 24 hours")
                }
            }
        }

        failedCleanups = remainingFailures

        if failedCleanups.isEmpty {
            print("✅ [AgentRunner] All failed cleanups resolved, stopping background job")
            backgroundCleanupTask?.cancel()
            backgroundCleanupTask = nil
        }
    }

    /// Get count of sandboxes waiting for cleanup
    func getFailedCleanupCount() -> Int {
        return failedCleanups.count
    }
}

// MARK: - Generic CLI Adapter

/// Adapts generic CLI tools (that accept stdin/stdout) to the AgentRunner interface
struct CLIAgentRunner: AgentRunner {
    /// Default timeout for agent execution (10 minutes)
    static let defaultTimeoutSeconds: TimeInterval = 600

    func execute(
        profile: AgentProfile,
        instruction: String,
        context: RepoWorkspace
    ) async throws -> AsyncThrowingStream<String, Error> {

        return AsyncThrowingStream { continuation in
            Task {
                var process: Process?
                do {
                    // 1. Locate Binary
                    let binaryPath = try await locateBinary(for: profile)

                    continuation.yield("🔍 Located binary: \(binaryPath)")
                    continuation.yield("📋 Instruction: \(instruction)")
                    continuation.yield("📂 Workspace: \(context.name)")
                    continuation.yield("---")

                    // 2. Configure Process
                    let agentProcess = Process()
                    process = agentProcess  // Store for timeout handler
                    agentProcess.executableURL = URL(fileURLWithPath: binaryPath)

                    // Build arguments based on agent type
                    // For now, assume the agent accepts instruction as first arg
                    agentProcess.arguments = [instruction]

                    // 3. Setup Environment
                    var env = ProcessInfo.processInfo.environment
                    env["ANIGMA_MODE"] = "governed"
                    env["ANIGMA_WORKSPACE"] = context.rootURL.path

                    // Network policy
                    if profile.networkStance == .offline {
                        // Note: This is advisory - real sandboxing requires macOS sandbox APIs
                        env["NETWORK_DISABLED"] = "1"
                    }

                    agentProcess.environment = env
                    agentProcess.currentDirectoryURL = context.rootURL

                    // 4. Setup Pipes
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    agentProcess.standardOutput = outputPipe
                    agentProcess.standardError = errorPipe

                    // 5. Run Process
                    try agentProcess.run()

                    // 6. Setup timeout watchdog
                    let timeoutTask = Task {
                        try await Task.sleep(for: .seconds(Self.defaultTimeoutSeconds))
                        if agentProcess.isRunning {
                            continuation.yield("⏱️ Agent execution timeout (\(Int(Self.defaultTimeoutSeconds))s) - terminating...")
                            agentProcess.terminate()

                            // If still running after 2s, force kill
                            try? await Task.sleep(for: .seconds(2))
                            if agentProcess.isRunning {
                                agentProcess.interrupt()
                            }
                        }
                    }

                    // 7. Stream Output (both stdout and stderr)
                    let outputHandle = outputPipe.fileHandleForReading
                    let errorHandle = errorPipe.fileHandleForReading

                    Task {
                        for try await line in outputHandle.bytes.lines {
                            continuation.yield(line)
                        }
                    }

                    Task {
                        for try await line in errorHandle.bytes.lines {
                            continuation.yield("⚠️ \(line)")
                        }
                    }

                    // 8. Wait for completion
                    agentProcess.waitUntilExit()

                    // Cancel timeout watchdog since process completed
                    timeoutTask.cancel()

                    // 9. Check exit code
                    let exitCode = agentProcess.terminationStatus
                    if exitCode == 0 {
                        continuation.yield("---")
                        continuation.yield("✅ Agent completed successfully")
                    } else if exitCode == 15 || agentProcess.terminationReason == .exit {
                        // SIGTERM (15) indicates timeout termination
                        continuation.yield("---")
                        continuation.yield("❌ Agent timed out after \(Int(Self.defaultTimeoutSeconds))s")
                        continuation.finish(throwing: AgentRunnerError.executionTimeout(profile.providerId))
                        return
                    } else {
                        continuation.yield("---")
                        continuation.yield("❌ Agent exited with code \(exitCode)")
                    }

                    continuation.finish()

                } catch {
                    // Ensure process is terminated on error
                    if let proc = process, proc.isRunning {
                        proc.terminate()
                    }
                    continuation.yield("❌ Execution failed: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Locate the binary for the given agent profile
    private func locateBinary(for profile: AgentProfile) async throws -> String {
        // For now, use a simple mapping of provider IDs to known binaries
        // In production, this would:
        // 1. Check profile.binaryPath if it exists
        // 2. Search PATH for the binary
        // 3. Validate binary hash against trust record

        if let path = profile.binaryPath, FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        switch profile.providerId {
        case "gemini-cli":
            // Check if gemini CLI exists in PATH
            if let path = findInPath("gemini") {
                return path
            }
            // Fallback to common locations
            let commonPaths = [
                "/usr/local/bin/gemini",
                "/opt/homebrew/bin/gemini",
                "\(NSHomeDirectory())/.local/bin/gemini"
            ]
            for path in commonPaths {
                if FileManager.default.fileExists(atPath: path) {
                    return path
                }
            }
            throw AgentRunnerError.binaryNotFound(profile.providerId)

        case "mock-agent":
            // For testing - use echo to simulate
            return "/bin/echo"

        default:
            // Generic: try to find by provider ID
            if let path = findInPath(profile.providerId) {
                return path
            }
            throw AgentRunnerError.binaryNotFound(profile.providerId)
        }
    }

    /// Search PATH for a binary
    private func findInPath(_ name: String) -> String? {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let paths = path.split(separator: ":").map(String.init)

        for dir in paths {
            let fullPath = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }
}

enum AgentRunnerError: LocalizedError {
    case binaryNotFound(String)
    case executionFailed(Int32)
    case executionTimeout(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let id):
            return "Could not locate binary for agent '\(id)'. Please ensure it's installed and in PATH."
        case .executionFailed(let code):
            return "Agent execution failed with exit code \(code)"
        case .executionTimeout(let id):
            return "Agent '\(id)' execution timed out after \(Int(CLIAgentRunner.defaultTimeoutSeconds)) seconds. The process was terminated to prevent hanging."
        }
    }
}
