//
//  BinaryManager.swift
//  AnigmaAppMac
//
//  Service for managing and launching bundled Anigma binaries.
//

import Foundation
import Observation

@MainActor
@Observable
final class BinaryManager {

    // MARK: - Binary Info

    struct BinaryInfo {
        let name: String
        let path: String
        let isAvailable: Bool
        let description: String
    }

    private struct ManagedProcess {
        let process: Process
        let standardInput: Pipe?
    }

    // MARK: - Available Binaries

    enum AnigmaBinary: String, CaseIterable {
        case anigmad = "anigmad"
        case harmonia = "harmonia"
        case mlWorker = "ml-worker"

        var description: String {
            switch self {
            case .anigmad:
                return "Background daemon for system services (gRPC server)"
            case .harmonia:
                return "CLI for AI coding assistance"
            case .mlWorker:
                return "ML inference worker process (MLX-based)"
            }
        }
    }

    // MARK: - State

    private(set) var availableBinaries: [BinaryInfo] = []
    private var runningProcesses: [String: ManagedProcess] = [:]

    // MARK: - Initialization

    init() {
        scanBinaries()
    }

    // MARK: - Binary Discovery

    func refreshDiscovery() {
        scanBinaries()
    }

    private func scanBinaries() {
        availableBinaries = AnigmaBinary.allCases.map { binary in
            let resolvedPath = binaryPath(for: binary)
            let path = resolvedPath ?? expectedBinaryPath(for: binary)
            let isAvailable = resolvedPath != nil
            return BinaryInfo(
                name: binary.rawValue,
                path: path,
                isAvailable: isAvailable,
                description: binary.description
            )
        }
    }

    private func binaryPath(for binary: AnigmaBinary) -> String? {
        let expectedPath = expectedBinaryPath(for: binary)
        return FileManager.default.fileExists(atPath: expectedPath) ? expectedPath : nil
    }

    private func expectedBinaryPath(for binary: AnigmaBinary) -> String {
        let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent().path
            ?? FileManager.default.currentDirectoryPath
        return (executableDirectory as NSString).appendingPathComponent(binary.rawValue)
    }

    private func runtimeDirectory() -> URL {
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let runtimeDir = appSupport.appendingPathComponent("Anigma", isDirectory: true)
        try? FileManager.default.createDirectory(at: runtimeDir, withIntermediateDirectories: true)
        return runtimeDir
    }

    private func resolvedArguments(for binary: AnigmaBinary, arguments: [String]) -> [String] {
        switch binary {
        case .mlWorker:
            if arguments.contains("--engine") || arguments.contains("-e") {
                return arguments
            }
            return ["--engine", "mlx"] + arguments
        case .anigmad:
            if arguments.isEmpty {
                return ["--tcp-enabled"]
            }
            return arguments
        case .harmonia:
            return arguments
        }
    }

