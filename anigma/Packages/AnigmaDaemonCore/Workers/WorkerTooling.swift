//
//  WorkerTooling.swift
//  AnigmaDaemonCore
//
//  Standardized utilities for job workers to discover and execute external binaries.
//

import Foundation

#if os(macOS) || os(Linux)
    import Darwin
#endif

public enum WorkerTooling {
    /// Standard search paths for external tools on macOS and Linux.
    private static let searchPaths: [String] = [
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/opt/homebrew/bin",  // macOS Homebrew
        "/usr/local/texlive/2024/bin/universal-darwin",  // Example TeX Live path
        "~/.anigma/tools"
    ]

    /// Find an executable tool by name, prioritizing bundle-adjacent locations.
    public static func findTool(named name: String) -> String? {
        let fileManager = FileManager.default

        // 1. Check if it's already an absolute path
        if name.hasPrefix("/") && fileManager.isExecutableFile(atPath: name) {
            return name
        }

        // 2. Priority: Check adjacent to the current running executable
        // This ensures self-contained apps (e.g. inside .app/Contents/MacOS) work without global install.
        let selfPath = CommandLine.arguments[0]
        let selfURL = URL(fileURLWithPath: selfPath).resolvingSymlinksInPath()
        let adjacentURL = selfURL.deletingLastPathComponent().appendingPathComponent(name)

        if fileManager.isExecutableFile(atPath: adjacentURL.path) {
             return adjacentURL.path
        }

        // 2b. Check in standard Bundle location (if we are in a Bundle)
        if let bundlePath = Bundle.main.executablePath {
             let bundleURL = URL(fileURLWithPath: bundlePath).resolvingSymlinksInPath()
             let adjacentBundleURL = bundleURL.deletingLastPathComponent().appendingPathComponent(name)
             if fileManager.isExecutableFile(atPath: adjacentBundleURL.path) {
                 return adjacentBundleURL.path
             }
        }

        // 3. Search in standardized system paths
        for basePath in searchPaths {
            let expandedPath = (basePath as NSString).expandingTildeInPath
            let fullPath = (expandedPath as NSString).appendingPathComponent(name)
            if fileManager.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

        // 4. Fallback to PATH environment variable
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let envPaths = pathEnv.split(separator: ":").map(String.init)
            for envPath in envPaths {
                let fullPath = (envPath as NSString).appendingPathComponent(name)
                if fileManager.isExecutableFile(atPath: fullPath) {
                    return fullPath
                }
            }
        }

        return nil
    }

    /// Result of a process execution
    public struct ProcessResult {
        public let exitCode: Int32
        public let stdout: Data
// Configuration struct for runProcess
public struct RunProcessConfiguration: Sendable {
    public let executable: String
    public let arguments: [String]
    public let workingDirectory: URL?
    public let inputData: Data?
    public let environment: [String: String]?
    public let timeout: TimeInterval
    public let sandboxProfile: String?
    
    public init(
        executable: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        inputData: Data? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 30.0,
        sandboxProfile: String? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.inputData = inputData
        self.environment = environment
        self.timeout = timeout
        self.sandboxProfile = sandboxProfile
    }
}

// Migration Guide:
// Old call:
// runProcess(
//     executable: value,
//     arguments: value,
//     workingDirectory: value,
//     inputData: value,
//     environment: value,
//     timeout: value,
//     sandboxProfile: value,
// )
//
// New call:
// let config = RunProcessConfiguration(
//     executable: value,
//     arguments: value,
//     workingDirectory: value,
//     inputData: value,
//     environment: value,
//     timeout: value,
//     sandboxProfile: value,
// )
// runProcess(config: config)
        executable: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        inputData: Data? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60.0,
        sandboxProfile: String? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.inputData = inputData
        self.environment = environment
        self.timeout = timeout
        self.sandboxProfile = sandboxProfile
    }
}

// Updated function signature:
func runProcess(config: RunProcessConfiguration) throws -> ProcessResult {
    // Implementation remains the same
    var effectiveExecutable = config.executable
    var effectiveArgs = config.arguments
    var profileURL: URL?
    
    if let profile = config.sandboxProfile {
        profileURL = FileManager.default.temporaryDirectory.appendingPathComponent("sb-\(UUID().uuidString).sb")
        try profile.write(to: profileURL!, atomically: true, encoding: .utf8)
    }
    // ... rest of implementation
}

