//
//  GrapheneInferenceBridge.swift
//  AnigmaCore
//
//  Bridge between Graphene nodes and Anigma's InferencePlane.
//
//  Provides:
//  - Unified inference API for AI nodes
//  - Model resolution and loading
//  - Backend selection (MLX, CoreML, llama.cpp)
//  - Streaming inference support
//  - Governance integration
//

import Foundation

// MARK: - Inference Bridge Protocol

/// Protocol for executing ML inference within Graphene nodes.
@preconcurrency public protocol InferenceBridge {
    /// Generate text from a prompt.
    func generateText(
        prompt: String,
        systemPrompt: String?,
        config: TextGenerationConfig
    ) async throws -> TextGenerationResult

    /// Generate text with streaming output.
    func generateTextStreaming(
        prompt: String,
        systemPrompt: String?,
        config: TextGenerationConfig
    ) -> AsyncThrowingStream<TextChunk, Error>

    /// Generate embeddings for text.
    func embed(
        text: String,
        config: EmbeddingConfig
    ) async throws -> EmbeddingResult

    /// Transcribe audio to text.
    func transcribe(
        audioURL: URL,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult

    /// Synthesize speech from text.
    func synthesize(
        text: String,
        config: SynthesisConfig
    ) async throws -> SynthesisResult

    /// Check model availability.
    func isModelAvailable(_ modelId: String) async -> Bool

    /// Get available models.
    func availableModels() async -> [ModelInfo]
}

// MARK: - Configuration Types

/// Configuration for text generation.
public struct TextGenerationConfig: Sendable {
    public let modelId: String
    public let maxTokens: Int
    public let temperature: Double
    public let topP: Double
    public let topK: Int
    public let repeatPenalty: Double
    public let stopSequences: [String]
    public let localOnly: Bool

    public init(
        modelId: String = "llama-3.2-3b",
        maxTokens: Int = 512,
        temperature: Double = 0.7,
        topP: Double = 0.9,
        topK: Int = 40,
        repeatPenalty: Double = 1.1,
        stopSequences: [String] = [],
        localOnly: Bool = true
    ) {
        self.modelId = modelId
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.repeatPenalty = repeatPenalty
        self.stopSequences = stopSequences
        self.localOnly = localOnly
    }
}

/// Configuration for embedding generation.
public struct EmbeddingConfig: Sendable {
    public let modelId: String
    public let normalize: Bool
    public let truncate: Bool
    public let maxTokens: Int

    public init(
        modelId: String = "nomic-embed-text",
        normalize: Bool = true,
        truncate: Bool = true,
        maxTokens: Int = 8192
    ) {
        self.modelId = modelId
        self.normalize = normalize
        self.truncate = truncate
        self.maxTokens = maxTokens
    }
}

/// Configuration for speech transcription.
public struct TranscriptionConfig: Sendable {
    public let modelId: String
    public let language: String
    public let translateToEnglish: Bool
    public let wordTimestamps: Bool

    public init(
        modelId: String = "whisper-large-v3",
        language: String = "auto",
        translateToEnglish: Bool = false,
        wordTimestamps: Bool = false
    ) {
        self.modelId = modelId
        self.language = language
        self.translateToEnglish = translateToEnglish
        self.wordTimestamps = wordTimestamps
    }
}

/// Configuration for speech synthesis.
public struct SynthesisConfig: Sendable {
    public let modelId: String
    public let voice: String
    public let speed: Double
    public let sampleRate: Int

    public init(
        modelId: String = "kokoro-tts",
        voice: String = "default",
        speed: Double = 1.0,
        sampleRate: Int = 24000
    ) {
        self.modelId = modelId
        self.voice = voice
        self.speed = speed
        self.sampleRate = sampleRate
    }
}

// MARK: - Result Types

/// Result of text generation.
public struct TextGenerationResult: Sendable {
    public let text: String
    public let tokenCount: Int
    public let promptTokenCount: Int
    public let finishReason: FinishReason
    public let modelId: String
    public let generationTime: TimeInterval

    public enum FinishReason: String, Sendable {
        case stop
        case maxTokens
        case cancelled
        case error
    }

    public init(
        text: String,
        tokenCount: Int,
        promptTokenCount: Int = 0,
        finishReason: FinishReason = .stop,
        modelId: String = "",
        generationTime: TimeInterval = 0
    ) {
        self.text = text
        self.tokenCount = tokenCount
        self.promptTokenCount = promptTokenCount
        self.finishReason = finishReason
        self.modelId = modelId
        self.generationTime = generationTime
    }
}

/// Result of embedding generation.
public struct EmbeddingResult: Sendable {
    public let embedding: [Float]
    public let dimensions: Int
    public let tokenCount: Int
    public let modelId: String

    public init(
        embedding: [Float],
        tokenCount: Int = 0,
        modelId: String = ""
    ) {
        self.embedding = embedding
        self.dimensions = embedding.count
        self.tokenCount = tokenCount
        self.modelId = modelId
    }
}

/// Result of transcription.
public struct TranscriptionResult: Sendable {
    public let text: String
    public let segments: [TranscriptionSegment]
    public let language: String
    public let duration: TimeInterval

