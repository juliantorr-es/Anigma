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

    // MARK: - Available Binaries

    enum AnigmaBinary: String, CaseIterable {
        case anigmad = "anigmad"
        case harmonia = "harmonia"
        case mlWorker = "ml-worker"
        case doctrine = "doctrine"
        case astServices = "anigma-ast-services"
        case harmoniaSurface = "harmonia-surface"
        case outlineumZine = "outlineum-zine"
        case diaplasionPipeline = "diaplasion-pipeline"
        case accessumFlow = "accessum-flow"

        var description: String {
            switch self {
            case .anigmad:
                return "Background daemon for system services (gRPC server)"
            case .harmonia:
                return "CLI for AI coding assistance"
            case .mlWorker:
                return "ML inference worker process (MLX-based)"
            case .doctrine:
                return "Policy enforcement CLI"
            case .astServices:
                return "Swift AST analysis service"
            case .harmoniaSurface:
                return "Surface-level Harmonia operations"
            case .outlineumZine:
                return "Zine and print production tools"
            case .diaplasionPipeline:
                return "Document transformation pipeline"
            case .accessumFlow:
                return "Accessibility workflow tools"
            }
        }
    }

    // MARK: - State

    private(set) var availableBinaries: [BinaryInfo] = []
    private var runningProcesses: [String: Process] = [:]

    // MARK: - Initialization

    init() {
        scanBinaries()
    }

    // MARK: - Binary Discovery

    private func scanBinaries() {
        availableBinaries = AnigmaBinary.allCases.map { binary in
            let path = binaryPath(for: binary)
            let isAvailable = FileManager.default.fileExists(atPath: path)
            return BinaryInfo(
                name: binary.rawValue,
                path: path,
                isAvailable: isAvailable,
                description: binary.description
            )
        }
    }

    private func binaryPath(for binary: AnigmaBinary) -> String {
        // First, try to find binary in app bundle
        if let bundlePath = Bundle.main.bundlePath as String? {
            let appBinaryPath = (bundlePath as NSString).appendingPathComponent("Contents/MacOS/\(binary.rawValue)")
            if FileManager.default.fileExists(atPath: appBinaryPath) {
                return appBinaryPath
            }
        }

        // Fallback: try build directory (for development)
        let projectRoot = FileManager.default.currentDirectoryPath
        let buildPath = (projectRoot as NSString).appendingPathComponent(".build/arm64-apple-macosx/release/\(binary.rawValue)")
        if FileManager.default.fileExists(atPath: buildPath) {
            return buildPath
        }

        // Fallback: just return the name (will search PATH)
        return binary.rawValue
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
        let path = binaryPath(for: binary)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

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
        let path = binaryPath(for: binary)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

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
        runningProcesses[binary.rawValue] = process
    }

    /// Check if a binary is currently running
    func isRunning(_ binary: AnigmaBinary) -> Bool {
        return runningProcesses[binary.rawValue]?.isRunning ?? false
    }

    /// Terminate a running binary
    func terminate(_ binary: AnigmaBinary) {
        runningProcesses[binary.rawValue]?.terminate()
        runningProcesses[binary.rawValue] = nil
    }

    /// Terminate all running binaries
    func terminateAll() {
        for process in runningProcesses.values {
            process.terminate()
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
        try launch(.anigmad, arguments: ["--port", "\(port)"])
    }

    /// Execute Harmonia CLI command
    func runHarmonia(arguments: [String]) async throws -> ExecutionResult {
        return try await execute(.harmonia, arguments: arguments, timeout: 300)
    }

    /// Execute ML Worker command
    func runMLWorker(arguments: [String]) async throws -> ExecutionResult {
        return try await execute(.mlWorker, arguments: arguments, timeout: 600)
    }

    /// Execute Doctrine command
    func runDoctrine(arguments: [String]) async throws -> ExecutionResult {
        return try await execute(.doctrine, arguments: arguments, timeout: 60)
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
            return "Binary '\(name)' not found in app bundle or build directory"
        case .executionFailed(let reason):
            return "Binary execution failed: \(reason)"
        case .timeout:
            return "Binary execution timed out"
        }
    }
}
