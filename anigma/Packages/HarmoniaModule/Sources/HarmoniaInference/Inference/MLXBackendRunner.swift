//
//  MLXBackendRunner.swift
//  HarmoniaModule
//
//  MLX backend runner for Apple Silicon inference.
//

import Foundation
import HarmoniaCore
import AnigmaPrimitives
import os.log
@preconcurrency import Foundation
import AnigmaCore
import HarmoniaInferenceContracts
import MLWorkerCommon
import InferenceCore
import MLWorkerCommon
import OSLog

/// MLX backend runner for Apple Silicon inference.
private let log = Logger(subsystem: "com.anigma.harmonia", category: "actor")
public actor MLXBackendRunner: BackendRunner {
    public let backend: BackendKind = .mlx
    private static let logger = Logger(subsystem: "com.anigma.HarmoniaModule", category: "MLXBackendRunner")
    
    private var engines: [String: any MLXEngineProtocol] = [:]
    private var loadedModels: Set<String> = []
    
    public init() {
        // Start periodic memory cleanup task
        Task {
            await self.startMemoryCleanupTask()
        }
    }
    
    public func start(model: ModelDescriptor) async throws {
        guard !loadedModels.contains(model.id) else { return }
        
        // Try to load MLX engine
        do {
            // Using direct initialization if possible, or fallback to class lookup
            // Note: MLXInferenceEngine should be available in scope or through imports
            // For now, we assume it's available via MLWorkerCommon or similar
            let engine = try await loadEngine(for: model.id)
            engines[model.id] = engine
            loadedModels.insert(model.id)
            log.info("MLX backend started for model: \(model.id)")
        } catch {
            log.info("Failed to initialize MLX engine: \(error)")
            throw InferenceError.modelLoadFailed(model: model.id, reason: error.localizedDescription)
        }
    }
    
    public func stop(modelId: String) async {
        if let engine = engines[modelId] {
            await engine.unload()
            engines.removeValue(forKey: modelId)
            loadedModels.remove(modelId)
            log.info("MLX backend stopped for model: \(modelId)")
            
            // Trigger memory cleanup
            await performMemoryCleanup()
        }
    }
    
    /// Perform system-wide memory cleanup
    private func performMemoryCleanup() async {
        for engine in engines.values {
            await engine.unload()
        }
    }

    private func startMemoryCleanupTask() async {
        // Implementation for periodic cleanup if needed
    }
    
    func execute(request: BackendRequest) async throws -> BackendResponse {
        guard let engine = engines[request.model.id] else {
            throw InferenceError.backendUnavailable(backend: .mlx)
        }
        
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
                temperature: Float(request.parameters.temperature)
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
                temperature: Float(request.parameters.temperature)
            )
            tokensOut = estimateTokenCount(summary)
            output = .text(summary)
            
        case .classify:
            let text = extractTextFromInput(request.input)
            tokensIn = estimateTokenCount(text)
            
            let classificationPrompt = """
            Classify the following text into one of the given categories.
            Text: \(text)
            Categories: general, technical, creative, business
            Classification:
            """
            
            let classification = try await engine.generate(
                prompt: classificationPrompt,
                maxTokens: 50,
                temperature: 0.1
            )
            tokensOut = estimateTokenCount(classification)
            
            let category = extractCategoryFromResponse(classification)
            output = .classification(label: category, confidence: 0.85)
            
        default:
            throw InferenceError.executionFailed(reason: "Task type \(request.kind) not yet implemented for MLX")
        }
        
        return BackendResponse(
            output: output,
            tokensIn: tokensIn,
            tokensOut: tokensOut
        )
    }
    
    func stream(request: BackendRequest) async throws -> AsyncThrowingStream<InferenceChunk, Error> {
        guard let engine = engines[request.model.id] else {
            throw InferenceError.backendUnavailable(backend: .mlx)
        }

        guard case .chat = request.kind else {
            // STUB_TRACK: mlx-stream-non-chat – MLX streaming only supports chat requests
            Self.logger.warning("⚠️ STUB INVOKED: MLXBackendRunner.stream(request:) called with unsupported request.kind \(String(describing: request.kind), privacy: .public)")
            throw InferenceError.executionFailed(reason: "MLX streaming supports chat requests only; request.kind=\(request.kind)")
        }
        
        let taskId = request.taskId
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let promptText = extractTextFromInput(request.input)
                    let stream = engine.generateStream(
                        prompt: promptText,
                        maxTokens: request.parameters.maxTokens ?? 512,
                        temperature: Float(request.parameters.temperature)
                    )
                    
                    var accumulatedTokens = 0
                    for try await chunk in stream {
                        accumulatedTokens += 1 // Simplified
                        continuation.yield(InferenceChunk(
                            taskId: taskId,
                            delta: chunk,
                            isComplete: false,
                            tokensGenerated: accumulatedTokens
                        ))
                    }
                    
                    continuation.yield(InferenceChunk(
                        taskId: taskId,
                        delta: "",
                        isComplete: true,
                        tokensGenerated: accumulatedTokens
                    ))
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func isAvailable() async -> Bool {
        return true
    }
    
    // MARK: - Private Helpers
    
    private func loadEngine(for modelId: String) async throws -> any MLXEngineProtocol {
        // This should use the actual MLXInferenceEngine if available
        // For now, we assume it's provided by the environment
        throw InferenceError.backendUnavailable(backend: .mlx)
    }

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
