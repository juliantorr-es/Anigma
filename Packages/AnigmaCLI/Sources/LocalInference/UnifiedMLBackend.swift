import Foundation

/// Unified ML backend that intelligently selects between MLX, llama.cpp, and Ollama
public actor UnifiedMLBackend {
    private var activeBackend: MLBackendType?
    private var mlxBackend: MLXBackend?
    private var llamaBackend: LlamaCppBackend?
    private var ollamaBackend: OllamaBackend?

    public enum MLBackendType {
        case mlx
        case llamacpp
        case ollama
    }

    public struct BackendConfig {
        public let modelPath: String
        public let preferredBackend: MLBackendType?
        public let autoDetect: Bool

        public init(
            modelPath: String,
            preferredBackend: MLBackendType? = nil,
            autoDetect: Bool = true
        ) {
            self.modelPath = modelPath
            self.preferredBackend = preferredBackend
            self.autoDetect = autoDetect
        }
    }

    public init() {}

    /// Initialize and select the best available backend
    public func initialize(config: BackendConfig) async throws {
        if let preferred = config.preferredBackend {
            try await setupBackend(preferred, modelPath: config.modelPath)
            self.activeBackend = preferred
            return
        }

        if config.autoDetect {
            // Try backends in order of preference
            if await isMLXAvailable() {
                try await setupBackend(.mlx, modelPath: config.modelPath)
                self.activeBackend = .mlx
                print("✓ Using MLX backend")
            } else if await isLlamaCppAvailable() {
                try await setupBackend(.llamacpp, modelPath: config.modelPath)
                self.activeBackend = .llamacpp
                print("✓ Using llama.cpp backend")
            } else if await isOllamaAvailable() {
                try await setupBackend(.ollama, modelPath: config.modelPath)
                self.activeBackend = .ollama
                print("✓ Using Ollama backend")
            } else {
                throw UnifiedMLError.noBackendAvailable
            }
        }
    }

    /// Generate text using active backend
    public func generate(prompt: String) async throws -> String {
        guard let backend = activeBackend else {
            throw UnifiedMLError.notInitialized
        }

        switch backend {
        case .mlx:
            return try await mlxBackend!.generate(prompt: prompt)
        case .llamacpp:
            return try await llamaBackend!.generate(prompt: prompt)
        case .ollama:
            return try await ollamaBackend!.generate(prompt: prompt)
        }
    }

    /// Generate embeddings using active backend
    public func embed(text: String) async throws -> [Float] {
        guard let backend = activeBackend else {
            throw UnifiedMLError.notInitialized
        }

        switch backend {
        case .mlx:
            return try await mlxBackend!.embed(text: text)
        case .llamacpp:
            let results = try await llamaBackend!.generateEmbeddings(texts: [text], modelPath: "")
            return results.first ?? []
        case .ollama:
            return try await ollamaBackend!.embed(text: text)
        }
    }

    /// Get current backend status
    public func getStatus() async -> MLBackendStatus {
        return MLBackendStatus(
            activeBackend: activeBackend,
            mlxAvailable: await isMLXAvailable(),
            llamacppAvailable: await isLlamaCppAvailable(),
            ollamaAvailable: await isOllamaAvailable()
        )
    }

    // MARK: - Private Methods

    private func setupBackend(_ type: MLBackendType, modelPath: String) async throws {
        switch type {
        case .mlx:
            let backend = MLXBackend(modelPath: modelPath)
            try await backend.loadModel()
            self.mlxBackend = backend

        case .llamacpp:
            self.llamaBackend = LlamaCppBackend(modelPath: modelPath)

        case .ollama:
            self.ollamaBackend = OllamaBackend()
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
        let tempBackend = LlamaCppBackend(modelPath: "")
        return await tempBackend.isAvailable()
    }

    private func isOllamaAvailable() async -> Bool {
        if let backend = ollamaBackend {
            return await backend.isAvailable()
        }
        let tempBackend = OllamaBackend()
        return await tempBackend.isAvailable()
    }
}

public struct MLBackendStatus {
    public let activeBackend: UnifiedMLBackend.MLBackendType?
    public let mlxAvailable: Bool
    public let llamacppAvailable: Bool
    public let ollamaAvailable: Bool
}

public enum UnifiedMLError: Error {
    case notInitialized
    case noBackendAvailable
    case backendFailed(String)
}
