import Foundation

#if canImport(MLX)
import MLX
#endif

/// Unified interface for all inference backends (cloud + local)
/// Combines auto-detection, intelligent fallback, and cloud provider support
public actor UnifiedInferenceEngine {
    private var mlxBackend: MLXBackend?
    private var llamaBackend: LlamaCppBackend?
    private var ollamaBackend: OllamaBackend?
    private var mlxEngine: MLXInferenceEngine?
    private var llamaCppEngine: LlamaCppEngine?
    private var activeBackend: InferenceBackend?
    private let config: BackendConfig

    public enum InferenceBackend: Equatable {
        case mlx
        case llamaCpp
        case ollama
        case cloud(String) // provider name
    }

    public struct BackendConfig {
        public let modelPath: String?
        public let preferredBackend: InferenceBackend?
        public let autoDetect: Bool
        public let fallbackEnabled: Bool

        public init(
            modelPath: String? = nil,
            preferredBackend: InferenceBackend? = nil,
            autoDetect: Bool = true,
            fallbackEnabled: Bool = true
        ) {
            self.modelPath = modelPath
            self.preferredBackend = preferredBackend
            self.autoDetect = autoDetect
            self.fallbackEnabled = fallbackEnabled
        }
    }

    public init(config: BackendConfig = BackendConfig()) {
        self.config = config
    }

    /// Initialize and select the best available backend
    public func initialize() async throws {
        if let preferred = config.preferredBackend {
            try await setupBackend(preferred)
            self.activeBackend = preferred
            print("✓ Using preferred backend: \(preferred)")
            return
        }

        if config.autoDetect {
            // Try backends in order of preference: MLX > llama.cpp > Ollama
            if await isMLXAvailable() {
                try await setupBackend(.mlx)
                self.activeBackend = .mlx
                print("✓ Auto-detected MLX backend")
            } else if await isLlamaCppAvailable() {
                try await setupBackend(.llamaCpp)
                self.activeBackend = .llamaCpp
                print("✓ Auto-detected llama.cpp backend")
            } else if await isOllamaAvailable() {
                try await setupBackend(.ollama)
                self.activeBackend = .ollama
                print("✓ Auto-detected Ollama backend")
            } else {
                throw InferenceError.noBackendAvailable
            }
        }
    }

    /// Generate text completion with automatic fallback
    public func generate(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) async throws -> String {
        guard let backend = activeBackend else {
            throw InferenceError.notInitialized
        }

        do {
            return try await generateWithBackend(
                backend: backend,
                prompt: prompt,
                maxTokens: maxTokens,
                temperature: temperature
            )
        } catch {
            if config.fallbackEnabled {
                return try await tryFallbackGeneration(
                    prompt: prompt,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    failedBackend: backend
                )
            }
            throw error
        }
    }

    /// Generate embeddings with automatic fallback
    public func embed(text: String) async throws -> [Float] {
        guard let backend = activeBackend else {
            throw InferenceError.notInitialized
        }

        do {
            return try await embedWithBackend(backend: backend, text: text)
        } catch {
            if config.fallbackEnabled {
                return try await tryFallbackEmbedding(text: text, failedBackend: backend)
            }
            throw error
        }
    }

    /// Get current backend status
    public func getStatus() async -> BackendStatus {
        return BackendStatus(
            activeBackend: activeBackend,
            mlxAvailable: await isMLXAvailable(),
            llamacppAvailable: await isLlamaCppAvailable(),
            ollamaAvailable: await isOllamaAvailable()
        )
    }

    /// Unload all backends
    public func unload() async {
        await mlxEngine?.unload()
        await llamaCppEngine?.unload()
        mlxBackend = nil
        llamaBackend = nil
        ollamaBackend = nil
    }

    // MARK: - Private Methods

    private func setupBackend(_ type: InferenceBackend) async throws {
        switch type {
        case .mlx:
            guard await isMLXAvailable() else {
                throw InferenceError.backendNotAvailable("MLX")
            }
            if let path = config.modelPath {
                mlxBackend = MLXBackend(modelPath: path)
                try await mlxBackend?.loadModel()
                mlxEngine = MLXInferenceEngine(modelPath: URL(fileURLWithPath: path))
                try await mlxEngine?.loadModel()
            }

        case .llamaCpp:
            guard await isLlamaCppAvailable() else {
                throw InferenceError.backendNotAvailable("llama.cpp")
            }
            if let path = config.modelPath {
                llamaBackend = LlamaCppBackend(modelPath: path)
                llamaCppEngine = LlamaCppEngine(modelPath: URL(fileURLWithPath: path))
                try await llamaCppEngine?.loadModel()
            }

        case .ollama:
            guard await isOllamaAvailable() else {
                throw InferenceError.backendNotAvailable("Ollama")
            }
            ollamaBackend = OllamaBackend()

        case .cloud:
            break // Cloud providers initialized separately
        }
    }

    private func generateWithBackend(
        backend: InferenceBackend,
        prompt: String,
        maxTokens: Int,
        temperature: Float
    ) async throws -> String {
        switch backend {
        case .mlx:
            if let engine = mlxEngine {
                return try await engine.generate(
                    prompt: prompt,
                    maxTokens: maxTokens,
                    temperature: temperature
                )
            } else if let mlx = mlxBackend {
                return try await mlx.generate(prompt: prompt)
            }
            throw InferenceError.backendNotAvailable("MLX")

        case .llamaCpp:
            if let engine = llamaCppEngine {
                return try await engine.generate(
                    prompt: prompt,
                    maxTokens: maxTokens,
                    temperature: temperature
                )
            } else if let llama = llamaBackend, let path = config.modelPath {
                return try await llama.chat(
                    prompt: prompt,
                    modelPath: path,
                    temperature: Double(temperature),
                    maxTokens: maxTokens
                )
            }
            throw InferenceError.backendNotAvailable("llama.cpp")

        case .ollama:
            guard let ollama = ollamaBackend else {
                throw InferenceError.backendNotAvailable("Ollama")
            }
            return try await ollama.generate(prompt: prompt)

        case .cloud(let provider):
            throw InferenceError.notImplemented("Cloud provider: \(provider)")
        }
    }

    private func embedWithBackend(backend: InferenceBackend, text: String) async throws -> [Float] {
        switch backend {
        case .mlx:
            if let engine = mlxEngine {
                return try await engine.embed(text: text)
            } else if let mlx = mlxBackend {
                let result = try await mlx.embed(text: text)
                return result
            }
            throw InferenceError.backendNotAvailable("MLX")

        case .llamaCpp:
            if let engine = llamaCppEngine {
                return try await engine.embed(text: text)
            } else if let llama = llamaBackend, let path = config.modelPath {
                let results = try await llama.generateEmbeddings(texts: [text], modelPath: path)
                return results.first ?? []
            }
            throw InferenceError.backendNotAvailable("llama.cpp")

        case .ollama:
            guard let ollama = ollamaBackend else {
                throw InferenceError.backendNotAvailable("Ollama")
            }
            return try await ollama.embed(text: text)

        case .cloud(let provider):
            throw InferenceError.notImplemented("Cloud embeddings: \(provider)")
        }
    }

    private func tryFallbackGeneration(
        prompt: String,
        maxTokens: Int,
        temperature: Float,
        failedBackend: InferenceBackend
    ) async throws -> String {
        let fallbackOrder: [InferenceBackend] = [.mlx, .llamaCpp, .ollama]

        for backend in fallbackOrder where backend != failedBackend {
            if await isBackendAvailable(backend) {
                print("⚠️ Falling back to \(backend)")
                try await setupBackend(backend)
                self.activeBackend = backend
                return try await generateWithBackend(
                    backend: backend,
                    prompt: prompt,
                    maxTokens: maxTokens,
                    temperature: temperature
                )
            }
        }

        throw InferenceError.allBackendsFailed
    }

    private func tryFallbackEmbedding(text: String, failedBackend: InferenceBackend) async throws -> [Float] {
        let fallbackOrder: [InferenceBackend] = [.mlx, .llamaCpp, .ollama]

        for backend in fallbackOrder where backend != failedBackend {
            if await isBackendAvailable(backend) {
                print("⚠️ Falling back to \(backend)")
                try await setupBackend(backend)
                self.activeBackend = backend
                return try await embedWithBackend(backend: backend, text: text)
            }
        }

        throw InferenceError.allBackendsFailed
    }

    private func isBackendAvailable(_ backend: InferenceBackend) async -> Bool {
        switch backend {
        case .mlx: return await isMLXAvailable()
        case .llamaCpp: return await isLlamaCppAvailable()
        case .ollama: return await isOllamaAvailable()
        case .cloud: return false
        }
    }

    private func isMLXAvailable() async -> Bool {
        #if canImport(MLX)
        return true
        #else
        return false
        #endif
    }

    private func isLlamaCppAvailable() async -> Bool {
        if let backend = llamaBackend {
            return await backend.isAvailable()
        }
        return await LlamaCppBackend.shared.isAvailable()
    }

    private func isOllamaAvailable() async -> Bool {
        if let ollama = ollamaBackend {
            return await ollama.isAvailable()
        }
        return await OllamaBackend().isAvailable()
    }
}

// MARK: - Supporting Types

public struct BackendStatus {
    public let activeBackend: UnifiedInferenceEngine.InferenceBackend?
    public let mlxAvailable: Bool
    public let llamacppAvailable: Bool
    public let ollamaAvailable: Bool
}
