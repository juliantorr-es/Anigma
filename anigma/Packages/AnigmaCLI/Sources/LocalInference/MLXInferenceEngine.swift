import Foundation
import MLX
import MLXLMCommon
import InferenceCore

public actor MLXInferenceEngine: MLXEngineProtocol {
    private var container: MLXLMCommon.ModelContainer?
    private let modelPath: URL
    private var isLoaded = false

    public init(modelId: String) {
        self.modelPath = URL(fileURLWithPath: modelId)
    }

    public init(modelPath: URL) {
        self.modelPath = modelPath
    }

    public func loadModel() async throws {
        guard !isLoaded else { return }
        container = try await MLXLMCommon.loadModelContainer(id: modelPath.path)
        isLoaded = true
    }

    private func getContainer() throws -> MLXLMCommon.ModelContainer {
        guard let container = container else {
            throw NSError(domain: "MLX", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        return container
    }

    public func generate(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) async throws -> String {
        let container = try getContainer()
        let params = GenerateParameters(maxTokens: maxTokens, temperature: temperature)
        let session = ChatSession(container, generateParameters: params)
        return try await session.respond(to: prompt)
    }

    public nonisolated func generateStream(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = try await self.isolatedGenerateStream(prompt: prompt, maxTokens: maxTokens, temperature: temperature)
                    for try await token in stream {
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func isolatedGenerateStream(
        prompt: String,
        maxTokens: Int,
        temperature: Float
    ) async throws -> AsyncThrowingStream<String, Error> {
        let container = try getContainer()
        let params = GenerateParameters(maxTokens: maxTokens, temperature: temperature)
        let session = ChatSession(container, generateParameters: params)
        return session.streamResponse(to: prompt)
    }

    public func embed(text: String) async throws -> [Float] {
        return []
    }
    
    public func unload() async {
        container = nil
        isLoaded = false
        MLX.GPU.clearCache()
    }
}
