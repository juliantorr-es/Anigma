//
//  ASTWorkerTypes.swift
//  AnigmaASTServices
//
//  Shared types for AST worker operations.
//  Used by both CLI and daemon integration.
//

import Foundation

// MARK: - Task Kinds

/// AST task kinds supported by the worker
public enum ASTTaskKind: String, Codable, Sendable {
    case parse = "parse"
    case analyze = "analyze"
    case batch = "batch"
    case search = "search"
    case transform = "transform"
}

// MARK: - Request/Response Models

/// AST worker request
public struct ASTWorkerRequest: Codable, Sendable {
    /// Unique request identifier
    public let requestId: String
    /// Run identifier for provenance tracking
    public let runId: String
    /// Step identifier for workflow tracking
    public let stepId: String
    /// Task to perform
    public let task: ASTTaskKind
    /// Input artifact references
    public let inputs: [ASTArtifactRef]
    /// Task-specific options
    public let options: ASTTaskOptions
    
    public init(
        requestId: String,
        runId: String,
        stepId: String,
        task: ASTTaskKind,
        inputs: [ASTArtifactRef],
        options: ASTTaskOptions
    ) {
        self.requestId = requestId
        self.runId = runId
        self.stepId = stepId
        self.task = task
        self.inputs = inputs
        self.options = options
    }
}

/// AST artifact reference
public struct ASTArtifactRef: Codable, Sendable {
    /// File path
    public let path: String
    /// Content hash (SHA256)
    public let hash: String
    
    public init(path: String, hash: String) {
        self.path = path
        self.hash = hash
    }
}

/// AST task options
public struct ASTTaskOptions: Codable, Sendable {
    /// Visitors to run (security, quality, concurrency, architecture)
    public let visitors: [String]
    /// Maximum file size to process (bytes)
    public let maxFileSize: Int?
    /// Cache configuration
    public let cacheEnabled: Bool
    /// Cache size limit (bytes)
    public let cacheSizeLimit: Int?
    /// Output directory for results
    public let outputDirectory: String?
    
    public init(
        visitors: [String] = ["security", "quality"],
        maxFileSize: Int? = 10 * 1024 * 1024, // 10MB default
        cacheEnabled: Bool = true,
        cacheSizeLimit: Int? = 100 * 1024 * 1024, // 100MB default
        outputDirectory: String? = nil
    ) {
        self.visitors = visitors
        self.maxFileSize = maxFileSize
        self.cacheEnabled = cacheEnabled
        self.cacheSizeLimit = cacheSizeLimit
        self.outputDirectory = outputDirectory
    }
}

/// AST worker response
public struct ASTWorkerResponse: Codable, Sendable {
    /// Request identifier
    public let requestId: String
    /// Response status
    public let status: ASTWorkerStatus
    /// Output artifacts
    public let outputs: [ASTWorkerArtifact]
    /// Performance metrics
    public let metrics: ASTWorkerMetrics?
    /// Engine metadata for provenance
    public let engineMeta: ASTWorkerEngineMetadata?
    /// Error message if failed
    public let errorMessage: String?
    
    public init(
        requestId: String,
        status: ASTWorkerStatus,
        outputs: [ASTWorkerArtifact],
        metrics: ASTWorkerMetrics? = nil,
        engineMeta: ASTWorkerEngineMetadata? = nil,
        errorMessage: String? = nil
    ) {
        self.requestId = requestId
        self.status = status
        self.outputs = outputs
        self.metrics = metrics
        self.engineMeta = engineMeta
        self.errorMessage = errorMessage
    }
}

/// AST worker status
public enum ASTWorkerStatus: String, Codable, Sendable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

/// AST worker artifact
public struct ASTWorkerArtifact: Codable, Sendable {
    /// File path
    public let path: String
    /// Content hash
    public let hash: String
    /// Normalized hash for provenance
    public let normalizedHash: String?
    
    public init(path: String, hash: String, normalizedHash: String? = nil) {
        self.path = path
        self.hash = hash
        self.normalizedHash = normalizedHash
    }
}

/// AST worker metrics
public struct ASTWorkerMetrics: Codable, Sendable {
    /// Duration in milliseconds
    public let durationMs: Int
    /// Files processed
    public let filesProcessed: Int
    /// Nodes processed
    public let nodesProcessed: Int?
    /// Cache hits
    public let cacheHits: Int?
    /// Cache misses
    public let cacheMisses: Int?
    /// Memory used in bytes
    public let memoryBytes: Int?
    
    public init(
        durationMs: Int,
        filesProcessed: Int,
        nodesProcessed: Int? = nil,
        cacheHits: Int? = nil,
        cacheMisses: Int? = nil,
        memoryBytes: Int? = nil
    ) {
        self.durationMs = durationMs
        self.filesProcessed = filesProcessed
        self.nodesProcessed = nodesProcessed
        self.cacheHits = cacheHits
        self.cacheMisses = cacheMisses
        self.memoryBytes = memoryBytes
    }
}

/// AST worker engine metadata
public struct ASTWorkerEngineMetadata: Codable, Sendable {
    /// Binary hash for provenance
    public let binaryHash: String
    /// Engine version
    public let version: String
    /// Engine identifier
    public let engineId: String
    /// SwiftSyntax version
    public let swiftSyntaxVersion: String
    
