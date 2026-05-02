import Foundation
import AnigmaClientKit

/// Actor responsible for executing Git commands safely
actor GitService {
    static let shared = GitService()

    // MARK: - Core Execution

    /// Execute a git command in the context of a given directory
    /// - Parameters:
    ///   - arguments: The arguments to pass to `git` (e.g. `["status", "-s"]`)
    ///   - directory: The working directory for the command
    /// - Returns: The stdout string if successful
    func run(arguments: [String], in directory: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Environment: Ensure no user prompts, english output
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["LANG"] = "en_US.UTF-8"
        process.environment = env

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown git error"
            throw GitError.commandFailed(code: process.terminationStatus, message: errorString)
        }

        return String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Higher Level Operations

    /// Clones a local repository to a new location
    func clone(from source: URL, to destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", source.path, destination.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown git error"
            throw GitError.commandFailed(code: Int32(process.terminationStatus), message: "git clone failed: \(errorText)")
        }
    }

    func getStatus(in directory: URL) async throws -> GitState {
        // Get branch
        let branch = try await run(arguments: ["rev-parse", "--abbrev-ref", "HEAD"], in: directory)

        // Get status (porcelain)
        let statusOutput = try await run(arguments: ["status", "--porcelain"], in: directory)
        let lines = statusOutput.components(separatedBy: .newlines).filter { !$0.isEmpty }

        let isDirty = !lines.isEmpty

        // Count added/modified/deleted
        var added = 0
        var modified = 0
        var deleted = 0

        for line in lines {
            if line.starts(with: "??") || line.starts(with: "A") { added += 1 } else if line.contains("M") { modified += 1 } else if line.contains("D") { deleted += 1 }
        }

        return GitState(
            headHash: (try? await run(arguments: ["rev-parse", "--short", "HEAD"], in: directory)) ?? "0000000",
            branch: branch,
            isDirty: isDirty,
            stagedSummary: "\(added) A, \(modified) M, \(deleted) D",
            remoteURL: nil
        )
    }

    func getDiff(in directory: URL) async throws -> String {
        return try await run(arguments: ["diff"], in: directory)
    }

    func applyPatch(diff: String, in directory: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["apply", "--reject", "--whitespace=fix"] // Standard safe apply
        process.currentDirectoryURL = directory

        let stdin = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardError = stderr

        try process.run()

        // Write diff to stdin
        if let data = diff.data(using: .utf8) {
            stdin.fileHandleForWriting.write(data)
            try stdin.fileHandleForWriting.close()
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Apply failed"
            throw GitError.applyFailed(message: errorMsg)
        }
    }
}

// MARK: - Errors

enum GitError: LocalizedError {
    case commandFailed(code: Int32, message: String)
    case applyFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let code, let message):
            return "Git command failed (Exit \(code)): \(message)"
        case .applyFailed(let message):
            return "Failed to apply patch: \(message)"
        }
    }
}
