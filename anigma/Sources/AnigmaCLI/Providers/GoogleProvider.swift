import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Google Gemini inference provider
public final class GoogleProvider: InferenceProvider, @unchecked Sendable {
    public let name = "Google"
    public let requiresAPIKey = true

    private var apiKey: String?
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let defaultModel = "gemini-2.0-flash-exp"

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

        guard let url = URL(string: "\(baseURL)/models?key=\(apiKey)") else {
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
        guard let apiKey = apiKey else {
            throw ProviderError.missingAPIKey(provider: name)
        }

        let modelName = model ?? defaultModel
        guard let url = URL(string: "\(baseURL)/models/\(modelName):generateContent?key=\(apiKey)") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert messages to Gemini format
        var contents: [[String: Any]] = []
        var systemInstruction: String?

        for message in messages {
            if message.role == "system" {
                systemInstruction = message.content
            } else {
                let role = message.role == "assistant" ? "model" : "user"
                contents.append([
                    "role": role,
                    "parts": [["text": message.content]]
                ])
            }
        }

        var payload: [String: Any] = [
            "contents": contents
        ]

        if let system = systemInstruction {
            payload["systemInstruction"] = [
                "parts": [["text": system]]
            ]
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
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
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
        guard let apiKey = apiKey else {
            throw ProviderError.missingAPIKey(provider: name)
        }

        let embeddingModel = model ?? "text-embedding-004"
        guard let url = URL(string: "\(baseURL)/models/\(embeddingModel):embedContent?key=\(apiKey)") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "content": [
                "parts": [["text": text]]
            ]
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
                  let embedding = json["embedding"] as? [String: Any],
                  let values = embedding["values"] as? [Double] else {
                throw ProviderError.invalidResponse("Missing embedding in response")
            }

            return values.map { Float($0) }
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
}