    public struct TranscriptionSegment: Sendable, Codable {
        public let text: String
        public let start: TimeInterval
        public let end: TimeInterval
        public let confidence: Double
    }

    public init(
        text: String,
        segments: [TranscriptionSegment] = [],
        language: String = "en",
        duration: TimeInterval = 0
    ) {
        self.text = text
        self.segments = segments
        self.language = language
        self.duration = duration
    }
}

/// Result of speech synthesis.
public struct SynthesisResult: Sendable {
    public let audioURL: URL
    public let duration: TimeInterval
    public let sampleRate: Int
    public let channels: Int

    public init(
        audioURL: URL,
        duration: TimeInterval,
        sampleRate: Int = 24000,
        channels: Int = 1
    ) {
        self.audioURL = audioURL
        self.duration = duration
        self.sampleRate = sampleRate
        self.channels = channels
    }
}

/// Information about an available model.
public struct ModelInfo: Sendable {
    public let id: String
    public let name: String
    public let type: ModelType
    public let size: Int64
    public let quantization: String?
    public let isLoaded: Bool
    public let capabilities: [ModelCapability]

    public enum ModelType: String, Sendable {
        case llm
        case embedding
        case asr
        case tts
        case vision
        case multimodal
    }

    public enum ModelCapability: String, Sendable {
        case textGeneration
        case chat
        case embedding
        case transcription
        case synthesis
        case imageDescription
        case streaming
    }

    public init(
        id: String,
        name: String,
        type: ModelType,
        size: Int64 = 0,
        quantization: String? = nil,
        isLoaded: Bool = false,
        capabilities: [ModelCapability] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.size = size
        self.quantization = quantization
        self.isLoaded = isLoaded
        self.capabilities = capabilities
    }
}

// MARK: - Mock Inference Bridge

/// Mock implementation for testing and development.
public actor MockInferenceBridge: InferenceBridge {
    private let delay: TimeInterval

    public init(delay: TimeInterval = 0.1) {
        self.delay = delay
    }

    nonisolated public func generateText(
        prompt: String,
        systemPrompt: String?,
        config: TextGenerationConfig
    ) async throws -> TextGenerationResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        let response = "[Mock response for: \(prompt.prefix(50))...]"
        return TextGenerationResult(
            text: response,
            tokenCount: response.split(separator: " ").count,
            promptTokenCount: prompt.split(separator: " ").count,
            modelId: config.modelId,
            generationTime: delay
        )
    }

    nonisolated public func generateTextStreaming(
        prompt: String,
        systemPrompt: String?,
        config: TextGenerationConfig
    ) -> AsyncThrowingStream<TextChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let words = "This is a mock streaming response that simulates token-by-token LLM output for testing the Graphene pipeline.".split(separator: " ")

                for (index, word) in words.enumerated() {
                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms per token
                    let isFinal = index == words.count - 1
                    let text = (index == 0 ? "" : " ") + String(word)
                    continuation.yield(TextChunk(text: text, isFinal: isFinal, tokenCount: 1))
                }

                continuation.finish()
            }
        }
    }

    nonisolated public func embed(
        text: String,
        config: EmbeddingConfig
    ) async throws -> EmbeddingResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        // Generate mock embedding
        let dimensions = 384
        let embedding = (0..<dimensions).map { _ in Float.random(in: -1...1) }

        return EmbeddingResult(
            embedding: embedding,
            tokenCount: text.split(separator: " ").count,
            modelId: config.modelId
        )
    }

    nonisolated public func transcribe(
        audioURL: URL,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        return TranscriptionResult(
            text: "[Mock transcription of audio file]",
            segments: [
                TranscriptionResult.TranscriptionSegment(
                    text: "[Mock transcription of audio file]",
                    start: 0,
                    end: 5.0,
                    confidence: 0.95
                )
            ],
            language: "en",
            duration: 5.0
        )
    }

    nonisolated public func synthesize(
        text: String,
        config: SynthesisConfig
    ) async throws -> SynthesisResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        // Create a temp file URL
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("tts_\(UUID().uuidString).wav")

        // In real impl, would write audio data
        return SynthesisResult(
            audioURL: audioURL,
            duration: Double(text.count) * 0.05,
            sampleRate: config.sampleRate
        )
    }

    nonisolated public func isModelAvailable(_ modelId: String) async -> Bool {
        // Mock: all models available
        true
    }

    nonisolated public func availableModels() async -> [ModelInfo] {
        [
            ModelInfo(id: "llama-3.2-3b", name: "Llama 3.2 3B", type: .llm, capabilities: [.textGeneration, .chat, .streaming]),
            ModelInfo(id: "nomic-embed-text", name: "Nomic Embed Text", type: .embedding, capabilities: [.embedding]),
            ModelInfo(id: "whisper-large-v3", name: "Whisper Large V3", type: .asr, capabilities: [.transcription]),
            ModelInfo(id: "kokoro-tts", name: "Kokoro TTS", type: .tts, capabilities: [.synthesis]),
            ModelInfo(id: "llava-1.5-7b", name: "LLaVA 1.5 7B", type: .multimodal, capabilities: [.imageDescription, .chat])
        ]
    }
}

