//
//  ASTWorker.swift
//  AnigmaASTServices
//
//  Direct in-process AST worker API for daemon integration.
//  Eliminates need for separate anigma-ast-services executable process.
//

import Foundation
import SwiftSyntax
import SwiftParser
import CryptoKit

// MARK: - AST Worker

/// Direct in-process AST worker for daemon integration.
/// Executes AST tasks using SwiftAstLens caching without spawning separate processes.
public actor ASTWorker {
    private let astLens: SwiftAstLens
    private let cacheEnabled: Bool
    private let maxFileSize: Int
    private let metricsCollector: ASTWorkerMetricsCollector?
    
    /// Initialize AST worker with configuration.
    /// - Parameters:
    ///   - cacheEnabled: Whether to use AST caching (default true)
    ///   - maxFileSize: Maximum file size to process in bytes (default 10MB)
    ///   - cacheSizeLimit: Cache size limit in bytes (default 100MB)
    ///   - enableMetrics: Whether to collect performance metrics (default true)
    public init(
        cacheEnabled: Bool = true,
        maxFileSize: Int = 10 * 1024 * 1024, // 10MB
        cacheSizeLimit: Int? = 100 * 1024 * 1024, // 100MB
        enableMetrics: Bool = true
    ) {
        self.cacheEnabled = cacheEnabled
        self.maxFileSize = maxFileSize
        self.astLens = SwiftAstLens()
        self.metricsCollector = enableMetrics ? ASTWorkerMetricsCollector() : nil
        
        // Configure cache if enabled
        if cacheEnabled {
            // SwiftAstLens already has 100MB default, but we could expose configuration
            // For now, rely on SwiftAstLens defaults
        }
    }
    
    /// Perform AST task asynchronously (in-process).
    /// - Parameter request: AST worker request
    /// - Returns: AST worker response
    public func performTask(_ request: ASTWorkerRequest) async throws -> ASTWorkerResponse {
        let start = Date()
        let operationId = "\(request.requestId)-\(UUID().uuidString.prefix(8))"
        
        // Start metrics collection
        metricsCollector?.startOperation(
            operationId: operationId,
            task: request.task,
            fileCount: request.inputs.count
        )
        
        // Validate request
        try validateRequest(request)
        
        // Use outputDirectory from request or create temporary directory
        let baseOutput = request.options.outputDirectory ?? createTemporaryDirectory().path
        let outputDir = URL(fileURLWithPath: baseOutput)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        var outputs: [ASTWorkerArtifact] = []
        var processingError: Error?
        var totalFilesProcessed = 0
        var totalNodesProcessed = 0
        var cacheHits = 0
        var cacheMisses = 0
        
        do {
            for input in request.inputs {
                let (artifact, nodes, hit) = try await processInput(
                    request: request,
                    input: input,
                    outputDir: outputDir
                )
                outputs.append(artifact)
                totalFilesProcessed += 1
                totalNodesProcessed += nodes
                if hit {
                    cacheHits += 1
                } else {
                    cacheMisses += 1
                }
            }
        } catch {
            processingError = error
        }
        
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        
        // Estimate memory usage
        let estimatedMemory = estimateMemoryUsage(
            filesProcessed: totalFilesProcessed,
            nodesProcessed: totalNodesProcessed
        )
        
        // End metrics collection
        metricsCollector?.endOperation(
            operationId: operationId,
            success: processingError == nil,
            filesProcessed: totalFilesProcessed,
            nodesProcessed: totalNodesProcessed,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            memoryUsed: estimatedMemory
        )
        
        // Propagate any error that occurred during processing
        if let error = processingError {
            throw error
        }
        
        let metrics = ASTWorkerMetrics(
            durationMs: durationMs,
            filesProcessed: totalFilesProcessed,
            nodesProcessed: totalNodesProcessed,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            memoryBytes: estimatedMemory
        )
        
        // Compute binary hash for provenance (hash of this executable's code)
        let binaryHash = try computeBinaryHash()
        
        let engineMeta = ASTWorkerEngineMetadata(
            binaryHash: binaryHash,
            version: "1.0",
            engineId: "swift-ast-worker",
            swiftSyntaxVersion: "600.0.0" // TODO: Get actual SwiftSyntax version
        )
        
        return ASTWorkerResponse(
            requestId: request.requestId,
            status: .completed,
            outputs: outputs,
            metrics: metrics,
            engineMeta: engineMeta
        )
    }
    
    /// Perform AST task asynchronously.
    /// - Parameter request: AST worker request
    /// - Returns: AST worker response
    public func performTaskAsync(_ request: ASTWorkerRequest) async throws -> ASTWorkerResponse {
        // For now, just call synchronous version
        // In future, could run in background thread or process multiple files in parallel
        return try await performTask(request)
    }
    
    /// Clear AST cache
    public func clearCache(for filePath: String? = nil) async {
        await astLens.clearCache(for: filePath)
    }
    
    /// Get cache statistics
    public func cacheStats() async -> (entries: Int, sizeBytes: Int) {
        let stats = await astLens.cacheStats()
        return (stats.entries, stats.sizeBytes)
    }
    
    // MARK: - Private Methods
    
    private func createTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("ast-worker-\(UUID().uuidString)")
    }
    
    private func validateRequest(_ request: ASTWorkerRequest) throws {
        // Validate file sizes
        for input in request.inputs {
            let attributes = try FileManager.default.attributesOfItem(atPath: input.path)
            if let fileSize = attributes[.size] as? Int, fileSize > maxFileSize {
                throw ASTWorkerError.fileTooLarge(input.path, fileSize)
            }
            
            if !FileManager.default.fileExists(atPath: input.path) {
                throw ASTWorkerError.fileNotFound(input.path)
            }
        }
        
        // Validate visitors
        let validVisitors = ["security", "quality", "concurrency", "architecture"]
        for visitor in request.options.visitors {
            if !validVisitors.contains(visitor) {
                throw ASTWorkerError.invalidRequest("Invalid visitor: \(visitor)")
            }
        }
    }
    
    private func processInput(
        request: ASTWorkerRequest,
        input: ASTArtifactRef,
        outputDir: URL
    ) async throws -> (ASTWorkerArtifact, Int, Bool) {
        let filePath = input.path
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ASTWorkerError.fileNotFound(filePath)
        }
        
        // Process based on task type
        switch request.task {
        case .parse:
            return try await processParse(
                filePath: filePath,
                outputDir: outputDir,
                requestId: request.requestId
            )
        case .analyze:
            return try await processAnalyze(
                filePath: filePath,
                visitors: request.options.visitors,
                outputDir: outputDir,
                requestId: request.requestId
            )
        case .batch:
            // Batch processing handled at higher level
            throw ASTWorkerError.invalidRequest("Batch task should be handled by caller")
        case .search:
            throw ASTWorkerError.invalidRequest("Search task not yet implemented")
        case .transform:
            throw ASTWorkerError.invalidRequest("Transform task not yet implemented")
        }
    }
    
    private func processParse(
        filePath: String,
        outputDir: URL,
        requestId: String
    ) async throws -> (ASTWorkerArtifact, Int, Bool) {
        let startTime = Date()
        
        // Get AST from cache or parse
        let (ast, contentHash) = try await astLens.ast(for: filePath)
        let wasCached = contentHash != "" // Simplified - actual caching determined by SwiftAstLens
        
        // Count nodes
        let nodeCount = countNodes(ast)
        
        // Read source for size
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        let sourceSize = source.count
        
        // Create result
        let result = ASTResult.parse(
            schemaVersion: "1.0",
            requestId: requestId,
            ok: true,
            filePath: filePath,
            sourceSize: sourceSize,
            nodeCount: nodeCount,
            parseTime: startTime
        )
        
        // Write result to output directory
        let outputPath = outputDir.appendingPathComponent("\(contentHash).parse.json").path
        try writeResult(result, to: outputPath)
        
        // Compute hash of result
        let resultData = try JSONEncoder().encode(result)
        let resultHash = sha256Hex(resultData)
        
        let artifact = ASTWorkerArtifact(
            path: outputPath,
            hash: resultHash,
            normalizedHash: resultHash
        )
        
        return (artifact, nodeCount, wasCached)
    }
    
    private func processAnalyze(
        filePath: String,
        visitors: [String],
        outputDir: URL,
        requestId: String
    ) async throws -> (ASTWorkerArtifact, Int, Bool) {
        let startTime = Date()
        
        // Get AST from cache or parse
        let (ast, contentHash) = try await astLens.ast(for: filePath)
        let wasCached = contentHash != "" // Simplified
        
        // Count nodes
        let nodeCount = countNodes(ast)
        
        // Read source for size
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        let sourceSize = source.count
        
        // Run visitors using registry
        let findings = ASTRuleRegistry.shared.runRules(
            visitors,
            ast: ast,
            filePath: filePath,
            source: source
        )
        
        // Create result
        let result = ASTResult.analyze(
            schemaVersion: "1.0",
            requestId: requestId,
            ok: true,
            filePath: filePath,
            sourceSize: sourceSize,
            visitors: visitors,
            findings: findings,
            analysisTime: Date()
        )
        
        // Write result to output directory
        let outputPath = outputDir.appendingPathComponent("\(contentHash).analyze.json").path
        try writeResult(result, to: outputPath)
        
        // Compute hash of result
        let resultData = try JSONEncoder().encode(result)
        let resultHash = sha256Hex(resultData)
        
        let artifact = ASTWorkerArtifact(
            path: outputPath,
            hash: resultHash,
            normalizedHash: resultHash
        )
        
        return (artifact, nodeCount, wasCached)
    }
    
    private func countNodes(_ syntax: SourceFileSyntax) -> Int {
        // Simple node count - can be improved
        var count = 0
        let visitor = NodeCountingVisitor(increment: { count += 1 })
        _ = visitor.visit(syntax)
        return count
    }
    
    private func writeResult(_ result: ASTResult, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(result)
        try data.write(to: URL(fileURLWithPath: path))
    }
    
    private func computeBinaryHash() throws -> String {
        // For in-process execution, compute hash of this module's code
        // For simplicity, use a constant for now
        return "in-process-ast-worker-v1"
    }
    
    private func estimateMemoryUsage(filesProcessed: Int, nodesProcessed: Int) -> Int {
        // Rough estimate: ~100 bytes per AST node + overhead
        return nodesProcessed * 100 + filesProcessed * 1024
    }
}

