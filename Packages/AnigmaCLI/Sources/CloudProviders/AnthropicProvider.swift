import Foundation

public final class AnthropicProvider: CloudProvider, @unchecked Sendable {
    public let name = "Anthropic"
    public let supportsChat = true
    public let supportsEmbeddings = true

    private var apiKey: String?
    private let baseURL = "https://api.anthropic.com/v1"

    public init() {}

    public func configure(apiKey: String) async throws {
        self.apiKey = apiKey
    }

    public func validateConnection() async throws -> Bool {
        guard apiKey != nil else {
            throw CloudProviderError.notConfigured
        }
        return true
    }

    public func chat(messages: [ChatMessage], model: String?, temperature: Double) async throws -> String {
        guard let apiKey = apiKey else {
            throw CloudProviderError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)/messages") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let payload: [String: Any] = [
            "model": model ?? "claude-3-5-sonnet-20241022",
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": 4096,
            "temperature": temperature
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudProviderError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CloudProviderError.apiError(error)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw CloudProviderError.invalidResponse
        }

        return text
    }

    public func embeddings(texts: [String], model: String?) async throws -> [[Float]] {
        guard let apiKey = apiKey else {
            throw CloudProviderError.notConfigured
        }

        // Anthropic uses Voyage AI for embeddings
        guard let url = URL(string: "https://api.voyageai.com/v1/embeddings") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": texts,
            "model": model ?? "voyage-2"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudProviderError.apiError("Failed to get embeddings")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]] else {
            throw CloudProviderError.invalidResponse
        }

        return dataArray.compactMap { item in
            (item["embedding"] as? [Double])?.map { Float($0) }
        }
    }
}
