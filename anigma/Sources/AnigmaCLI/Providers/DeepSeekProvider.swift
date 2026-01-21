import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// DeepSeek inference provider
public final class DeepSeekProvider: InferenceProvider, @unchecked Sendable {
    public let name = "DeepSeek"
    public let requiresAPIKey = true

    private var apiKey: String?
    private let baseURL = "https://api.deepseek.com/v1"
    private let defaultModel = "deepseek-chat"

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

        // Test API key with a minimal request
        guard let url = URL(string: "\(baseURL)/models") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

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

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model ?? defaultModel,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]

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
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw ProviderError.invalidResponse("Missing content in response")
            }

            return content
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }

    public func embed(text: String, model: String?) async throws -> [Float] {
        // DeepSeek doesn't have a dedicated embedding endpoint in their public API
        // This would need to be implemented if they add one
        throw ProviderError.modelNotAvailable("Embeddings not supported by DeepSeek")
    }
}
