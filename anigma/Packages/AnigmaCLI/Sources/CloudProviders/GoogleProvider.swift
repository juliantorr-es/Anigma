import Foundation
import AnigmaSidecar

public final class GoogleProvider: CloudProvider, @unchecked Sendable {
    public let name = "Google"
    public let supportsChat = true
    public let supportsEmbeddings = true
    
    public var bridge: SidecarBridge?

    private var apiKey: String?
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"

    public init() {}

    public func configure(apiKey: String) async throws {
        self.apiKey = apiKey
    }

    public func validateConnection() async throws -> Bool {
        if let bridge = bridge {
            return try await bridge.healthCheck()
        }
        guard apiKey != nil else {
            throw CloudProviderError.notConfigured
        }
        return true
    }

    public func chat(messages: [ChatMessage], model: String?, temperature: Double) async throws -> String {
        if let bridge = bridge {
            return try await bridge.chat(
                messages: messages.map { AnigmaPrimitives.ChatMessage(role: $0.role, content: $0.content) },
                model: model,
                temperature: temperature,
                provider: "google"
            )
        }
        
        guard let apiKey = apiKey else {
            throw CloudProviderError.notConfigured
        }

        let modelName = model ?? "gemini-2.0-flash-exp"
        guard let url = URL(string: "\(baseURL)/models/\(modelName):generateContent?key=\(apiKey)") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let contents = messages.map { msg in
            ["role": msg.role == "assistant" ? "model" : "user", "parts": [["text": msg.content]]]
        }

        let payload: [String: Any] = [
            "contents": contents,
            "generationConfig": ["temperature": temperature]
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
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw CloudProviderError.invalidResponse
        }

        return text
    }

    public func embeddings(texts: [String], model: String?) async throws -> [[Float]] {
        if let bridge = bridge {
            var allEmbeddings: [[Float]] = []
            for text in texts {
                let response = try await bridge.embed(text: text, model: model ?? "text-embedding-004")
                allEmbeddings.append(response.vector)
            }
            return allEmbeddings
        }
        
        guard let apiKey = apiKey else {
            throw CloudProviderError.notConfigured
        }

        let modelName = model ?? "text-embedding-004"
        var allEmbeddings: [[Float]] = []

        for text in texts {
            guard let url = URL(string: "\(baseURL)/models/\(modelName):embedContent?key=\(apiKey)") else {
                fatalError("Failed to unwrap url")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let payload: [String: Any] = [
                "content": ["parts": [["text": text]]]
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
                  let embedding = json["embedding"] as? [String: Any],
                  let values = embedding["values"] as? [Double] else {
                throw CloudProviderError.invalidResponse
            }

            allEmbeddings.append(values.map { Float($0) })
        }

        return allEmbeddings
    }
}
