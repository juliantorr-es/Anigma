//
//  main.swift
//  BuildIngest
//
//  Build diagnostics ingestion command.
//  Captures Swift compiler output and stores it as structured evidence.
//  Turns "compiler screaming" into queryable incident response data.
//

import Foundation
import DatabaseCore
import ArgumentParser
import CryptoKit

@main
struct BuildIngest: AsyncParsableCommand {
    @Argument(help: "Build target to compile (e.g., HarmoniaModule, DatabaseCore)")
    var target: String

    @Option(help: "Build configuration (debug/release)")
    var configuration: String = "debug"

    @Option(help: "Toolchain identifier")
    var toolchain: String = "swift-5.9"

    @Option(help: "Custom session ID (auto-generated if not provided)")
    var sessionId: String?

    @Option(help: "Working directory for build")
    var workingDirectory: String = FileManager.default.currentDirectoryPath

    @Option(help: "Verbose build output")
    var verbose: Bool = false

    func run() async throws {
        let sessionId = sessionId ?? UUID().uuidString
        let startTime = Date()

        print("🔨 Build Ingestion Session: \(sessionId)")
        print("📁 Working Directory: \(workingDirectory)")
        print("🎯 Target: \(target)")
        print("⚙️  Configuration: \(configuration)")

        // Initialize database
        let dbActor = DatabaseActor()
        try await dbActor.open()

        // Create build session record
        let gitState = try await captureGitState(workingDirectory: workingDirectory)
        let buildSessionId = try await createBuildSession(
            dbActor: dbActor,
            sessionId: sessionId,
            gitState: gitState,
            target: target,
            configuration: configuration,
            toolchain: toolchain,
            workingDirectory: workingDirectory
        )

        // Execute build and capture output
        let buildResult = await executeBuild(
            target: target,
            configuration: configuration,
            workingDirectory: workingDirectory,
            verbose: verbose
        )

        // Parse and store diagnostics
        let diagnosticsCount = try await parseAndStoreDiagnostics(
            dbActor: dbActor,
            buildSessionId: buildSessionId,
            buildOutput: buildResult.output,
            exitCode: buildResult.exitCode
        )

        // Update build session with completion status
        try await updateBuildSession(
            dbActor: dbActor,
            sessionId: buildSessionId,
            exitCode: buildResult.exitCode,
            endTime: Date(),
            totalErrors: diagnosticsCount.errors,
            totalWarnings: diagnosticsCount.warnings,
            artifactPath: buildResult.artifactPath
        )

        let duration = Date().timeIntervalSince(startTime)
        print("✅ Build session completed in \(String(format: "%.2f", duration))s")
        print("📊 Stored \(diagnosticsCount.errors) errors, \(diagnosticsCount.warnings) warnings")
        print("🔗 Session ID: \(buildSessionId)")

        await dbActor.close()
    }

    // MARK: - Git State Capture

    private func captureGitState(workingDirectory: String) async throws -> BuildIngestTypes.GitState {
        let process = Process()
        process.currentDirectoryPath = workingDirectory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "rev-parse", "HEAD",  // Current commit
            "--abbrev-ref", "HEAD",  // Current branch
            "status", "--porcelain"  // Working tree status
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
            throw BuildIngestError.gitStateCaptureFailed("Failed to read git output")
        }
        let lines = output.components(separatedBy: .newlines)

        guard lines.count >= 2 else {
            throw BuildIngestError.gitStateCaptureFailed("Insufficient git output")
        }

        let commitHash = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if working tree is dirty
        let statusProcess = Process()
        statusProcess.currentDirectoryPath = workingDirectory
        statusProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        statusProcess.arguments = ["status", "--porcelain=v1"]

        let statusPipe = Pipe()
        statusProcess.standardOutput = statusPipe
        try statusProcess.run()
        statusProcess.waitUntilExit()

        guard let statusOutput = String(data: statusPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
            throw BuildIngestError.gitStateCaptureFailed("Failed to read git status")
        }
        let isDirty = !statusOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let logProcess = Process()
        logProcess.currentDirectoryPath = workingDirectory
        logProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        logProcess.arguments = ["log", "-1", "--pretty=format:%an%n%ae%n%at%n%s"]

        let logPipe = Pipe()
        logProcess.standardOutput = logPipe
        try logProcess.run()
        logProcess.waitUntilExit()

        let logOutput = String(data: logPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        let logLines = logOutput?.components(separatedBy: .newlines) ?? []
        let authorName = !logLines.isEmpty ? logLines[0] : nil
        let authorEmail = logLines.count > 1 ? logLines[1] : nil
        let commitTimestamp = logLines.count > 2 ? Int(logLines[2]) : nil
        let message = logLines.count > 3 ? logLines[3] : nil

        return BuildIngestTypes.GitState(
            id: UUID().uuidString,
            commitHash: commitHash,
            branch: branch,
            isDirty: isDirty,
            diffHash: isDirty ? try await captureDiffHash(workingDirectory: workingDirectory) : nil,
            authorName: authorName,
            authorEmail: authorEmail,
            commitTimestamp: commitTimestamp,
            message: message
        )
    }

