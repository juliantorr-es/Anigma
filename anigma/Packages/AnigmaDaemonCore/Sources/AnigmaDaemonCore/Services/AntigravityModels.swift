//
//  AntigravityModels.swift
//  AnigmaDaemonCore
//
//  Data models for Google Antigravity (Cloud Code) API.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives

public struct AntigravityGenerateContentRequest: Codable, Sendable {
    public let contents: [AntigravityContent]
    public let generationConfig: AntigravityGenerationConfig?
    public let safetySettings: [AntigravitySafetySetting]?
    public let tools: [AntigravityTool]?
    
    public init(
        contents: [AntigravityContent],
        generationConfig: AntigravityGenerationConfig? = nil,
        safetySettings: [AntigravitySafetySetting]? = nil,
        tools: [AntigravityTool]? = nil
    ) {
        self.contents = contents
        self.generationConfig = generationConfig
        self.safetySettings = safetySettings
        self.tools = tools
    }
}

public struct AntigravityContent: Codable, Sendable {
    public let role: String
    public let parts: [AntigravityPart]
    
    public init(role: String, parts: [AntigravityPart]) {
        self.role = role
        self.parts = parts
    }
}

public struct AntigravityPart: Codable, Sendable {
    public let text: String?
    // Future: Add functionCall, inlineData, etc.
    
    public init(text: String?) {
        self.text = text
    }
}

public struct AntigravityGenerationConfig: Codable, Sendable {
    public let temperature: Double?
    public let maxOutputTokens: Int?
    public let topP: Double?
    public let topK: Int?
    public let stopSequences: [String]?
    
    public init(
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stopSequences: [String]? = nil
    ) {
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
    }
}

public struct AntigravitySafetySetting: Codable, Sendable {
    public let category: String
    public let threshold: String
    
    public init(category: String, threshold: String) {
        self.category = category
        self.threshold = threshold
    }
}

public struct AntigravityTool: Codable, Sendable {
    public let functionDeclarations: [AntigravityFunctionDeclaration]?
    
    public init(functionDeclarations: [AntigravityFunctionDeclaration]?) {
        self.functionDeclarations = functionDeclarations
    }
}

public struct AntigravityFunctionDeclaration: Codable, Sendable {
    public let name: String
    public let description: String?
    public let parameters: [String: AnyCodable]? // Uses Primitives or simple JSON
    
    public init(name: String, description: String?, parameters: [String: AnyCodable]?) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

// Responses

public struct AntigravityGenerateContentResponse: Codable, Sendable {
    public let candidates: [AntigravityCandidate]?
    public let usageMetadata: AntigravityUsageMetadata?
}

public struct AntigravityCandidate: Codable, Sendable {
    public let content: AntigravityContent?
    public let finishReason: String?
    // public let safetyRatings: ...
}

public struct AntigravityUsageMetadata: Codable, Sendable {
    public let promptTokenCount: Int?
    public let candidatesTokenCount: Int?
    public let totalTokenCount: Int?
}

public typealias AnyCodable = AnigmaPrimitives.AnyCodable
