//
//  MLXEmbeddingProvider.swift
//  AnigmaCLI
//

import Foundation
import AnigmaNativeShims
import AnigmaCLICore

public actor MLXEmbeddingProvider: EmbeddingProvider {
    public nonisolated let name = "MLX"
    public nonisolated var dimension: Int { 384 }

    private let bridge: NativeMLXBridge
    private var currentModel: String?

    public init() {
        self.bridge = NativeMLXBridge()
    }

    public func loadModel(modelID: String, hubModelID: String? = nil, progressCallback: (@Sendable (String) -> Void)? = nil) async throws {
        #if canImport(MLX)
        progressCallback?("Loading MLX model: \(modelID)")
        let modelPath = try await resolveModelPath(modelID: modelID, hubID: hubModelID)
        try await bridge.loadModel(path: modelPath, modelType: .embedding)
        currentModel = modelID
        progressCallback?("Model loaded successfully")
        #else
        throw MLXEmbeddingError.mlxNotAvailable
        #endif
    }

    public func unloadModel() {
        currentModel = nil
    }

    public func embed(text: String) async throws -> [Float] {
        guard currentModel != nil else {
            throw MLXEmbeddingError.modelNotLoaded
        }
        return try await bridge.generateEmbedding(text: text)
    }

    public func embedBatch(texts: [String]) async throws -> [[Float]] {
        guard currentModel != nil else {
            throw MLXEmbeddingError.modelNotLoaded
        }
        // TODO: Implement true batch processing in MLX bridge
        return try await withThrowingTaskGroup(of: [Float].self) { group in
            for text in texts {
                group.addTask {
                    try await self.embed(text: text)
                }
            }

            var results: [[Float]] = []
            for try await embedding in group {
                results.append(embedding)
            }
            return results
        }
    }

    public func initialize() async throws {
        // MLX initialization is done lazily when model is loaded
    }

    public func getModelInfo() -> ModelInfo? {
        guard let modelID = currentModel else { return nil }
        return ModelInfo(modelID: modelID, dimension: 384, loaded: true)
    }

    public static func recommendedModels() -> [RecommendedModel] {
        return [
            RecommendedModel(
                id: "all-minilm-l6-v2",
                hubID: "sentence-transformers/all-MiniLM-L6-v2",
                dimension: 384,
                size: "80MB",
                speed: .veryFast,
                quality: .medium,
                description: "Fast, lightweight embeddings for semantic search"
            ),
            RecommendedModel(
                id: "bge-small-en-v1.5",
                hubID: "BAAI/bge-small-en-v1.5",
                dimension: 384,
                size: "130MB",
                speed: .fast,
                quality: .high,
                description: "High-quality embeddings optimized for retrieval"
            )
        ]
    }

    private func resolveModelPath(modelID: String, hubID: String?) async throws -> String {
        // Check local cache first
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("anigma-cli/models")
        let modelPath = cacheDir.appendingPathComponent(modelID)

        if FileManager.default.fileExists(atPath: modelPath.path) {
            return modelPath.path
        }

        // TODO: Download from HuggingFace if not found
        throw MLXEmbeddingError.modelNotFound(modelID)
    }
}

public struct ModelInfo: Sendable {
    public let modelID: String
    public let dimension: Int
    public let loaded: Bool
}

public enum MLXEmbeddingError: Error, LocalizedError {
    case mlxNotAvailable
    case modelNotLoaded
    case modelNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .mlxNotAvailable:
            return "MLX not available on this system"
        case .modelNotLoaded:
            return "No model loaded. Call loadModel() first"
        case .modelNotFound(let id):
            return "Model not found: \(id)"
        }
    }
}

public struct RecommendedModel: Sendable {
    public let id: String
    public let hubID: String
    public let dimension: Int
    public let size: String
    public let speed: Speed
    public let quality: Quality
    public let description: String

    public enum Speed: String, Sendable { case veryFast, fast, medium, slow }
    public enum Quality: String, Sendable { case high, medium, low }
}
