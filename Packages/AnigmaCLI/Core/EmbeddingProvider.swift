import Foundation

/// Protocol for embedding providers (local and cloud)
@preconcurrency
public protocol EmbeddingProvider: Sendable {
    /// Generate embedding vector for text
    func embed(text: String) async throws -> [Float]

    /// Embedding dimension
    nonisolated var dimension: Int { get }

    /// Provider name
    nonisolated var name: String { get }
}

public enum EmbeddingError: Error {
    case apiError(String)
    case invalidResponse
    case modelNotFound
    case backendNotAvailable
    case notInitialized
}
