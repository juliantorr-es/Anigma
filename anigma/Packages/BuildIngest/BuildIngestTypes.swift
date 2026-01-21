//
//  BuildIngestTypes.swift
//  BuildIngest
//
//  Shared types for BuildIngest operations.
//  Eliminates duplicate definitions across files.
//

import Foundation

// MARK: - Core Records

/// Document unit record for evidence tracking.
public struct DocumentUnitRecord: Sendable, Codable {
    public let id: String
    public let origin: String
    public let path: String
    public let contentHash: String
    public let gitCommit: String?
    public let createdAtUnix: Int64

    public init(
        id: String,
        origin: String,
        path: String,
        contentHash: String,
        gitCommit: String?,
        createdAtUnix: Int64
    ) {
        self.id = id
        self.origin = origin
        self.path = path
        self.contentHash = contentHash
        self.gitCommit = gitCommit
        self.createdAtUnix = createdAtUnix
    }
}

/// Build session record for tracking builds.
public struct BuildSessionRecord: Sendable, Codable {
    public let id: String
    public let gitStateId: String
    public let target: String
    public let configuration: String
    public let toolchain: String
    public let startTimeUnix: Int64
    public let buildStatus: String

    public init(
        id: String,
        gitStateId: String,
        target: String,
        configuration: String,
        toolchain: String,
        startTimeUnix: Int64,
        buildStatus: String
    ) {
        self.id = id
        self.gitStateId = gitStateId
        self.target = target
        self.configuration = configuration
        self.toolchain = toolchain
        self.startTimeUnix = startTimeUnix
        self.buildStatus = buildStatus
    }
}

/// Swift diagnostic record for build errors.
public struct SwiftDiagnostic: Sendable, Codable {
    public let severity: String
    public let message: String
    public let filePath: String
    public let lineNumber: Int
    public let columnNumber: Int
    public let buildSessionId: String
    public let category: String
    public let tool: String
    public let codeSnippet: String?
    public let functionName: String?
    public let moduleName: String?
    public let ruleId: String?
    public let fixitAvailable: Bool

    public init(
        severity: String,
        message: String,
        filePath: String,
        lineNumber: Int,
        columnNumber: Int,
        buildSessionId: String,
        category: String,
        tool: String,
        codeSnippet: String?,
        functionName: String?,
        moduleName: String?,
        ruleId: String?,
        fixitAvailable: Bool
    ) {
        self.severity = severity
        self.message = message
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self.buildSessionId = buildSessionId
        self.category = category
        self.tool = tool
        self.codeSnippet = codeSnippet
        self.functionName = functionName
        self.moduleName = moduleName
        self.ruleId = ruleId
        self.fixitAvailable = fixitAvailable
    }
}

/// Git state for repository tracking.
public struct GitState: Sendable, Codable {
    public let id: String
    public let commitHash: String
    public let branch: String
    public let isDirty: Bool
    public let diffHash: String?
    public let authorName: String?
    public let authorEmail: String?
    public let commitTimestamp: Int?
    public let message: String?

    public init(
        id: String,
        commitHash: String,
        branch: String,
        isDirty: Bool,
        diffHash: String?,
        authorName: String?,
        authorEmail: String?,
        commitTimestamp: Int?,
        message: String?
    ) {
        self.id = id
        self.commitHash = commitHash
        self.branch = branch
        self.isDirty = isDirty
        self.diffHash = diffHash
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.commitTimestamp = commitTimestamp
        self.message = message
    }
}

/// Build result for tracking execution.
public struct BuildResult: Sendable, Codable {
    public let output: String
    public let errorOutput: String
    public let exitCode: Int32
    public let artifactPath: String?

    public init(
        output: String,
        errorOutput: String,
        exitCode: Int32,
        artifactPath: String?
    ) {
        self.output = output
        self.errorOutput = errorOutput
        self.exitCode = exitCode
        self.artifactPath = artifactPath
    }
}

/// Diagnostic for build errors.
public struct Diagnostic: Sendable, Codable {
    public let id: String
    public var buildSessionId: String
    public let filePath: String
    public let lineNumber: Int
    public let columnNumber: Int
    public let severity: String
    public let category: String
    public let tool: String
    public let message: String
    public let codeSnippet: String?
    public let functionName: String?
    public let moduleName: String?
    public let ruleId: String?
    public let fixitAvailable: Bool

    public init(
        id: String,
        buildSessionId: String,
        filePath: String,
        lineNumber: Int,
        columnNumber: Int,
        severity: String,
        category: String,
        tool: String,
        message: String,
        codeSnippet: String?,
        functionName: String?,
        moduleName: String?,
        ruleId: String?,
        fixitAvailable: Bool
    ) {
        self.id = id
        self.buildSessionId = buildSessionId
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self.severity = severity
        self.category = category
        self.message = message
        self.codeSnippet = codeSnippet
        self.functionName = functionName
        self.moduleName = moduleName
        self.ruleId = ruleId
        self.fixitAvailable = fixitAvailable
    }
}

// MARK: - Error Types

/// BuildIngest-specific errors.
public enum BuildIngestError: Error, LocalizedError {
    case gitStateCaptureFailed(String)
    case fileNotFound(String)
    case buildExecutionFailed(String)
    case parseError(String)
    case databaseError(String)

    public var errorDescription: String? {
        switch self {
        case .gitStateCaptureFailed(let message):
            return "Failed to capture git state: \(message)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .buildExecutionFailed(let message):
            return "Build execution failed: \(message)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        }
    }
}

// MARK: - Utility Types

/// Build configuration options.
public struct BuildConfiguration: Sendable, Codable {
    public let target: String
    public let configuration: String
    public let toolchain: String
    public let workingDirectory: String
    public let verbose: Bool

    public init(
        target: String,
        configuration: String = "debug",
        toolchain: String = "swift-6.0",
        workingDirectory: String = FileManager.default.currentDirectoryPath,
        verbose: Bool = false
    ) {
        self.target = target
        self.configuration = configuration
        self.toolchain = toolchain
        self.workingDirectory = workingDirectory
        self.verbose = verbose
    }
}

/// Build statistics for reporting.
public struct BuildStatistics: Sendable, Codable {
    public let errors: Int
    public let warnings: Int
    public let duration: TimeInterval
    public let artifactPath: String?

    public init(
        errors: Int,
        warnings: Int,
        duration: TimeInterval,
        artifactPath: String? = nil
    ) {
        self.errors = errors
        self.warnings = warnings
        self.duration = duration
        self.artifactPath = artifactPath
    }
}
