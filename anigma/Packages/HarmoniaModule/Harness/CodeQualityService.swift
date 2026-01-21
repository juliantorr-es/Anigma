//
//  CodeQualityService.swift
//  HarmoniaModule
//
//  Service for running code quality tools (formatter, linter).
//

import Foundation

// MARK: - Formatter Results

/// Results from running a code formatter.
public struct FormatterResults: Codable, Sendable {
    /// Whether formatting succeeded.
    public let succeeded: Bool

    /// Number of warnings.
    public let warnings: Int

    /// Number of errors.
    public let errors: Int

    /// Files formatted.
    public let filesFormatted: Int

    /// Files unchanged.
    public let filesUnchanged: Int

    public init(
        succeeded: Bool,
        warnings: Int = 0,
        errors: Int = 0,
        filesFormatted: Int = 0,
        filesUnchanged: Int = 0
    ) {
        self.succeeded = succeeded
        self.warnings = warnings
        self.errors = errors
        self.filesFormatted = filesFormatted
        self.filesUnchanged = filesUnchanged
    }
}

// MARK: - Linter Results

/// Results from running a linter.
public struct LinterResults: Codable, Sendable {
    /// Whether linting succeeded.
    public let succeeded: Bool

    /// Number of warnings.
    public let warnings: Int

    /// Number of errors.
    public let errors: Int

    /// Files linted.
    public let filesLinted: Int

    /// Issues by category.
    public let issuesByCategory: [String: Int]

    public init(
        succeeded: Bool,
        warnings: Int = 0,
        errors: Int = 0,
        filesLinted: Int = 0,
        issuesByCategory: [String: Int] = [:]
    ) {
        self.succeeded = succeeded
        self.warnings = warnings
        self.errors = errors
        self.filesLinted = filesLinted
        self.issuesByCategory = issuesByCategory
    }
}

// MARK: - Code Quality Service

