//
//  BuildOutputIngestionPipeline.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import DatabaseCore
import Foundation
import CryptoKit
public actor BuildOutputIngestionPipeline {
    private let dbActor: DatabaseActor

    public init(dbActor: DatabaseActor) {
        self.dbActor = dbActor
    }

    /// Ingest build output with complete git and toolchain context
    public func ingestBuild(
        buildCommand: String,
        target: String,
        configuration: String = "debug",
        workingDirectory: String = FileManager.default.currentDirectoryPath
    ) async throws -> BuildIngestionResult {
        let sessionId = UUID().uuidString
        let startTime = Int(Date().timeIntervalSince1970)

        // Step 1: Capture git state
        let gitState = try await captureGitState(workingDirectory: workingDirectory)
        let gitStateId = try await storeGitState(gitState: gitState)

        // Step 2: Execute build command and capture output
        let buildResult = try await executeBuild(
            command: buildCommand,
            workingDirectory: workingDirectory
        )

        // Step 3: Parse build output and create artifacts
        let outputPath = try await storeBuildArtifact(
            sessionId: sessionId,
            output: buildResult.output,
            buildCommand: buildCommand
        )

        // Step 4: Parse diagnostics and store structured records
        let diagnostics = try await parseBuildDiagnostics(
            output: buildResult.output,
            error: buildResult.error
        )

        let storedDiagnostics = try await storeDiagnostics(
            sessionId: sessionId,
            gitStateId: gitStateId,
            target: target,
            configuration: configuration,
            buildCommand: buildCommand,
            workingDirectory: workingDirectory,
            diagnostics: diagnostics,
            startTime: startTime,
            endTime: Int(Date().timeIntervalSince1970),
            exitCode: buildResult.exitCode,
            outputPath: outputPath
        )

        // Step 5: Store build artifacts (binaries, libraries, etc.)
        let artifacts = try await storeBuildArtifacts(
            sessionId: sessionId,
            target: target,
            configuration: configuration,
            buildOutput: buildResult.output
        )

        return BuildIngestionResult(
            sessionId: sessionId,
            gitStateId: gitStateId,
            diagnosticsStored: storedDiagnostics.count,
            artifactsStored: artifacts.count,
            exitCode: buildResult.exitCode,
            buildDuration: Int(Date().timeIntervalSince1970) - startTime
        )
    }

    // MARK: - Git State Capture

    private func captureGitState(workingDirectory: String) async throws -> GitState {
        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let commitData = pipe.fileHandleForReading.readDataToEndOfFile()
        let commitHash = String(data: commitData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Get branch
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        let branchPipe = Pipe()
        process.standardOutput = branchPipe
        try process.run()
        process.waitUntilExit()

        let branchData = branchPipe.fileHandleForReading.readDataToEndOfFile()
        let branch = String(data: branchData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "main"

        // Check if dirty
        process.arguments = ["status", "--porcelain"]
        let statusPipe = Pipe()
        process.standardOutput = statusPipe
        try process.run()
        process.waitUntilExit()

        let statusData = statusPipe.fileHandleForReading.readDataToEndOfFile()
        let statusOutput = String(data: statusData, encoding: .utf8) ?? ""
        let isDirty = !statusOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // Get diff hash if dirty
        var diffHash: String?
        if isDirty {
            process.arguments = ["diff", "--cached"]
            let diffPipe = Pipe()
            process.standardOutput = diffPipe
            try process.run()
            process.waitUntilExit()

            let diffData = diffPipe.fileHandleForReading.readDataToEndOfFile()
            diffHash = sha256Hex(diffData)
        }

        // Get commit info
        process.arguments = ["log", "-1", "--pretty=format:%an|%ae|%ct|%s", commitHash]
        let logPipe = Pipe()
        process.standardOutput = logPipe
        try process.run()
        process.waitUntilExit()

        let logData = logPipe.fileHandleForReading.readDataToEndOfFile()
        let logOutput = String(data: logData, encoding: .utf8) ?? ""
        let logParts = logOutput.split(separator: "|", maxSplits: 4)

        return GitState(
            commitHash: commitHash,
            branch: branch,
            isDirty: isDirty,
            diffHash: diffHash,
            authorName: !logParts.isEmpty ? String(logParts[0]) : nil,
            authorEmail: logParts.count > 1 ? String(logParts[1]) : nil,
            commitTimestamp: logParts.count > 2 ? Int(logParts[2]) : nil,
            message: logParts.count > 3 ? String(logParts[3]) : nil
        )
    }

    private func storeGitState(gitState: GitState) async throws -> String {
        let id = UUID().uuidString

        try await dbActor.execute("""
            INSERT OR REPLACE INTO git_states (
                id, commit_hash, branch, is_dirty, diff_hash,
                author_name, author_email, commit_timestamp, message
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, parameters: [
            DatabaseParameter.text(id),
            DatabaseParameter.text(gitState.commitHash),
            DatabaseParameter.text(gitState.branch),
            DatabaseParameter.int(gitState.isDirty ? 1 : 0),
            DatabaseParameter.text(gitState.diffHash ?? ""),
            DatabaseParameter.text(gitState.authorName ?? ""),
            DatabaseParameter.text(gitState.authorEmail ?? ""),
            DatabaseParameter.int(gitState.commitTimestamp ?? 0),
            DatabaseParameter.text(gitState.message ?? "")
        ])

        return id
    }

    // MARK: - Build Execution

    private func executeBuild(command: String, workingDirectory: String) async throws -> BuildOutputResult {
        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return BuildOutputResult(
            output: String(data: outputData, encoding: .utf8) ?? "",
            error: String(data: errorData, encoding: .utf8) ?? "",
            exitCode: Int(process.terminationStatus)
        )
    }

    private func storeBuildArtifact(sessionId: String, output: String, buildCommand: String) async throws -> String {
        let artifactDir = ".accessum-artifacts/build/\(sessionId)"
        try FileManager.default.createDirectory(atPath: artifactDir, withIntermediateDirectories: true)

        let artifactPath = "\(artifactDir)/build-output.log"
        try output.write(to: URL(fileURLWithPath: artifactPath), atomically: true, encoding: .utf8)

        // Store metadata
        let metadata = BuildArtifactMetadata(
            sessionId: sessionId,
            command: buildCommand,
            timestamp: Int(Date().timeIntervalSince1970)
        )

        let metadataPath = "\(artifactPath).json"
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: URL(fileURLWithPath: metadataPath))

        return artifactPath
    }

    // MARK: - Diagnostic Parsing

    private func parseBuildDiagnostics(output: String, error: String) async throws -> [BuildOutputDiagnostic] {
        var diagnostics: [BuildOutputDiagnostic] = []

        // Parse Swift compiler output
        diagnostics.append(contentsOf: parseSwiftDiagnostics(output: output))
        diagnostics.append(contentsOf: parseSwiftDiagnostics(output: error))

        // Parse linker errors
        diagnostics.append(contentsOf: parseLinkerDiagnostics(output: error))

        return diagnostics
    }

    private func parseSwiftDiagnostics(output: String) -> [BuildOutputDiagnostic] {
        var diagnostics: [BuildOutputDiagnostic] = []

        // Swift compiler diagnostic pattern: /path/to/file.swift:line:column: severity: message
        let swiftPattern = #"^(/[^:]+):(\d+):(\d+):\s*(warning|error|note|remark):\s*(.+)$"#

        let regex = try? NSRegularExpression(pattern: swiftPattern, options: [.anchorsMatchLines])

        let lines = output.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)
            guard let match = regex?.firstMatch(in: line, options: [], range: fullRange) else { continue }

            let filePath = match.range(at: 1).location != NSNotFound ? nsLine.substring(with: match.range(at: 1)) : ""
            let lineNumber = match.range(at: 2).location != NSNotFound ? Int(nsLine.substring(with: match.range(at: 2))) ?? 0 : 0
            let columnNumber = match.range(at: 3).location != NSNotFound ? Int(nsLine.substring(with: match.range(at: 3))) ?? 0 : 0
            let severity = match.range(at: 4).location != NSNotFound ? nsLine.substring(with: match.range(at: 4)) : ""
            let message = match.range(at: 5).location != NSNotFound ? nsLine.substring(with: match.range(at: 5)) : ""

            // Extract code context
            let codeSnippet = extractCodeContext(filePath: filePath, lineNumber: lineNumber)
            let functionName = extractFunctionName(message: message)
            let moduleName = extractModuleName(filePath: filePath)
            let fixitAvailable = detectFixItAvailability(lines: lines, index: index)

            diagnostics.append(BuildOutputDiagnostic(
                filePath: filePath,
                lineNumber: lineNumber,
                columnNumber: columnNumber,
                severity: severity,
                category: "compiler",
                tool: "swiftc",
                message: message,
                codeSnippet: codeSnippet,
                functionName: functionName,
                moduleName: moduleName,
                ruleId: extractRuleId(message: message),
                fixitAvailable: fixitAvailable
            ))
        }

        return diagnostics
    }

    private func parseLinkerDiagnostics(output: String) -> [BuildOutputDiagnostic] {
        var diagnostics: [BuildOutputDiagnostic] = []

        // Linker error patterns
        let linkerPatterns = [
            #"^ld:\s*(.+)"#,
            #"^Undefined symbols for architecture .+:"#,
            #"^Referenced from:"#
        ]
        let compiledPatterns = linkerPatterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }

        let lines = output.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..., in: line)
            let matchesPattern = compiledPatterns.contains { regex in
                regex.firstMatch(in: line, options: [], range: range) != nil
            }
            guard matchesPattern else { continue }

            diagnostics.append(BuildOutputDiagnostic(
                filePath: "", // Linker errors may not have specific file paths
                lineNumber: 0,
                columnNumber: 0,
                severity: "error",
                category: "linker",
                tool: "ld",
                message: line,
                codeSnippet: extractLinkerContext(lines: lines, currentIndex: index),
                functionName: nil,
                moduleName: nil,
                ruleId: nil,
                fixitAvailable: false
            ))
        }

        return diagnostics
    }

    private func extractCodeContext(filePath: String, lineNumber: Int) -> String? {
        guard FileManager.default.fileExists(atPath: filePath),
              lineNumber > 0 else { return nil }

        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            let startLine = max(0, lineNumber - 2)
            let endLine = min(lines.count - 1, lineNumber + 2)

            return lines[startLine...endLine].enumerated().map { offset, line in
                let lineNum = startLine + offset + 1
                let marker = lineNum == lineNumber ? ">>>" : "   "
                return "\(marker) \(lineNum): \(line)"
            }.joined(separator: "\n")
        } catch {
            return nil
        }
    }

    private func extractFunctionName(message: String) -> String? {
        // Extract function name from Swift diagnostic messages
        let functionPattern = #"in\s+(\w+)"#
        let nsMessage = message as NSString
        let fullRange = NSRange(location: 0, length: nsMessage.length)
        if let match = try? NSRegularExpression(pattern: functionPattern).firstMatch(in: message, options: [], range: fullRange),
           match.range(at: 1).location != NSNotFound {
            return nsMessage.substring(with: match.range(at: 1))
        }
        return nil
    }

    private func extractModuleName(filePath: String) -> String? {
        // Extract module name from Swift file path
        let url = URL(fileURLWithPath: filePath)
        let filename = url.deletingPathExtension().lastPathComponent

        // Common patterns: ModuleName.swift, Sources/ModuleName/file.swift
        if filename.contains("Sources") {
            let components = url.pathComponents
            if let sourcesIndex = components.firstIndex(of: "Sources"),
               sourcesIndex + 1 < components.count {
                return components[sourcesIndex + 1]
            }
        }

        return filename
    }

    private func extractRuleId(message: String) -> String? {
        // Extract compiler rule ID from messages like "warning: [rule-id] message"
        let rulePattern = #"\[([-\w]+)\]"#
        let nsMessage = message as NSString
        let fullRange = NSRange(location: 0, length: nsMessage.length)
        if let match = try? NSRegularExpression(pattern: rulePattern).firstMatch(in: message, options: [], range: fullRange),
           match.range(at: 1).location != NSNotFound {
            return nsMessage.substring(with: match.range(at: 1))
        }
        return nil
    }

    private func extractLinkerContext(lines: [String], currentIndex: Int) -> String? {
        let startLine = max(0, currentIndex - 2)
        let endLine = min(lines.count - 1, currentIndex + 2)
        return lines[startLine...endLine].joined(separator: "\n")
    }

    private func detectFixItAvailability(lines: [String], index: Int) -> Bool {
        guard index + 1 < lines.count else { return false }
        let lookahead = lines[(index + 1)..<min(lines.count, index + 4)]
        for line in lookahead {
            let lower = line.lowercased()
            if lower.contains("fix-it") || lower.contains("fixit") {
                return true
            }
        }
struct StoreDiagnosticsConfiguration: Sendable {
    let sessionId: String
    let gitStateId: String
    let target: String
    let configuration: String
    let buildCommand: String
    let workingDirectory: String
    let diagnostics: [BuildOutputDiagnostic]
    let startTime: Int
    let endTime: Int
    let exitCode: Int
    let outputPath: String
    
    init(
        sessionId: String,
        gitStateId: String,
        target: String,
        configuration: String,
        buildCommand: String,
        workingDirectory: String,
        diagnostics: [BuildOutputDiagnostic],
        startTime: Int,
        endTime: Int,
        exitCode: Int,
        outputPath: String
    ) {
        self.sessionId = sessionId
        self.gitStateId = gitStateId
        self.target = target
        self.configuration = configuration
        self.buildCommand = buildCommand
        self.workingDirectory = workingDirectory
        self.diagnostics = diagnostics
        self.startTime = startTime
        self.endTime = endTime
        self.exitCode = exitCode
        self.outputPath = outputPath
    }
}

// Function signature would change to:
func storeDiagnostics(config: StoreDiagnosticsConfiguration) async throws -> [String] {
    let toolchain = detectToolchain(buildCommand: config.buildCommand)
    let outputData = (try? Data(contentsOf: URL(fileURLWithPath: config.outputPath))) ?? Data()
    // ... rest of function implementation
}

        // Store build session
        try await dbActor.execute("""
            INSERT INTO build_sessions (
                id, git_state_id, target, configuration, toolchain,
                command_line, working_directory, start_timestamp, end_timestamp,
                exit_code, artifact_path, artifact_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, parameters: [
            DatabaseParameter.text(sessionId),
            DatabaseParameter.text(gitStateId),
            DatabaseParameter.text(target),
            DatabaseParameter.text(configuration),
            DatabaseParameter.text(toolchain),
            DatabaseParameter.text(buildCommand),
            DatabaseParameter.text(workingDirectory),
            DatabaseParameter.int(startTime),
            DatabaseParameter.int(endTime),
            DatabaseParameter.int(exitCode),
            DatabaseParameter.text(outputPath),
            DatabaseParameter.text(sha256Hex(outputData))
        ])

        // Store diagnostics
        var storedIds: [String] = []
        for diagnostic in diagnostics {
            let id = UUID().uuidString

            try await dbActor.execute("""
                INSERT INTO build_diagnostics (
                    id, build_session_id, file_path, line_number, column_number,
                    severity, category, tool, message, code_snippet,
                    function_name, module_name, rule_id, fixit_available
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                DatabaseParameter.text(id),
                DatabaseParameter.text(sessionId),
                DatabaseParameter.text(diagnostic.filePath),
                DatabaseParameter.int(diagnostic.lineNumber),
                DatabaseParameter.int(diagnostic.columnNumber),
                DatabaseParameter.text(diagnostic.severity),
                DatabaseParameter.text(diagnostic.category),
                DatabaseParameter.text(diagnostic.tool),
                DatabaseParameter.text(diagnostic.message),
                DatabaseParameter.text(diagnostic.codeSnippet ?? ""),
                DatabaseParameter.text(diagnostic.functionName ?? ""),
                DatabaseParameter.text(diagnostic.moduleName ?? ""),
                DatabaseParameter.text(diagnostic.ruleId ?? ""),
                DatabaseParameter.int(diagnostic.fixitAvailable ? 1 : 0)
            ])

            storedIds.append(id)
        }

        return storedIds
    }

    private func storeBuildArtifacts(
        sessionId: String,
        target: String,
        configuration: String,
        buildOutput: String
    ) async throws -> [String] {
        var artifacts: [String] = []

        // Look for common build artifacts in .build directory
        let buildDir = ".build"
        guard FileManager.default.fileExists(atPath: buildDir) else { return artifacts }

        // Search for binaries, libraries, etc.
        let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: buildDir), includingPropertiesForKeys: [.fileSizeKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else { continue }

            // Determine artifact type
            let artifactType = determineArtifactType(fileURL: fileURL)

            do {
                let fileData = try Data(contentsOf: fileURL)
                let id = UUID().uuidString

                try await dbActor.execute("""
                    INSERT INTO build_artifacts (
                        id, build_session_id, artifact_type, file_path, file_size, file_hash, target, configuration
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, parameters: [
                    DatabaseParameter.text(id),
                    DatabaseParameter.text(sessionId),
                    DatabaseParameter.text(artifactType),
                    DatabaseParameter.text(fileURL.path),
                    DatabaseParameter.int(fileData.count),
                    DatabaseParameter.text(sha256Hex(fileData)),
                    DatabaseParameter.text(target),
                    DatabaseParameter.text(configuration)
                ])

                artifacts.append(id)
            } catch {
                // Skip files that can't be read
                continue
            }
        }

        return artifacts
    }

    // MARK: - Utility Methods

    private func detectToolchain(buildCommand: String) -> String {
        if buildCommand.contains("swift") {
            return "swift-\(detectSwiftVersion())"
        } else if buildCommand.contains("xcodebuild") {
            return "xcode-\(detectXcodeVersion())"
        } else if buildCommand.contains("cmake") {
            return "cmake"
        } else {
            return "unknown"
        }
    }

    private func detectSwiftVersion() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Extract version from "Swift version X.Y.Z"
        if let match = output.range(of: #"Swift version (\d+\.\d+\.\d+)"#, options: .regularExpression) {
            return String(output[match].dropFirst(14))
        }

        return "unknown"
    }

    private func detectXcodeVersion() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = ["-version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Extract version from "Xcode X.Y.Z"
        if let match = output.range(of: #"Xcode (\d+\.\d+)"#, options: .regularExpression) {
            return String(output[match].dropFirst(6))
        }

        return "unknown"
    }

    private func determineArtifactType(fileURL: URL) -> String {
        let path = fileURL.path.lowercased()

        if path.hasSuffix(".a") {
            return "static_library"
        } else if path.hasSuffix(".dylib") || path.hasSuffix(".so") {
            return "dynamic_library"
        } else if path.hasSuffix(".exe") || path.contains("debug/") || path.contains("release/") {
            return "binary"
        } else if path.hasSuffix(".o") || path.hasSuffix(".obj") {
            return "object_file"
        } else if path.hasSuffix(".framework") {
            return "framework"
        } else if path.hasSuffix(".bundle") {
            return "bundle"
        } else {
            return "other"
        }
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Data Models

public struct BuildIngestionResult {
    public let sessionId: String
    public let gitStateId: String
    public let diagnosticsStored: Int
    public let artifactsStored: Int
    public let exitCode: Int
    public let buildDuration: Int
}

private struct GitState {
    let commitHash: String
    let branch: String
    let isDirty: Bool
    let diffHash: String?
    let authorName: String?
    let authorEmail: String?
    let commitTimestamp: Int?
    let message: String?
}

private struct BuildOutputResult {
    let output: String
    let error: String
    let exitCode: Int
}

private struct BuildOutputDiagnostic {
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

private struct BuildArtifactMetadata: Codable {
    let sessionId: String
    let command: String
    let timestamp: Int

    var schemaVersion: Int { 1 }
    var artifactType: String { "build_output" }
}
