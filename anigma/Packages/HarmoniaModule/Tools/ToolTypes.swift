//
//  ToolTypes.swift
//  HarmoniaModule
//
//  Core tool system type definitions.
//

@preconcurrency import Foundation
import DatabaseCore

// MARK: - Core Tool Types

/// Request structure for tool handlers
public struct ToolRequest: Sendable, Codable {
    public let name: String?
    public let arguments: [String: String]
    public let sessionId: String?
    public let projectId: String?
    
    public init(name: String? = nil, arguments: [String: String], sessionId: String? = nil, projectId: String? = nil) {
        self.name = name
        self.arguments = arguments
        self.sessionId = sessionId
        self.projectId = projectId
    }
}

/// Response structure from tool handlers
public struct ToolResponse: Sendable, Codable {
    public let success: Bool
    public let output: String
    
    public init(success: Bool, output: String) {
        self.success = success
        self.output = output
    }
    
    /// Success response factory
    public static func success(_ output: String) -> ToolResponse {
        return ToolResponse(success: true, output: output)
    }
    
    /// Failure response factory
    public static func failure(_ output: String) -> ToolResponse {
        return ToolResponse(success: false, output: output)
    }
}

/// Callback for tool progress updates
public typealias ToolProgressCallback = @Sendable (Int, Int, String) async -> Void

/// Protocol for tool handlers
public protocol ToolHandlerProtocol: Sendable {
    func handle(request: ToolRequest) async throws -> ToolResponse
}

/// Type-erased wrapper for tool handlers
public struct AnyToolHandler: Sendable {
    private let _handle: @Sendable (ToolRequest) async throws -> ToolResponse
    
    public init<T: ToolHandlerProtocol>(_ handler: T) {
        self._handle = { try await handler.handle(request: $0) }
    }
    
    public func handle(request: ToolRequest) async throws -> ToolResponse {
        return try await _handle(request)
    }
}

/// Registry for managing tools
public actor SimpleToolRegistry {
    private var handlers: [String: AnyToolHandler] = [:]
    
    public init() {}
    
    /// Register a tool handler
    public func register(name: String, handler: AnyToolHandler) {
        handlers[name] = handler
    }
    
    /// Get the number of registered tools
    public var toolCount: Int {
        return handlers.count
    }
    
    /// Get a handler by name
    public func handler(for name: String) -> AnyToolHandler? {
        return handlers[name]
    }

    /// Execute a tool request
    public func execute(request: ToolRequest) async throws -> ToolResponse {
        guard let name = request.name else {
            return .failure("Missing tool name")
        }
        guard let handler = handlers[name] else {
            return .failure("Unknown tool: \(name)")
        }
        return try await handler.handle(request: request)
    }
}

// MARK: - Build System Types

/// Build configuration options
public enum BuildConfiguration: String, Sendable, Codable, CaseIterable {
    case debug = "debug"
    case release = "release"
}

/// Build request structure
public struct BuildRequest: Sendable, Codable {
    public let target: String?
    public let configuration: BuildConfiguration
    public let additionalFlags: [String]
    public let environment: [String: String]?
    
    public init(
        target: String? = nil,
        configuration: BuildConfiguration = .debug,
        additionalFlags: [String] = [],
        environment: [String: String]? = nil
    ) {
        self.target = target
        self.configuration = configuration
        self.additionalFlags = additionalFlags
        self.environment = environment
    }
}

/// Build execution result
public struct BuildResult: Sendable, Codable {
    public let exitCode: Int32
    public let duration: TimeInterval
    public let stdout: String
    public let stderr: String
    
