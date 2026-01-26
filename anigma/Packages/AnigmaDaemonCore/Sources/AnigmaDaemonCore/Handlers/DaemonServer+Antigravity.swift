//
//  DaemonServer+Antigravity.swift
//  AnigmaDaemonCore
//
//  Handlers for Antigravity Model Services.
//

import Foundation
import AnigmaPrimitives
import AnigmaCore

extension DaemonServer {
    
    func handleAntigravityListModels() async throws -> AntigravityListModelsResponse {
        do {
            let models = try await antigravityService.listModels()
            return AntigravityListModelsResponse(models: models)
        } catch {
            return AntigravityListModelsResponse(models: [], error: error.localizedDescription)
        }
    }
    
    func handleAntigravityChat(request: AntigravityChatRequest) async throws -> AsyncThrowingStream<String, Error> {
        // Convert simplified chat request to Antigravity Content
        let contents = request.messages.map { msg in
            AntigravityContent(role: msg.role, parts: [AntigravityPart(text: msg.content)])
        }
        
        let config = AntigravityGenerationConfig(
            temperature: request.temperature,
            maxOutputTokens: request.maxTokens
        )
        
        return try await antigravityService.streamGenerateContent(
            model: request.model,
            messages: contents,
            config: config
        )
    }
}

// MARK: - DTOs

public struct AntigravityListModelsResponse: Codable, Sendable {
    public let models: [AntigravityModelInfo]
    public let error: String?
    
    public init(models: [AntigravityModelInfo], error: String? = nil) {
        self.models = models
        self.error = error
    }
}

public struct AntigravityChatRequest: Codable, Sendable {
    public let model: String
    public let messages: [ChatMessage]
    public let temperature: Double?
    public let maxTokens: Int?
}

public struct ChatMessage: Codable, Sendable {
    public let role: String
    public let content: String
}