// MARK: - Visitor Implementations

private extension ASTWorker {
    func runSecurityVisitor(ast: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding] {
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
    
    func runQualityVisitor(ast: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding] {
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
    
    func runConcurrencyVisitor(ast: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding] {
        var findings: [ASTFinding] = []
        
        // Simple concurrency analysis
        let lines = source.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check for DispatchQueue usage without MainActor
            if (line.contains("DispatchQueue") || line.contains("Task")) && 
               !line.contains("@MainActor") && 
               !trimmedLine.hasPrefix("//") {
                findings.append(ASTFinding(
                    type: "concurrency",
                    ruleId: "concurrency-001",
                    severity: "warning",
                    message: "Potential concurrency issue - consider @MainActor annotation",
                    filePath: filePath,
                    lineNumber: lineNumber,
                    columnNumber: nil,
                    context: line.trimmingCharacters(in: .whitespaces)
                ))
            }
        }
        
        return findings
    }
    
    func runArchitectureVisitor(ast: SourceFileSyntax, filePath: String, source: String) -> [ASTFinding] {
        var findings: [ASTFinding] = []
        
        // Simple architecture analysis - count class members
        let lines = source.components(separatedBy: .newlines)
        var inClass = false
        var classStartLine = 0
        var memberCount = 0
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("class ") || trimmedLine.hasPrefix("struct ") {
                if inClass && memberCount > 20 {
                    findings.append(ASTFinding(
                        type: "architecture",
                        ruleId: "architecture-001",
                        severity: "warning",
                        message: "Class/struct too large (\(memberCount) members) - consider splitting",
                        filePath: filePath,
                        lineNumber: classStartLine,
                        columnNumber: nil,
                        context: lines[classStartLine - 1].trimmingCharacters(in: .whitespaces)
                    ))
                }
                
                inClass = true
                classStartLine = lineNumber
                memberCount = 0
            } else if inClass && (trimmedLine.hasPrefix("func ") || trimmedLine.hasPrefix("var ") || trimmedLine.hasPrefix("let ")) {
                memberCount += 1
            } else if trimmedLine.hasPrefix("}") && inClass {
                if memberCount > 20 {
                    findings.append(ASTFinding(
                        type: "architecture",
                        ruleId: "architecture-001",
                        severity: "warning",
                        message: "Class/struct too large (\(memberCount) members) - consider splitting",
                        filePath: filePath,
                        lineNumber: classStartLine,
                        columnNumber: nil,
                        context: lines[classStartLine - 1].trimmingCharacters(in: .whitespaces)
                    ))
                }
                inClass = false
            }
        }
        
        return findings
    }
}

// MARK: - Helper Types

private class NodeCountingVisitor: SyntaxAnyVisitor {
    private let increment: () -> Void
    
    init(increment: @escaping () -> Void) {
        self.increment = increment
        super.init(viewMode: .sourceAccurate)
    }
    
    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        increment()
        return .visitChildren
    }
}

private func sha256Hex(_ data: Data) -> String {
    let hashed = SHA256.hash(data: data)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}