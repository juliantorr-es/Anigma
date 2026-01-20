//
//  MLXChatProvider.swift
//  AnigmaCLI
//

import Foundation

public actor MLXChatProvider {
    private var isInitialized = false

    public init() {}

    public func initialize() async throws {
        guard !isInitialized else { return }
        throw MLXChatError.mlxNotAvailable
    }

    public func loadModel(modelID: String, hubModelID: String? = nil, progressCallback: (@Sendable (String) -> Void)? = nil) async throws {
        throw MLXChatError.mlxNotAvailable
    }

    public func unloadModel() {}

    public func generate(prompt: String, maxTokens: Int = 512, temperature: Float = 0.7) async throws -> String {
        throw MLXChatError.mlxNotAvailable
    }

    public func chat(prompt: String, systemPrompt: String? = nil, temperature: Double = 0.7, maxTokens: Int = 2048) async throws -> String {
        throw MLXChatError.mlxNotAvailable
    }

    public func chatStreaming(prompt: String, systemPrompt: String? = nil, temperature: Double = 0.7, maxTokens: Int = 2048, onToken: @escaping @Sendable (String) async -> Void) async throws {
        throw MLXChatError.mlxNotAvailable
    }

    public func getModelInfo() -> ChatModelInfo? { nil }
    public static func recommendedModels() -> [RecommendedChatModel] { [] }
}

public struct ChatModelInfo: Sendable {
    public let modelID: String
    public let loaded: Bool
}

public enum MLXChatError: Error, LocalizedError {
    case mlxNotAvailable
    public var errorDescription: String? { "MLX not available" }
}

public struct RecommendedChatModel: Sendable {
    public let id: String
    public let hubID: String
    public let size: String
    public let quantization: String
    public let speed: Speed
    public let quality: Quality
    public let description: String

    public enum Speed: String, Sendable { case veryFast, fast, medium, slow }
    public enum Quality: String, Sendable { case high, medium, low }
}
