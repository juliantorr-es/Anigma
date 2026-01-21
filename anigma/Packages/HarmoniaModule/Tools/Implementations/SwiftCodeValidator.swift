//
//  SwiftCodeValidator.swift
//  HarmoniaModule
//
//  Pre-flight validation for Swift code patches.
//  Checks for strict concurrency, Sendable conformance, data races, best practices, and more.
//

import Foundation
import AnigmaPrimitives

/// Result of Swift code validation
public struct SwiftValidationResult: Sendable, Codable {
    /// Whether validation passed (no blocking issues)
    public let isValid: Bool

    /// Compilation succeeded
    public let compilationSucceeded: Bool

    /// Issues found during validation
    public let issues: [SwiftValidationIssue]

    /// Suggestions for fixing issues
    public let suggestions: [SwiftFixSuggestion]

    /// Build output (stdout/stderr)
    public let buildOutput: String

    public init(
        isValid: Bool,
        compilationSucceeded: Bool,
        issues: [SwiftValidationIssue],
        suggestions: [SwiftFixSuggestion],
        buildOutput: String
    ) {
        self.isValid = isValid
        self.compilationSucceeded = compilationSucceeded
        self.issues = issues
        self.suggestions = suggestions
        self.buildOutput = buildOutput
    }
}

/// A validation issue found in Swift code
public struct SwiftValidationIssue: Sendable, Codable {
    public enum IssueType: String, Sendable, Codable {
        case strictConcurrency = "strict_concurrency"
        case sendableConformance = "sendable_conformance"
        case dataRace = "data_race"
        case actorIsolation = "actor_isolation"
        case compilationError = "compilation_error"
        case compilationWarning = "compilation_warning"
        case styleViolation = "style_violation"
        case bestPractice = "best_practice"
        case performanceWarning = "performance_warning"
    }

    public enum Severity: String, Sendable, Codable {
        case error = "error"
        case warning = "warning"
        case note = "note"
    }

    /// Type of issue
    public let type: IssueType

    /// Severity level
    public let severity: Severity

    /// File path where issue occurs
    public let filePath: String

    /// Line number
    public let line: Int?

    /// Column number
    public let column: Int?

    /// Issue description
    public let message: String

    /// Raw compiler/linter output
    public let rawOutput: String?

    /// Code snippet showing the issue
    public let codeSnippet: String?

    public init(
        type: IssueType,
        severity: Severity,
        filePath: String,
        line: Int? = nil,
        column: Int? = nil,
        message: String,
        rawOutput: String? = nil,
        codeSnippet: String? = nil
    ) {
        self.type = type
        self.severity = severity
        self.filePath = filePath
        self.line = line
        self.column = column
        self.message = message
        self.rawOutput = rawOutput
        self.codeSnippet = codeSnippet
    }
}

/// A suggestion for fixing a validation issue
public struct SwiftFixSuggestion: Sendable, Codable {
    /// The issue this suggestion addresses
    public let issueType: SwiftValidationIssue.IssueType

    /// File to fix
    public let filePath: String

    /// Line number
    public let line: Int?

    /// Description of the fix
    public let description: String

    /// Example fix (if available)
    public let exampleFix: String?

    /// Automatic fix available
    public let automaticFixAvailable: Bool

    public init(
        issueType: SwiftValidationIssue.IssueType,
        filePath: String,
        line: Int? = nil,
        description: String,
        exampleFix: String? = nil,
        automaticFixAvailable: Bool = false
    ) {
        self.issueType = issueType
        self.filePath = filePath
        self.line = line
        self.description = description
        self.exampleFix = exampleFix
        self.automaticFixAvailable = automaticFixAvailable
    }
}

/// Validates Swift code for concurrency, Sendable, and best practices
public struct SwiftCodeValidator: Sendable {
    private let workingDirectory: String

    public init(workingDirectory: String = FileManager.default.currentDirectoryPath) {
        self.workingDirectory = workingDirectory
    }

    /// Validate Swift files after a patch is applied
    public func validate(affectedFiles: [String]) async throws -> SwiftValidationResult {
        var allIssues: [SwiftValidationIssue] = []
        var allSuggestions: [SwiftFixSuggestion] = []
        var buildOutput = ""

        // Step 1: Run Swift compiler with strict concurrency
        let (compileIssues, compileSuggestions, compileOutput, compileSucceeded) = try await runSwiftCompiler(files: affectedFiles)
        allIssues.append(contentsOf: compileIssues)
        allSuggestions.append(contentsOf: compileSuggestions)
        buildOutput += compileOutput

        // Step 2: Run SwiftLint if available
        let (lintIssues, lintSuggestions, lintOutput) = await runSwiftLint(files: affectedFiles)
        allIssues.append(contentsOf: lintIssues)
        allSuggestions.append(contentsOf: lintSuggestions)
        buildOutput += "\n" + lintOutput

        // Step 3: Analyze for specific patterns
        let patternIssues = await analyzeCodePatterns(files: affectedFiles)
        allIssues.append(contentsOf: patternIssues)

        // Determine if validation passed
        let blockingIssues = allIssues.filter { $0.severity == .error }
        let isValid = blockingIssues.isEmpty && compileSucceeded

        return SwiftValidationResult(
            isValid: isValid,
            compilationSucceeded: compileSucceeded,
            issues: allIssues,
            suggestions: allSuggestions,
            buildOutput: buildOutput
        )
    }

