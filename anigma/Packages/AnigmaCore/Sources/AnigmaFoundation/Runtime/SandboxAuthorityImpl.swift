//
//  SandboxAuthorityImpl.swift
//  AnigmaCore
//
//  Phase 1 implementation of SandboxAuthority.
//  Executes code using macOS 'sandbox-exec' with custom profiles.
//

import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts
import Foundation
import AnigmaPrimitives

actor SandboxAuthorityImpl: SandboxAuthority {
    public init() {}

    func execute(
        code: String,
        language: ToolLanguage,
        constraints: SandboxConstraints,
        context: ExecutionContext
    ) async throws -> ToolResult {
        // 1. Generate Sandbox Profile (.sb)
        let profile = generateProfile(constraints: constraints)
        let profileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sb")
        try profile.write(to: profileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: profileURL) }

        // 2. Prepare Source Code File
        let sourceExtension = getExtension(for: language)
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + sourceExtension)
        try code.write(to: sourceURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        // 3. Prepare Process
        let process = Process()
        let pipe = Pipe()
        let errPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
        process.arguments = [
            "-f", profileURL.path,
            getRuntime(for: language), sourceURL.path
        ]
        process.standardOutput = pipe
        process.standardError = errPipe

        let startTime = Date()

        // 4. Run Process with Timeout
        try process.run()

        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(constraints.timeoutSeconds) * 1_000_000_000)
            if process.isRunning {
                process.terminate()
                return true
            }
            return false
        }

        process.waitUntilExit()
        let timedOut = (try? await timeoutTask.value) ?? false

        let durationMs = Int64(Date().timeIntervalSince(startTime) * 1000)
        let stdoutData = try pipe.fileHandleForReading.readToEnd() ?? Data()
        let stderrData = try errPipe.fileHandleForReading.readToEnd() ?? Data()

        return ToolResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus,
            durationMs: durationMs,
            timedOut: timedOut
        )
    }

    private func generateProfile(constraints: SandboxConstraints) -> String {
        var profile = "(version 1)\n(deny default)\n"
        profile += "(allow process-exec)\n"
        
        if constraints.allowFileSystem {
            profile += "(allow file-read*)\n"
            for path in constraints.allowedPaths {
                profile += "(allow file-read* file-write* (subpath \"\(path)\"))\n"
            }
        }
        
        if constraints.allowNetwork {
            profile += "(allow network*)\n"
        }
        
        return profile
    }

    private func getExtension(for language: ToolLanguage) -> String {
        switch language {
        case .python: return ".py"
        case .swift: return ".swift"
        case .bash: return ".sh"
        }
    }

    private func getRuntime(for language: ToolLanguage) -> String {
        switch language {
        case .python: return "/usr/bin/python3"
        case .swift: return "/usr/bin/swift"
        case .bash: return "/bin/bash"
        }
    }
}
