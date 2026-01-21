import Foundation

/// Ollama-based inference backend via HTTP API
public actor OllamaBackend {
    private let baseURL: URL
    private let session: URLSession

    public struct OllamaConfig {
        public let model: String
        public let maxTokens: Int
        public let temperature: Float
        public let topP: Float

        public init(
            model: String = "llama2",
            maxTokens: Int = 2048,
            temperature: Float = 0.7,
            topP: Float = 0.9
        ) {
            self.model = model
            self.maxTokens = maxTokens
            self.temperature = temperature
            self.topP = topP
        }
    }

    private let config: OllamaConfig

    public init(baseURL: String = "http://localhost:11434", config: OllamaConfig = OllamaConfig()) {
        guard let url = URL(string: baseURL) else {
            fatalError("Failed to unwrap baseURL")
        }
        self.baseURL = url
        self.config = config
        self.session = URLSession.shared
    }

    /// Check if Ollama is running
    public func isAvailable() async -> Bool {
        do {
            let url = baseURL.appendingPathComponent("api/tags")
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Generate text using Ollama
    public func generate(prompt: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/generate")

        let body: [String: Any] = [
            "model": config.model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "num_predict": config.maxTokens,
                "temperature": config.temperature,
                "top_p": config.topP
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OllamaError.requestFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = json?["response"] as? String else {
            throw OllamaError.decodingFailed("Failed to extract response")
        }

        return text
    }

    /// Generate embeddings using Ollama
    public func embed(text: String) async throws -> [Float] {
        let url = baseURL.appendingPathComponent("api/embeddings")

        let body: [String: Any] = [
            "model": config.model,
            "prompt": text
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OllamaError.requestFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let embedding = json?["embedding"] as? [Double] else {
            throw OllamaError.decodingFailed("Failed to extract embedding")
        }

        return embedding.map { Float($0) }
    }

    /// List available models
    public func listModels() async throws -> [String] {
        let url = baseURL.appendingPathComponent("api/tags")
        let (data, _) = try await session.data(from: url)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let models = json?["models"] as? [[String: Any]] else {
            throw OllamaError.decodingFailed("Failed to extract models list")
        }

        return models.compactMap { $0["name"] as? String }
    }

    /// Pull a model from Ollama registry
    public func pullModel(name: String) async throws {
        let url = baseURL.appendingPathComponent("api/pull")

        let body: [String: Any] = ["name": name]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OllamaError.requestFailed("Failed to pull model")
        }
    }
}
