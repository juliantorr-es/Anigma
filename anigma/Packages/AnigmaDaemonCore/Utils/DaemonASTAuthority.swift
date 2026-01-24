//
//  DaemonASTAuthority.swift
//  AnigmaDaemonCore
//
//  AST authority for daemon that executes AST analysis in-process.
//

import Foundation
import AnigmaCore
import AnigmaASTServices

private struct DaemonASTError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
    
    init(_ message: String) {
        self.message = message
    }
}

actor DaemonASTAuthority: ASTAuthority {
    private let astWorker: ASTWorker
    private let timeoutSeconds: Int
    private let maxFileSize: Int
    private let astWorkerAvailable: Bool
    private let fallbackAuthority: MockASTAuthority?
    
    init(
        cacheEnabled: Bool = true,
        maxFileSize: Int = 10 * 1024 * 1024, // 10MB
        cacheSizeLimit: Int? = 100 * 1024 * 1024, // 100MB
        timeoutSeconds: Int = 60,
        enableMetrics: Bool = true
    ) {
        self.timeoutSeconds = timeoutSeconds
        self.maxFileSize = maxFileSize
        
        // Initialize AST worker
        self.astWorker = ASTWorker(
            cacheEnabled: cacheEnabled,
            maxFileSize: maxFileSize,
            cacheSizeLimit: cacheSizeLimit,
            enableMetrics: enableMetrics
        )
        
        // AST worker is always available when initialized in-process
        self.astWorkerAvailable = true
        
        // Create fallback mock authority if needed
        self.fallbackAuthority = astWorkerAvailable ? nil : MockASTAuthority()
        
        print("[DaemonASTAuthority] AST worker initialized with cache: \(cacheEnabled), maxFileSize: \(maxFileSize)")
    }
    
    func parseFile(_ filePath: String) async throws -> ASTResult {
        guard astWorkerAvailable else {
            guard let fallback = fallbackAuthority else {
                throw DaemonASTError("AST worker not available and no fallback")
            }
            return try await fallback.parseFile(filePath)
        }
        
        // Create request for single file parse
        let request = ASTWorkerRequest(
            requestId: UUID().uuidString,
            runId: "daemon-parse-\(UUID().uuidString.prefix(8))",
            stepId: "parse",
            task: .parse,
            inputs: [
                ASTArtifactRef(path: filePath, hash: "input")
            ],
            options: ASTTaskOptions(
                visitors: [],
                maxFileSize: maxFileSize,
                cacheEnabled: true,
                cacheSizeLimit: 100 * 1024 * 1024,
                outputDirectory: nil
            )
        )
        
        do {
            let response = try await executeWithTimeout {
                try await self.astWorker.performTask(request)
            }
            
            guard response.status == .completed, let firstOutput = response.outputs.first else {
                throw DaemonASTError("AST worker response not successful: \(response.status)")
            }
            
            // Read result from output artifact
            let resultData = try Data(contentsOf: URL(fileURLWithPath: firstOutput.path))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let result = try decoder.decode(ASTResult.self, from: resultData)
            return result
            
        } catch {
            // If in-process fails, try fallback
            guard let fallback = fallbackAuthority else {
                throw error
            }
            return try await fallback.parseFile(filePath)
        }
    }
    
    func analyzeFile(_ filePath: String, visitors: [String]) async throws -> ASTResult {
        guard astWorkerAvailable else {
            guard let fallback = fallbackAuthority else {
                throw DaemonASTError("AST worker not available and no fallback")
            }
            return try await fallback.analyzeFile(filePath, visitors: visitors)
        }
        
        // Validate visitors
        let validVisitors = ["security", "quality", "concurrency", "architecture"]
        let filteredVisitors = visitors.filter { validVisitors.contains($0) }
        
        // Create request for single file analysis
        let request = ASTWorkerRequest(
            requestId: UUID().uuidString,
            runId: "daemon-analyze-\(UUID().uuidString.prefix(8))",
            stepId: "analyze",
            task: .analyze,
            inputs: [
                ASTArtifactRef(path: filePath, hash: "input")
            ],
            options: ASTTaskOptions(
                visitors: filteredVisitors,
                maxFileSize: maxFileSize,
                cacheEnabled: true,
                cacheSizeLimit: 100 * 1024 * 1024,
                outputDirectory: nil
            )
        )
        
        do {
            let response = try await executeWithTimeout {
                try await self.astWorker.performTask(request)
            }
            
            guard response.status == .completed, let firstOutput = response.outputs.first else {
                throw DaemonASTError("AST worker response not successful: \(response.status)")
            }
            
            // Read result from output artifact
            let resultData = try Data(contentsOf: URL(fileURLWithPath: firstOutput.path))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let result = try decoder.decode(ASTResult.self, from: resultData)
            return result
            
        } catch {
            // If in-process fails, try fallback
            guard let fallback = fallbackAuthority else {
                throw error
            }
            return try await fallback.analyzeFile(filePath, visitors: visitors)
        }
    }
    
    func analyzeDirectory(_ directoryPath: String, visitors: [String]) async throws -> [ASTResult] {
        guard astWorkerAvailable else {
            guard let fallback = fallbackAuthority else {
                throw DaemonASTError("AST worker not available and no fallback")
            }
            return try await fallback.analyzeDirectory(directoryPath, visitors: visitors)
        }
        
        // Get all Swift files in directory
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: directoryPath), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
        
        var swiftFiles: [String] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "swift" {
                swiftFiles.append(fileURL.path)
            }
        }
        
        if swiftFiles.isEmpty {
            return []
        }
        
        // Process files in batches to avoid memory issues
        let batchSize = 10
        var allResults: [ASTResult] = []
        
        for batchStart in stride(from: 0, to: swiftFiles.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, swiftFiles.count)
            let batch = Array(swiftFiles[batchStart..<batchEnd])
            
            // Create batch request
            let inputs = batch.map { ASTArtifactRef(path: $0, hash: "input") }
            let request = ASTWorkerRequest(
                requestId: UUID().uuidString,
                runId: "daemon-batch-\(UUID().uuidString.prefix(8))",
                stepId: "batch",
                task: .analyze,
                inputs: inputs,
                options: ASTTaskOptions(
                    visitors: visitors,
                    maxFileSize: maxFileSize,
                    cacheEnabled: true,
                    cacheSizeLimit: 100 * 1024 * 1024,
                    outputDirectory: nil
                )
            )
            
            do {
                let response = try await executeWithTimeout {
                    try await self.astWorker.performTask(request)
                }
                
                guard response.status == .completed else {
                    throw DaemonASTError("AST worker batch response not successful: \(response.status)")
                }
                
                // Read all output artifacts
                for output in response.outputs {
                    let resultData = try Data(contentsOf: URL(fileURLWithPath: output.path))
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    let result = try decoder.decode(ASTResult.self, from: resultData)
                    allResults.append(result)
                }
                
            } catch {
                // Skip failed batch, continue with others
                print("[DaemonASTAuthority] Batch processing failed: \(error)")
                continue
            }
        }
        
        return allResults
    }
    
    func getStatus() async -> ASTServiceStatus {
        let isAvailable = astWorkerAvailable
        let currentLoad = 0.0 // TODO: Track actual load
        
        var cacheStats: ASTCacheStats? = nil
        if astWorkerAvailable {
            // Get cache statistics from worker
            let (entries, sizeBytes) = await astWorker.cacheStats()
            cacheStats = ASTCacheStats(
                entries: entries,
                sizeBytes: sizeBytes,
                hitRate: 0.0 // TODO: Get actual hit rate from metrics
            )
        }
        
        let engineInfo = ASTEngineInfo(
            engineId: "swift-ast-worker",
            version: "1.0",
            swiftSyntaxVersion: "600.0.0" // TODO: Get actual version
        )
        
        return ASTServiceStatus(
            isAvailable: isAvailable,
            currentLoad: currentLoad,
            cacheStats: cacheStats,
            engineInfo: engineInfo
        )
    }
    
    // MARK: - Private Methods
    
    private func executeWithTimeout<T>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the operation
            group.addTask {
                try await operation()
            }
            
            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds) * 1_000_000_000)
                throw DaemonASTError("Operation timed out after \(timeoutSeconds) seconds")
            }
            
            // Wait for first completed task
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /// Clear AST cache
    public func clearCache(for filePath: String? = nil) async {
        await astWorker.clearCache(for: filePath)
    }
}

