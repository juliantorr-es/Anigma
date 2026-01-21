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
            try FileManager.default.removeItem(at: url)
            // Remove from active map (scan keys)
            // Optimization: Track better map
        } catch {
            print("Failed to clean up sandbox: \(error)")
        }
    }
}

// MARK: - Generic CLI Adapter

/// Adapts generic CLI tools (that accept stdin/stdout) to the AgentRunner interface
struct CLIAgentRunner: AgentRunner {

    func execute(
        profile: AgentProfile,
        instruction: String,
        context: RepoWorkspace
    ) async throws -> AsyncThrowingStream<String, Error> {

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // 1. Locate Binary
                    let binaryPath = try await locateBinary(for: profile)

                    continuation.yield("🔍 Located binary: \(binaryPath)")
                    continuation.yield("📋 Instruction: \(instruction)")
                    continuation.yield("📂 Workspace: \(context.name)")
                    continuation.yield("---")

                    // 2. Configure Process
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: binaryPath)

                    // Build arguments based on agent type
                    // For now, assume the agent accepts instruction as first arg
                    process.arguments = [instruction]

                    // 3. Setup Environment
                    var env = ProcessInfo.processInfo.environment
                    env["ANIGMA_MODE"] = "governed"
                    env["ANIGMA_WORKSPACE"] = context.rootURL.path

                    // Network policy
                    if profile.networkStance == .offline {
                        // Note: This is advisory - real sandboxing requires macOS sandbox APIs
                        env["NETWORK_DISABLED"] = "1"
                    }

                    process.environment = env
                    process.currentDirectoryURL = context.rootURL

                    // 4. Setup Pipes
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe

                    // 5. Run Process
                    try process.run()

                    // 6. Stream Output (both stdout and stderr)
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

                    // 7. Wait for completion
                    process.waitUntilExit()

                    // 8. Check exit code
                    if process.terminationStatus == 0 {
                        continuation.yield("---")
                        continuation.yield("✅ Agent completed successfully")
                    } else {
                        continuation.yield("---")
                        continuation.yield("❌ Agent exited with code \(process.terminationStatus)")
                    }

                    continuation.finish()

                } catch {
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

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let id):
            return "Could not locate binary for agent '\(id)'. Please ensure it's installed and in PATH."
        case .executionFailed(let code):
            return "Agent execution failed with exit code \(code)"
        }
    }
}