// MARK: - Inference Bridge Registry

/// Registry for inference bridge implementations.
public actor InferenceBridgeRegistry {
    public static let shared = InferenceBridgeRegistry()

    private var bridges: [String: any InferenceBridge] = [:]
    private var defaultBridgeId: String = "mock"

    private init() {
        // Register mock bridge by default
        bridges["mock"] = MockInferenceBridge()
    }

    /// Register an inference bridge.
    public func register(id: String, bridge: any InferenceBridge) {
        bridges[id] = bridge
    }

    /// Get the default bridge.
    public func getDefault() -> any InferenceBridge {
        bridges[defaultBridgeId] ?? MockInferenceBridge()
    }

    /// Get a specific bridge.
    public func get(id: String) -> (any InferenceBridge)? {
        bridges[id]
    }

    /// Set the default bridge.
    public func setDefault(id: String) {
        if bridges[id] != nil {
            defaultBridgeId = id
        }
    }
}

// MARK: - AI Node Executors with Bridge

/// Text generation executor using InferenceBridge.
public struct BridgedTextGenerationExecutor: StreamingNodeExecutor {
    private let bridgeRegistry: InferenceBridgeRegistry

    public init(bridgeRegistry: InferenceBridgeRegistry = .shared) {
        self.bridgeRegistry = bridgeRegistry
    }

    public func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let bridge = await bridgeRegistry.getDefault()

        let prompt = inputs["prompt"]?.as(TextPort.self)?.value ?? ""
        let systemPrompt = inputs["systemPrompt"]?.as(TextPort.self)?.value

        let config = TextGenerationConfig(
            modelId: instance.parameterValues["model"]?.stringValue ?? "llama-3.2-3b",
            maxTokens: instance.parameterValues["maxTokens"]?.intValue ?? 512,
            temperature: instance.parameterValues["temperature"]?.doubleValue ?? 0.7,
            topP: instance.parameterValues["topP"]?.doubleValue ?? 0.9,
            localOnly: instance.parameterValues["localOnly"]?.boolValue ?? true
        )

        let result = try await bridge.generateText(
            prompt: prompt,
            systemPrompt: systemPrompt,
            config: config
        )

        return [
            "response": AnyPortValue(TextPort(result.text)),
            "tokens": AnyPortValue(NumberPort(Double(result.tokenCount)))
        ]
    }

    public func executeStreaming(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) -> AsyncThrowingStream<StreamingOutput, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let bridge = await bridgeRegistry.getDefault()

                let prompt = inputs["prompt"]?.as(TextPort.self)?.value ?? ""
                let systemPrompt = inputs["systemPrompt"]?.as(TextPort.self)?.value

                let config = TextGenerationConfig(
                    modelId: instance.parameterValues["model"]?.stringValue ?? "llama-3.2-3b",
                    maxTokens: instance.parameterValues["maxTokens"]?.intValue ?? 512,
                    temperature: instance.parameterValues["temperature"]?.doubleValue ?? 0.7
                )

                var fullText = ""
                var tokenCount = 0

                let stream = bridge.generateTextStreaming(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    config: config
                )

                do {
                    for try await chunk in stream {
                        fullText += chunk.text
                        tokenCount += chunk.tokenCount

                        continuation.yield(.chunk(
                            portName: "response",
                            value: AnyPortValue(TextPort(chunk.text)),
                            progress: chunk.isFinal ? 1.0 : 0.5
                        ))
                    }

                    continuation.yield(.final(outputs: [
                        "response": AnyPortValue(TextPort(fullText)),
                        "tokens": AnyPortValue(NumberPort(Double(tokenCount)))
                    ]))

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

/// Embedding executor using InferenceBridge.
public struct BridgedEmbeddingExecutor: NodeExecutor {
    private let bridgeRegistry: InferenceBridgeRegistry

    public init(bridgeRegistry: InferenceBridgeRegistry = .shared) {
        self.bridgeRegistry = bridgeRegistry
    }

    public func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let bridge = await bridgeRegistry.getDefault()

        let text = inputs["text"]?.as(TextPort.self)?.value ?? ""

        let config = EmbeddingConfig(
            modelId: instance.parameterValues["model"]?.stringValue ?? "nomic-embed-text",
            normalize: instance.parameterValues["normalize"]?.boolValue ?? true
        )

        let result = try await bridge.embed(text: text, config: config)

        // Store embedding and return reference
        let storageKey = "embedding_\(UUID().uuidString)"
        // Store the embedding vector in resource manager
        await context.resourceManager.allocate(key: storageKey, value: result.embedding)

        let tensorPort = TensorPort(
            shape: [result.dimensions],
            dtype: "float32",
            storageKey: storageKey
        )

        return ["embedding": AnyPortValue(tensorPort)]
    }
}
