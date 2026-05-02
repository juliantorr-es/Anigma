import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Ollama local/cloud inference provider
public final class OllamaProvider: InferenceProvider, @unchecked Sendable {
    public let name = "Ollama"
    public let requiresAPIKey = false

    private var baseURL: String
    private let defaultModel = "qwen2.5-coder:7b"

    public init(baseURL: String = "http://localhost:11434") {
        self.baseURL = baseURL
    }

    public func configure(apiKey: String?) async throws {
        // Ollama doesn't require API key, but might need custom URL
        if let customURL = apiKey, !customURL.isEmpty {
            self.baseURL = customURL
        }
    }

    public func validateConfiguration() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)

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
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model ?? defaultModel,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.invalidResponse("Not an HTTP response")
            }

            guard httpResponse.statusCode == 200 else {
                throw ProviderError.invalidResponse("Ollama request failed with status \(httpResponse.statusCode)")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
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
        guard let url = URL(string: "\(baseURL)/api/embeddings") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let embeddingModel = model ?? "nomic-embed-text"
        let payload: [String: Any] = [
            "model": embeddingModel,
            "prompt": text
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.invalidResponse("Not an HTTP response")
            }

            guard httpResponse.statusCode == 200 else {
                throw ProviderError.invalidResponse("Ollama embedding request failed")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let embedding = json["embedding"] as? [Double] else {
                throw ProviderError.invalidResponse("Missing embedding in response")
            }

            return embedding.map { Float($0) }
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
}
