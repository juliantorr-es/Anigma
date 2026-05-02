import Foundation

/// Simple fallback embedding provider using TF-IDF-like approach
public final class SimpleFallbackProvider: EmbeddingProvider, @unchecked Sendable {
    public let name = "Simple Fallback"
    public let dimensions = 384

    public init() {}

    public var isAvailable: Bool {
        get async { true } // Always available
    }

    public func generateEmbedding(text: String) async throws -> [Float] {
        // Simple hash-based embedding for fallback
        // Not semantically meaningful but deterministic and fast
        var embedding = [Float](repeating: 0, count: dimensions)

        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)

        for (index, word) in words.enumerated() {
            let hash = Swift.abs(word.hashValue)
            let position = hash % dimensions
            let value = Float(index + 1) / Float(words.count)
            embedding[position] += value
        }

        // Normalize
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            embedding = embedding.map { $0 / magnitude }
        }

        return embedding
    }
}

/// OpenAI API-based embedding provider
public final class OpenAIEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    public let name = "OpenAI API"
    public let dimensions = 1536 // text-embedding-3-small

    private let apiKey: String
    private let model: String

    public init(apiKey: String, model: String = "text-embedding-3-small") {
        self.apiKey = apiKey
        self.model = model
    }

    public var isAvailable: Bool {
        get async {
            !apiKey.isEmpty
        }
    }

    public func generateEmbedding(text: String) async throws -> [Float] {
        guard await isAvailable else {
            throw EmbeddingError.providerUnavailable
        }

        guard let url = URL(string: "https://api.openai.com/v1/embeddings") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": text,
            "model": model
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EmbeddingError.computationFailed("API request failed")
        }

        struct EmbeddingResponse: Codable {
            struct Data: Codable {
                let embedding: [Float]
            }
            let data: [Data]
        }

        let result = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        guard let embedding = result.data.first?.embedding else {
            throw EmbeddingError.computationFailed("No embedding in response")
        }

        return embedding
    }
}