// MARK: - Mock AST Authority (Fallback)

private actor MockASTAuthority: ASTAuthority {
    func parseFile(_ filePath: String) async throws -> ASTResult {
        // Mock implementation
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        
        return ASTResult.parse(
            schemaVersion: "1.0",
            requestId: UUID().uuidString,
            ok: true,
            filePath: filePath,
            sourceSize: source.count,
            nodeCount: source.components(separatedBy: .newlines).count,
            parseTime: Date()
        )
    }
    
    func analyzeFile(_ filePath: String, visitors: [String]) async throws -> ASTResult {
        // Mock implementation with simple findings
        let source = try String(contentsOfFile: filePath, encoding: .utf8)
        
        var findings: [ASTFinding] = []
        
        // Add some mock findings based on visitors
        if visitors.contains("security") {
            findings.append(ASTFinding(
                type: "security",
                ruleId: "sec-mock-001",
                severity: "warning",
                message: "Mock security finding",
                filePath: filePath,
                lineNumber: 1,
                columnNumber: nil,
                context: "Mock context"
            ))
        }
        
        if visitors.contains("quality") {
            findings.append(ASTFinding(
                type: "quality",
                ruleId: "quality-mock-001",
                severity: "info",
                message: "Mock quality finding",
                filePath: filePath,
                lineNumber: 1,
                columnNumber: nil,
                context: "Mock context"
            ))
        }
        
        return ASTResult.analyze(
            schemaVersion: "1.0",
            requestId: UUID().uuidString,
            ok: true,
            filePath: filePath,
            sourceSize: source.count,
            visitors: visitors,
            findings: findings,
            analysisTime: Date()
        )
    }
    
    func analyzeDirectory(_ directoryPath: String, visitors: [String]) async throws -> [ASTResult] {
        // Mock implementation - return empty array
        return []
    }
    
    func getStatus() async -> ASTServiceStatus {
        return ASTServiceStatus(
            isAvailable: true,
            currentLoad: 0.0,
            cacheStats: nil,
            engineInfo: nil
        )
    }
}