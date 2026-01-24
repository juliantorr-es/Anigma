import Foundation
import MLX
import MLXLMCommon

public protocol MLXEngineProtocol {
    func loadModel() async throws
    func unload() async
    func generate(prompt: String, maxTokens: Int, temperature: Float) async throws -> String
    func embed(text: String) async throws -> [Float]
}

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

    public func generate(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) async throws -> String {
        guard let container = container else { 
            throw NSError(domain: "MLX", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"]) 
        }
        
        let params = GenerateParameters(maxTokens: maxTokens, temperature: temperature)
        let session = ChatSession(container, generateParameters: params)
        return try await session.respond(to: prompt)
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
