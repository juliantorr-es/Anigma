//
//  ASTAnalysisWorker.swift
//  AnigmaDaemonCore
//
//  ast.analyze worker
//  Executes AST analysis via the in-process AST worker.
//

import Foundation
import ContractsCore
import ExecutionCore
import AnigmaASTServices

/// ast.analyze worker
/// Executes AST analysis via the in-process AST worker.
public struct ASTAnalysisWorker: JobWorker {
    public static let kind = "ast.analyze"
    
    public init() {}
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting AST analysis (via in-process AST worker)...\n", stderr)
        fflush(stderr)
        
        // Decode config
        let astConfig = ASTAnalysisConfig.decode(from: config)
        
        // Create AST authority
        let astAuthority = DaemonASTAuthority(
            cacheEnabled: astConfig.cacheEnabled,
            maxFileSize: astConfig.maxFileSize,
            cacheSizeLimit: astConfig.cacheSizeLimit,
            timeoutSeconds: astConfig.timeoutSeconds,
            enableMetrics: true
        )
        
        return try await WorkerTooling.withTemporaryDirectoryAsync(prefix: "ast-analysis-job") { dir in
            // 1. Write Input Files to Temp Dir
            var astInputs: [ASTArtifactRef] = []
            
            for (index, input) in inputs.enumerated() {
                guard let inputData = vaultData[input.hash] else {
                    throw WorkerError.missingInputData(hash: input.hash)
                }
                
                let inputPath = dir.appendingPathComponent("input-\(index).swift").path
                try inputData.write(to: URL(fileURLWithPath: inputPath))
                
                astInputs.append(ASTArtifactRef(path: inputPath, hash: input.hash))
            }
            
            // 2. Prepare Output Directory
            let outputDir = dir.appendingPathComponent("output")
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            
            var jobOutputs: [JobOutputPayload] = []
            
            // 3. Process based on operation type
            switch astConfig.operation {
            case .parse:
                // Parse each file
                for input in astInputs {
                    let result = try await astAuthority.parseFile(input.path)
                    
                    // Encode result
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    
                    let resultData = try encoder.encode(result)
                    
                    jobOutputs.append(JobOutputPayload(
                        data: resultData,
                        mediaType: "application/json",
                        kind: "ast.parse.result"
                    ))
                }
                
            case .analyze:
                // Analyze each file
                for input in astInputs {
                    let result = try await astAuthority.analyzeFile(
                        input.path,
                        visitors: astConfig.visitors
                    )
                    
                    // Encode result
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    
                    let resultData = try encoder.encode(result)
                    
                    jobOutputs.append(JobOutputPayload(
                        data: resultData,
                        mediaType: "application/json",
                        kind: "ast.analyze.result"
                    ))
                }
                
            case .batch:
                // Batch analysis of directory (if inputs represent a directory)
                if let firstInput = inputs.first,
                   let inputData = vaultData[firstInput.hash],
                   let inputString = String(data: inputData, encoding: .utf8),
                   inputString.contains("\n") || astInputs.count == 1 {
                    // Single file or directory path encoded as string
                    let path = inputString.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                       isDirectory.boolValue {
                        // Directory analysis
                        let results = try await astAuthority.analyzeDirectory(
                            path,
                            visitors: astConfig.visitors
                        )
                        
                        for result in results {
                            let encoder = JSONEncoder()
                            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                            encoder.dateEncodingStrategy = .iso8601
                            
                            let resultData = try encoder.encode(result)
                            
                            jobOutputs.append(JobOutputPayload(
                                data: resultData,
                                mediaType: "application/json",
                                kind: "ast.analyze.result"
                            ))
                        }
                    } else {
                        // Single file
                        let result = try await astAuthority.analyzeFile(
                            path,
                            visitors: astConfig.visitors
                        )
                        
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        encoder.dateEncodingStrategy = .iso8601
                        
                        let resultData = try encoder.encode(result)
                        
                        jobOutputs.append(JobOutputPayload(
                            data: resultData,
                            mediaType: "application/json",
                            kind: "ast.analyze.result"
                        ))
                    }
                } else {
                    // Multiple files as separate inputs
                    for input in astInputs {
                        let result = try await astAuthority.analyzeFile(
                            input.path,
                            visitors: astConfig.visitors
                        )
                        
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        encoder.dateEncodingStrategy = .iso8601
                        
                        let resultData = try encoder.encode(result)
                        
                        jobOutputs.append(JobOutputPayload(
                            data: resultData,
                            mediaType: "application/json",
                            kind: "ast.analyze.result"
                        ))
                    }
                }
            }
            
            // 4. Collect any metrics or additional outputs
            let status = await astAuthority.getStatus()
            let statusEncoder = JSONEncoder()
            let statusData = try statusEncoder.encode(status)
            
            jobOutputs.append(JobOutputPayload(
                data: statusData,
                mediaType: "application/json",
                kind: "ast.service.status"
            ))
            
            return jobOutputs
        }
    }
}

// MARK: - Configuration

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
    
    static let `default` = ASTAnalysisConfig(
        operation: .analyze,
        visitors: ["security", "quality"],
        maxFileSize: 10 * 1024 * 1024, // 10MB
        cacheEnabled: true,
        cacheSizeLimit: 100 * 1024 * 1024, // 100MB
        timeoutSeconds: 60
    )
    
    static func decode(from data: Data) -> ASTAnalysisConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(ASTAnalysisConfig.self, from: data)) ?? .default
    }
}