    public init(
        exitCode: Int32,
        duration: TimeInterval,
        stdout: String,
        stderr: String
    ) {
        self.exitCode = exitCode
        self.duration = duration
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Build session information
public struct BuildSession: Sendable, Codable {
    public let id: String
    
    public init(id: String) {
        self.id = id
    }
}

/// Diagnostic statistics
public struct DiagnosticStatistics: Sendable, Codable {
    public let errorCount: Int
    public let warningCount: Int
    public let noteCount: Int
    
    public init(errorCount: Int, warningCount: Int, noteCount: Int) {
        self.errorCount = errorCount
        self.warningCount = warningCount
        self.noteCount = noteCount
    }
}

/// Build executor protocol
public protocol BuildExecutor: Sendable {
    func execute(_ request: BuildRequest) async throws -> BuildResult
}

/// Build executor implementation
public struct DefaultBuildExecutor: BuildExecutor {
    private let workingDirectory: URL
    
    public init(workingDirectory: URL) {
        self.workingDirectory = workingDirectory
    }
    
    public func execute(_ request: BuildRequest) async throws -> BuildResult {
        // Stub implementation
        return BuildResult(
            exitCode: 0,
            duration: 0.0,
            stdout: "",
            stderr: ""
        )
    }
}

/// Build session manager
public actor BuildSessionManager {
    private let dbActor: any DatabaseExecutor
    
    public init(dbActor: any DatabaseExecutor) {
        self.dbActor = dbActor
    }
    
    public func startSession(
        target: String?,
        configuration: BuildConfiguration,
        commandLine: String
    ) async throws -> BuildSession {
        // Stub implementation
        return BuildSession(id: UUID().uuidString)
    }
    
    public func completeSession(
        sessionId: String,
        result: BuildResult,
        diagnostics: [ParsedDiagnostic]
    ) async throws {
        // Stub implementation
    }
}

/// Build timing analyzer
public actor BuildTimingAnalyzer {
    private let dbActor: any DatabaseExecutor
    
    public init(dbActor: any DatabaseExecutor) {
        self.dbActor = dbActor
    }
    
    public func recordTiming(
        sessionId: String,
        phase: String,
        duration: TimeInterval
    ) async throws {
        // Stub implementation
    }
}

/// Swift build cache
public actor SwiftBuildCache {
    private let dbActor: any DatabaseExecutor
    
    public init(dbActor: any DatabaseExecutor) {
        self.dbActor = dbActor
    }
    
    // Stub implementation
}

/// Diagnostic analyzer
public actor DiagnosticAnalyzer {
    private let dbActor: any DatabaseExecutor
    
    public init(dbActor: any DatabaseExecutor) {
        self.dbActor = dbActor
    }
    
    public func getStatistics(sessionId: String) async throws -> DiagnosticStatistics {
        // Stub implementation
        return DiagnosticStatistics(errorCount: 0, warningCount: 0, noteCount: 0)
    }
}

// MARK: - Patch System Types

/// Verification issue
public struct VerificationIssue: Sendable, Codable {
    public enum IssueType: String, Sendable, Codable {
        case conflictingChanges = "conflicting_changes"
        case malformedPatch = "malformed_patch"
        case missingContext = "missing_context"
        case securityViolation = "security_violation"
    }
    
    public let type: IssueType
    public let location: String
    public let severity: String
    public let description: String
    
    public init(type: IssueType, location: String, severity: String, description: String) {
        self.type = type
        self.location = location
        self.severity = severity
        self.description = description
    }
}

/// Patch verification result
public struct PatchVerificationResult: Sendable, Codable {
    public let isValid: Bool
    public let beforeHash: String
    public let afterHash: String
    public let matchedLines: Int
    public let failedLines: Int
    public let partiallyApplied: Bool
    public let issues: [VerificationIssue]
    public let remediations: [String]
    
    public init(
        isValid: Bool,
        beforeHash: String,
        afterHash: String,
        matchedLines: Int,
        failedLines: Int,
        partiallyApplied: Bool,
        issues: [VerificationIssue],
        remediations: [String] = []
    ) {
        self.isValid = isValid
        self.beforeHash = beforeHash
        self.afterHash = afterHash
        self.matchedLines = matchedLines
        self.failedLines = failedLines
        self.partiallyApplied = partiallyApplied
        self.issues = issues
        self.remediations = remediations
    }
}

/// Patch file verification
public struct PatchFileVerification: Sendable, Codable {
    public let filePath: String
    public let verification: PatchVerificationResult
    
    public init(filePath: String, verification: PatchVerificationResult) {
        self.filePath = filePath
        self.verification = verification
    }
}

/// Result of Swift code validation
public struct SwiftValidationResult: Sendable, Codable {
    public let isValid: Bool
    public let compilationSucceeded: Bool
    public let issues: [SwiftValidationIssue]
    public let suggestions: [SwiftFixSuggestion]
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

    public let type: IssueType
    public let severity: Severity
    public let filePath: String
    public let line: Int?
    public let column: Int?
    public let message: String
    public let rawOutput: String?
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
    public let issueType: SwiftValidationIssue.IssueType
    public let filePath: String
    public let line: Int?
    public let description: String
    public let exampleFix: String?
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

/// Patch verifier
public actor PatchVerifier: Sendable {
    private let dbActor: any DatabaseExecutor
    
    public init(dbActor: any DatabaseExecutor) {
        self.dbActor = dbActor
    }
    
    public func verify(
        patchContent: String,
        originalContent: String,
        patchedContent: String
    ) async throws -> PatchVerificationResult {
        // Stub implementation
        return PatchVerificationResult(
            isValid: true,
            beforeHash: "",
            afterHash: "",
            matchedLines: 0,
            failedLines: 0,
            partiallyApplied: false,
            issues: []
        )
    }
}

/// Patch auditor
public actor PatchAuditor: Sendable {
    private let dbActor: any DatabaseExecutor
    
    public init(dbActor: any DatabaseExecutor) {
        self.dbActor = dbActor
    }
    
    public func logAction(
        action: String,
        actor: String,
        targetFile: String,
        patchId: String,
        beforeState: String,
        afterState: String,
        outcome: String,
        details: String
    ) async throws {
        // Stub implementation
    }
}

/// Parsed diagnostic from build output
public struct ParsedDiagnostic: Sendable, Codable {
    public let filePath: String
    public let lineNumber: Int
    public let columnNumber: Int?
    public let severity: String
    public let category: String
    public let tool: String
    public let message: String
    
    public init(
        filePath: String,
        lineNumber: Int,
        columnNumber: Int?,
        severity: String,
        category: String,
        tool: String,
        message: String
    ) {
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self.severity = severity
        self.category = category
        self.tool = tool
        self.message = message
    }
}

/// Rollback manager
public actor RollbackManager: Sendable {
    private let dbActor: any DatabaseExecutor
    
    public init(dbActor: any DatabaseExecutor) {
        self.dbActor = dbActor
    }
    
    public func recordPatchApplication(
        patchId: String,
        targetFile: String,
        beforeHash: String,
        afterHash: String,
        appliedBy: String
    ) async throws {
        // Stub implementation
    }
    
    public func rollbackPatch(
        patchId: String,
        targetFile: String,
        currentContent: String
    ) async throws {
        // Stub implementation
    }
}
