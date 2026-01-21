import Foundation

/// Unified inference provider supporting MLX and llama.cpp backends
@available(macOS 13.0, *)
public actor UnifiedInferenceProvider {
    public enum Backend: String, Codable, Sendable {
        case mlx
        case llamacpp
        case cloud
    }

    public struct Config: Codable, Sendable {
        let backend: Backend
        let modelPath: String?
        let contextSize: Int
        let threads: Int

        public init(backend: Backend, modelPath: String? = nil, contextSize: Int = 2048, threads: Int = 0) {
            self.backend = backend
            self.modelPath = modelPath
            self.contextSize = contextSize
            self.threads = threads
        }
    }

    private let config: Config
    private var mlxProvider: MLXChatProvider?
    private var llamaProvider: LlamaCppProvider?
    private var isInitialized = false

    public init(config: Config) {
        self.config = config
    }

    public func initialize() async throws {
        guard !isInitialized else { return }

        switch config.backend {
        case .mlx:
            #if canImport(MLX)
            mlxProvider = MLXChatProvider()
            try await mlxProvider?.initialize()
            #else
            throw InferenceError.backendNotAvailable("MLX not available")
            #endif

        case .llamacpp:
            #if canImport(llama)
            guard let modelPath = config.modelPath else {
                throw InferenceError.missingConfiguration("Model path required for llama.cpp")
            }
            llamaProvider = LlamaCppProvider(
                modelPath: modelPath,
                contextSize: config.contextSize,
                threads: config.threads
            )
            try await llamaProvider?.initialize()
            #else
            throw InferenceError.backendNotAvailable("llama.cpp not available")
            #endif

        case .cloud:
            throw InferenceError.backendNotAvailable("Cloud backend requires separate provider")
        }

        isInitialized = true
    }

    public func generate(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        stopSequences: [String] = []
    ) async throws -> String {
        guard isInitialized else {
            throw InferenceError.notInitialized
        }

        switch config.backend {
        case .mlx:
            #if canImport(MLX)
            guard let provider = mlxProvider else {
                throw InferenceError.backendNotAvailable("MLX provider not initialized")
            }
            return try await provider.generate(
                prompt: prompt,
                maxTokens: maxTokens,
                temperature: temperature
            )
            #else
            throw InferenceError.backendNotAvailable("MLX not available")
            #endif

        case .llamacpp:
            guard let provider = llamaProvider else {
                throw InferenceError.backendNotAvailable("llama.cpp provider not initialized")
            }
            return try await provider.generate(
                prompt: prompt,
                maxTokens: maxTokens,
                temperature: temperature
            )

        case .cloud:
            throw InferenceError.backendNotAvailable("Cloud backend not supported in unified provider")
        }
    }

    public func stream(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await generate(
                        prompt: prompt,
                        maxTokens: maxTokens,
                        temperature: temperature
                    )

                    // Simple word-by-word streaming for now
                    let words = result.split(separator: " ")
                    for word in words {
                        continuation.yield(String(word) + " ")
                        try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

public enum InferenceError: Error {
    case backendNotAvailable(String)
    case notInitialized
    case missingConfiguration(String)
    case generationFailed(String)
}

/// Auto-selecting inference provider that chooses the best available backend
@available(macOS 13.0, *)
public actor AutoInferenceProvider {
    private var provider: UnifiedInferenceProvider?

    public init() {}

    public func initialize(preferredBackend: UnifiedInferenceProvider.Backend? = nil) async throws {
        let config: UnifiedInferenceProvider.Config

        if let preferred = preferredBackend {
            config = UnifiedInferenceProvider.Config(backend: preferred)
        } else {
            // Auto-detect best available backend
            #if canImport(MLX)
            config = UnifiedInferenceProvider.Config(backend: .mlx)
            #elseif canImport(llama)
            // Try to find a default model
            let defaultPaths = [
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".anigma/models/llama-2-7b.gguf"),
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("models/llama-2-7b.gguf")
            ]

            if let modelPath = defaultPaths.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
                config = UnifiedInferenceProvider.Config(
                    backend: .llamacpp,
                    modelPath: modelPath.path
                )
            } else {
                throw InferenceError.missingConfiguration("No models found in default locations")
            }
            #else
            throw InferenceError.backendNotAvailable("No local inference backend available")
            #endif
        }

        provider = UnifiedInferenceProvider(config: config)
        try await provider?.initialize()
    }

    public func generate(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) async throws -> String {
        guard let provider = provider else {
            throw InferenceError.notInitialized
        }
        return try await provider.generate(
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: temperature
        )
    }

    public func stream(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let provider = self.provider else {
                    continuation.finish(throwing: InferenceError.notInitialized)
                    return
                }

                do {
                    for try await chunk in await provider.stream(prompt: prompt, maxTokens: maxTokens, temperature: temperature) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
