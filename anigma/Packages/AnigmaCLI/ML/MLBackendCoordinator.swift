//
//  MLBackendCoordinator.swift
//  AnigmaCLI
//
//  Coordinates all ML backends (MLX, llama.cpp, cloud providers) and provides
//  unified interface for chat and embeddings with intelligent fallback.
//

import Foundation
import AnigmaCLIProviders
import AnigmaCLIRAG

#if canImport(MLX)
import MLX
#endif

/// Central coordinator for all ML operations in anigma-cli
@available(macOS 13.0, *)
public actor MLBackendCoordinator {

    // MARK: - Backends

    private var mlxChatProvider: MLXChatProvider?
    private var mlxEmbeddingProvider: MLXEmbeddingProvider?
    private var llamaChatProvider: LlamaCppProvider?
    private var llamaEmbeddingProvider: LlamaCppEmbeddingProvider?
    private var cloudProviders: [String: CloudProvider] = [:]

    private let config: BackendConfig
    private var activeChat: ChatBackend?
    private var activeEmbedding: EmbeddingBackend?

    // MARK: - Configuration

    public struct BackendConfig {
        public let mlxModelsDir: URL?
        public let llamaCppModelsDir: URL?
        public let preferredChatBackend: ChatBackend?
        public let preferredEmbeddingBackend: EmbeddingBackend?
        public let enableFallback: Bool
        public let cloudAPIKeys: [String: String]

        public init(
            mlxModelsDir: URL? = nil,
            llamaCppModelsDir: URL? = nil,
            preferredChatBackend: ChatBackend? = nil,
            preferredEmbeddingBackend: EmbeddingBackend? = nil,
            enableFallback: Bool = true,
            cloudAPIKeys: [String: String] = [:]
        ) {
            self.mlxModelsDir = mlxModelsDir
            self.llamaCppModelsDir = llamaCppModelsDir
            self.preferredChatBackend = preferredChatBackend
            self.preferredEmbeddingBackend = preferredEmbeddingBackend
            self.enableFallback = enableFallback
            self.cloudAPIKeys = cloudAPIKeys
        }
    }

    public enum ChatBackend: String, Codable, Equatable, Sendable {
        case mlx
        case llamaCpp
        case deepseek
        case openai
        case anthropic
        case google
        case ollama
    }

    public enum EmbeddingBackend: String, Codable, Equatable, Sendable {
        case mlx
        case llamaCpp
        case openai
        case google
    }

    // MARK: - Initialization

    public init(config: BackendConfig) {
        self.config = config
    }

    /// Initialize all available backends based on configuration
    public func initialize() async throws {
        var initializedBackends: [String] = []

        // 1. Try MLX
        #if canImport(MLX)
        do {
            mlxChatProvider = MLXChatProvider()
            try await mlxChatProvider?.initialize()
            mlxEmbeddingProvider = MLXEmbeddingProvider()
            try await mlxEmbeddingProvider?.initialize()
            initializedBackends.append("MLX")

            if config.preferredChatBackend == .mlx {
                activeChat = .mlx
            }
            if config.preferredEmbeddingBackend == .mlx {
                activeEmbedding = .mlx
            }
        } catch {
            print("⚠️ MLX initialization failed: \(error)")
            mlxChatProvider = nil
            mlxEmbeddingProvider = nil
        }
        #endif

        // 2. Try llama.cpp
        if let llamaDir = config.llamaCppModelsDir {
            do {
                // Try to find a chat model
                let chatModels = try FileManager.default.contentsOfDirectory(at: llamaDir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "gguf" }

                if let chatModel = chatModels.first {
                    llamaChatProvider = LlamaCppProvider(
                        modelPath: chatModel.path,
                        contextSize: 4096,
                        threads: 0
                    )
                    try await llamaChatProvider?.initialize()

                    // Use same model for embeddings
                    llamaEmbeddingProvider = LlamaCppEmbeddingProvider(
                        modelPath: chatModel.path,
                        contextSize: 512
                    )
                    try await llamaEmbeddingProvider?.initialize()
                    initializedBackends.append("llama.cpp")

                    if config.preferredChatBackend == .llamaCpp {
                        activeChat = .llamaCpp
                    }
                    if config.preferredEmbeddingBackend == .llamaCpp {
                        activeEmbedding = .llamaCpp
                    }
                }
            } catch {
                print("⚠️ llama.cpp initialization failed: \(error)")
            }
        }

        // 3. Initialize cloud providers
        try await initializeCloudProviders()

        // 4. Auto-select if no preference set
        if activeChat == nil {
            activeChat = selectBestChatBackend()
        }
        if activeEmbedding == nil {
            activeEmbedding = selectBestEmbeddingBackend()
        }

        print("✅ ML Backend initialized: \(initializedBackends.joined(separator: ", "))")
        print("   Active chat: \(activeChat?.rawValue ?? "none")")
        print("   Active embeddings: \(activeEmbedding?.rawValue ?? "none")")
    }

    private func initializeCloudProviders() async throws {
        // DeepSeek
        if let apiKey = config.cloudAPIKeys["deepseek"] {
            let provider = DeepSeekProvider(apiKey: apiKey)
            cloudProviders["deepseek"] = provider
        }

        // OpenAI
        if let apiKey = config.cloudAPIKeys["openai"] {
            let provider = OpenAIProvider(apiKey: apiKey)
            cloudProviders["openai"] = provider
        }

        // Anthropic
        if let apiKey = config.cloudAPIKeys["anthropic"] {
            let provider = AnthropicProvider(apiKey: apiKey)
            cloudProviders["anthropic"] = provider
        }

        // Google
        if let apiKey = config.cloudAPIKeys["google"] {
            let provider = GoogleGeminiProvider(apiKey: apiKey)
            cloudProviders["google"] = provider
        }

        // Ollama
        if let apiKey = config.cloudAPIKeys["ollama"] {
            let provider = OllamaCloudProvider(apiKey: apiKey)
            cloudProviders["ollama"] = provider
        }
    }

    private func selectBestChatBackend() -> ChatBackend? {
        // Priority: Cloud (DeepSeek > OpenAI > Anthropic > Google) > Local (MLX > llama.cpp > Ollama)
        if cloudProviders["deepseek"] != nil {
            return .deepseek
        }
        if cloudProviders["openai"] != nil {
            return .openai
        }
        if cloudProviders["anthropic"] != nil {
            return .anthropic
        }
        if cloudProviders["google"] != nil {
            return .google
        }
        if mlxChatProvider != nil {
            return .mlx
        }
        if llamaChatProvider != nil {
            return .llamaCpp
        }
        if cloudProviders["ollama"] != nil {
            return .ollama
        }
        return nil
    }

    private func selectBestEmbeddingBackend() -> EmbeddingBackend? {
        // Priority: Cloud (OpenAI > Google) > Local (MLX > llama.cpp)
        if cloudProviders["openai"] != nil {
            return .openai
        }
        if cloudProviders["google"] != nil {
            return .google
        }
        if mlxEmbeddingProvider != nil {
            return .mlx
        }
        if llamaEmbeddingProvider != nil {
            return .llamaCpp
        }
        return nil
    }

    // MARK: - Chat Interface

    public func chat(
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 1024,
        temperature: Float = 0.7,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        guard let backend = activeChat else {
            throw MLError.noBackendAvailable("chat")
        }

        do {
            return try await chatWithBackend(
                backend: backend,
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                temperature: temperature,
                onProgress: onProgress
            )
        } catch {
            if config.enableFallback {
                return try await fallbackChat(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    failedBackend: backend
                )
            }
            throw error
        }
    }

    /// Streaming chat interface
    public func chatStream(
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 1024,
        temperature: Float = 0.7,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let backend = activeChat else {
            throw MLError.noBackendAvailable("chat")
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await chatStreamWithBackend(
                        backend: backend,
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        maxTokens: maxTokens,
                        temperature: temperature,
                        continuation: continuation,
                        onProgress: onProgress
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func chatWithBackend(
        backend: ChatBackend,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        temperature: Float,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        switch backend {
        case .mlx:
            // Use ml-worker via MLWorkerService
            let modelId = config.mlxModelsDir?.path ?? "mlx-community/Llama-3.2-3B-Instruct-4bit"
            // Note: MLWorkerService handles the execution
            return try await MLWorkerService.shared.chat(
                modelPath: modelId,
                prompt: prompt,
                maxTokens: maxTokens,
                temperature: Double(temperature),
                engine: .mlx,
                onProgress: onProgress
            )

        case .llamaCpp:
            guard let provider = llamaChatProvider else {
                throw MLError.backendNotAvailable("llama.cpp")
            }
            return try await provider.generate(
                prompt: prompt,
                maxTokens: maxTokens,
                temperature: temperature
            )

        case .deepseek:
            guard let provider = cloudProviders["deepseek"] else {
                throw MLError.backendNotAvailable("DeepSeek")
            }
            let request = ChatRequest(
                messages: [ChatMessage(role: "user", content: prompt)],
                model: "deepseek-coder",
                temperature: Double(temperature),
                maxTokens: maxTokens,
                systemPrompt: systemPrompt
            )
            let response = try await provider.chat(request: request)
            return response.content

        case .openai:
            guard let provider = cloudProviders["openai"] else {
                throw MLError.backendNotAvailable("OpenAI")
            }
            let request = ChatRequest(
                messages: [ChatMessage(role: "user", content: prompt)],
                model: "gpt-4",
                temperature: Double(temperature),
                maxTokens: maxTokens,
                systemPrompt: systemPrompt
            )
            let response = try await provider.chat(request: request)
            return response.content

        case .anthropic:
            guard let provider = cloudProviders["anthropic"] else {
                throw MLError.backendNotAvailable("Anthropic")
            }
            let request = ChatRequest(
                messages: [ChatMessage(role: "user", content: prompt)],
                model: "claude-3-5-sonnet-20241022",
                temperature: Double(temperature),
                maxTokens: maxTokens,
                systemPrompt: systemPrompt
            )
            let response = try await provider.chat(request: request)
            return response.content

        case .google:
            guard let provider = cloudProviders["google"] else {
                throw MLError.backendNotAvailable("Google")
            }
            let request = ChatRequest(
                messages: [ChatMessage(role: "user", content: prompt)],
                model: "gemini-2.0-flash-exp",
                temperature: Double(temperature),
                maxTokens: maxTokens,
                systemPrompt: systemPrompt
            )
            let response = try await provider.chat(request: request)
            return response.content

        case .ollama:
            guard let provider = cloudProviders["ollama"] else {
                throw MLError.backendNotAvailable("Ollama")
            }
            let request = ChatRequest(
                messages: [ChatMessage(role: "user", content: prompt)],
                model: "llama3.1",
                temperature: Double(temperature),
                maxTokens: maxTokens,
                systemPrompt: systemPrompt
            )
            let response = try await provider.chat(request: request)
            return response.content
        }
    }

    private func chatStreamWithBackend(
        backend: ChatBackend,
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        temperature: Float,
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws {
        switch backend {
        case .mlx:
            let modelId = config.mlxModelsDir?.path ?? "mlx-community/Llama-3.2-3B-Instruct-4bit"
            let response = try await MLWorkerService.shared.chat(
                modelPath: modelId,
                prompt: prompt,
                maxTokens: maxTokens,
                temperature: Double(temperature),
                engine: .mlx,
                onProgress: onProgress
            )
            continuation.yield(response)

        case .llamaCpp:
            guard let provider = llamaChatProvider else {
                throw MLError.backendNotAvailable("llama.cpp")
            }
            let response = try await provider.generate(
                prompt: prompt,
                maxTokens: maxTokens,
                temperature: temperature
            )
            continuation.yield(response)

        case .deepseek, .openai, .anthropic, .google, .ollama:
            let provider: CloudProvider?
            switch backend {
            case .deepseek: provider = cloudProviders["deepseek"]
            case .openai: provider = cloudProviders["openai"]
            case .anthropic: provider = cloudProviders["anthropic"]
            case .google: provider = cloudProviders["google"]
            case .ollama: provider = cloudProviders["ollama"]
            default: provider = nil
            }

            guard let provider = provider else {
                throw MLError.backendNotAvailable(backend.rawValue)
            }

            let request = ChatRequest(
                messages: [ChatMessage(role: "user", content: prompt)],
                model: getCloudModelName(for: backend),
                temperature: Double(temperature),
                maxTokens: maxTokens,
                systemPrompt: systemPrompt
            )

            for try await chunk in provider.streamChat(request: request) {
                continuation.yield(chunk.delta)
            }
        }
    }

    private func getCloudModelName(for backend: ChatBackend) -> String {
        switch backend {
        case .deepseek: return "deepseek-coder"
        case .openai: return "gpt-4"
        case .anthropic: return "claude-3-5-sonnet-20241022"
        case .google: return "gemini-2.0-flash-exp"
        case .ollama: return "llama3.1"
        default: return ""
        }
    }

    private func fallbackChat(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        temperature: Float,
        failedBackend: ChatBackend
    ) async throws -> String {
        let fallbackOrder: [ChatBackend] = [.mlx, .llamaCpp, .deepseek, .openai, .anthropic]

        for backend in fallbackOrder where backend != failedBackend {
            if isBackendAvailable(backend) {
                print("⚠️ Falling back to \(backend.rawValue) for chat")
                activeChat = backend
                return try await chatWithBackend(
                    backend: backend,
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    temperature: temperature
                )
            }
        }

        throw MLError.allBackendsFailed("chat")
    }

    // MARK: - Embedding Interface

    public func embed(text: String) async throws -> [Float] {
        guard let backend = activeEmbedding else {
            throw MLError.noBackendAvailable("embeddings")
        }

        do {
            return try await embedWithBackend(backend: backend, text: text)
        } catch {
            if config.enableFallback {
                return try await fallbackEmbed(text: text, failedBackend: backend)
            }
            throw error
        }
    }

    public func embedBatch(texts: [String]) async throws -> [[Float]] {
        guard let backend = activeEmbedding else {
            throw MLError.noBackendAvailable("embeddings")
        }

        var results: [[Float]] = []
        for text in texts {
            let embedding = try await embedWithBackend(backend: backend, text: text)
            results.append(embedding)
        }
        return results
    }

    private func embedWithBackend(backend: EmbeddingBackend, text: String) async throws -> [Float] {
        switch backend {
        case .mlx:
            guard let provider = mlxEmbeddingProvider else {
                throw MLError.backendNotAvailable("MLX embeddings")
            }
            return try await provider.embed(text: text)

        case .llamaCpp:
            guard let provider = llamaEmbeddingProvider else {
                throw MLError.backendNotAvailable("llama.cpp embeddings")
            }
            let results = try await provider.embedBatch(texts: [text])
            guard let first = results.first else {
                throw MLError.embeddingFailed("Empty result")
            }
            return first

        case .openai:
            guard let provider = cloudProviders["openai"] else {
                throw MLError.backendNotAvailable("OpenAI embeddings")
            }
            let request = EmbeddingRequest(input: [text], model: "text-embedding-3-small")
            let response = try await provider.embeddings(request: request)
            guard let first = response.embeddings.first else {
                throw MLError.embeddingFailed("Empty result")
            }
            return first

        case .google:
            guard let provider = cloudProviders["google"] else {
                throw MLError.backendNotAvailable("Google embeddings")
            }
            let request = EmbeddingRequest(input: [text], model: "text-embedding-004")
            let response = try await provider.embeddings(request: request)
            guard let first = response.embeddings.first else {
                throw MLError.embeddingFailed("Empty result")
            }
            return first
        }
    }

    private func fallbackEmbed(text: String, failedBackend: EmbeddingBackend) async throws -> [Float] {
        let fallbackOrder: [EmbeddingBackend] = [.mlx, .llamaCpp, .openai]

        for backend in fallbackOrder where backend != failedBackend {
            if isEmbeddingBackendAvailable(backend) {
                print("⚠️ Falling back to \(backend.rawValue) for embeddings")
                activeEmbedding = backend
                return try await embedWithBackend(backend: backend, text: text)
            }
        }

        throw MLError.allBackendsFailed("embeddings")
    }

    // MARK: - Status & Management

    public func getStatus() -> BackendStatus {
        BackendStatus(
            activeChat: activeChat,
            activeEmbedding: activeEmbedding,
            availableChats: availableChatBackends(),
            availableEmbeddings: availableEmbeddingBackends()
        )
    }

    public func switchChatBackend(_ backend: ChatBackend) async throws {
        guard isBackendAvailable(backend) else {
            throw MLError.backendNotAvailable(backend.rawValue)
        }
        activeChat = backend
        print("✅ Switched chat backend to \(backend.rawValue)")
    }

    public func switchEmbeddingBackend(_ backend: EmbeddingBackend) async throws {
        guard isEmbeddingBackendAvailable(backend) else {
            throw MLError.backendNotAvailable(backend.rawValue)
        }
        activeEmbedding = backend
        print("✅ Switched embedding backend to \(backend.rawValue)")
    }

    private func isBackendAvailable(_ backend: ChatBackend) -> Bool {
        switch backend {
        case .mlx: return true // We now use MLWorkerService which is always available (if binary exists)
        case .llamaCpp: return llamaChatProvider != nil
        case .deepseek: return cloudProviders["deepseek"] != nil
        case .openai: return cloudProviders["openai"] != nil
        case .anthropic: return cloudProviders["anthropic"] != nil
        case .google: return cloudProviders["google"] != nil
        case .ollama: return cloudProviders["ollama"] != nil
        }
    }

    private func isEmbeddingBackendAvailable(_ backend: EmbeddingBackend) -> Bool {
        switch backend {
        case .mlx: return mlxEmbeddingProvider != nil
        case .llamaCpp: return llamaEmbeddingProvider != nil
        case .openai: return cloudProviders["openai"] != nil
        case .google: return cloudProviders["google"] != nil
        }
    }

    private func availableChatBackends() -> [ChatBackend] {
        ChatBackend.allCases.filter { isBackendAvailable($0) }
    }

    private func availableEmbeddingBackends() -> [EmbeddingBackend] {
        EmbeddingBackend.allCases.filter { isEmbeddingBackendAvailable($0) }
    }
}

// MARK: - EmbeddingProviderProtocol Conformance

extension MLBackendCoordinator: EmbeddingProviderProtocol {
    public func generateEmbedding(text: String) async throws -> [Float] {
        return try await embed(text: text)
    }
}

// MARK: - Supporting Types

extension MLBackendCoordinator.ChatBackend: CaseIterable {}
extension MLBackendCoordinator.EmbeddingBackend: CaseIterable {}

public struct BackendStatus: Sendable {
    public let activeChat: MLBackendCoordinator.ChatBackend?
    public let activeEmbedding: MLBackendCoordinator.EmbeddingBackend?
    public let availableChats: [MLBackendCoordinator.ChatBackend]
    public let availableEmbeddings: [MLBackendCoordinator.EmbeddingBackend]
}

public enum MLError: Error, LocalizedError {
    case noBackendAvailable(String)
    case backendNotAvailable(String)
    case allBackendsFailed(String)
    case embeddingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noBackendAvailable(let type):
            return "No backend available for \(type)"
        case .backendNotAvailable(let name):
            return "Backend '\(name)' is not available"
        case .allBackendsFailed(let type):
            return "All backends failed for \(type)"
        case .embeddingFailed(let reason):
            return "Embedding generation failed: \(reason)"
        }
    }
}