// Backward compatibility (deprecated)
@available(*, deprecated, message: "Use runProcess(config:) instead")
func runProcess(
    executable: String,
    arguments: [String],
    workingDirectory: URL? = nil,
    inputData: Data? = nil,
    environment: [String: String]? = nil,
    timeout: TimeInterval = 60.0,
    sandboxProfile: String? = nil
) throws -> ProcessResult {
    let config = RunProcessConfiguration(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
        inputData: inputData,
        environment: environment,
        timeout: timeout,
        sandboxProfile: sandboxProfile
    )
    return try runProcess(config: config)
}
             effectiveExecutable = "/usr/bin/sandbox-exec"
             effectiveArgs = ["-f", profileURL!.path, executable] + arguments
        }

        defer {
            if let url = profileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        var stdinPipe: Pipe?

        process.executableURL = URL(fileURLWithPath: effectiveExecutable)
        process.arguments = effectiveArgs // Use effectiveArgs
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        if let envOverrides = environment {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in envOverrides {
                env[key] = value
            }
            process.environment = env
        }

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let _ = inputData {
            stdinPipe = Pipe()
struct RunProcessAsyncConfiguration: Sendable {
    let executable: String
    let arguments: [String]
    let workingDirectory: URL?
    let inputData: Data?
    let environment: [String: String]?
    let timeout: TimeInterval?
    let sandboxProfile: String?
    
    init(
        executable: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        inputData: Data? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil,
        sandboxProfile: String? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.inputData = inputData
        self.environment = environment
        self.timeout = timeout
        self.sandboxProfile = sandboxProfile
    }
}

// Then update the function signature to:
// func runProcessAsync(config: RunProcessAsyncConfiguration) async throws -> ProcessResult
        if let input = inputData, let pipe = stdinPipe {
            try pipe.fileHandleForWriting.write(contentsOf: input)
            try pipe.fileHandleForWriting.close()
        }

        var stdoutData = Data()
        var stderrData = Data()
        let ioGroup = DispatchGroup()

        ioGroup.enter()
        DispatchQueue.global().async {
            stdoutData = (try? stdoutPipe.fileHandleForReading.readToEnd()) ?? Data()
            ioGroup.leave()
        }

        ioGroup.enter()
        DispatchQueue.global().async {
            stderrData = (try? stderrPipe.fileHandleForReading.readToEnd()) ?? Data()
            ioGroup.leave()
        }

        let result = processGroup.wait(timeout: .now() + timeout)

        if result == .timedOut {
             process.terminate()
             processGroup.wait()
        }

        ioGroup.wait()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: stdoutData,

        timeout: TimeInterval = 60.0,
        sandboxProfile: String? = nil
    ) async throws -> ProcessResult {
        var effectiveExecutable = executable
        var effectiveArgs = arguments
        var profileURL: URL?

        if let profile = sandboxProfile {
             profileURL = FileManager.default.temporaryDirectory.appendingPathComponent("sb-\(UUID().uuidString).sb")
struct RunProcessAsyncConfiguration: Sendable {
    let executable: String
    let arguments: [String]
    let workingDirectory: URL?
    let inputData: Data?
    let environment: [String: String]?
    let timeout: TimeInterval?
    let sandboxProfile: String?
    
    init(
        executable: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        inputData: Data? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil,
        sandboxProfile: String? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.inputData = inputData
        self.environment = environment
        self.timeout = timeout
        self.sandboxProfile = sandboxProfile
    }
}

// Update function signature to:
// func runProcessAsync(config: RunProcessAsyncConfiguration) async throws -> ProcessResult

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        var stdinPipe: Pipe?

        process.executableURL = URL(fileURLWithPath: effectiveExecutable)
        process.arguments = effectiveArgs
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        if let envOverrides = environment {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in envOverrides {
                env[key] = value
            }
            process.environment = env
        }

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let _ = inputData {
            stdinPipe = Pipe()
            process.standardInput = stdinPipe
        }

        // Bridge to async execution
        return try await withTaskCancellationHandler {
            return try await withCheckedThrowingContinuation { continuation in
                do {
                    // Monitor completion
                    process.terminationHandler = { proc in
                        let stdoutData = (try? stdoutPipe.fileHandleForReading.readToEnd()) ?? Data()
                        let stderrData = (try? stderrPipe.fileHandleForReading.readToEnd()) ?? Data()

                        let result = ProcessResult(
                            exitCode: proc.terminationStatus,
                            stdout: stdoutData,
                            stderr: String(data: stderrData, encoding: .utf8) ?? ""
                        )
                        continuation.resume(returning: result)
                    }

                    try process.run()

                    if let input = inputData, let pipe = stdinPipe {
                        DispatchQueue.global().async {
                            try? pipe.fileHandleForWriting.write(contentsOf: input)
                            try? pipe.fileHandleForWriting.close()
                        }
                    }

                    // Setup timeout
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        if process.isRunning {
                            process.terminate() // This triggers terminationHandler
                        }
                    }

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }
    }

    /// Create and manage a temporary directory for worker operations.
    public static func withTemporaryDirectory<T>(
        prefix: String,
        _ block: (URL) throws -> T
    ) throws -> T {
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueDirName = "\(prefix)-\(UUID().uuidString)"
        let workingDir = tempDir.appendingPathComponent(uniqueDirName, isDirectory: true)

        try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: workingDir)
        }

        return try block(workingDir)
    }

    /// Async version of temporary directory helper
    public static func withTemporaryDirectoryAsync<T>(
        prefix: String,
        _ block: (URL) async throws -> T
    ) async throws -> T {
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueDirName = "\(prefix)-\(UUID().uuidString)"
        let workingDir = tempDir.appendingPathComponent(uniqueDirName, isDirectory: true)

        try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: workingDir)
        }

        return try await block(workingDir)
    }
}
