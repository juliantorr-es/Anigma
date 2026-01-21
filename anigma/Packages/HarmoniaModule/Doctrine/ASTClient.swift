//
//  ASTClient.swift
//  HarmoniaModule
//
//  Client for calling AnigmaASTServices binary as subprocess.
//  Keeps SwiftSyntax completely out of Harmonia build chain.
//

import AnigmaPrimitives
import DoctrineCore
import Foundation

// MARK: - AST Client

/// Client for interacting with AnigmaASTServices binary
public actor ASTClient {

    /// Path to the AST services binary
    private let binaryPath: String

    /// Whether to use binary or fallback to in-process
    private let useBinary: Bool

    public init(binaryPath: String? = nil, useBinary: Bool = true) {
        self.binaryPath = binaryPath ?? Self.findBinaryPath() ?? "anigma-ast-services"
        self.useBinary = useBinary
    }

    /// Parse a Swift file using AST services
    public func parseFile(_ path: String) async throws -> ParseResult {
        if useBinary {
            return try await callBinary(operation: "parse", file: path, visitors: nil)
        } else {
            // Fallback to simple string parsing
            return try parseFileFallback(path)
        }
    }

    /// Analyze a Swift file with specific visitors
    public func analyzeFile(_ path: String, visitors: [String] = ["security", "quality"])
        async throws -> AnalyzeResult {
        if useBinary {
            return try await callBinaryAnalyze(operation: "analyze", file: path, visitors: visitors)
        } else {
            // Fallback to simple analysis
            return try analyzeFileFallback(path, visitors: visitors)
        }
    }

    /// Analyze a directory of Swift files
    public func analyzeDirectory(_ path: String, visitors: [String] = ["security", "quality"])
        async throws -> [AnalyzeResult] {
        if useBinary {
            return try await callBinaryDirectory(path: path, visitors: visitors)
        } else {
            // Fallback to directory analysis
            return try analyzeDirectoryFallback(path, visitors: visitors)
        }
    }
}

// MARK: - Binary Communication

extension ASTClient {

    /// Call the AST services binary for single file operations
    private func callBinary(operation: String, file: String, visitors: [String]?) async throws
        -> ParseResult {
        let jsonString = try await runBinary(operation: operation, file: file, visitors: visitors)
        return try decodeBinaryResponse(jsonString)
    }

    /// Call the AST services binary for single file analyze operations
    private func callBinaryAnalyze(operation: String, file: String, visitors: [String]?)
        async throws -> AnalyzeResult {
        let jsonString = try await runBinary(operation: operation, file: file, visitors: visitors)
        return try decodeBinaryAnalyzeResponse(jsonString)
    }

