//
//  SandboxAuthorityImpl.swift
//  AnigmaCore
//
//  Phase 1 implementation of SandboxAuthority.
//  Uses macOS Sandbox profiles to isolate tool execution.
//

import Foundation

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

        // 2. Prepare Code File
        let fileExtension = getExtension(for: language)
        let codeURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + fileExtension)
        try code.write(to: codeURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: codeURL) }

        // 3. Execute via sandbox-exec
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
        process.arguments = ["-f", profileURL.path, getRuntime(for: language), codeURL.path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        // 4. Timeout Management
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(constraints.timeoutSeconds) * 1_000_000_000)
            if process.isRunning {
                process.terminate()
                print("SandboxAuthority: Execution timed out after \(constraints.timeoutSeconds)s")
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        return ToolResult(
            stdout: String(data: outputData, encoding: .utf8) ?? "",
            stderr: String(data: errorData, encoding: .utf8) ?? "",
            exitCode: Int(process.terminationStatus)
        )
    }

    private func generateProfile(constraints: SandboxConstraints) -> String {
        var profile = "(version 1)\n(deny default)\n"
        profile += "(allow process-exec)\n"
        profile += "(allow file-read* (subpath \"/usr/lib\"))\n"
        profile += "(allow file-read* (subpath \"/usr/bin\"))\n"

        if constraints.allowNetwork {
            profile += "(allow network*)\n"
        }

        if constraints.allowFileSystem {
            profile += "(allow file*)\n"
        }

        return profile
    }

    private func getExtension(for language: ToolLanguage) -> String {
        switch language {
        case .python: return ".py"
        case .javascript: return ".js"
        case .wasm: return ".wasm"
        case .shell: return ".sh"
        }
    }

    private func getRuntime(for language: ToolLanguage) -> String {
        switch language {
        case .python: return "/usr/bin/python3"
        case .javascript: return "/usr/bin/node"
        case .shell: return "/bin/zsh"
        default: return "/usr/bin/true"
        }
    }
}
