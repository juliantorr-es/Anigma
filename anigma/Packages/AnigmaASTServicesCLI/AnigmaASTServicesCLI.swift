//
//  AnigmaASTServicesCLI.swift
//  AnigmaASTServicesCLI
//
//  main.swift
//  AnigmaASTServices - Standalone CLI Tool
//
//  SwiftSyntax parsing and analysis as a standalone binary.
//  Designed to be called as subprocess from Harmonia to keep SwiftSyntax
//  out of main build chain.
//

import Foundation
import SwiftSyntax
import SwiftParser
import ArgumentParser

// MARK: - CLI Interface

@main
struct AnigmaASTServices: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "anigma-ast-services",
        abstract: "SwiftSyntax parsing and analysis services for Harmonia",
        version: "1.0.0"
    )

    @Argument(help: "Operation to perform: parse, analyze, batch")
    var operation: Operation

    @Option(name: .long, help: "Swift file to parse")
    var file: String?

    @Option(name: .long, help: "Directory to analyze")
    var directory: String?

    @Option(name: .long, help: "Comma-separated list of visitors to run")
    var visitors: String = "security,quality"

    @Option(name: .long, help: "Output format: json, ndjson")
    var outputFormat: OutputFormat = .json

    @Option(name: .long, help: "Batch mode: read JSON from stdin, write to stdout")
    var batch: Bool = false

    @Option(name: .long, help: "Keep process alive for stdin/stdio mode")
    var stdio: Bool = false
}

enum Operation: String, ExpressibleByArgument {
    case parse
    case analyze
    case batch
    case stdio
}

enum OutputFormat: String, ExpressibleByArgument {
    case json
    case ndjson
}

// MARK: - Main Execution

extension AnigmaASTServices {
    mutating func run() throws {
        switch operation {
        case .parse:
            try runParse()
        case .analyze:
            try runAnalyze()
        case .batch:
            try runBatch()
        case .stdio:
            try runStdio()
        }
    }

    private func runParse() throws {
        guard let file = file else {
            throw ValidationError.missingFile
        }

        let result = try parseFile(file)
        outputResult(result)
    }

    private func runAnalyze() throws {
        guard let file = file else {
            throw ValidationError.missingFile
        }

        let result = try analyzeFile(file, visitors: visitors.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        outputResult(result)
    }

    private func runBatch() throws {
        guard let directory = directory else {
            throw ValidationError.missingDirectory
        }

        let results = try analyzeDirectory(directory, visitors: visitors.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        for result in results {
            outputResult(result)
        }
    }

    private func runStdio() throws {
        // Keep process alive for stdin/stdio mode
        let stdin = FileHandle.standardInput
        let stdout = FileHandle.standardOutput

        while true {
            let data = stdin.availableData
            guard !data.isEmpty else { break }
            guard !data.isEmpty else { continue }

            let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines)
            guard let line = line else { continue }

            do {
                let request = try JSONDecoder().decode(BatchRequest.self, from: line.data(using: .utf8)!)
                let result = try processBatchRequest(request)
                let output = try JSONEncoder().encode(result)
                stdout.write(output)
                stdout.write("\n".data(using: .utf8)!)
            } catch {
                let errorResult = ASTResult.error(
                    schemaVersion: "1.0.0",
                    requestId: UUID().uuidString,
                    ok: false,
                    error: ErrorInfo(
                        code: "PROCESSING_ERROR",
                        message: error.localizedDescription
                    )
                )
                let output = try JSONEncoder().encode(errorResult)
                stdout.write(output)
                stdout.write("\n".data(using: .utf8)!)
            }
        }
    }
}

// MARK: - Data Models

struct BatchRequest: Codable {
    let operation: String
    let file: String?
    let visitors: [String]?
}

struct Finding: Codable {
    let type: String
    let ruleId: String
    let severity: String
    let message: String
    let filePath: String
    let lineNumber: Int
    let columnNumber: Int?
    let context: String
}

struct ErrorInfo: Codable {
    let code: String
    let message: String
}

enum ResultType: String, Codable {
    case parse
    case analyze
    case error
}

struct ASTResult: Codable {
    let type: ResultType
    let schemaVersion: String
    let requestId: String
    let ok: Bool
    let filePath: String?
    let sourceSize: Int?
    let nodeCount: Int?
    let parseTime: Date?
    let visitors: [String]?
    let findings: [Finding]?
    let analysisTime: Date?
    let error: ErrorInfo?
    
