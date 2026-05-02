//
//  AntigravityInferenceAdapter.swift
//  AnigmaDaemonCore
//
//  Bridges AntigravityService to the standard InferencePlane protocol.
//

import Foundation
import InferenceCore
import AnigmaPrimitives

public actor AntigravityInferenceAdapter: InferencePlane {
    private let service: AntigravityService
    
    public init(service: AntigravityService) {
        self.service = service
    }
    
    public func perform(_ request: InferenceRequest) async throws -> InferenceResponse {
        switch request.task {
        case .chat, .textGeneration:
            return try await handleChat(request)
        case .embedding, .embed:
            throw InferenceError.unavailable("Embeddings not supported via Antigravity gateway yet")
        case .rerank:
            throw InferenceError.unavailable("Reranking not supported via Antigravity gateway")
        case .summarize, .classify, .toolCall, .codeGeneration, .codeExplanation, .extraction, .translation:
            throw InferenceError.unavailable("Task type not supported via Antigravity gateway yet")
        }
    }
    
    private func handleChat(_ request: InferenceRequest) async throws -> InferenceResponse {
        // Map request to Antigravity format
        let model = request.modelID ?? "gemini-1.5-pro"
        
        let content = AntigravityContent(
            role: "user",
            parts: [AntigravityPart(text: request.input)]
        )
        
        // Extract config from options
        var temperature: Double?
        var maxTokens: Int?
        
        if let tempVal = request.options["temperature"], let val = tempVal.asDouble {
            temperature = val
        }
        
        if let maxVal = request.options["max_tokens"], let val = maxVal.asInt {
            maxTokens = val
        }
        
        let config = AntigravityGenerationConfig(
            temperature: temperature,
            maxOutputTokens: maxTokens
        )
        
        // Accumulate stream
        var fullText = ""
        let stream = try await service.streamGenerateContent(
            model: model,
            messages: [content],
            config: config
        )
        
        for try await chunk in stream {
            fullText += chunk
        }
        
        // Return standard response
        return InferenceResponse(
            output: fullText,
            usage: InferenceUsage(inputTokens: nil, outputTokens: nil), // Usage not always available in stream
            metadata: ["provider": "google-antigravity", "model": model]
        )
    }
}
