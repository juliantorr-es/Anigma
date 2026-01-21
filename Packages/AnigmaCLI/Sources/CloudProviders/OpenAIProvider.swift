import Foundation

public final class OpenAIProvider: CloudProvider, @unchecked Sendable {
    public let name = "OpenAI"
    public let supportsChat = true
    public let supportsEmbeddings = true

    private var apiKey: String?
    private let baseURL = "https://api.openai.com/v1"

    public init() {}

    public func configure(apiKey: String) async throws {
        self.apiKey = apiKey
    }

    public func validateConnection() async throws -> Bool {
        guard let apiKey = apiKey else {
            throw CloudProviderError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)/models") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    public func chat(messages: [ChatMessage], model: String?, temperature: Double) async throws -> String {
        guard let apiKey = apiKey else {
            throw CloudProviderError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model ?? "gpt-4o-mini",
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
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
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw CloudProviderError.invalidResponse
        }

        return content
    }

    public func embeddings(texts: [String], model: String?) async throws -> [[Float]] {
        guard let apiKey = apiKey else {
            throw CloudProviderError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)/embeddings") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model ?? "text-embedding-3-small",
            "input": texts
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
              let data = json["data"] as? [[String: Any]] else {
            throw CloudProviderError.invalidResponse
        }

        return try data.map { item in
            guard let embedding = item["embedding"] as? [Double] else {
                throw CloudProviderError.invalidResponse
            }
            return embedding.map { Float($0) }
        }
    }
}