    private init(
        type: ResultType,
        schemaVersion: String,
        requestId: String,
        ok: Bool,
        filePath: String? = nil,
        sourceSize: Int? = nil,
        nodeCount: Int? = nil,
        parseTime: Date? = nil,
        visitors: [String]? = nil,
        findings: [Finding]? = nil,
        analysisTime: Date? = nil,
        error: ErrorInfo? = nil
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
    
    static func parse(
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
    
    static func analyze(
        schemaVersion: String,
        requestId: String,
        ok: Bool,
        filePath: String,
        sourceSize: Int,
        visitors: [String],
        findings: [Finding],
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
    
    static func error(
        schemaVersion: String,
        requestId: String,
        ok: Bool,
        error: ErrorInfo
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

enum ValidationError: LocalizedError {
    case missingFile
    case missingDirectory
    case unknownOperation(String)

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "File path required"
        case .missingDirectory:
            return "Directory path required"
        case .unknownOperation(let op):
            return "Unknown operation: \(op)"
        }
    }
}

// MARK: - Core Processing

private func parseFile(_ path: String) throws -> ASTResult {
    let source = try String(contentsOfFile: path, encoding: .utf8)
    let syntax = try Parser.parse(source: source)

    return ASTResult.parse(
        schemaVersion: "1.0.0",
        requestId: UUID().uuidString,
        ok: true,
        filePath: path,
        sourceSize: source.count,
        nodeCount: countNodes(syntax),
        parseTime: Date()
    )
}

private func analyzeFile(_ path: String, visitors: [String]) throws -> ASTResult {
    let source = try String(contentsOfFile: path, encoding: .utf8)
    let syntax = try Parser.parse(source: source)

    var findings: [Finding] = []

    // Run requested visitors
    if visitors.contains("security") {
        findings.append(contentsOf: runSecurityVisitor(syntax: syntax, filePath: path, source: source))
    }

    if visitors.contains("quality") {
        findings.append(contentsOf: runQualityVisitor(syntax: syntax, filePath: path, source: source))
    }

    return ASTResult.analyze(
        schemaVersion: "1.0.0",
        requestId: UUID().uuidString,
        ok: true,
        filePath: path,
        sourceSize: source.count,
        visitors: visitors,
        findings: findings,
        analysisTime: Date()
    )
}

private func analyzeDirectory(_ path: String, visitors: [String]) throws -> [ASTResult] {
    let fileManager = FileManager.default
    let swiftFiles = try fileManager.contentsOfDirectory(atPath: path)
        .filter { $0.hasSuffix(".swift") }
        .map { "\(path)/\($0)" }

    var results: [ASTResult] = []
    for file in swiftFiles {
        do {
            let result = try analyzeFile(file, visitors: visitors)
            results.append(result)
        } catch {
            let errorResult = ASTResult.error(
                schemaVersion: "1.0.0",
                requestId: UUID().uuidString,
                ok: false,
                error: ErrorInfo(
                    code: "FILE_ERROR",
                    message: "Failed to analyze \(file): \(error.localizedDescription)"
                )
            )
            results.append(errorResult)
        }
    }

    return results
}

private func processBatchRequest(_ request: BatchRequest) throws -> ASTResult {
    switch request.operation {
    case "parse":
        guard let filePath = request.file else {
            throw ValidationError.missingFile
        }
        return try parseFile(filePath)
    case "analyze":
        guard let filePath = request.file else {
            throw ValidationError.missingFile
        }
        return try analyzeFile(filePath, visitors: request.visitors ?? ["security", "quality"])
    default:
        throw ValidationError.unknownOperation(request.operation)
    }
}

// MARK: - Visitor Implementations

private func runSecurityVisitor(syntax: SourceFileSyntax, filePath: String, source: String) -> [Finding] {
    var findings: [Finding] = []

    // Simple string-based security analysis
    let lines = source.components(separatedBy: .newlines)
    let secretKeywords = ["api_key", "api-key", "secret_key", "secret-key", "password", "token"]

    for (index, line) in lines.enumerated() {
        let lineNumber = index + 1
        let lowerLine = line.lowercased()

        for keyword in secretKeywords {
            if lowerLine.contains(keyword) {
                findings.append(Finding(
                    type: "security",
                    ruleId: "sec-secret-001",
                    severity: "error",
                    message: "Potential hardcoded secret keyword '\(keyword)'",
                    filePath: filePath,
                    lineNumber: lineNumber,
                    columnNumber: nil,
                    context: line.trimmingCharacters(in: .whitespaces)
                ))
            }
        }
    }

    return findings
}

private func runQualityVisitor(syntax: SourceFileSyntax, filePath: String, source: String) -> [Finding] {
    var findings: [Finding] = []

    let lines = source.components(separatedBy: .newlines)

    for (index, line) in lines.enumerated() {
        let lineNumber = index + 1
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)

        // Skip comments
        if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") {
            continue
        }

        // Check for force unwrapping
        if line.contains("!") {
            findings.append(Finding(
                type: "quality",
                ruleId: "quality-002",
                severity: "warning",
                message: "Force unwrapping detected",
                filePath: filePath,
                lineNumber: lineNumber,
                columnNumber: nil,
                context: line.trimmingCharacters(in: .whitespaces)
            ))
        }

        // Check for long lines
        if line.count > 120 {
            findings.append(Finding(
                type: "quality",
                ruleId: "quality-003",
                severity: "info",
                message: "Line exceeds 120 characters",
                filePath: filePath,
                lineNumber: lineNumber,
                columnNumber: nil,
                context: String(line.prefix(120)) + "..."
            ))
        }
    }

    return findings
}

// MARK: - Utility Functions

private func countNodes(_ syntax: SyntaxProtocol) -> Int {
    // For now, return a simple estimate - can be improved later
    return syntax.description.count / 10 // Rough estimate of nodes
}

private func outputResult(_ result: ASTResult) {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let json = try encoder.encode(result)
        print(String(data: json, encoding: .utf8)!)
    } catch {
        let errorResult = ASTResult.error(
            schemaVersion: "1.0.0",
            requestId: UUID().uuidString,
            ok: false,
            error: ErrorInfo(
                code: "JSON_ERROR",
                message: "Failed to encode result: \(error.localizedDescription)"
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let json = try! encoder.encode(errorResult)
        print(String(data: json, encoding: .utf8)!)
    }
}
