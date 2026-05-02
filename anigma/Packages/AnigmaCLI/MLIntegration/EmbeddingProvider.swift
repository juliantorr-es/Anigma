import Foundation

/// Protocol for embedding providers
public protocol EmbeddingProvider: Sendable {
    func generateEmbedding(text: String) async throws -> [Float]
    var dimensions: Int { get }
    var name: String { get }
    var isAvailable: Bool { get async }
}

/// Error types for embedding operations
public enum EmbeddingError: Error {
    case providerUnavailable
    case modelNotLoaded
    case invalidInput
    case computationFailed(String)
}

/// Manages available embedding providers with fallback support
public actor EmbeddingManager {
    private var providers: [EmbeddingProvider] = []
    private var activeProvider: EmbeddingProvider?

    public init() {}

    public func registerProvider(_ provider: EmbeddingProvider) {
        providers.append(provider)
    }

    public func initializeProvider() async throws {
        // Try providers in order of preference
        for provider in providers {
            if await provider.isAvailable {
                activeProvider = provider
                print("✓ Initialized embedding provider: \(provider.name)")
                return
            }
        }
        throw EmbeddingError.providerUnavailable
    }

    public func generateEmbedding(text: String) async throws -> [Float] {
        guard let provider = activeProvider else {
            throw EmbeddingError.providerUnavailable
        }
        return try await provider.generateEmbedding(text: text)
    }

    public var dimensions: Int {
        get async {
            activeProvider?.dimensions ?? 384
        }
    }

    public var providerName: String {
        get async {
            activeProvider?.name ?? "none"
        }
    }
}
