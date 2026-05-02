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
//  Enhanced with daemon delegation and in-process execution options.
//

import Foundation
import SwiftSyntax
import SwiftParser
import ArgumentParser
import AnigmaASTServicesCore
import AnigmaSidecar
import AnigmaPrimitives
import CryptoKit

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
    
    @Option(name: .long, help: "Execution mode: daemon, in-process, subprocess")
    var executionMode: ExecutionMode = .inProcess

    @Option(name: .long, help: "Daemon socket path (for daemon mode)")
    var daemonSocket: String?
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

enum ExecutionMode: String, ExpressibleByArgument {
    case daemon
    case inProcess = "in-process"
    case subprocess
}

// MARK: - Main Execution

extension AnigmaASTServices {
    mutating func run() async throws {
        switch operation {
        case .parse:
            try await runParse()
        case .analyze:
            try await runAnalyze()
        case .batch:
            try await runBatch()
        case .stdio:
            try await runStdio()
        }
    }

    private func runParse() async throws {
        guard let file = file else {
            throw ValidationError.missingFile
        }

        let result = try await executeParse(file: file, visitors: parseVisitors())
        outputResult(result)
    }

    private func runAnalyze() async throws {
        guard let file = file else {
            throw ValidationError.missingFile
        }

        let result = try await executeAnalyze(file: file, visitors: parseVisitors())
        outputResult(result)
    }

    private func runBatch() async throws {
        guard let directory = directory else {
            throw ValidationError.missingDirectory
        }

        let results = try await executeBatch(directory: directory, visitors: parseVisitors())
        for result in results {
            outputResult(result)
        }
    }

