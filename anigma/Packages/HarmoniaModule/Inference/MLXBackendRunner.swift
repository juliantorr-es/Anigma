//
//  MLXBackendRunner.swift
//  HarmoniaModule
//
//  MLX backend runner for Apple Silicon inference.
//

import Foundation
import AnigmaCore

// MARK: - MLX Engine Protocol

/// Protocol to abstract MLX engine implementation without direct import
public protocol MLXEngineProtocol {
    func loadModel() async throws
    func unload() async
    func generate(prompt: String, maxTokens: Int, temperature: Float, topP: Float) async throws -> String
    func embed(text: String) async throws -> [Float]
}

/// MLX backend runner for Apple Silicon inference.
public actor MLXBackendRunner: BackendRunner {
    public let backend: BackendKind = .mlx
    
    private var engines: [String: any MLXEngineProtocol] = [:]
    private var loadedModels: Set<String> = []
    
    public init() {
        // Start periodic memory cleanup task
        Task {
            await startMemoryCleanupTask()
        }
    }
    
    /// Start periodic memory cleanup task
    private func startMemoryCleanupTask() async {
        Task {
            while true {
                try? await Task.sleep(for: .minutes(10)) // Cleanup every 10 minutes
                await performMemoryCleanup()
            }
        }
    }
    
    public init() {}
    
    public func start(model: ModelDescriptor) async throws {
        guard !loadedModels.contains(model.id) else { return }
        
        // Try to load MLX engine
        do {
            let engineClass = NSClassFromString("MLXInferenceEngine")
            if let engineClass = engineClass {
                let engine = engineClass.init()
                // Try to call loadModel via reflection
                if let mlxEngine = engine as? any MLXEngineProtocol {
                    try await mlxEngine.loadModel()
                    engines[model.id] = engine
                    loadedModels.insert(model.id)
                    print("MLX backend started for model: \(model.id)")
                    return
                }
            }
        } catch {
            print("Failed to initialize MLX engine: \(error)")
        }
        
        throw InferenceError.backendNotAvailable("MLX - framework not available")
    }
    
    public func stop(modelId: String) async {
        if let engine = engines[modelId] as? any MLXEngineProtocol {
            await engine.unload()
            engines.removeValue(forKey: modelId)
            loadedModels.remove(modelId)
            print("MLX backend stopped for model: \(modelId)")
            
            // Trigger memory cleanup
            await performMemoryCleanup()
        }
    }
    
    /// Perform system-wide memory cleanup
    private func performMemoryCleanup() async {
        // Force garbage collection on all engines
        for engine in engines.values {
            if let mlxEngine = engine as? (any MLXEngineProtocol & AnyObject) {
                if engine.responds(to: Selector(("cleanupMemory"))) {
                    mlxEngine.perform(#selector(cleanupMemory))
                }
            }
        }
    }
    
    public func execute(request: BackendRequest) async throws -> BackendResponse {
        guard let engine = engines[request.model.id] else {
            throw InferenceError.notInitialized
        }
        
        let startTime = Date()
        var tokensIn = 0
        var tokensOut = 0
        
        let output: InferenceOutput
        
        switch request.kind {
        case .chat:
            let promptText = extractTextFromInput(request.input)
            tokensIn = estimateTokenCount(promptText)
            
            let response = try await engine.generate(
                prompt: promptText,
                maxTokens: request.parameters.maxTokens ?? 512,
                temperature: Float(request.parameters.temperature),
                topP: Float(request.parameters.topP ?? 0.9)
            )
            tokensOut = estimateTokenCount(response)
            output = .text(response)
            
        case .embed:
            let text = extractTextFromInput(request.input)
            tokensIn = estimateTokenCount(text)
            
            let embedding = try await engine.embed(text: text)
            output = .embedding(embedding)
            
        case .summarize:
            let text = extractTextFromInput(request.input)
            tokensIn = estimateTokenCount(text)
            
            let summary = try await engine.generate(
                prompt: "Summarize the following text:\n\n\(text)",
                maxTokens: request.parameters.maxTokens ?? 256,
                temperature: Float(request.parameters.temperature),
                topP: Float(request.parameters.topP ?? 0.9)
            )
            tokensOut = estimateTokenCount(summary)
            output = .text(summary)
            
        case .classify:
            let text = extractTextFromInput(request.input)
            tokensIn = estimateTokenCount(text)
            
            // For classification, we'll use a prompt-based approach
            let classificationPrompt = """
            Classify the following text into one of the given categories.
            Text: \(text)
            Categories: general, technical, creative, business
            Classification:
            """
            
            let classification = try await engine.generate(
                prompt: classificationPrompt,
                maxTokens: 50,
                temperature: 0.1,  // Low temperature for consistent classification
                topP: 0.9
            )
            tokensOut = estimateTokenCount(classification)
            
            // Extract category and assign confidence
            let category = extractCategoryFromResponse(classification)
            output = .classification(label: category, confidence: 0.85)
            
        default:
            throw InferenceError.notImplemented("Task type \(request.kind) not yet implemented for MLX")
        }
        
        return BackendResponse(
            output: output,
            tokensIn: tokensIn,
            tokensOut: tokensOut
        )
    }
    
    public func stream(request: BackendRequest) async throws -> AsyncThrowingStream<InferenceChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let engine = engines[request.model.id] else {
                        continuation.finish(throwing: InferenceError.notInitialized)
                        return
                    }
                    
                    switch request.kind {
                    case .chat:
                        let promptText = extractTextFromInput(request.input)
                        
                        // For now, use generate() and chunk the response
                        // In a real implementation, we'd need streaming support in the protocol
                        let response = try await engine.generate(
                            prompt: promptText,
                            maxTokens: request.parameters.maxTokens ?? 512,
                            temperature: Float(request.parameters.temperature),
                            topP: Float(request.parameters.topP ?? 0.9)
                        )
                        
                        // Split response into chunks for streaming
                        let chunkSize = 10
                        let chunks = response.chunked(into: chunkSize)
                        
                        for chunk in chunks {
                            continuation.yield(InferenceChunk(
                                content: chunk,
                                isComplete: false,
                                metadata: nil
                            ))
                        }
                        
                        continuation.yield(InferenceChunk(
                            content: "",
                            isComplete: true,
                            metadata: ["totalTokens": estimateTokenCount(response)]
                        ))
                        
                        continuation.finish()
                        
                    default:
                        continuation.finish(throwing: InferenceError.notImplemented("Streaming not implemented for \(request.kind)"))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func isAvailable() async -> Bool {
        // Check if MLX is available by trying to load the class
        return NSClassFromString("MLXInferenceEngine") != nil
    }
    
    // MARK: - Private Helpers
    
    private func extractTextFromInput(_ input: InferenceInput) -> String {
        switch input {
        case .text(let text):
            return text
        case .messages(let messages):
            return messages.map { "\($0.role): \($0.content)" }.joined(separator: "\n")
        case .batch(let texts):
            return texts.first ?? ""
        case .structured(let structured):
            return structured.data.description
        }
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token
        return Int(ceil(Double(text.count) / 4.0))
    }
    
    private func extractCategoryFromResponse(_ response: String) -> String {
        let cleanedResponse = response.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let categories = ["general", "technical", "creative", "business"]
        for category in categories {
            if cleanedResponse.contains(category) {
                return category
            }
        }
        
        return "general"
    }
}
        
        let startTime = Date()
        var tokensIn = 0
        var tokensOut = 0
        
        let output: InferenceOutput
        
        switch request.kind {
        case .chat:
            let promptText = extractTextFromInput(request.input)
            tokensIn = estimateTokenCount(promptText)
            
            let response = try await engine.generate(
                prompt: promptText,
                maxTokens: request.parameters.maxTokens ?? 512,
                temperature: Float(request.parameters.temperature),
                topP: Float(request.parameters.topP ?? 0.9)
            )
            tokensOut = estimateTokenCount(response)
            output = .text(response)
            
        case .embed:
            let text = extractTextFromInput(request.input)
            tokensIn = estimateTokenCount(text)
            
            let embedding = try await engine.embed(text: text)
            output = .embedding(embedding)
            
        case .summarize:
            let text = extractTextFromInput(request.input)
            tokensIn = estimateTokenCount(text)
            
            let summary = try await engine.generate(
                prompt: "Summarize the following text:\n\n\(text)",
                maxTokens: request.parameters.maxTokens ?? 256,
                temperature: Float(request.parameters.temperature),
                topP: Float(request.parameters.topP ?? 0.9)
            )
            tokensOut = estimateTokenCount(summary)
            output = .text(summary)
            
        case .classify:
            let text = extractTextFromInput(request.input)
            tokensIn = estimateTokenCount(text)
            
            // For classification, we'll use a prompt-based approach
            let classificationPrompt = """
            Classify the following text into one of the given categories.
            Text: \(text)
            Categories: general, technical, creative, business
            Classification:
            """
            
            let classification = try await engine.generate(
                prompt: classificationPrompt,
                maxTokens: 50,
                temperature: 0.1,  // Low temperature for consistent classification
                topP: 0.9
            )
            tokensOut = estimateTokenCount(classification)
            
            // Extract category and assign confidence
            let category = extractCategoryFromResponse(classification)
            output = .classification(label: category, confidence: 0.85)
            
        default:
            throw InferenceError.notImplemented("Task type \(request.kind) not yet implemented for MLX")
        }
        
        
        return BackendResponse(
            output: output,
            tokensIn: tokensIn,
            tokensOut: tokensOut
        )
        #else
        throw InferenceError.backendNotAvailable("MLX")
        #endif
    }
    
    public func stream(request: BackendRequest) async throws -> AsyncThrowingStream<InferenceChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    #if canImport(MLX)
                    guard let engine = engines[request.model.id] else {
                        continuation.finish(throwing: InferenceError.notInitialized)
                        return
                    }
                    
                    switch request.kind {
                    case .chat:
                        let promptText = extractTextFromInput(request.input)
                        let stream = engine.generateStream(
                            prompt: promptText,
                            maxTokens: request.parameters.maxTokens ?? 512,
                            temperature: Float(request.parameters.temperature),
                            topP: Float(request.parameters.topP ?? 0.9)
                        )
                        
                        var accumulatedText = ""
                        for try await chunk in stream {
                            accumulatedText += chunk
                            continuation.yield(InferenceChunk(
                                content: chunk,
                                isComplete: false,
                                metadata: nil
                            ))
                        }
                        
                        continuation.yield(InferenceChunk(
                            content: "",
                            isComplete: true,
                            metadata: ["totalTokens": estimateTokenCount(accumulatedText)]
                        ))
                        
                        continuation.finish()
                        
                    default:
                        continuation.finish(throwing: InferenceError.notImplemented("Streaming not implemented for \(request.kind)"))
                    }
                    #else
                    continuation.finish(throwing: InferenceError.backendNotAvailable("MLX"))
                    #endif
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func isAvailable() async -> Bool {
        #if canImport(MLX)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Private Helpers
    
    #if canImport(MLX)
    private func extractTextFromInput(_ input: InferenceInput) -> String {
        switch input {
        case .text(let text):
            return text
        case .messages(let messages):
            return messages.map { "\($0.role): \($0.content)" }.joined(separator: "\n")
        case .batch(let texts):
            return texts.first ?? ""
        case .structured(let structured):
            return structured.data.description
        }
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token
        return Int(ceil(Double(text.count) / 4.0))
    }
    
    private func extractCategoryFromResponse(_ response: String) -> String {
        let cleanedResponse = response.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let categories = ["general", "technical", "creative", "business"]
        for category in categories {
            if cleanedResponse.contains(category) {
                return category
            }
        }
        
        return "general"
    }
    #endif
}

// MARK: - String Extension

extension String {
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: count, by: size).map {
            String(self[index(startIndex, offsetBy: $0)..<index(startIndex, offsetBy: min($0 + size, count))])
        }
    }
}

// MARK: - MLX Backend Metadata

public struct MLXBackendMetadata: Sendable, Codable {
    public let modelId: String
    public let device: String
    public let mlxFramework: String
}