    private func processEnvironment(for binary: AnigmaBinary) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if let mlWorkerPath = binaryPath(for: .mlWorker) {
            environment["ML_WORKER_PATH"] = mlWorkerPath
        }
        if let harmoniaPath = binaryPath(for: .harmonia) {
            environment["HARMONIA_PATH"] = harmoniaPath
        }
        environment["ANIGMA_APP_SUPPORT"] = runtimeDirectory().path
        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent().path {
            let existing = environment["DYLD_LIBRARY_PATH"].map { "\($0):\(executableDirectory)" } ?? executableDirectory
            environment["DYLD_LIBRARY_PATH"] = existing
        }
        if binary == .mlWorker {
            environment["MLX_MODEL_ID"] = environment["MLX_MODEL_ID"] ?? "mlx-community/Qwen3-4B-4bit"
        }
        return environment
    }

    // MARK: - Binary Execution

    struct ExecutionResult {
        let exitCode: Int32
        let output: String
        let error: String
    }

    /// Execute a binary synchronously and return the result
    func execute(
        _ binary: AnigmaBinary,
        arguments: [String] = [],
        timeout: TimeInterval? = nil
    ) async throws -> ExecutionResult {
        guard let path = binaryPath(for: binary) else {
            throw BinaryManagerError.binaryNotFound(binary.rawValue)
        }
        let resolvedArguments = resolvedArguments(for: binary, arguments: arguments)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = resolvedArguments
        process.environment = processEnvironment(for: binary)
        process.currentDirectoryURL = runtimeDirectory()

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        if binary == .mlWorker {
            process.standardInput = Pipe()
        }

        try process.run()

        // Handle timeout if specified
        if let timeout = timeout {
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning {
                    process.terminate()
                }
            }
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        return ExecutionResult(
            exitCode: process.terminationStatus,
            output: output,
            error: error
        )
    }

    /// Launch a binary in the background and return immediately
    func launch(
        _ binary: AnigmaBinary,
        arguments: [String] = [],
        outputHandler: ((String) -> Void)? = nil
    ) throws {
        guard let path = binaryPath(for: binary) else {
            throw BinaryManagerError.binaryNotFound(binary.rawValue)
        }
        let resolvedArguments = resolvedArguments(for: binary, arguments: arguments)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = resolvedArguments
        process.environment = processEnvironment(for: binary)
        process.currentDirectoryURL = runtimeDirectory()
        let inputPipe = binary == .mlWorker ? Pipe() : nil
        process.standardInput = inputPipe

        if let outputHandler = outputHandler {
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                    Task { @MainActor in
                        outputHandler(output)
                    }
                }
            }
        }

        try process.run()
        runningProcesses[binary.rawValue] = ManagedProcess(process: process, standardInput: inputPipe)
    }

    /// Check if a binary is currently running
    func isRunning(_ binary: AnigmaBinary) -> Bool {
        return runningProcesses[binary.rawValue]?.process.isRunning ?? false
    }

    /// Runtime health for the launcher surface.
    struct RuntimeHealth {
        let bundleIdentifier: String?
        let isAppBundle: Bool
        let applicationSupportReady: Bool
        let databaseReady: Bool
        let databasePath: String
        let bundledBinaryCount: Int
        let totalBinaryCount: Int
    }

    var runtimeHealth: RuntimeHealth {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        let isAppBundle = Bundle.main.bundleURL.pathExtension == "app"

        let supportURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let applicationSupportReady = supportURL != nil

        let databaseURL = supportURL?
            .appendingPathComponent("Anigma", isDirectory: true)
            .appendingPathComponent("harmonia_v3.postgres") ??
            URL(fileURLWithPath: "")
        let databaseReady = !databaseURL.path.isEmpty && FileManager.default.fileExists(atPath: databaseURL.path)

        let bundledBinaryCount = availableBinaries.filter(\.isAvailable).count

        return RuntimeHealth(
            bundleIdentifier: bundleIdentifier,
            isAppBundle: isAppBundle,
            applicationSupportReady: applicationSupportReady,
            databaseReady: databaseReady,
            databasePath: databaseURL.path,
            bundledBinaryCount: bundledBinaryCount,
            totalBinaryCount: availableBinaries.count
        )
    }

    /// Terminate a running binary
    func terminate(_ binary: AnigmaBinary) {
        runningProcesses[binary.rawValue]?.process.terminate()
        runningProcesses[binary.rawValue] = nil
    }

    /// Terminate all running binaries
    func terminateAll() {
        for managed in runningProcesses.values {
            managed.process.terminate()
        }
        runningProcesses.removeAll()
    }

    // MARK: - Convenience Methods

    /// Check if the daemon is running
    var isDaemonRunning: Bool {
        isRunning(.anigmad)
    }

    /// Launch the daemon
    func launchDaemon(port: Int = 50051) throws {
        _ = port
        try launch(.anigmad, arguments: ["--tcp-enabled"])
    }

    /// Execute Harmonia CLI command
    func runHarmonia(arguments: [String]) async throws -> ExecutionResult {
        return try await execute(.harmonia, arguments: arguments, timeout: 300)
    }

    /// Execute ML Worker command
    func runMLWorker(arguments: [String]) async throws -> ExecutionResult {
        return try await execute(.mlWorker, arguments: arguments, timeout: 600)
    }

}

// MARK: - Error Types

enum BinaryManagerError: Error, LocalizedError {
    case binaryNotFound(String)
    case executionFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let name):
            return "Binary '\(name)' not found in launcher runtime directory"
        case .executionFailed(let reason):
            return "Binary execution failed: \(reason)"
        case .timeout:
            return "Binary execution timed out"
        }
    }
}
