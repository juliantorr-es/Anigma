//
//  MLXChatProvider.swift
//  AnigmaCLI
//

import Foundation
import AnigmaCLILocalInference

public actor MLXChatProvider {
    private var mlxEngine: MLXInferenceEngine?
    private var isInitialized = false
    private var currentModel: String?

    public init() {}

    public func initialize() async throws {
        guard !isInitialized else { return }
        isInitialized = true
    }

    public func loadModel(modelID: String, hubModelID: String? = nil, progressCallback: (@Sendable (String) -> Void)? = nil) async throws {
        #if canImport(MLX)
        progressCallback?("Initializing MLX engine...")
        
        // Use hubModelID if provided, otherwise use modelID directly
        let modelToLoad = hubModelID ?? modelID
        
        mlxEngine = MLXInferenceEngine(modelId: modelToLoad)
        
        progressCallback?("Loading model: \(modelToLoad)")
        try await mlxEngine!.loadModel()
        
        currentModel = modelID
        progressCallback?("Model loaded successfully")
        #else
        throw MLXChatError.mlxNotAvailable
        #endif
    }

    public func unloadModel() {
        #if canImport(MLX)
        Task {
            await mlxEngine?.unload()
            mlxEngine = nil
            currentModel = nil
        }
        #endif
    }

    public func generate(prompt: String, maxTokens: Int = 512, temperature: Float = 0.7) async throws -> String {
        #if canImport(MLX)
        guard let engine = mlxEngine else {
            throw MLXChatError.modelNotLoaded
        }
        
        return try await engine.generate(
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: temperature
        )
        #else
        throw MLXChatError.mlxNotAvailable
        #endif
    }

    public func chat(prompt: String, systemPrompt: String? = nil, temperature: Double = 0.7, maxTokens: Int = 2048) async throws -> String {
        #if canImport(MLX)
        guard let engine = mlxEngine else {
            throw MLXChatError.modelNotLoaded
        }
        
        // Build chat prompt with system message
        var fullPrompt = ""
        if let systemPrompt = systemPrompt {
            fullPrompt += "System: \(systemPrompt)\n\n"
        }
        fullPrompt += "User: \(prompt)\n\nAssistant:"
        
        return try await engine.generate(
            prompt: fullPrompt,
            maxTokens: maxTokens,
            temperature: Float(temperature)
        )
        #else
        throw MLXChatError.mlxNotAvailable
        #endif
    }

    public func chatStreaming(prompt: String, systemPrompt: String? = nil, temperature: Double = 0.7, maxTokens: Int = 2048, onToken: @escaping @Sendable (String) async -> Void) async throws {
        #if canImport(MLX)
        guard let engine = mlxEngine else {
            throw MLXChatError.modelNotLoaded
        }
        
        // Build chat prompt with system message
        var fullPrompt = ""
        if let systemPrompt = systemPrompt {
            fullPrompt += "System: \(systemPrompt)\n\n"
        }
        fullPrompt += "User: \(prompt)\n\nAssistant:"
        
        let stream = engine.generateStream(
            prompt: fullPrompt,
            maxTokens: maxTokens,
            temperature: Float(temperature)
        )
        
        for try await token in stream {
            await onToken(token)
        }
        #else
        throw MLXChatError.mlxNotAvailable
        #endif
    }

    public func getModelInfo() -> ChatModelInfo? {
        guard let modelID = currentModel else { return nil }
        return ChatModelInfo(modelID: modelID, loaded: true)
    }
    
    public static func recommendedModels() -> [RecommendedChatModel] {
        #if canImport(MLX)
        return [
            RecommendedChatModel(
                id: "llama3-8b-instruct-4bit",
                hubID: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                size: "~2GB",
                quantization: "4-bit",
                speed: .fast,
                quality: .high,
                description: "High-quality chat model optimized for Apple Silicon"
            ),
            RecommendedChatModel(
                id: "qwen2.5-1.5b-instruct",
                hubID: "mlx-community/Qwen2.5-1.5B-Instruct",
                size: "~1GB",
                quantization: "4-bit",
                speed: .veryFast,
                quality: .medium,
                description: "Fast and lightweight model for quick responses"
            ),
            RecommendedChatModel(
                id: "phi3.5-mini-instruct",
                hubID: "mlx-community/phi-3.5-mini-instruct",
                size: "~2.3GB",
                quantization: "4-bit",
                speed: .fast,
                quality: .medium,
                description: "Efficient model with good reasoning capabilities"
            )
        ]
        #else
        return []
        #endif
    }
}

public struct ChatModelInfo: Sendable {
    public let modelID: String
    public let loaded: Bool
}

public enum MLXChatError: Error, LocalizedError {
    case mlxNotAvailable
    case modelNotLoaded
    case inferenceFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .mlxNotAvailable:
            return "MLX not available - ensure you're running on Apple Silicon with macOS 14+"
        case .modelNotLoaded:
            return "No model loaded - call loadModel() first"
        case .inferenceFailed(let reason):
            return "Inference failed: \(reason)"
        }
    }
}

public struct RecommendedChatModel: Sendable {
    public let id: String
    public let hubID: String
    public let size: String
    public let quantization: String
    public let speed: Speed
    public let quality: Quality
    public let description: String

    public enum Speed: String, Sendable { 
        case veryFast, fast, medium, slow 
    }
    
    public enum Quality: String, Sendable { 
        case high, medium, low 
    }
}