    private func runStdio() async throws {
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
                let request = try JSONDecoder().decode(ASTBatchRequest.self, from: line.data(using: .utf8)!)
                let result = try await processBatchRequest(request)
                let output = try JSONEncoder().encode(result)
                stdout.write(output)
                stdout.write("\n".data(using: .utf8)!)
            } catch {
                let errorResult = ASTResult.error(
                    schemaVersion: "1.0.0",
                    requestId: UUID().uuidString,
                    ok: false,
                    error: ASTErrorInfo(
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

    // MARK: - Execution Mode Routing

    private func executeParse(file: String, visitors: [String]) async throws -> ASTResult {
        switch executionMode {
        case .daemon:
            return try await executeViaDaemon(task: .parse, file: file, visitors: visitors)
        case .inProcess:
            return try await executeInProcess(task: .parse, file: file, visitors: visitors)
        case .subprocess:
            return try executeLegacyParse(file: file)
        }
    }

    private func executeAnalyze(file: String, visitors: [String]) async throws -> ASTResult {
        switch executionMode {
        case .daemon:
            return try await executeViaDaemon(task: .analyze, file: file, visitors: visitors)
        case .inProcess:
            return try await executeInProcess(task: .analyze, file: file, visitors: visitors)
        case .subprocess:
            return try executeLegacyAnalyze(file: file, visitors: visitors)
        }
    }

    private func executeBatch(directory: String, visitors: [String]) async throws -> [ASTResult] {
        // For batch, we can still delegate to daemon or in-process worker
        // For simplicity, we'll process each file individually
        let fileManager = FileManager.default
        let swiftFiles = try fileManager.contentsOfDirectory(atPath: directory)
            .filter { $0.hasSuffix(".swift") }
            .map { "\(directory)/\($0)" }

        var results: [ASTResult] = []
        for file in swiftFiles {
            do {
                let result = try await executeAnalyze(file: file, visitors: visitors)
                results.append(result)
            } catch {
                let errorResult = ASTResult.error(
                    schemaVersion: "1.0.0",
                    requestId: UUID().uuidString,
                    ok: false,
                    error: ASTErrorInfo(
                        code: "FILE_ERROR",
                        message: "Failed to analyze \(file): \(error.localizedDescription)"
                    )
                )
                results.append(errorResult)
            }
        }
        return results
    }

    // MARK: - Daemon Execution

    private func executeViaDaemon(task: ASTTaskKind, file: String, visitors: [String]) async throws -> ASTResult {
        let socketPath = try resolveDaemonSocketPath()
        let bridge = try await SidecarBridge.create(
            socketPath: socketPath,
            clientName: "anigma-ast-services",
            scopes: ["job.submit", "job.read", "vault.read", "vault.write"]
        )

        // 1. Ingest input file
        let fileData = try Data(contentsOf: URL(fileURLWithPath: file))
        let ingestResponse = try await bridge.ingestArtifact(
            data: fileData,
            kind: "source.swift",
            mediaType: "text/x-swift",
            filenameHint: URL(fileURLWithPath: file).lastPathComponent
        )
        let inputHash = ingestResponse.artifact.hash

        // 2. Prepare Config
        let operation: ASTOperation
        switch task {
        case .parse: operation = .parse
        case .analyze: operation = .analyze
        case .batch: operation = .batch
        default: throw ValidationError.unknownOperation(task.rawValue)
        }

        let config = ASTAnalysisConfig(
            operation: operation,
            visitors: visitors,
            maxFileSize: 100 * 1024 * 1024,
            cacheEnabled: true,
            cacheSizeLimit: nil,
            timeoutSeconds: 60
        )
        let configData = try JSONEncoder().encode(config)

        // 3. Submit Job
        let jobSpec = AnigmaJobSpec(
            kind: "ast.analyze",
            configCanonical: configData,
            inputs: [
                AnigmaArtifactRef(hash: inputHash, mediaType: "text/x-swift", sizeBytes: UInt64(fileData.count))
            ]
        )
        
        let submitResponse = try await bridge.submitJob(jobSpec)
        guard let jobId = submitResponse.jobId else {
            throw ValidationError.executionFailed("Daemon accepted job but returned no Job ID: \(submitResponse.error?.message ?? "unknown error")")
        }

        // 4. Wait for completion
        for try await event in try await bridge.streamJobEvents(jobId: jobId) {
            if event.type == "completed" {
                // Get job status to find outputs
                let jobStatus = try await bridge.getJobStatus(jobId: jobId)
                
                for output in jobStatus.outputs {
                    if output.mediaType == "application/json" {
                         let retrieveResponse = try await bridge.retrieveArtifact(hash: output.hash)
                         let data = retrieveResponse.data
                         
                         // Try to decode as ASTResult
                         if let result = try? JSONDecoder().decode(ASTResult.self, from: data) {
                             return result
                         }
                    }
                }
                
                throw ValidationError.executionFailed("Job completed but no valid ASTResult found in outputs")
            } else if event.type == "failed" {
                throw ValidationError.executionFailed("Job failed: \(event.message)")
            }
        }
        
        throw ValidationError.executionFailed("Job stream ended without completion")
    }

    private func resolveDaemonSocketPath() throws -> String {
        // 1. Command-line argument
        if let socket = daemonSocket {
            return socket
        }

        // 2. Environment variable
        if let envSocket = ProcessInfo.processInfo.environment["ANIGMA_DAEMON_SOCKET"] {
            return envSocket
        }

        // 3. Default socket path
        let defaultSocket = "/tmp/anigmad.sock"
        if FileManager.default.fileExists(atPath: defaultSocket) {
            return defaultSocket
        }

        throw ValidationError.daemonUnavailable("Daemon socket not found. Please specify --daemon-socket or ensure daemon is running.")
    }

    // MARK: - In-Process Execution

    private func executeInProcess(task: ASTTaskKind, file: String, visitors: [String]) async throws -> ASTResult {
        let worker = ASTWorker()
        let fileData = try Data(contentsOf: URL(fileURLWithPath: file))
        let fileHash = SHA256.hash(data: fileData).compactMap { String(format: "%02x", $0) }.joined()

        let request = ASTWorkerRequest(
            requestId: UUID().uuidString,
            runId: "cli-in-process",
            stepId: "ast-\(task.rawValue)",
            task: task,
            inputs: [ASTArtifactRef(path: file, hash: fileHash)],
            options: ASTTaskOptions(visitors: visitors)
        )

        let response = try await worker.performTask(request)
        guard response.status == .completed else {
            throw ValidationError.executionFailed("AST worker failed: \(response.errorMessage ?? "unknown error")")
        }

        // Read result from output artifact
        guard let output = response.outputs.first else {
            throw ValidationError.executionFailed("No output produced")
        }

        let resultData = try Data(contentsOf: URL(fileURLWithPath: output.path))
        return try JSONDecoder().decode(ASTResult.self, from: resultData)
    }

    // MARK: - Legacy Subprocess Execution (Original Implementation)

    private func executeLegacyParse(file: String) throws -> ASTResult {
        let source = try String(contentsOfFile: file, encoding: .utf8)
        let syntax = try Parser.parse(source: source)

        return ASTResult.parse(
            schemaVersion: "1.0.0",
            requestId: UUID().uuidString,
            ok: true,
            filePath: file,
            sourceSize: source.count,
            nodeCount: countNodes(syntax),
            parseTime: Date()
        )
    }

    private func executeLegacyAnalyze(file: String, visitors: [String]) throws -> ASTResult {
        let source = try String(contentsOfFile: file, encoding: .utf8)
        let syntax = try Parser.parse(source: source)

        var findings: [ASTFinding] = []

        // Run requested visitors
        if visitors.contains("security") {
            findings.append(contentsOf: runSecurityVisitor(syntax: syntax, filePath: file, source: source))
        }

        if visitors.contains("quality") {
            findings.append(contentsOf: runQualityVisitor(syntax: syntax, filePath: file, source: source))
        }

        return ASTResult.analyze(
            schemaVersion: "1.0.0",
            requestId: UUID().uuidString,
            ok: true,
            filePath: file,
            sourceSize: source.count,
            visitors: visitors,
            findings: findings,
            analysisTime: Date()
        )
    }

    // MARK: - Utility Methods

    private func parseVisitors() -> [String] {
        return visitors.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func processBatchRequest(_ request: ASTBatchRequest) async throws -> ASTResult {
        switch request.operation {
        case "parse":
            guard let filePath = request.file else {
                throw ValidationError.missingFile
            }
            return try await executeParse(file: filePath, visitors: request.visitors ?? ["security", "quality"])
        case "analyze":
            guard let filePath = request.file else {
                throw ValidationError.missingFile
            }
            return try await executeAnalyze(file: filePath, visitors: request.visitors ?? ["security", "quality"])
        default:
            throw ValidationError.unknownOperation(request.operation)
        }
    }

    private func outputResult(_ result: ASTResult) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            
            let json = try encoder.encode(result)
            print(String(data: json, encoding: .utf8)!)
        } catch {
            let errorResult = ASTResult.error(
                schemaVersion: "1.0.0",
                requestId: UUID().uuidString,
                ok: false,
                error: ASTErrorInfo(
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
}

// MARK: - Visitor Implementations

private func runSecurityVisitor(syntax: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding] {
    var findings: [ASTFinding] = []

    // Simple string-based security analysis
    let lines = source.components(separatedBy: .newlines)
    let secretKeywords = ["api_key", "api-key", "secret_key", "secret-key", "password", "token"]

    for (index, line) in lines.enumerated() {
        let lineNumber = index + 1
        let lowerLine = line.lowercased()

        for keyword in secretKeywords {
            if lowerLine.contains(keyword) {
                findings.append(ASTFinding(
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

private func runQualityVisitor(syntax: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding] {
    var findings: [ASTFinding] = []

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
            findings.append(ASTFinding(
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
            findings.append(ASTFinding(
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

// MARK: - Errors

enum ValidationError: LocalizedError {
    case missingFile
    case missingDirectory
    case unknownOperation(String)
    case daemonUnavailable(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "File path required"
        case .missingDirectory:
            return "Directory path required"
        case .unknownOperation(let op):
            return "Unknown operation: \(op)"
        case .daemonUnavailable(let reason):
            return "Daemon unavailable: \(reason)"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        }
    }
}

// MARK: - Daemon Configuration Models

private enum ASTOperation: String, Codable {
    case parse = "parse"
    case analyze = "analyze"
    case batch = "batch"
}

private struct ASTAnalysisConfig: Codable {
    let operation: ASTOperation
    let visitors: [String]
    let maxFileSize: Int
    let cacheEnabled: Bool
    let cacheSizeLimit: Int?
    let timeoutSeconds: Int
}
