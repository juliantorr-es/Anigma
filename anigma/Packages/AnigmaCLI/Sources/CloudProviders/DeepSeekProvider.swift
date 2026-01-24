import Foundation
import AnigmaSidecar

public final class DeepSeekProvider: CloudProvider, @unchecked Sendable {
    public let name = "DeepSeek"
    public let supportsChat = true
    public let supportsEmbeddings = false
    
    public var bridge: SidecarBridge?

    private var apiKey: String?
    private let baseURL = "https://api.deepseek.com/v1"

    public init() {}

    public func configure(apiKey: String) async throws {
        self.apiKey = apiKey
    }

    public func validateConnection() async throws -> Bool {
        if let bridge = bridge {
            return try await bridge.healthCheck()
        }
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
        if let bridge = bridge {
            return try await bridge.chat(
                messages: messages.map { AnigmaPrimitives.ChatMessage(role: $0.role, content: $0.content) },
                model: model,
                temperature: temperature,
                provider: "deepseek"
            )
        }
        
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
            "model": model ?? "deepseek-chat",
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
        if let bridge = bridge {
            var results: [[Float]] = []
            for text in texts {
                let response = try await bridge.embed(text: text, model: model ?? "deepseek-embedder")
                results.append(response.vector)
            }
            return results
        }
        
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

        let body: [String: Any] = [
            "input": texts,
            "model": model ?? "deepseek-embedder"
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