/// Service for running code quality tools.
public actor CodeQualityService {
    /// Shared instance.
    public static let shared = CodeQualityService()

    private init() {}

    /// Runs code formatter on project.
    public func runFormatter(projectDirectory: String) async throws -> FormatterResults {
        // Check for common formatters
        let formatters = ["swiftformat", "swift-format"]

        for formatter in formatters {
            if await isToolAvailable(formatter) {
                return try await runSwiftFormatter(formatter, at: projectDirectory)
            }
        }

        // No formatter found
        return FormatterResults(
            succeeded: true, // Not a failure, just no formatter
            warnings: 0,
            errors: 0,
            filesFormatted: 0,
            filesUnchanged: 0
        )
    }

    /// Runs linter on project.
    public func runLinter(projectDirectory: String) async throws -> LinterResults {
        // Check for common linters
        let linters = ["swiftlint"]

        for linter in linters {
            if await isToolAvailable(linter) {
                return try await runSwiftLinter(linter, at: projectDirectory)
            }
        }

        // No linter found
        return LinterResults(
            succeeded: true, // Not a failure, just no linter
            warnings: 0,
            errors: 0,
            filesLinted: 0,
            issuesByCategory: [:]
        )
    }

    /// Checks if a tool is available.
    private func isToolAvailable(_ tool: String) async -> Bool {
        return await resolveToolPath(tool) != nil
    }

    /// Resolves a tool path using `which`.
    private func resolveToolPath(_ tool: String) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [tool]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }

    /// Runs Swift formatter.
    private func runSwiftFormatter(_ formatter: String, at path: String) async throws -> FormatterResults {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [formatter]
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Try to run formatter
        var arguments = ["."]

        // Add common arguments
        if formatter == "swiftformat" {
            arguments = ["--quiet", "."]
        } else if formatter == "swift-format" {
            arguments = ["format", "."]
        }

        let formatterProcess = Process()
        formatterProcess.executableURL = URL(fileURLWithPath: "/usr/local/bin/\(formatter)")
        formatterProcess.arguments = arguments
        formatterProcess.currentDirectoryURL = URL(fileURLWithPath: path)

        let formatterOutputPipe = Pipe()
        let formatterErrorPipe = Pipe()
        formatterProcess.standardOutput = formatterOutputPipe
        formatterProcess.standardError = formatterErrorPipe

        do {
            try formatterProcess.run()
            formatterProcess.waitUntilExit()

            let exitCode = formatterProcess.terminationStatus

            // Parse output to count files
            let outputData = formatterOutputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            let errorData = formatterErrorPipe.fileHandleForReading.readDataToEndOfFile()
            _ = String(data: errorData, encoding: .utf8) ?? ""

            // Simple parsing for common formatters
            var filesFormatted = 0
            var filesUnchanged = 0

            if formatter == "swiftformat" {
                // swiftformat output: "Formatted: X files, Y unchanged"
                let lines = output.split(separator: "\n")
                for line in lines {
                    if line.contains("Formatted:") {
                        let parts = line.split(separator: " ")
                        if let formattedStr = parts.first(where: { $0.allSatisfy { $0.isNumber } }) {
                            filesFormatted = Int(formattedStr) ?? 0
                        }
                    }
                    if line.contains("unchanged") {
                        let parts = line.split(separator: " ")
                        if let unchangedStr = parts.first(where: { $0.allSatisfy { $0.isNumber } }) {
                            filesUnchanged = Int(unchangedStr) ?? 0
                        }
                    }
                }
            }

            return FormatterResults(
                succeeded: exitCode == 0,
                warnings: 0, // Would need to parse warnings
                errors: exitCode == 0 ? 0 : 1,
                filesFormatted: filesFormatted,
                filesUnchanged: filesUnchanged
            )

        } catch {
            // Formatter failed to run
            return FormatterResults(
                succeeded: false,
                warnings: 0,
                errors: 1,
                filesFormatted: 0,
                filesUnchanged: 0
            )
        }
    }

    /// Runs Swift linter.
    private func runSwiftLinter(_ linter: String, at path: String) async throws -> LinterResults {
        guard let linterPath = await resolveToolPath(linter) else {
            return LinterResults(
                succeeded: true,
                warnings: 0,
                errors: 0,
                filesLinted: 0,
                issuesByCategory: [:]
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: linterPath)
        process.arguments = ["lint", "--quiet", "--path", path]
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let exitCode = process.terminationStatus
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errors = String(data: errorData, encoding: .utf8) ?? ""

        let combined = (output + "\n" + errors).split(separator: "\n")
        var warningCount = 0
        var errorCount = 0
        var issuesByCategory: [String: Int] = [:]

        for line in combined {
            let lower = line.lowercased()
            if lower.contains("warning:") {
                warningCount += 1
            } else if lower.contains("error:") {
                errorCount += 1
            }
            if let rule = line.split(separator: "(").last?.split(separator: ")").first {
                let key = String(rule)
                if !key.isEmpty {
                    issuesByCategory[key, default: 0] += 1
                }
            }
        }

        return LinterResults(
            succeeded: exitCode == 0,
            warnings: warningCount,
            errors: errorCount,
            filesLinted: 0,
            issuesByCategory: issuesByCategory
        )
    }
}

// MARK: - Integration with Behavioral Health Metrics

extension BehavioralHealthMetrics {
    /// Creates metrics with code quality data.
    public static func withCodeQuality(
        baseMetrics: BehavioralHealthMetrics,
        formatterResults: FormatterResults? = nil,
        linterResults: LinterResults? = nil
    ) -> BehavioralHealthMetrics {
        var metrics = baseMetrics

        if let formatter = formatterResults {
            metrics.formatterSucceeded = formatter.succeeded
            metrics.formatterWarnings = formatter.warnings
            metrics.formatterErrors = formatter.errors
        }

        if let linter = linterResults {
            metrics.lintSucceeded = linter.succeeded
            metrics.lintWarnings = linter.warnings
            metrics.lintErrors = linter.errors
        }

        return metrics
    }
}
