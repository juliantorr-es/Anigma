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
        "/opt/homebrew/bin",
        "/usr/local/texlive/2024/bin/universal-darwin",
        "~/.anigma/tools"
    ]

    /// Find an executable tool by name, prioritizing bundle-adjacent locations.
    public static func findTool(named name: String) -> String? {
        let fileManager = FileManager.default

        if name.hasPrefix("/") && fileManager.isExecutableFile(atPath: name) {
            return name
        }

        let selfPath = CommandLine.arguments[0]
        let selfURL = URL(fileURLWithPath: selfPath).resolvingSymlinksInPath()
        let adjacentURL = selfURL.deletingLastPathComponent().appendingPathComponent(name)

        if fileManager.isExecutableFile(atPath: adjacentURL.path) {
             return adjacentURL.path
        }

        if let bundlePath = Bundle.main.executablePath {
             let bundleURL = URL(fileURLWithPath: bundlePath).resolvingSymlinksInPath()
             let adjacentBundleURL = bundleURL.deletingLastPathComponent().appendingPathComponent(name)
             if fileManager.isExecutableFile(atPath: adjacentBundleURL.path) {
                 return adjacentBundleURL.path
             }
        }

        for basePath in searchPaths {
            let expandedPath = (basePath as NSString).expandingTildeInPath
            let fullPath = (expandedPath as NSString).appendingPathComponent(name)
            if fileManager.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

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

    public struct ProcessResult {
        public let exitCode: Int32
        public let stdout: Data
        public let stderr: String
    }

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

    public static func runProcess(config: RunProcessConfiguration) throws -> ProcessResult {
        var effectiveExecutable = config.executable
        var effectiveArgs = config.arguments
        var profileURL: URL?
        
        if let profile = config.sandboxProfile {
            profileURL = FileManager.default.temporaryDirectory.appendingPathComponent("sb-\(UUID().uuidString).sb")
            try profile.write(to: profileURL!, atomically: true, encoding: .utf8)
            effectiveExecutable = "/usr/bin/sandbox-exec"
            effectiveArgs = ["-f", profileURL!.path, config.executable] + config.arguments
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
        process.arguments = effectiveArgs
        if let workingDirectory = config.workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        if let envOverrides = config.environment {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in envOverrides {
                env[key] = value
            }
            process.environment = env
        }

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let input = config.inputData {
            stdinPipe = Pipe()
            process.standardInput = stdinPipe
        }

        try process.run()

        if let input = config.inputData, let pipe = stdinPipe {
            try pipe.fileHandleForWriting.write(contentsOf: input)
            try pipe.fileHandleForWriting.close()
        }

        let stdoutData = (try? stdoutPipe.fileHandleForReading.readToEnd()) ?? Data()
        let stderrData = (try? stderrPipe.fileHandleForReading.readToEnd()) ?? Data()

        process.waitUntilExit()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: stdoutData,
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    public static func runProcess(
        executable: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        inputData: Data? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60.0,
        sandboxProfile: String? = nil
    ) throws -> ProcessResult {
        try runProcess(
            config: RunProcessConfiguration(
                executable: executable,
                arguments: arguments,
                workingDirectory: workingDirectory,
                inputData: inputData,
                environment: environment,
                timeout: timeout,
                sandboxProfile: sandboxProfile
            )
        )
    }

    public static func runProcessAsync(config: RunProcessConfiguration) async throws -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        var stdinPipe: Pipe?

        var effectiveExecutable = config.executable
        var effectiveArgs = config.arguments
        var profileURL: URL?

        if let profile = config.sandboxProfile {
            profileURL = FileManager.default.temporaryDirectory.appendingPathComponent("sb-\(UUID().uuidString).sb")
            try profile.write(to: profileURL!, atomically: true, encoding: .utf8)
            effectiveExecutable = "/usr/bin/sandbox-exec"
            effectiveArgs = ["-f", profileURL!.path, config.executable] + config.arguments
        }

        defer {
            if let url = profileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        process.executableURL = URL(fileURLWithPath: effectiveExecutable)
        process.arguments = effectiveArgs
        if let workingDirectory = config.workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        if let envOverrides = config.environment {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in envOverrides {
                env[key] = value
            }
            process.environment = env
        }

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let _ = config.inputData {
            stdinPipe = Pipe()
            process.standardInput = stdinPipe
        }

        return try await withTaskCancellationHandler {
            return try await withCheckedThrowingContinuation { continuation in
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

                do {
                    try process.run()

                    if let input = config.inputData, let pipe = stdinPipe {
                        Task.detached {
                            try? pipe.fileHandleForWriting.write(contentsOf: input)
                            try? pipe.fileHandleForWriting.close()
                        }
                    }

                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(config.timeout * 1_000_000_000))
                        if process.isRunning {
                            process.terminate()
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