    public init(
        binaryHash: String,
        version: String,
        engineId: String,
        swiftSyntaxVersion: String
    ) {
        self.binaryHash = binaryHash
        self.version = version
        self.engineId = engineId
        self.swiftSyntaxVersion = swiftSyntaxVersion
    }
}

// MARK: - Analysis Results (Shared with CLI)

/// Finding from analysis
public struct ASTFinding: Codable, Sendable {
    /// Finding type
    public let type: String
    /// Rule identifier
    public let ruleId: String
    /// Severity (error, warning, info)
    public let severity: String
    /// Message
    public let message: String
    /// File path
    public let filePath: String
    /// Line number
    public let lineNumber: Int
    /// Column number (optional)
    public let columnNumber: Int?
    /// Context snippet
    public let context: String
    
    public init(
        type: String,
        ruleId: String,
        severity: String,
        message: String,
        filePath: String,
        lineNumber: Int,
        columnNumber: Int? = nil,
        context: String
    ) {
        self.type = type
        self.ruleId = ruleId
        self.severity = severity
        self.message = message
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self.context = context
    }
}

/// Error information
public struct ASTErrorInfo: Codable, Sendable {
    /// Error code
    public let code: String
    /// Error message
    public let message: String
    
    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

/// AST result type
public enum ASTResultType: String, Codable, Sendable {
    case parse = "parse"
    case analyze = "analyze"
    case error = "error"
}

/// AST result (compatible with CLI format)
public struct ASTResult: Codable, Sendable {
    /// Result type
    public let type: ASTResultType
    /// Schema version
    public let schemaVersion: String
    /// Request identifier
    public let requestId: String
    /// Success flag
    public let ok: Bool
    /// File path
    public let filePath: String?
    /// Source size in bytes
    public let sourceSize: Int?
    /// Node count
    public let nodeCount: Int?
    /// Parse time
    public let parseTime: Date?
    /// Visitors run
    public let visitors: [String]?
    /// Findings
    public let findings: [ASTFinding]?
    /// Analysis time
    public let analysisTime: Date?
    /// Error information
    public let error: ASTErrorInfo?
    
    public init(
        type: ASTResultType,
        schemaVersion: String,
        requestId: String,
        ok: Bool,
        filePath: String? = nil,
        sourceSize: Int? = nil,
        nodeCount: Int? = nil,
        parseTime: Date? = nil,
        visitors: [String]? = nil,
        findings: [ASTFinding]? = nil,
        analysisTime: Date? = nil,
        error: ASTErrorInfo? = nil
    ) {
        self.type = type
        self.schemaVersion = schemaVersion
        self.requestId = requestId
        self.ok = ok
        self.filePath = filePath
        self.sourceSize = sourceSize
        self.nodeCount = nodeCount
        self.parseTime = parseTime
        self.visitors = visitors
        self.findings = findings
        self.analysisTime = analysisTime
        self.error = error
    }
    
    /// Create parse result
    public static func parse(
        schemaVersion: String,
        requestId: String,
        ok: Bool,
        filePath: String,
        sourceSize: Int,
        nodeCount: Int?,
        parseTime: Date?
    ) -> ASTResult {
        return ASTResult(
            type: .parse,
            schemaVersion: schemaVersion,
            requestId: requestId,
            ok: ok,
            filePath: filePath,
            sourceSize: sourceSize,
            nodeCount: nodeCount,
            parseTime: parseTime
        )
    }
    
    /// Create analyze result
    public static func analyze(
        schemaVersion: String,
        requestId: String,
        ok: Bool,
        filePath: String,
        sourceSize: Int,
        visitors: [String],
        findings: [ASTFinding],
        analysisTime: Date?
    ) -> ASTResult {
        return ASTResult(
            type: .analyze,
            schemaVersion: schemaVersion,
            requestId: requestId,
            ok: ok,
            filePath: filePath,
            sourceSize: sourceSize,
            visitors: visitors,
            findings: findings,
            analysisTime: analysisTime
        )
    }
    
    /// Create error result
    public static func error(
        schemaVersion: String,
        requestId: String,
        ok: Bool,
        error: ASTErrorInfo
    ) -> ASTResult {
        return ASTResult(
            type: .error,
            schemaVersion: schemaVersion,
            requestId: requestId,
            ok: ok,
            error: error
        )
    }
}

// MARK: - Batch Operations

/// Batch request for multiple files
public struct ASTBatchRequest: Codable, Sendable {
    /// Operation to perform
    public let operation: String
    /// File path (single file) or directory
    public let file: String?
    /// Visitors to run
    public let visitors: [String]?
    
    public init(operation: String, file: String? = nil, visitors: [String]? = nil) {
        self.operation = operation
        self.file = file
        self.visitors = visitors
    }
}

// MARK: - Errors

/// AST worker errors
public enum ASTWorkerError: Error, LocalizedError, Sendable {
    case fileNotFound(String)
    case fileTooLarge(String, Int)
    case parseError(String)
    case analysisError(String)
    case invalidRequest(String)
    case cacheError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileTooLarge(let path, let size):
            return "File too large: \(path) (\(size) bytes)"
        case .parseError(let reason):
            return "Parse error: \(reason)"
        case .analysisError(let reason):
            return "Analysis error: \(reason)"
        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"
        case .cacheError(let reason):
            return "Cache error: \(reason)"
        }
    }
}