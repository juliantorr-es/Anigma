//
//  GenerateCodeTool.swift
//  AnigmaDaemonCore
//
//  Tool for generating code using retrieved chunks as context.
//

import Foundation
import AnigmaPrimitives
import ContextumModule
import AnigmaCore
import InferenceCore
import HarmoniaModule // For ChatMessage if needed, though we might construct prompt manually

public struct GenerateCodeTool: Tool {
    public static let id = "generate_code"
    public static let description = "Generates code based on an instruction and a set of retrieved context chunks."
    
    private let contextumDB: ContextumDatabase
    private let inference: any InferenceAuthority
    
    public init(contextumDB: ContextumDatabase, inference: any InferenceAuthority) {
        self.contextumDB = contextumDB
        self.inference = inference
    }
    
    public struct Parameters: Codable, Sendable {
        public let instruction: String
        public let chunkIds: [String]
        public let language: String?
        
        public init(instruction: String, chunkIds: [String], language: String? = nil) {
            self.instruction = instruction
            self.chunkIds = chunkIds
            self.language = language
        }
    }
    
    public struct Metadata: Codable, Sendable {
        public let tokensGenerated: Int?
        public let modelUsed: String?
        public let latencyMs: Double?
        
        public init(tokensGenerated: Int? = nil, modelUsed: String? = nil, latencyMs: Double? = nil) {
            self.tokensGenerated = tokensGenerated
            self.modelUsed = modelUsed
            self.latencyMs = latencyMs
        }
    }
    
    public func execute(params: Parameters, context: ToolContext) async throws -> ToolResult<Metadata> {
        // 1. Retrieve Context from ContextumDatabase
        let chunks = try await contextumDB.getChunkContent(chunkIds: params.chunkIds)
        
        // 2. Construct Prompt/Context
        var contextString = ""
        for (index, chunk) in chunks.enumerated() {
            contextString += """
            [CHUNK \(index + 1)]
            Source: \(chunk.sourceId)
            Content:
            \(chunk.content)
            
            """
        }
        
        let systemPrompt = """
        You are an expert coding assistant. Your task is to generate code based strictly on the provided context chunks and the user's instruction.
        
        Guidelines:
        - Use the provided context to understand existing patterns, variable names, and architectural style.
        - Do not invent new libraries or patterns unless explicitly asked.
        - Output ONLY the requested code, or a brief explanation if code cannot be generated.
        - If the language is specified as '\(params.language ?? "unknown")', ensure the code matches that language.
        """
        
        let userPrompt = """
        Context:
        \(contextString)
        
        Instruction:
        \(params.instruction)
        """
        
        // 3. Call Inference Authority
        // We construct an InferenceRequest.
        // Since InferenceRequest takes a single "input" string, we'll combine system and user prompt 
        // or rely on a "chat" mode if the backend supports it.
        // However, InferenceRequest structure suggests a simple input. 
        // We will format it as a chat transcript for the model if it's a raw text model, 
        // or rely on the `task: .chat` kind to interpret the input potentially.
        // But `InferenceRequest` has `task: InferenceTaskKind`. 
        // We'll use `.chat` and assume the backend can handle the structured prompt in `input` 
        // or we'll construct a prompt string.
        
        // Let's assume we pass the full prompt in `input`.
        let fullPrompt = "\(systemPrompt)\n\n\(userPrompt)"
        
        let request = InferenceRequest(
            task: .chat, // Or .textGeneration depending on backend preference
            input: fullPrompt,
            options: [
                "temperature": .number(0.2), // Low temperature for code
                "max_tokens": .integer(2048)
            ]
        )
        
        // We use .ui priority for responsiveness since this is likely user-initiated
        let response = try await inference.chatCompletion(
            request,
            priority: .ui,
            speculativeConfig: nil,
            context: ExecutionContext(principal: .system) // Helper context
        )
        
        // 4. Return Result
        return ToolResult(
            title: "Generated Code",
            output: response.output,
            metadata: Metadata(
                tokensGenerated: response.usage.outputTokens,
                modelUsed: nil, // InferenceResponse doesn't seem to return model used in `output` (it's in InferenceResult wrapper usually)
                latencyMs: nil
            )
        )
    }
}