    /// Runs the binary and returns its JSON output.
    private func runBinary(operation: String, file: String, visitors: [String]?) async throws
        -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = buildArguments(operation: operation, file: file, visitors: visitors)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        guard let data = try pipe.fileHandleForReading.readToEnd() else {
            throw ASTError.invalidOutput
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ASTError.binaryFailed(process.terminationStatus)
        }

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ASTError.invalidOutput
        }

        return jsonString
    }

    /// Call the AST services binary for directory analysis
    private func callBinaryDirectory(path: String, visitors: [String]) async throws
        -> [AnalyzeResult] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "analyze",
            "--directory", path,
            "--visitors", visitors.joined(separator: ","),
            "--output-format", "ndjson"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        guard let data = try pipe.fileHandleForReading.readToEnd() else {
            throw ASTError.invalidOutput
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ASTError.binaryFailed(process.terminationStatus)
        }

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ASTError.invalidOutput
        }

        return try decodeBinaryNDJSONResponse(jsonString)
    }

    /// Build command line arguments for binary
    private func buildArguments(operation: String, file: String, visitors: [String]?) -> [String] {
        var args = [operation]

        if let file = file as String? {
            args.append(contentsOf: ["--file", file])
        }

        if let visitors = visitors, !visitors.isEmpty {
            args.append(contentsOf: ["--visitors", visitors.joined(separator: ",")])
        }

        args.append(contentsOf: ["--output-format", "json"])

        return args
    }

    /// Decode single JSON response from binary
    private func decodeBinaryResponse(_ jsonString: String) throws -> ParseResult {
        guard let data = jsonString.data(using: .utf8) else {
            throw ASTError.invalidOutput
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(BinaryResponse.self, from: data)

        guard response.ok else {
            throw ASTError.analysisFailed(response.error?.message ?? "Unknown error")
        }

        return ParseResult(
            filePath: response.filePath ?? "",
            sourceSize: response.sourceSize ?? 0,
            nodeCount: response.nodeCount ?? 0,
            parseTime: response.parseTime ?? Date()
        )
    }

    /// Decode single analysis response from binary
    private func decodeBinaryAnalyzeResponse(_ jsonString: String) throws -> AnalyzeResult {
        guard let data = jsonString.data(using: .utf8) else {
            throw ASTError.invalidOutput
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(BinaryResponse.self, from: data)
        guard response.ok else {
            throw ASTError.analysisFailed(response.error?.message ?? "Unknown error")
        }

        return AnalyzeResult(
            filePath: response.filePath ?? "",
            sourceSize: response.sourceSize ?? 0,
            visitors: response.visitors ?? [],
            findings: doctrineViolations(from: response.findings ?? []),
            analysisTime: response.analysisTime ?? Date()
        )
    }

    /// Decode NDJSON response from binary
    private func decodeBinaryNDJSONResponse(_ jsonString: String) throws -> [AnalyzeResult] {
        let lines = jsonString.components(separatedBy: .newlines)
        var results: [AnalyzeResult] = []

        let decoder = JSONDecoder()
        for line in lines {
            guard line.isEmpty == false,
                let data = line.data(using: .utf8)
            else { continue }

            let response = try decoder.decode(BinaryResponse.self, from: data)
            guard response.ok else { continue }

            results.append(
                AnalyzeResult(
                    filePath: response.filePath ?? "",
                    sourceSize: response.sourceSize ?? 0,
                    visitors: response.visitors ?? [],
                    findings: doctrineViolations(from: response.findings ?? []),
                    analysisTime: response.analysisTime ?? Date()
                ))
        }

        return results
    }
}

// MARK: - Fallback Implementations

extension ASTClient {

    /// Fallback file parsing when binary not available
    private func parseFileFallback(_ path: String) throws -> ParseResult {
        let source = try String(contentsOfFile: path, encoding: .utf8)
        let lines = source.components(separatedBy: .newlines)

        return ParseResult(
            filePath: path,
            sourceSize: source.count,
            nodeCount: lines.count,  // Rough estimate
            parseTime: Date()
        )
    }

    /// Fallback file analysis when binary not available
    private func analyzeFileFallback(_ path: String, visitors: [String]) throws -> AnalyzeResult {
        let source = try String(contentsOfFile: path, encoding: .utf8)
        var findings: [DoctrineViolation] = []

        if visitors.contains("security") {
            findings.append(contentsOf: analyzeSecurityFallback(source: source, filePath: path))
        }

        if visitors.contains("quality") {
            findings.append(contentsOf: analyzeQualityFallback(source: source, filePath: path))
        }

        return AnalyzeResult(
            filePath: path,
            sourceSize: source.count,
            visitors: visitors,
            findings: findings,
            analysisTime: Date()
        )
    }

    /// Fallback directory analysis when binary not available
    private func analyzeDirectoryFallback(_ path: String, visitors: [String]) throws
        -> [AnalyzeResult] {
        let fileManager = FileManager.default
        let swiftFiles = try fileManager.contentsOfDirectory(atPath: path)
            .filter { $0.hasSuffix(".swift") }
            .map { "\(path)/\($0)" }

        var results: [AnalyzeResult] = []
        for file in swiftFiles {
            let result = try analyzeFileFallback(file, visitors: visitors)
            results.append(result)
        }

        return results
    }

    /// Simple security analysis fallback
    private func analyzeSecurityFallback(source: String, filePath: String) -> [DoctrineViolation] {
        var violations: [DoctrineViolation] = []
        let lines = source.components(separatedBy: .newlines)
        let secretKeywords = [
            "api_key", "api-key", "secret_key", "secret-key", "password", "token"
        ]

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let lowerLine = line.lowercased()

            for keyword in secretKeywords {
                if lowerLine.contains(keyword) {
                    violations.append(
                        DoctrineViolation(
                            ruleId: "sec-secret-001",
                            severity: .error,
                            message: "Potential hardcoded secret keyword '\(keyword)'",
                            filePath: filePath,
                            lineNumber: lineNumber,
                            context: line.trimmingCharacters(in: .whitespaces)
                        ))
                }
            }
        }

        return violations
    }

    /// Simple quality analysis fallback
    private func analyzeQualityFallback(source: String, filePath: String) -> [DoctrineViolation] {
        var violations: [DoctrineViolation] = []
        let lines = source.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip comments
            if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*")
                || trimmedLine.hasPrefix("*") {
                continue
            }

            // Check for force unwrapping
            if line.contains("!") {
                violations.append(
                    DoctrineViolation(
                        ruleId: "quality-002",
                        severity: .warning,
                        message: "Force unwrapping detected",
                        filePath: filePath,
                        lineNumber: lineNumber,
                        context: line.trimmingCharacters(in: .whitespaces)
                    ))
            }
        }

        return violations
    }
}