    private func captureDiffHash(workingDirectory: String) async throws -> String {
        let process = Process()
        process.currentDirectoryPath = workingDirectory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["diff", "--staged", "--raw"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutputData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard let output = String(data: outputData, encoding: .utf8) else {
            return BuildIngestTypes.BuildResult(
                output: "",
                errorOutput: "Failed to read build output",
                exitCode: -1,
                artifactPath: nil
            )
        }
        guard let errorOutput = String(data: errorOutputData, encoding: .utf8) else {
            return BuildIngestTypes.BuildResult(
                output: output,
                errorOutput: "Failed to read error output",
                exitCode: -1,
                artifactPath: nil
            )
        }

        // Extract artifact path from build output
        let artifactPath = extractArtifactPath(from: (output ?? "") + (errorOutput ?? ""))

        return BuildIngestTypes.BuildResult(
            output: (output ?? "") + (errorOutput ?? ""),
            errorOutput: errorOutput ?? "",
            exitCode: Int32(process.terminationStatus),
            artifactPath: artifactPath
        )
    }

    private func extractArtifactPath(from output: String) -> String? {
        // Look for build artifact patterns in Swift output
        let patterns = [
            "Build of product '(.+)' complete",
            "Built target '(.+)'",
            "Linking (.+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: output.utf16.count)
                if let match = regex.firstMatch(in: output, options: [], range: range) {
                    if match.numberOfRanges > 1 {
                        let artifactRange = match.range(at: 1)
                        guard let artifactRange = artifactRange else { continue }
                        let start = String.Index(utf16Offset: artifactRange.location, in: output)
                        let end = String.Index(utf16Offset: artifactRange.location + artifactRange.length, in: output)
                        return String(output[start..<end])
                    }
                }
            }
        }

/// Configuration for creating a build session
struct CreateBuildSessionConfiguration: Sendable {
    let dbActor: DatabaseActor
    let sessionId: String
    let gitState: GitState
    let target: String
    let configuration: String
    let toolchain: String
    let workingDirectory: String
}

// Function signature should change to:
// func createBuildSession(config: CreateBuildSessionConfiguration) async throws -> BuildSession

// Migration Guide:
// Old call:
// createBuildSession(
//     dbActor: value,
//     sessionId: value,
//     gitState: value,
//     target: value,
//     configuration: value,
//     toolchain: value,
//     workingDirectory: value,
// )
//
// New call:
// let config = CreateBuildSessionConfiguration(
//     dbActor: value,
//     sessionId: value,
//     gitState: value,
//     target: value,
//     configuration: value,
//     toolchain: value,
//     workingDirectory: value,
// )
// createBuildSession(config: config)
func createBuildSession(config: CreateBuildSessionConfiguration) async throws -> String {
    // Implementation using config.dbActor, config.sessionId, etc.
}
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'running')
        """

        try await dbActor.execute(insertSQL, parameters: [
            .text(sessionId),
            .text(gitState.id),
            .text(target),
            .text(configuration),
            .text(toolchain),
            .text(getSwiftVersion()),
            .text(getXcodeVersion()),
            .text("macos"),
            .text("arm64"),
            .text("swift build --target \(target)"),
            .text(workingDirectory),
            .text(String(Int(Date().timeIntervalSince1970)))
        ])

        return sessionId
    }

    private func parseAndStoreDiagnostics(
        dbActor: DatabaseActor,
        buildSessionId: String,
        buildOutput: String,
        exitCode: Int32
    ) async throws -> (errors: Int, warnings: Int) {

        let lines = buildOutput.components(separatedBy: .newlines)
        var errorCount = 0
        var warningCount = 0

        for (index, line) in lines.enumerated() {
            if let diagnostic = parseDiagnosticLine(line, defaultLineNumber: index + 1) {
                try await storeDiagnostic(dbActor: dbActor, buildSessionId: buildSessionId, diagnostic: diagnostic)

                if diagnostic.severity == "error" {
                    errorCount += 1
                } else if diagnostic.severity == "warning" {
                    warningCount += 1
                }
            }
        }

        return (errors: errorCount, warnings: warningCount)
    }

    private func parseDiagnosticLine(_ line: String, defaultLineNumber: Int) -> BuildIngestTypes.Diagnostic? {
        // Swift compiler format: /path/to/file.swift:line:column: error: message
        let pattern = #"^(.+?):(\d+):(\d+):\s*(error|warning|note):\s*(.+)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }

        guard match.numberOfRanges >= 5 else { return nil }

        let filePath = extractString(from: line, range: match.range(at: 1))
        let parsedLineNumber = extractInt(from: line, range: match.range(at: 2))
        let parsedColumnNumber = extractInt(from: line, range: match.range(at: 3))
        let severity = extractString(from: line, range: match.range(at: 4))
        let message = extractString(from: line, range: match.range(at: 5))
        let lineNumber = parsedLineNumber > 0 ? parsedLineNumber : defaultLineNumber

        return BuildIngestTypes.Diagnostic(
            id: UUID().uuidString,
            buildSessionId: "", // Will be filled by caller
            filePath: filePath,
            lineNumber: lineNumber,
            columnNumber: parsedColumnNumber,
            severity: severity,
            category: "compiler",
            tool: "swiftc",
            message: message,
            codeSnippet: extractCodeSnippet(filePath: filePath, lineNumber: lineNumber),
            functionName: nil,
            moduleName: nil,
            ruleId: nil,
            fixitAvailable: false
        )
    }

    private func extractString(from string: String, range: NSRange) -> String {
        guard range.location != NSNotFound else { return "" }
        let start = String.Index(utf16Offset: range.location, in: string)
        let end = String.Index(utf16Offset: range.location + range.length, in: string)
        return String(string[start..<end])
    }

    private func extractInt(from string: String, range: NSRange) -> Int {
        guard range.location != NSNotFound else { return 0 }
        let substring = extractString(from: string, range: range)
        return Int(substring) ?? 0
    }

    private func extractCodeSnippet(filePath: String, lineNumber: Int) -> String? {
        guard !filePath.isEmpty,
              FileManager.default.fileExists(atPath: filePath),
              lineNumber > 0 else { return nil }

        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let index = lineNumber - 1
            guard index < lines.count else { return nil }

            let start = max(0, index - 2)
            let end = min(lines.count - 1, index + 2)
            return lines[start...end].enumerated().map { offset, line in
                let lineIndex = start + offset + 1
                let marker = lineIndex == lineNumber ? ">>>" : "   "
                return "\(marker) \(lineIndex): \(line)"
            }.joined(separator: "\n")

        totalWarnings: Int,
        artifactPath: String?
    ) async throws {

        try await DatabaseExtensions.updateBuildSession(
            dbActor: dbActor,
struct UpdateBuildSessionConfiguration: Sendable {
    let dbActor: DatabaseActor
    let sessionId: String
    let exitCode: Int32
    let endTime: Date
    let totalErrors: Int
    let totalWarnings: Int
    let artifactPath: String?
}

// Function signature should be updated to:
// func updateBuildSession(config: UpdateBuildSessionConfiguration) async throws
    
    init(
        dbActor: DatabaseActor,
        sessionId: String,
        exitCode: Int32,
        endTime: Date,
        totalErrors: Int,
        totalWarnings: Int,
        artifactPath: String?
    ) {
        self.dbActor = dbActor
        self.sessionId = sessionId
        self.exitCode = exitCode
        self.endTime = endTime
        self.totalErrors = totalErrors
        self.totalWarnings = totalWarnings
        self.artifactPath = artifactPath
    }
}

// Updated function signature:
private func updateBuildSession(config: UpdateBuildSessionConfiguration) async throws {
    // Implementation using config.dbActor, config.sessionId, etc.
}

        try await DatabaseExtensions.storeDiagnostic(
            dbActor: dbActor,
            buildSessionId: buildSessionId,
            diagnostic: diagnostic
        )
    }

    // MARK: - Environment Helpers

    private func getSwiftVersion() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
            return "Unknown"
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func getXcodeVersion() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = ["-version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
            return "Unknown"
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types

struct GitState {
    let id: String
    let commitHash: String
    let branch: String
    let isDirty: Bool
    let diffHash: String?
    let authorName: String?
    let authorEmail: String?
    let commitTimestamp: Int?
    let message: String?
}

struct BuildResult {
    let output: String
    let errorOutput: String
    let exitCode: Int32
    let artifactPath: String?
}

struct Diagnostic {
    let id: String
    var buildSessionId: String
    let filePath: String
    let lineNumber: Int
    let columnNumber: Int
    let severity: String
    let category: String
    let tool: String
    let message: String
    let codeSnippet: String?
    let functionName: String?
    let moduleName: String?
    let ruleId: String?
    let fixitAvailable: Bool
}

enum BuildIngestError: Error, LocalizedError {
    case gitStateCaptureFailed(String)

    var errorDescription: String? {
        switch self {
        case .gitStateCaptureFailed(let message):
            return "Failed to capture git state: \(message)"
        }
    }
}