    // MARK: - Swift Compiler

    private func runSwiftCompiler(files: [String]) async throws -> (
        issues: [SwiftValidationIssue],
        suggestions: [SwiftFixSuggestion],
        output: String,
        succeeded: Bool
    ) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        // Run swift build with strict concurrency checking
        process.arguments = [
            "build",
            "-Xswiftc", "-strict-concurrency=complete",
            "-Xswiftc", "-enable-actor-data-race-checks",
            "-Xswiftc", "-warn-concurrency",
            "-Xswiftc", "-enable-upcoming-feature", "-Xswiftc", "StrictConcurrency"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        let fullOutput = output + "\n" + errorOutput

        let succeeded = process.terminationStatus == 0

        // Parse compiler output for issues
        let (issues, suggestions) = parseCompilerOutput(fullOutput, affectedFiles: files)

        return (issues, suggestions, fullOutput, succeeded)
    }

    private func parseCompilerOutput(
        _ output: String,
        affectedFiles: [String]
    ) -> (issues: [SwiftValidationIssue], suggestions: [SwiftFixSuggestion]) {
        var issues: [SwiftValidationIssue] = []
        var suggestions: [SwiftFixSuggestion] = []

        // Parse Swift compiler diagnostic format:
        // /path/to/file.swift:123:45: error: message
        // /path/to/file.swift:123:45: warning: message

        let lines = output.split(separator: "\n").map(String.init)
        let affectedSet = Set(affectedFiles.map { normalizePath($0) })

        for line in lines {
            guard let diagnostic = parseDiagnosticLine(line) else { continue }

            // Only report issues in affected files
            let normalizedFile = normalizePath(diagnostic.filePath)
            guard affectedSet.contains(normalizedFile) else { continue }

            // Determine issue type based on message content
            let issueType = classifyIssue(message: diagnostic.message)

            let issue = SwiftValidationIssue(
                type: issueType,
                severity: diagnostic.severity,
                filePath: diagnostic.filePath,
                line: diagnostic.line,
                column: diagnostic.column,
                message: diagnostic.message,
                rawOutput: line
            )
            issues.append(issue)

            // Generate suggestions for common issues
            if let suggestion = generateSuggestion(for: diagnostic, issueType: issueType) {
                suggestions.append(suggestion)
            }
        }

        return (issues, suggestions)
    }

    private struct DiagnosticLine {
        let filePath: String
        let line: Int?
        let column: Int?
        let severity: SwiftValidationIssue.Severity
        let message: String
    }

    private func parseDiagnosticLine(_ line: String) -> DiagnosticLine? {
        // Pattern: /path/to/file.swift:123:45: error: message
        let pattern = #"^(.+?):(\d+):(\d+):\s+(error|warning|note):\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsLine = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else {
            return nil
        }

        let filePath = nsLine.substring(with: match.range(at: 1))
        let lineNum = Int(nsLine.substring(with: match.range(at: 2)))
        let colNum = Int(nsLine.substring(with: match.range(at: 3)))
        let severityStr = nsLine.substring(with: match.range(at: 4))
        let message = nsLine.substring(with: match.range(at: 5))

        let severity: SwiftValidationIssue.Severity
        switch severityStr {
        case "error": severity = .error
        case "warning": severity = .warning
        case "note": severity = .note
        default: return nil
        }

