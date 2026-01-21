//
//  ProcessIsolation.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Process isolation for mutation engines.
//  Runs engines in separate processes with restricted capabilities.
//  Not vibes - actual OS-level isolation.
//

import Foundation
import AnigmaCore // Import AnigmaCore for AuditLogger, SandboxConfig, ProcessResult

// MARK: - Process Runner

/// Runs commands in isolated processes.
public actor ProcessIsolationRunner {
    private let config: SandboxConfig
    private let auditLogger: AuditLogger

    public init(config: SandboxConfig, auditLogger: AuditLogger = AuditLogger()) {
        self.config = config
        self.auditLogger = auditLogger
    }

    /// Run a command in the sandbox.
    public func run(
        command: String,
        arguments: [String] = [],
        input: Data? = nil,
        engineId: String,
        operation: String
    ) async throws -> ProcessResult {
        let startTime = Date()

        // Log the operation
        await auditLogger.logOperation(
            engineId: engineId,
            operation: operation,
            command: command,
            arguments: arguments,
            config: config
        )

        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: config.workingDirectory)

        // Set environment (filtered)
        process.environment = filteredEnvironment()

        // Set up pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        if let input = input {
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            try inputPipe.fileHandleForWriting.write(contentsOf: input)
            try inputPipe.fileHandleForWriting.close()
        }

        // Set resource limits (macOS specific)
        #if os(macOS)
        let task = process
        var limits = rlimit()

        // Memory limit
        limits.rlim_cur = rlim_t(config.maxMemoryMB * 1024 * 1024)
        limits.rlim_max = rlim_t(config.maxMemoryMB * 1024 * 1024)
        setrlimit(RLIMIT_AS, &limits)

        // CPU time limit
        limits.rlim_cur = rlim_t(config.maxCPUTimeSeconds)
        limits.rlim_max = rlim_t(config.maxCPUTimeSeconds)
        setrlimit(RLIMIT_CPU, &limits)
        #endif

        // Run process
        try process.run()
        process.waitUntilExit()

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Read output
        let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        let result = ProcessResult(
            exitCode: process.terminationStatus,
            output: output,
            error: error,
            duration: duration,
            timedOut: duration > Double(config.maxCPUTimeSeconds)
        )

        // Log result
        await auditLogger.logResult(
            engineId: engineId,
            operation: operation,
            result: result,
            startTime: startTime,
            endTime: endTime
        )

        return result
    }

    /// Run Swift code in isolated process.
    public func runSwiftCode(
        _ code: String,
        engineId: String,
        operation: String
    ) async throws -> ProcessResult {
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString).swift")

        do {
            try code.write(to: tempFile, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: tempFile) }

            return try await run(
                command: "/usr/bin/swift",
                arguments: [tempFile.path],
                engineId: engineId,
                operation: operation
            )
        } catch {
            await auditLogger.logError(
                engineId: engineId,
                operation: operation,
                error: "Failed to run Swift code: \(error)"
            )
            throw error
        }
    }

    /// Filter environment variables to remove secrets.
    private func filteredEnvironment() -> [String: String] {
        var filtered = config.environment

        // Remove potential secrets
        let secretPatterns = [
            "API_KEY", "TOKEN", "SECRET", "PASSWORD",
            "AWS_ACCESS_KEY", "AWS_SECRET_KEY",
            "GITHUB_TOKEN", "SLACK_TOKEN"
        ]

        for key in filtered.keys {
            for pattern in secretPatterns {
                if key.uppercased().contains(pattern) {
                    filtered.removeValue(forKey: key)
                    break
                }
            }
        }

        return filtered
    }
}

// MARK: - System Calls (macOS specific)

#if os(macOS)
import Darwin
import HarmoniaModule

private func setrlimit(_ resource: Int32, _ rlp: UnsafePointer<rlimit>!) -> Int32 {
    Darwin.setrlimit(resource, rlp)
}

private let RLIMIT_AS = Darwin.RLIMIT_AS
private let RLIMIT_CPU = Darwin.RLIMIT_CPU
#endif
