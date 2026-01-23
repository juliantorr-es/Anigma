//
//  CodeGenerationWorker.swift
//  AnigmaDaemonCore
//
//  Worker for generating code using retrieved context chunks.
//

import Foundation
import AnigmaPrimitives
import AnigmaCore
import DatabaseCore
import ContextumModule
import InferenceCore

/// Configuration for code generation.
public struct CodeGenerationConfig: Codable, Sendable {
    public let instruction: String
    public let chunkIds: [String]
    public let language: String?
    
    public init(instruction: String, chunkIds: [String], language: String? = nil) {
        self.instruction = instruction
        self.chunkIds = chunkIds
        self.language = language
    }
}

/// Worker that executes code generation using the GenerateCodeTool.
public struct CodeGenerationWorker: JobWorker {
    public static let kind = "code.generate"
    
    public init() {}
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // 1. Decode configuration
        let jobConfig = try JSONDecoder().decode(CodeGenerationConfig.self, from: config)
        
        // 2. Initialize Infrastructure (similar to HarmoniaWorker)
        let dbPath = (NSHomeDirectory() as NSString).appendingPathComponent(".anigma/anigma.db")
        let dbActor = DatabaseActor(dbPath: dbPath)
        try await dbActor.open()
        
        // Initialize Contextum Database (The Engram Store)
        let contextumDB = try await ContextumDatabase(database: dbActor)
        
        // 3. Create Inference Authority
        // Use DaemonInferenceAuthority for real ml-worker execution
        let inferenceAuthority = DaemonInferenceAuthority()
        
        // 4. Create GenerateCodeTool
        let tool = GenerateCodeTool(contextumDB: contextumDB, inference: inferenceAuthority)
        
        // 5. Execute tool with decoded parameters
        let toolContext = SimpleToolContext(sessionId: UUID().uuidString, agentName: "code_generation_worker")
        let params = GenerateCodeTool.Parameters(
            instruction: jobConfig.instruction,
            chunkIds: jobConfig.chunkIds,
            language: jobConfig.language
        )
        
        let result = try await tool.execute(params: params, context: toolContext)
        
        // 6. Package result as output payload
        let resultData = try JSONEncoder().encode(result)
        let resultArtifact = JobOutputPayload(
            kind: "generated_code",
            mediaType: "application/json",
            data: resultData,
            filenameHint: "generated_code_\(UUID().uuidString.prefix(8)).json"
        )
        
        return [resultArtifact]
    }
}

/// Simple ToolContext implementation for worker usage.
private struct SimpleToolContext: ToolContext {
    let sessionId: String
    let agentName: String
    
    func updateMetadata(_ metadata: [String: Sendable]) async {
        // No-op for worker usage
    }
    
    func ask(permission: String, pattern: String) async throws {
        // Worker doesn't need interactive permissions; assume allowed
    }
}