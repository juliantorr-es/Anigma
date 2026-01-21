//
//  Swift6DiagnosticScout.swift
//  HarmoniaModule
//
//  Real implementation of a Swift 6 diagnostic scout that runs swift build -Xswiftc -warn-swift6.
//

import Foundation

/// Real implementation of a Swift 6 diagnostic scout.
public struct Swift6DiagnosticScout: ProjectScout {
    /// The project root directory.
    private let projectRoot: String

    /// Creates a new Swift 6 diagnostic scout.
    /// - Parameter projectRoot: The project root directory.
    public init(projectRoot: String) {
        self.projectRoot = projectRoot
    }

    /// Scans a project for Swift 6 compatibility issues.
    /// - Parameter projectId: The project identifier.
    /// - Returns: Array of scout findings.
    public func scan(projectId: UUID) async throws -> [ScoutFinding] {
        // Run swift build with Swift 6 warnings enabled
        let diagnostics = try await runSwiftBuildWarnSwift6()

        // Parse diagnostics and convert to scout findings
        let findings = parseDiagnostics(diagnostics, projectId: projectId)

        return findings
    }

    /// Runs swift build with Swift 6 warnings enabled.
    /// - Returns: Diagnostic output from stderr.
    private func runSwiftBuildWarnSwift6() async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "build", "-Xswiftc", "-strict-concurrency=complete"]
        process.currentDirectoryURL = URL(fileURLWithPath: projectRoot)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            // We want stderr (diagnostics) not stdout
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            // Also capture stdout for debugging
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let standardOutput = String(data: outputData, encoding: .utf8) ?? ""

            // Combine both outputs for diagnostics
            let combinedOutput = standardOutput + errorOutput

            // If the build fails completely, we might still get useful diagnostics
            // Return whatever we got
            return combinedOutput
        } catch {
            throw NSError(domain: "Swift6DiagnosticScout", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to run swift build: \(error)"])
        }
    }

    /// Parses diagnostic output from swift build.
    /// - Parameters:
    ///   - diagnostics: Raw diagnostic output.
    ///   - projectId: The project identifier.
    /// - Returns: Array of scout findings.
    func parseDiagnostics(_ diagnostics: String, projectId: UUID) -> [ScoutFinding] {
        var findings: [ScoutFinding] = []

        // Split by lines and process each diagnostic line
        let lines = diagnostics.components(separatedBy: .newlines)

        for line in lines {
            // Skip empty lines
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            // Try to parse diagnostic line format: /path/to/file.swift:12:34: warning: message
            if let finding = parseDiagnosticLine(line, projectId: projectId) {
                findings.append(finding)
            }
        }

        return findings
    }

    /// Parses a single diagnostic line.
    /// - Parameters:
    ///   - line: The diagnostic line.
    ///   - projectId: The project identifier.
    /// - Returns: A scout finding if the line matches the expected format.
    func parseDiagnosticLine(_ line: String, projectId: UUID) -> ScoutFinding? {
        // Pattern: /path/to/file.swift:line:column: (warning|error|note): message
        let pattern = #"^([^:]+):(\d+):(\d+):\s*(warning|error|note):\s*(.+)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else {
            return nil
        }

        // Extract components
        guard let filePathRange = Range(match.range(at: 1), in: line),
              let lineNumberRange = Range(match.range(at: 2), in: line),
              let _ = Range(match.range(at: 3), in: line), // column (unused)
              let severityRange = Range(match.range(at: 4), in: line),
              let messageRange = Range(match.range(at: 5), in: line) else {
            return nil
        }

        let filePath = String(line[filePathRange])
        let lineNumber = Int(line[lineNumberRange]) ?? 1
        let severityString = String(line[severityRange])
        let message = String(line[messageRange])

        // Map severity string to ScoutFindingSeverity
        let severity: ScoutFindingSeverity
        switch severityString.lowercased() {
        case "error":
            severity = .error
        case "warning":
            severity = .warning
        case "note":
            severity = .info
        default:
            severity = .info
        }

        // Determine problem kind based on message content
        let problemKind = determineProblemKind(from: message)

        // Generate suggested fix based on problem kind
        let suggestedFix = generateSuggestedFix(for: problemKind, message: message)

        return ScoutFinding(
            projectId: projectId,
            filePath: filePath,
            problemKind: problemKind,
            severity: severity,
            description: message,
            suggestedFix: suggestedFix,
            lineStart: lineNumber,
            lineEnd: lineNumber
        )
    }

    /// Determines the problem kind from the diagnostic message.
    /// - Parameter message: The diagnostic message.
    /// - Returns: A problem kind string.
    func determineProblemKind(from message: String) -> String {
        let lowercasedMessage = message.lowercased()

        if lowercasedMessage.contains("sendable") || lowercasedMessage.contains("concurrency") {
            return "swift6-concurrency"
        } else if lowercasedMessage.contains("actor") || lowercasedMessage.contains("isolated") {
            return "swift6-actor-isolation"
        } else if lowercasedMessage.contains("mainactor") || lowercasedMessage.contains("@mainactor") {
            return "swift6-mainactor"
        } else if lowercasedMessage.contains("data race") || lowercasedMessage.contains("race condition") {
            return "swift6-data-race"
        } else if lowercasedMessage.contains("deprecated") || lowercasedMessage.contains("obsolete") {
            return "swift6-deprecation"
        } else {
            return "swift6-general"
        }
    }

    /// Generates a suggested fix based on problem kind and message.
    /// - Parameters:
    ///   - problemKind: The problem kind.
    ///   - message: The diagnostic message.
    /// - Returns: A suggested fix string.
    func generateSuggestedFix(for problemKind: String, message: String) -> String {
        switch problemKind {
        case "swift6-concurrency":
            if message.lowercased().contains("sendable") {
                return "Add Sendable conformance to type or use @unchecked Sendable for non-Sendable types"
            } else {
                return "Review concurrency usage and ensure proper actor isolation"
            }
        case "swift6-actor-isolation":
            return "Mark calling context as 'await' or move code to appropriate actor"
        case "swift6-mainactor":
            return "Add @MainActor annotation to UI-updating methods or use MainActor.run"
        case "swift6-data-race":
            return "Use actor isolation, @Sendable closures, or proper synchronization"
        case "swift6-deprecation":
            return "Update to recommended Swift 6 API or alternative approach"
        default:
            return "Review code for Swift 6 compatibility and update as needed"
        }
    }
}

// MARK: - Factory

extension Swift6DiagnosticScout {
    /// Creates a Swift 6 diagnostic scout for the self-host project.
    public static func selfHostScout() -> Swift6DiagnosticScout {
        // Use the current directory as project root
        let currentDirectory = FileManager.default.currentDirectoryPath
        return Swift6DiagnosticScout(projectRoot: currentDirectory)
    }
}
