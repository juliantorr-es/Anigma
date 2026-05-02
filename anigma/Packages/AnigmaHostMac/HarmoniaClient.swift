//
//  HarmoniaClient.swift
//  AnigmaHostMac
//
//  Client for invoking the Harmonia CLI from the macOS app.
//

import Foundation

/// Client for executing Harmonia CLI commands from the macOS app.
@MainActor
public final class HarmoniaClient {

    /// Errors that can occur when executing Harmonia commands.
    public enum HarmoniaError: Error, LocalizedError {
        case binaryNotFound(String)
        case executionFailed(Int32, String)
        case outputParsing(Error)
        case timeout(TimeInterval)

        public var errorDescription: String? {
            switch self {
            case .binaryNotFound(let path):
                return "Harmonia binary not found at: \(path)"
            case .executionFailed(let code, let stderr):
                return "Harmonia command failed with exit code \(code): \(stderr)"
            case .outputParsing(let error):
                return "Failed to parse Harmonia output: \(error.localizedDescription)"
            case .timeout(let duration):
                return "Harmonia command timed out after \(duration) seconds"
            }
        }
    }

    private let binaryPath: String
    private let workingDirectory: URL?

    /// Initialize a Harmonia client.
    ///
    /// - Parameters:
    ///   - binaryPath: Path to the harmonia binary. If nil, searches common locations.
    ///   - workingDirectory: Optional working directory for commands.
    public init(binaryPath: String? = nil, workingDirectory: URL? = nil) {
        self.binaryPath = binaryPath ?? Self.findHarmoniaBinary()
        self.workingDirectory = workingDirectory
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent().path {
            let existing = environment["DYLD_LIBRARY_PATH"].map { "\($0):\(executableDirectory)" } ?? executableDirectory
            environment["DYLD_LIBRARY_PATH"] = existing
        }
        return environment
    }

    // MARK: - Binary Location

    private static func findHarmoniaBinary() -> String {
        // 1. Check /usr/local/bin (installed location)
        let installedPath = "/usr/local/bin/harmonia"
        if FileManager.default.fileExists(atPath: installedPath) {
            return installedPath
        }

        // 2. Check relative to bundle for development
        if let bundlePath = Bundle.main.executableURL?.deletingLastPathComponent().path {
            // Check in the same directory as the executable
            let sameDir = (bundlePath as NSString).appendingPathComponent("harmonia")
            if FileManager.default.fileExists(atPath: sameDir) {
                return sameDir
            }
            
            // Check if we are in a SwiftPM build directory (.build/debug or .build/release)
            // By going up from the bundle if it's in .build/debug/Anigma.app/Contents/MacOS
            let projectRoot = URL(fileURLWithPath: bundlePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path
            
            let releasePath = (projectRoot as NSString).appendingPathComponent(".build/release/harmonia")
            if FileManager.default.fileExists(atPath: releasePath) {
                return releasePath
            }
            
            let debugPath = (projectRoot as NSString).appendingPathComponent(".build/debug/harmonia")
            if FileManager.default.fileExists(atPath: debugPath) {
                return debugPath
            }
        }

        // 3. Fallback to PATH lookup
        return "harmonia"
    }

    // MARK: - Command Execution

    /// Execute a Harmonia command and return parsed JSON output.
    ///
    /// - Parameters:
    ///   - arguments: Command arguments (e.g., ["daemon", "status"])
    ///   - timeout: Maximum execution time in seconds
    /// - Returns: Decoded JSON response
    public func execute<T: Decodable>(
        _ arguments: [String],
        timeout: TimeInterval = 30.0
    ) async throws -> T {
        let output = try await executeRaw(arguments, timeout: timeout)

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: output)
        } catch {
            throw HarmoniaError.outputParsing(error)
        }
    }

    /// Execute a Harmonia command and return raw output.
    ///
    /// - Parameters:
    ///   - arguments: Command arguments
    ///   - timeout: Maximum execution time in seconds
    /// - Returns: Raw stdout data
    public func executeRaw(
        _ arguments: [String],
        timeout: TimeInterval = 30.0
    ) async throws -> Data {
        // Verify binary exists
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw HarmoniaError.binaryNotFound(binaryPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments
        process.environment = processEnvironment()

        if let workingDir = workingDirectory {
            process.currentDirectoryURL = workingDir
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Wait for completion with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        if process.isRunning {
            process.terminate()
            throw HarmoniaError.timeout(timeout)
        }

        let stdoutData = try stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
        let stderrData = try stderrPipe.fileHandleForReading.readToEnd() ?? Data()

        if process.terminationStatus != 0 {
            let stderr = String(data: stderrData, encoding: .utf8) ?? "(no error output)"
            throw HarmoniaError.executionFailed(process.terminationStatus, stderr)
        }

        return stdoutData
    }

    /// Execute a Harmonia command and stream output line-by-line.
    ///
    /// - Parameters:
    ///   - arguments: Command arguments
    ///   - timeout: Maximum execution time in seconds
    /// - Returns: AsyncThrowingStream of output lines
    public func executeStreaming(
        _ arguments: [String],
        timeout: TimeInterval = 300.0
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard FileManager.default.fileExists(atPath: binaryPath) else {
                        throw HarmoniaError.binaryNotFound(binaryPath)
                    }

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: binaryPath)
                    process.arguments = arguments
                    process.environment = processEnvironment()

                    if let workingDir = workingDirectory {
                        process.currentDirectoryURL = workingDir
                    }

                    let stdoutPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    process.standardError = Pipe()

                    let fileHandle = stdoutPipe.fileHandleForReading

                    try process.run()

                    // Read output in background
                    Task {
                        while process.isRunning {
                            if let data = fileHandle.availableData as Data?, !data.isEmpty {
                                if let line = String(data: data, encoding: .utf8) {
                                    for outputLine in line.components(separatedBy: .newlines) {
                                        if !outputLine.isEmpty {
                                            continuation.yield(outputLine)
                                        }
                                    }
                                }
                            }
                            try await Task.sleep(for: .milliseconds(50))
                        }

                        // Read any remaining data
                        if let data = try? fileHandle.readToEnd(), !data.isEmpty {
                            if let line = String(data: data, encoding: .utf8) {
                                for outputLine in line.components(separatedBy: .newlines) {
                                    if !outputLine.isEmpty {
                                        continuation.yield(outputLine)
                                    }
                                }
                            }
                        }

                        if process.terminationStatus == 0 {
                            continuation.finish()
                        } else {
                            continuation.finish(throwing: HarmoniaError.executionFailed(
                                process.terminationStatus,
                                "Process exited with code \(process.terminationStatus)"
                            ))
                        }
                    }

                    // Timeout handling
                    Task {
                        try await Task.sleep(for: .seconds(timeout))
                        if process.isRunning {
                            process.terminate()
                            continuation.finish(throwing: HarmoniaError.timeout(timeout))
                        }
                    }

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Convenience Methods

extension HarmoniaClient {

    /// Check if Harmonia binary is available.
    public var isBinaryAvailable: Bool {
        FileManager.default.fileExists(atPath: binaryPath)
    }

    /// Get Harmonia version.
    public func getVersion() async throws -> String {
        let data = try await executeRaw(["--version"])
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
    }

    /// Get Harmonia help text.
    public func getHelp(for subcommand: String? = nil) async throws -> String {
        var args = ["--help"]
        if let subcommand = subcommand {
            args = [subcommand, "--help"]
        }
        let data = try await executeRaw(args)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
