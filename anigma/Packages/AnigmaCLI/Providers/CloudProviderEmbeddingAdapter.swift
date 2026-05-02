import Foundation
import AnigmaCLICore

/// Adapter to use cloud providers for embeddings
public actor CloudProviderEmbeddingAdapter: EmbeddingProvider {
    private let provider: any CloudProvider
    private let modelName: String
    public nonisolated let name: String
    public nonisolated let dimension: Int

    public init(provider: any CloudProvider, model: String, dimension: Int = 1536) {
        self.provider = provider
        self.modelName = model
        self.name = "Cloud(\(type(of: provider)))"
        self.dimension = dimension
    }

    public func embed(text: String) async throws -> [Float] {
        let request = EmbeddingRequest(input: [text], model: modelName)
        let response = try await provider.embeddings(request: request)
        guard let first = response.embeddings.first else {
            throw EmbeddingError.invalidResponse
        }
        return first
    }
}
