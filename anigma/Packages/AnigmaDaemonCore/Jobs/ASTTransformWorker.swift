//
//  ASTTransformWorker.swift
//  AnigmaDaemonCore
//
//  Worker for multi-pass AST transformations using RewritePipeline.
//

import Foundation
import AnigmaCore
import AnigmaASTServices
import ContractsCore

/// Configuration for AST transformation job.
public struct ASTTransformConfig: Codable, Sendable {
    public let files: [String]
    public let ruleNames: [String]
    public let dryRun: Bool
    
    public init(files: [String], ruleNames: [String], dryRun: Bool = false) {
        self.files = files
        self.ruleNames = ruleNames
        self.dryRun = dryRun
    }
}

/// Worker that executes AST rewrites.
public struct ASTTransformWorker: JobWorker {
    public static let kind = "ast.transform"
    
    public init() {}
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // 1. Decode Configuration
        let transformConfig = try JSONDecoder().decode(ASTTransformConfig.self, from: config)
        
        // 2. Prepare Pipeline
        let allRules: [String: any RewriteRule] = [
            "add-sendable": AddSendableToValueTypesRule()
        ]
        
        let selectedRules = transformConfig.ruleNames.compactMap { allRules[$0] }
        
        let pipeline = RewritePipeline(
            rules: selectedRules,
            config: PipelineConfig(dryRun: transformConfig.dryRun)
        )
        
        // 3. Prepare Items
        let items = transformConfig.files.map { path in
            RewritePipeline.PipelineItem(filePath: path)
        }
        
        // 4. Execute Pipeline
        let result = await pipeline.execute(on: items)
        
        // 5. Package Results
        let resultData = try JSONEncoder().encode(result)
        return [
            JobOutputPayload(
                data: resultData,
                mediaType: "application/json",
                kind: "ast.transform.result"
            )
        ]
    }
}
