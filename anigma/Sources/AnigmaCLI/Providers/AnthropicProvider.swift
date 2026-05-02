import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Anthropic Claude inference provider
public final class AnthropicProvider: InferenceProvider, @unchecked Sendable {
    public let name = "Anthropic"
    public let requiresAPIKey = true

    private var apiKey: String?
    private let baseURL = "https://api.anthropic.com/v1"
    private let defaultModel = "claude-3-5-sonnet-20241022"
    private let apiVersion = "2023-06-01"

    public init() {}

    public func configure(apiKey: String?) async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw ProviderError.missingAPIKey(provider: name)
        }
        self.apiKey = apiKey
    }

    public func validateConfiguration() async throws -> Bool {
        guard let apiKey = apiKey else {
            throw ProviderError.missingAPIKey(provider: name)
        }

        // Anthropic doesn't have a models endpoint, so we do a minimal completion
        guard let url = URL(string: "\(baseURL)/messages") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": defaultModel,
            "messages": [["role": "user", "content": "test"]],
            "max_tokens": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.invalidResponse("Not an HTTP response")
            }
            return httpResponse.statusCode == 200
        } catch {
            throw ProviderError.networkError(error)
        }
    }

    public func chat(messages: [ChatMessage], model: String?) async throws -> String {
        guard let apiKey = apiKey else {
            throw ProviderError.missingAPIKey(provider: name)
        }

        guard let url = URL(string: "\(baseURL)/messages") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert messages - Anthropic doesn't support system messages the same way
        var anthropicMessages: [[String: Any]] = []
        var systemMessage: String?

        for message in messages {
            if message.role == "system" {
                systemMessage = message.content
            } else {
                anthropicMessages.append([
                    "role": message.role,
                    "content": message.content
                ])
            }
        }

        var payload: [String: Any] = [
            "model": model ?? defaultModel,
            "messages": anthropicMessages,
            "max_tokens": 4096
        ]

        if let system = systemMessage {
            payload["system"] = system
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.invalidResponse("Not an HTTP response")
            }

            guard httpResponse.statusCode == 200 else {
                throw ProviderError.invalidAPIKey(provider: name)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                throw ProviderError.invalidResponse("Missing content in response")
            }

            return text
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }

    public func embed(text: String, model: String?) async throws -> [Float] {
        // Anthropic doesn't provide embedding endpoints
        throw ProviderError.modelNotAvailable("Embeddings not supported by Anthropic")
    }
}