        return DiagnosticLine(
            filePath: filePath,
            line: lineNum,
            column: colNum,
            severity: severity,
            message: message
        )
    }

    private func classifyIssue(message: String) -> SwiftValidationIssue.IssueType {
        let lower = message.lowercased()

        if lower.contains("sendable") {
            return .sendableConformance
        } else if lower.contains("actor") || lower.contains("isolated") {
            return .actorIsolation
        } else if lower.contains("data race") || lower.contains("concurrent") {
            return .dataRace
        } else if lower.contains("concurrency") {
            return .strictConcurrency
        } else {
            return .compilationError
        }
    }

    private func generateSuggestion(
        for diagnostic: DiagnosticLine,
        issueType: SwiftValidationIssue.IssueType
    ) -> SwiftFixSuggestion? {
        let message = diagnostic.message

        // Sendable conformance suggestions
        if issueType == .sendableConformance {
            if message.contains("does not conform to the 'Sendable' protocol") {
                return SwiftFixSuggestion(
                    issueType: .sendableConformance,
                    filePath: diagnostic.filePath,
                    line: diagnostic.line,
                    description: "Add Sendable conformance to the type declaration",
                    exampleFix: """
                    // Change:
                    struct MyType { ... }

                    // To:
                    struct MyType: Sendable { ... }

                    // Or for classes with mutable state, use an actor:
                    actor MyType { ... }
                    """,
                    automaticFixAvailable: true
                )
            }
        }

        // Actor isolation suggestions
        if issueType == .actorIsolation {
            if message.contains("actor-isolated") {
                return SwiftFixSuggestion(
                    issueType: .actorIsolation,
                    filePath: diagnostic.filePath,
                    line: diagnostic.line,
                    description: "Access actor-isolated property asynchronously or mark caller as nonisolated",
                    exampleFix: """
                    // Option 1: Use await
                    let value = await myActor.property

                    // Option 2: Mark as nonisolated if safe
                    nonisolated func myMethod() { ... }
                    """,
                    automaticFixAvailable: false
                )
            }
        }

        // Data race suggestions
        if issueType == .dataRace {
            return SwiftFixSuggestion(
                issueType: .dataRace,
                filePath: diagnostic.filePath,
                line: diagnostic.line,
                description: "Protect shared mutable state with an actor or use value types",
                exampleFix: """
                // Option 1: Use an actor for shared state
                actor Counter {
                    private var value = 0
                    func increment() { value += 1 }
                }

                // Option 2: Use value types (struct) instead of reference types
                struct ImmutableData { let value: Int }
                """,
                automaticFixAvailable: false
            )
        }

        return nil
    }

    // MARK: - SwiftLint

    private func runSwiftLint(files: [String]) async -> (
        issues: [SwiftValidationIssue],
        suggestions: [SwiftFixSuggestion],
        output: String
    ) {
        // Check if swiftlint is available
        guard await isToolAvailable("swiftlint") else {
            return ([], [], "SwiftLint not available")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.arguments = ["swiftlint", "lint", "--quiet"] + files

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            let issues = parseSwiftLintOutput(output)
            return (issues, [], output)
        } catch {
            return ([], [], "SwiftLint execution failed: \(error)")
        }
    }

    private func parseSwiftLintOutput(_ output: String) -> [SwiftValidationIssue] {
        var issues: [SwiftValidationIssue] = []

        // SwiftLint format: /path/to/file.swift:123:45: warning: message (rule_id)
        let lines = output.split(separator: "\n").map(String.init)

        for line in lines {
            if let diagnostic = parseDiagnosticLine(line) {
                let issue = SwiftValidationIssue(
                    type: .styleViolation,
                    severity: diagnostic.severity,
                    filePath: diagnostic.filePath,
                    line: diagnostic.line,
                    column: diagnostic.column,
                    message: diagnostic.message,
                    rawOutput: line
                )
                issues.append(issue)
            }
        }

        return issues
    }

    // MARK: - Pattern Analysis

    private func analyzeCodePatterns(files: [String]) async -> [SwiftValidationIssue] {
        var issues: [SwiftValidationIssue] = []

        for file in files {
            let fullPath = URL(fileURLWithPath: file, relativeTo: URL(fileURLWithPath: workingDirectory)).path

            guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
                continue
            }

            // Check for common anti-patterns
            let lines = content.split(separator: "\n").map(String.init)

            for (index, line) in lines.enumerated() {
                let lineNumber = index + 1

                // Check for @unchecked Sendable without justification
                if line.contains("@unchecked Sendable") && !line.contains("//") {
                    issues.append(SwiftValidationIssue(
                        type: .bestPractice,
                        severity: .warning,
                        filePath: file,
                        line: lineNumber,
                        message: "@unchecked Sendable should include a comment explaining why it's safe",
                        codeSnippet: line.trimmingCharacters(in: .whitespaces)
                    ))
                }

                // Check for DispatchQueue usage (prefer actors)
                if line.contains("DispatchQueue") {
                    issues.append(SwiftValidationIssue(
                        type: .bestPractice,
                        severity: .note,
                        filePath: file,
                        line: lineNumber,
                        message: "Consider using actors instead of DispatchQueue for better Swift 6 compatibility",
                        codeSnippet: line.trimmingCharacters(in: .whitespaces)
                    ))
                }

                // Check for force unwrapping in production code
                if line.contains("!") && !line.contains("//") && !line.contains("guard") {
                    let hasForceUnwrap = line.range(of: #"\w+!"#, options: .regularExpression) != nil
                    if hasForceUnwrap {
                        issues.append(SwiftValidationIssue(
                            type: .bestPractice,
                            severity: .note,
                            filePath: file,
                            line: lineNumber,
                            message: "Force unwrapping should be avoided; use optional binding or guard statements",
                            codeSnippet: line.trimmingCharacters(in: .whitespaces)
                        ))
                    }
                }
            }
        }

        return issues
    }

    // MARK: - Utilities

    private func isToolAvailable(_ tool: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [tool]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func normalizePath(_ path: String) -> String {
        // Remove leading ./ or a/b/ prefixes from git-style paths
        var normalized = path
        if normalized.hasPrefix("./") {
            normalized = String(normalized.dropFirst(2))
        }
        if normalized.hasPrefix("a/") || normalized.hasPrefix("b/") {
            normalized = String(normalized.dropFirst(2))
        }
        return normalized
    }
}
