import Foundation
import AnigmaNativeShims
import AnigmaCLICore

/// llama.cpp-based embedding provider
@available(macOS 13.0, *)
public actor LlamaCppEmbeddingProvider: EmbeddingProvider {
    public nonisolated let name = "llama.cpp"
    public nonisolated var dimension: Int { 384 } // TODO: Get from model

    private let bridge: NativeLlamaCppBridge
    private var isInitialized = false
    private var modelPath: String

    public init(modelPath: String, contextSize: Int = 512) {
        self.modelPath = modelPath
        self.bridge = NativeLlamaCppBridge()
    }

    public func initialize() async throws {
        guard !isInitialized else { return }
        try await bridge.loadModel(path: modelPath, forEmbeddings: true)
        isInitialized = true
    }

    public func embed(text: String) async throws -> [Float] {
        guard isInitialized else {
            throw EmbeddingError.notInitialized
        }

        return try await bridge.generateEmbedding(text: text)
    }

    public func embedBatch(texts: [String]) async throws -> [[Float]] {
        try await withThrowingTaskGroup(of: [Float].self) { group in
            for text in texts {
                group.addTask {
                    try await self.embed(text: text)
                }
            }

            var results: [[Float]] = []
            for try await embedding in group {
                results.append(embedding)
            }
            return results
        }
    }
}

/// Unified embedding provider supporting both MLX and llama.cpp
@available(macOS 13.0, *)
public actor HybridEmbeddingProvider {
    private enum Backend {
        case mlx
        case llamacpp
        case fallback
    }

    private let backend: Backend
    private var mlxProvider: MLXEmbeddingProvider?
    private var llamaProvider: LlamaCppEmbeddingProvider?

    public init(preferMLX: Bool = true, modelPath: String? = nil) async throws {
        #if canImport(MLX)
        if preferMLX {
            self.backend = .mlx
            self.mlxProvider = MLXEmbeddingProvider()
            try await mlxProvider?.initialize()
            return
        }
        #endif

        #if canImport(llama)
        if let modelPath = modelPath {
            self.backend = .llamacpp
            self.llamaProvider = LlamaCppEmbeddingProvider(modelPath: modelPath)
            try await llamaProvider?.initialize()
            return
        }
        #endif

        self.backend = .fallback
        print("⚠️ No native embedding backend available, using fallback")
    }

    public func embed(text: String) async throws -> [Float] {
        switch backend {
        case .mlx:
            #if canImport(MLX)
            guard let provider = mlxProvider else {
                throw EmbeddingError.backendNotAvailable
            }
            return try await provider.embed(text: text)
            #else
            throw EmbeddingError.backendNotAvailable
            #endif

        case .llamacpp:
            guard let provider = llamaProvider else {
                throw EmbeddingError.backendNotAvailable
            }
            return try await provider.embed(text: text)

        case .fallback:
            // Simple hash-based fallback for development
            return hashToVector(text: text, dimensions: 384)
        }
    }

    public func embedBatch(texts: [String]) async throws -> [[Float]] {
        switch backend {
        case .mlx:
            #if canImport(MLX)
            guard let provider = mlxProvider else {
                throw EmbeddingError.backendNotAvailable
            }
            return try await provider.embedBatch(texts: texts)
            #else
            throw EmbeddingError.backendNotAvailable
            #endif

        case .llamacpp:
            guard let provider = llamaProvider else {
                throw EmbeddingError.backendNotAvailable
            }
            return try await provider.embedBatch(texts: texts)

        case .fallback:
            return texts.map { hashToVector(text: $0, dimensions: 384) }
        }
    }

    private func hashToVector(text: String, dimensions: Int) -> [Float] {
        var hasher = Hasher()
        hasher.combine(text)
        let seed = hasher.finalize()

        var rng = SeededRandom(seed: UInt64(bitPattern: Int64(seed)))
        return (0..<dimensions).map { _ in rng.nextFloat() * 2 - 1 }
    }
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func nextFloat() -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let value = (state >> 32) ^ state
        return Float(value) / Float(UInt64.max)
    }
}
