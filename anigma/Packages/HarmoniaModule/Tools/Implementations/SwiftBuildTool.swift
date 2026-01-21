//
//  SwiftBuildTool.swift
//  HarmoniaModule
//
//  Enhanced swift_build tool with file-level caching, error tracking, and performance monitoring.
//  Integrates BuildExecutor, SwiftBuildCache, and diagnostic analysis for production-grade builds.
//

import AnigmaPrimitives
import DatabaseCore
import Foundation

// Import Build components
// Note: These are internal to HarmoniaModule, so we use relative paths
// The actual imports depend on the build system structure

/// Represents the result of a build with rich metadata
public struct EnhancedBuildResult: Sendable, Codable {
    /// Exit code from the build
    public let exitCode: Int32

    /// Total build duration
    public let duration: TimeInterval

    /// Build session ID for traceability
    public let sessionId: String

    /// Whether this was a cache hit
    public let cacheHit: Bool

    /// Number of files from cache
    public let cachedFiles: Int

    /// Number of files rebuilt
    public let rebuiltFiles: Int

    /// Diagnostic summary
    public let diagnostics: DiagnosticSummary

    /// Build output (stdout + stderr)
    public let output: String

    public init(
        exitCode: Int32,
        duration: TimeInterval,
        sessionId: String,
        cacheHit: Bool,
        cachedFiles: Int,
        rebuiltFiles: Int,
        diagnostics: DiagnosticSummary,
        output: String
    ) {
        self.exitCode = exitCode
        self.duration = duration
        self.sessionId = sessionId
        self.cacheHit = cacheHit
        self.cachedFiles = cachedFiles
        self.rebuiltFiles = rebuiltFiles
        self.diagnostics = diagnostics
        self.output = output
    }
}

/// Diagnostic summary for a build
public struct DiagnosticSummary: Sendable, Codable {
    /// Total errors
    public let errors: Int

    /// Total warnings
    public let warnings: Int

    /// Total notes
    public let notes: Int

    /// Affected files
    public let affectedFiles: [String]

    /// Error details (limited to top 10)
    public let topErrors: [DiagnosticDetail]

    public init(
        errors: Int,
        warnings: Int,
        notes: Int,
        affectedFiles: [String],
        topErrors: [DiagnosticDetail] = []
    ) {
        self.errors = errors
        self.warnings = warnings
        self.notes = notes
        self.affectedFiles = affectedFiles
        self.topErrors = Array(topErrors.prefix(10))
    }
}

/// Individual diagnostic detail
public struct DiagnosticDetail: Sendable, Codable {
    public let file: String
    public let line: Int
    public let column: Int
    public let severity: String
    public let message: String

    public init(file: String, line: Int, column: Int, severity: String, message: String) {
        self.file = file
        self.line = line
        self.column = column
        self.severity = severity
        self.message = message
    }
}

