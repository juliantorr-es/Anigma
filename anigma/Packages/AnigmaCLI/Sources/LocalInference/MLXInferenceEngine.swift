import Foundation
#if canImport(MLX)
import MLX
import MLXNN
import MLXRandom
import MLXLM
#endif

// MARK: - MLX Engine Protocol

/// Protocol to abstract MLX engine implementation
public protocol MLXEngineProtocol {
    func loadModel() async throws
    func unload() async
    func generate(prompt: String, maxTokens: Int, temperature: Float, topP: Float) async throws -> String
    func embed(text: String) async throws -> [Float]
}

/// MLX-based local inference engine for Apple Silicon
public actor MLXInferenceEngine: MLXEngineProtocol {
    #if canImport(MLX)
    private var modelContainer: MLXLM.ModelContainer?
    private var modelConfiguration: MLXLM.ModelConfiguration?
    private var generateParams: MLXLM.GenerateParameters?
    #endif

    private let modelId: String
    private var isLoaded = false

    public init(modelId: String) {
        self.modelId = modelId
    }

    /// Load model into memory
    public func loadModel() async throws {
        #if canImport(MLX)
        guard !isLoaded else { return }

        // Configure model loading with GPU acceleration
        modelConfiguration = MLXLM.ModelConfiguration(id: modelId)
        generateParams = MLXLM.GenerateParameters(
            temperature: 0.7,
            topP: 0.9,
            repetitionPenalty: 1.1,
            maxTokens: 512
        )

        // Load model with MLX
        print("Loading MLX model: \(modelId)")
        modelContainer = try await MLXLM.loadModelContainer(configuration: modelConfiguration!)
        
        // Configure GPU acceleration for Apple Silicon
        MLX.GPU.set(device: 0)
        
        // Optimize for Apple Silicon GPU
        MLX.metal.setCacheLimit(bytes: 2_147_483_648) // 2GB cache
        
        isLoaded = true
        print("Model loaded successfully on Apple Silicon GPU")
        #else
        throw MLXError.notAvailable
        #endif
    }

    /// Generate text completion
    public func generate(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        topP: Float = 0.9
    ) async throws -> String {
        #if canImport(MLX)
        guard isLoaded else {
            throw MLXError.modelNotLoaded
        }

        guard let container = modelContainer else {
            throw MLXError.modelNotLoaded
        }

        // Update generation parameters
        var params = generateParams!
        params.temperature = temperature
        params.topP = topP
        params.maxTokens = maxTokens

        // Generate response using MLX
        let result = try await container.perform { model, tokenizer in
            let tokens = tokenizer.encode(text: prompt)
            let input = MLX.array(tokens)
            
            // Generate text
            let outputTokens = MLXLM.generate(
                model,
                input,
                parameters: params,
                tokenizer: tokenizer
            )
            
            // Decode to text
            return tokenizer.decode(tokens: outputTokens)
        }

        return result
        #else
        throw MLXError.notAvailable
        #endif
    }

    /// Generate embeddings for text
    public func embed(text: String) async throws -> [Float] {
        #if canImport(MLX)
        guard isLoaded else {
            throw MLXError.modelNotLoaded
        }

        guard let container = modelContainer else {
            throw MLXError.modelNotLoaded
        }

        // Generate embeddings using the model
        let embedding = try await container.perform { model, tokenizer in
            let tokens = tokenizer.encode(text: text)
            let input = MLX.array(tokens).reshaped([1, tokens.count])
            
            // Get model output (last hidden state)
            let outputs = model.callAsModule(input)
            
            // Mean pooling across sequence dimension
            let pooled = MLX.mean(outputs, axis: 1, keepDims: false)
            
            // Convert to Float array
            return pooled.asArray(Float.self)
        }

        return Array(embedding)
        #else
        throw MLXError.notAvailable
        #endif
    }

    /// Generate embeddings for batch of texts
    public func embedBatch(texts: [String]) async throws -> [[Float]] {
        #if canImport(MLX)
        guard isLoaded else {
            throw MLXError.modelNotLoaded
        }

        guard let container = modelContainer else {
            throw MLXError.modelNotLoaded
        }

        var embeddings: [[Float]] = []
        
        // Process in batch if possible, otherwise sequentially
        for text in texts {
            let embedding = try await embed(text: text)
            embeddings.append(embedding)
        }
        
        return embeddings
        #else
        throw MLXError.notAvailable
        #endif
    }

    /// Stream text generation
    public func generateStream(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        topP: Float = 0.9
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    #if canImport(MLX)
                    guard isLoaded else {
                        continuation.finish(throwing: MLXError.modelNotLoaded)
                        return
                    }

                    guard let container = modelContainer else {
                        continuation.finish(throwing: MLXError.modelNotLoaded)
                        return
                    }

                    // Update generation parameters
                    var params = generateParams!
                    params.temperature = temperature
                    params.topP = topP
                    params.maxTokens = maxTokens

                    // Stream generation
                    let tokens = try await container.perform { model, tokenizer in
                        return tokenizer.encode(text: prompt)
                    }
                    
                    let input = MLX.array(tokens)
                    
                    for try await token in MLXLM.generateStreaming(
                        model,
                        input,
                        parameters: params,
                        tokenizer: container.tokenizer
                    ) {
                        let text = container.tokenizer.decode(tokens: [token])
                        continuation.yield(text)
                    }
                    
                    continuation.finish()
                    #else
                    continuation.finish(throwing: MLXError.notAvailable)
                    #endif
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Unload model from memory
    public func unload() {
        #if canImport(MLX)
        modelContainer = nil
        modelConfiguration = nil
        generateParams = nil
        isLoaded = false
        
        // Comprehensive memory cleanup
        MLX.eval() // Force evaluation of pending operations
        MLX.metal.clearCache() // Clear GPU memory cache
        
        // Force garbage collection if available
        if MLX.metal.isAvailable() {
            MLX.metal.clearCache()
        }
        
        print("Model unloaded from memory, GPU cache cleared")
        #endif
    }
    
    /// Perform memory cleanup without unloading model
    public func cleanupMemory() {
        #if canImport(MLX)
        MLX.eval()
        if MLX.metal.isAvailable() {
            MLX.metal.clearCache()
        }
        #endif
    }

    /// Check if model is loaded
    public var modelLoaded: Bool {
        isLoaded
    }

    /// Get model info
    public func getModelInfo() -> MLXEngineModelInfo? {
        guard isLoaded else { return nil }
        return MLXEngineModelInfo(
            modelId: modelId,
            loaded: true,
            backend: "MLX",
            device: "GPU (Apple Silicon)"
        )
    }
}

// MARK: - Model Info

public struct MLXEngineModelInfo: Sendable {
    public let modelId: String
    public let loaded: Bool
    public let backend: String
    public let device: String
}