// MARK: - Utility Functions

extension ASTClient {

    /// Find the AST services binary in standard locations
    private static func findBinaryPath() -> String? {
        let searchPaths = [
            "/usr/local/bin/anigma-ast-services",
            "~/.local/bin/anigma-ast-services",
            "./anigma-ast-services"
        ]

        for path in searchPaths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: expandedPath) {
                return expandedPath
            }
        }

        return nil
    }
}

// MARK: - Data Models

/// Result from parsing a file
public struct ParseResult: Sendable {
    public let filePath: String
    public let sourceSize: Int
    public let nodeCount: Int
    public let parseTime: Date
}

/// Result from analyzing a file
public struct AnalyzeResult: Sendable {
    public let filePath: String
    public let sourceSize: Int
    public let visitors: [String]
    public let findings: [DoctrineViolation]
    public let analysisTime: Date
}

/// Binary response structure
private struct BinaryResponse: Codable {
    let schemaVersion: String
    let requestId: String
    let ok: Bool
    let filePath: String?
    let sourceSize: Int?
    let nodeCount: Int?
    let visitors: [String]?
    let findings: [BinaryFinding]?
    let parseTime: Date?
    let analysisTime: Date?
    let error: BinaryError?
}

/// Finding from binary analysis
private struct BinaryFinding: Codable {
    let type: String
    let ruleId: String
    let severity: String
    let message: String
    let filePath: String
    let lineNumber: Int
    let columnNumber: Int?
    let context: String
}

/// Convert binary findings to domain violations.
private func doctrineViolations(from findings: [BinaryFinding]) -> [DoctrineViolation] {
    findings.map { finding in
        DoctrineViolation(
            ruleId: finding.ruleId,
            severity: DoctrineSeverity(rawValue: finding.severity) ?? .warning,
            message: finding.message,
            filePath: finding.filePath,
            lineNumber: finding.lineNumber,
            context: finding.context
        )
    }
}

/// Error from binary
private struct BinaryError: Codable {
    let code: String
    let message: String
}

/// AST client errors
public enum ASTError: Error, LocalizedError {
    case binaryFailed(Int32)
    case invalidOutput
    case analysisFailed(String)
    case binaryNotFound

    public var errorDescription: String? {
        switch self {
        case .binaryFailed(let code):
            return "AST services binary failed with exit code \(code)"
        case .invalidOutput:
            return "Invalid output from AST services binary"
        case .analysisFailed(let message):
            return "Analysis failed: \(message)"
        case .binaryNotFound:
            return "AST services binary not found"
        }
    }
}