/// Enhanced SwiftBuildTool with caching, diagnostics, and performance tracking
public actor SwiftBuildTool {
    private let buildExecutor: BuildExecutor
    private let sessionManager: BuildSessionManager
    private let buildCache: SwiftBuildCache
    private let diagnosticAnalyzer: DiagnosticAnalyzer
    private let timingAnalyzer: BuildTimingAnalyzer
    private let workingDirectory: URL
    private let progressCallback: ToolProgressCallback?

    public init(
        buildExecutor: BuildExecutor? = nil,
        sessionManager: BuildSessionManager? = nil,
        buildCache: SwiftBuildCache? = nil,
        diagnosticAnalyzer: DiagnosticAnalyzer? = nil,
        timingAnalyzer: BuildTimingAnalyzer? = nil,
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        dbActor: DatabaseActor? = nil,
        progressCallback: ToolProgressCallback? = nil
    ) {
        self.workingDirectory = workingDirectory

        // If no components provided, create them
        let db = dbActor ?? DatabaseActor(dbPath: Self.defaultDatabasePath())

        self.buildExecutor = buildExecutor ?? BuildExecutor(workingDirectory: workingDirectory)
        self.sessionManager = sessionManager ?? BuildSessionManager(dbActor: db)
        self.buildCache = buildCache ?? SwiftBuildCache(dbActor: db)
        self.diagnosticAnalyzer = diagnosticAnalyzer ?? DiagnosticAnalyzer(dbActor: db)
        self.timingAnalyzer = timingAnalyzer ?? BuildTimingAnalyzer(dbActor: db)
        self.progressCallback = progressCallback
    }

    /// Execute a build with caching, diagnostics, and timing
    public func execute(_ request: ToolCallRequest, session: SessionContext) async
        -> ToolCallResponse {
        let paramsData = Data(request.parameters.utf8)
        let parameters =
            (try? JSONSerialization.jsonObject(with: paramsData) as? [String: Any]) ?? [:]

        // Extract parameters
        let target = parameters["target"] as? String
        let packagePath = parameters["package_path"] as? String
        let configuration = (parameters["configuration"] as? String) ?? "debug"
        let buildConfig = BuildConfiguration(rawValue: configuration) ?? .debug
        guard let targetName = (target?.isEmpty == false) ? target else {
            fatalError("Failed to unwrap targetName")
        }
        let requestWorkingDirectory = packagePath
            .map { URL(fileURLWithPath: $0).standardizedFileURL } ?? workingDirectory

        do {
            let executor = requestWorkingDirectory == workingDirectory
                ? buildExecutor
                : BuildExecutor(workingDirectory: requestWorkingDirectory)

            // Start build session
            let buildSession = try await sessionManager.startSession(
                target: targetName,
                configuration: configuration,
                commandLine: target.map { "swift build --target \($0) --configuration \(configuration)" }
                    ?? "swift build --configuration \(configuration)"
            )

            await progressCallback?(1, 4, "Build session \(buildSession.id) started")

            // Execute the build
            let buildRequest = BuildRequest(
                target: target,
                configuration: buildConfig,
                additionalFlags: [],
                environment: nil
            )

            let buildResult = try await executor.execute(buildRequest)

            await progressCallback?(2, 4, "Build command finished")

            // Record total timing
            try await timingAnalyzer.recordTiming(
                sessionId: buildSession.id,
                phase: .total,
                duration: buildResult.duration
            )

            // Parse diagnostics from stderr
            let diagnostics = parseSwiftDiagnostics(stderr: buildResult.stderr)

            // Complete session with diagnostics
            try await sessionManager.completeSession(
                sessionId: buildSession.id,
                result: buildResult,
                diagnostics: diagnostics
            )

            // Get diagnostic summary
            let diagStats = try await diagnosticAnalyzer.getStatistics(sessionId: buildSession.id)
            let topDiagnostics = diagnostics.prefix(10).map { diag in
                DiagnosticDetail(
                    file: diag.filePath,
                    line: diag.lineNumber,
                    column: diag.columnNumber ?? 0,
                    severity: diag.severity,
                    message: diag.message
                )
            }

            let diagnosticSummary = DiagnosticSummary(
                errors: diagStats.totalErrors,
                warnings: diagStats.totalWarnings,
                notes: diagStats.totalNotes,
                affectedFiles: Array(diagStats.affectedFiles),
                topErrors: Array(topDiagnostics)
            )

            // Build the enhanced result
            let enhancedResult = EnhancedBuildResult(
                exitCode: buildResult.exitCode,
                duration: buildResult.duration,
                sessionId: buildSession.id,
                cacheHit: false,  // For now, always rebuild (cache integration in future)
                cachedFiles: 0,
                rebuiltFiles: 0,
                diagnostics: diagnosticSummary,
                output: buildResult.stdout + buildResult.stderr
            )

            await progressCallback?(3, 4, "Diagnostics summarized")

            // Encode result
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let resultData = try encoder.encode(enhancedResult)

            let toolStatus: ToolCallStatus = buildResult.exitCode == 0 ? .success : .failed
            let diagnosis = toolStatus == .failed
                ? "Build failed with \(diagStats.totalErrors) error(s), \(diagStats.totalWarnings) warning(s)"
                : nil

            await progressCallback?(4, 4, "Build result ready")

            return ToolCallResponse(
                status: toolStatus,
                result: resultData,
                toolName: request.toolName,
                diagnosis: diagnosis
            )
        } catch {
            return ToolCallResponse(
                status: .failed,
                toolName: request.toolName,
                diagnosis: "Build execution error: \(error.localizedDescription)"
            )
        }
    }

    /// Parse Swift compiler diagnostics from stderr
    private func parseSwiftDiagnostics(stderr: String) -> [ParsedDiagnostic] {
        var diagnostics: [ParsedDiagnostic] = []

        // Pattern for Swift compiler diagnostics: file:line:col: severity: message
        let pattern = #"^(.+?):(\d+):(\d+):\s*(error|warning|note):\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        else {
            return []
        }

        let lines = stderr.components(separatedBy: .newlines)
        for line in lines {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            guard let match = regex.firstMatch(in: line, options: [], range: range) else { continue }

            guard match.numberOfRanges >= 5 else { continue }

            let filePath = nsLine.substring(with: match.range(at: 1))
            let lineNumber = Int(nsLine.substring(with: match.range(at: 2))) ?? 0
            let columnNumber = Int(nsLine.substring(with: match.range(at: 3)))
            let severity = nsLine.substring(with: match.range(at: 4))
            let message = nsLine.substring(with: match.range(at: 5))

            let diagnostic = ParsedDiagnostic(
                filePath: filePath,
                lineNumber: lineNumber,
                columnNumber: columnNumber,
                severity: severity,
                category: "compiler",
                tool: "swiftc",
                message: message
            )

            diagnostics.append(diagnostic)
        }

        return diagnostics
    }

    /// Get default database path
    private static func defaultDatabasePath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())

        let anigmaDir = appSupport.appendingPathComponent("Anigma")
        try? FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)

        return anigmaDir.appendingPathComponent("builds.sqlite").path
    }
}
