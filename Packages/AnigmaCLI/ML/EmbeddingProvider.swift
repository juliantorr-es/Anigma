import Foundation
import AnigmaCLICore

/// OpenAI embedding provider
public actor OpenAIEmbeddingProvider: EmbeddingProvider {
    public let dimension = 1536
    public let name = "OpenAI"
    private let apiKey: String
    private let model: String

    public init(apiKey: String, model: String = "text-embedding-3-small") {
        self.apiKey = apiKey
        self.model = model
    }

    public func embed(text: String) async throws -> [Float] {
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
            throw EmbeddingError.apiError("Failed to get embedding")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]],
              let first = dataArray.first,
              let embedding = first["embedding"] as? [Double] else {
            throw EmbeddingError.invalidResponse
        }

        return embedding.map { Float($0) }
    }
}
