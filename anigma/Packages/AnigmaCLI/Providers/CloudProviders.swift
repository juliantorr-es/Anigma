//
//  CloudProviders.swift
//  AnigmaCLIProviders
//
//  Cloud inference provider implementations for major LLM providers.
//

import Foundation
import OSLog

// MARK: - Base Protocol

@preconcurrency
public protocol CloudProvider: Sendable {
    func chat(request: ChatRequest) async throws -> ChatResponse
    func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatStreamChunk, Error>
    func embeddings(request: EmbeddingRequest) async throws -> EmbeddingResponse
}

// MARK: - Request/Response Types

public struct ChatRequest: Sendable {
    public let messages: [ChatMessage]
    public let model: String
    public let temperature: Double
    public let maxTokens: Int
    public let systemPrompt: String?
    public let tools: [ToolDefinition]?

    public init(
        messages: [ChatMessage],
        model: String,
        temperature: Double = 0.7,
        maxTokens: Int = 2048,
        systemPrompt: String? = nil,
        tools: [ToolDefinition]? = nil
    ) {
        self.messages = messages
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.tools = tools
    }
}

public struct ChatMessage: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ChatResponse: Sendable {
    public let content: String
    public let model: String
    public let usage: UsageInfo
    public let toolCalls: [ToolCall]?

    public init(content: String, model: String, usage: UsageInfo, toolCalls: [ToolCall]? = nil) {
        self.content = content
        self.model = model
        self.usage = usage
        self.toolCalls = toolCalls
    }
}

public struct ChatStreamChunk: Sendable {
    public let delta: String
    public let isComplete: Bool

    public init(delta: String, isComplete: Bool = false) {
        self.delta = delta
        self.isComplete = isComplete
    }
}

public struct EmbeddingRequest: Sendable {
    public let input: [String]
    public let model: String

    public init(input: [String], model: String) {
        self.input = input
        self.model = model
    }
}

public struct EmbeddingResponse: Sendable {
    public let embeddings: [[Float]]
    public let model: String
    public let usage: UsageInfo

    public init(embeddings: [[Float]], model: String, usage: UsageInfo) {
        self.embeddings = embeddings
        self.model = model
        self.usage = usage
    }
}

public struct UsageInfo: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int

    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

public struct ToolDefinition: Codable, @unchecked Sendable {
    public let name: String
    public let description: String
    public let parameters: [String: Any]

    enum CodingKeys: String, CodingKey {
        case name, description, parameters
    }

    public init(name: String, description: String, parameters: [String: Any]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        parameters = [:] // Simplified for now
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
    }
}

public struct ToolCall: Codable, Sendable {
    public let id: String
    public let name: String
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - OpenAI Provider

public final class OpenAIProvider: CloudProvider, @unchecked Sendable {
    private let apiKey: String
    private let endpoint: String

    public init(apiKey: String, endpoint: String = "https://api.openai.com/v1") {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        var messages = request.messages
        if let system = request.systemPrompt {
            messages.insert(ChatMessage(role: "system", content: system), at: 0)
        }

        let payload: [String: Any] = [
            "model": request.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": request.temperature,
            "max_tokens": request.maxTokens
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/chat/completions") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ProviderError.invalidResponse("Cannot parse OpenAI response")
        }

        let usage = extractUsage(from: json)

        return ChatResponse(content: content, model: request.model, usage: usage)
    }

    public func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Simplified streaming implementation
                    let response = try await chat(request: request)
                    continuation.yield(ChatStreamChunk(delta: response.content, isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func embeddings(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        let payload: [String: Any] = [
            "model": request.model,
            "input": request.input
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/embeddings") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw ProviderError.invalidResponse("Cannot parse embeddings response")
        }

        let embeddings = dataArray.compactMap { dict -> [Float]? in
            guard let embedding = dict["embedding"] as? [Double] else { return nil }
            return embedding.map { Float($0) }
        }

        let usage = extractUsage(from: json)

        return EmbeddingResponse(embeddings: embeddings, model: request.model, usage: usage)
    }

    private func extractUsage(from json: [String: Any]) -> UsageInfo {
        guard let usageDict = json["usage"] as? [String: Any],
              let prompt = usageDict["prompt_tokens"] as? Int,
              let completion = usageDict["completion_tokens"] as? Int,
              let total = usageDict["total_tokens"] as? Int else {
            return UsageInfo(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        }
        return UsageInfo(promptTokens: prompt, completionTokens: completion, totalTokens: total)
    }
}

// MARK: - Anthropic Provider

public final class AnthropicProvider: CloudProvider, @unchecked Sendable {
    private let apiKey: String
    private let endpoint: String

    public init(apiKey: String, endpoint: String = "https://api.anthropic.com/v1") {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        let payload: [String: Any] = [
            "model": request.model,
            "messages": request.messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "system": request.systemPrompt ?? ""
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/messages") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let firstContent = contentArray.first,
              let text = firstContent["text"] as? String else {
            throw ProviderError.invalidResponse("Cannot parse Anthropic response")
        }

        let usage = extractUsage(from: json)

        return ChatResponse(content: text, model: request.model, usage: usage)
    }

    public func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await chat(request: request)
                    continuation.yield(ChatStreamChunk(delta: response.content, isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func embeddings(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        throw ProviderError.notSupported("Anthropic does not provide embeddings API")
    }

    private func extractUsage(from json: [String: Any]) -> UsageInfo {
        guard let usageDict = json["usage"] as? [String: Any],
              let input = usageDict["input_tokens"] as? Int,
              let output = usageDict["output_tokens"] as? Int else {
            return UsageInfo(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        }
        return UsageInfo(promptTokens: input, completionTokens: output, totalTokens: input + output)
    }
}

// MARK: - DeepSeek Provider

public final class DeepSeekProvider: CloudProvider, @unchecked Sendable {
    private let apiKey: String
    private let endpoint: String

    public init(apiKey: String, endpoint: String = "https://api.deepseek.com/v1") {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        // DeepSeek uses OpenAI-compatible API
        var messages = request.messages
        if let system = request.systemPrompt {
            messages.insert(ChatMessage(role: "system", content: system), at: 0)
        }

        let payload: [String: Any] = [
            "model": request.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": request.temperature,
            "max_tokens": request.maxTokens
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/chat/completions") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ProviderError.invalidResponse("Cannot parse DeepSeek response")
        }

        let usage = extractUsage(from: json)

        return ChatResponse(content: content, model: request.model, usage: usage)
    }

    public func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        var messages = request.messages
        if let system = request.systemPrompt {
            messages.insert(ChatMessage(role: "system", content: system), at: 0)
        }

        let payload: [String: Any] = [
            "model": request.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": request.temperature,
            "max_tokens": request.maxTokens,
            "stream": true
        ]

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Encode to Data first to ensure thread safety when passing to Task
                    let requestData = try JSONSerialization.data(withJSONObject: payload)

                    guard let url = URL(string: "\(endpoint)/chat/completions") else {
                        fatalError("Failed to unwrap url")
                    }
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = requestData

                    let (stream, response) = try await URLSession.shared.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)"))
                        return
                    }

                    for try await line in stream.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                            if jsonString == "[DONE]" {
                                break
                            }

                            if let jsonData = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let firstChoice = choices.first,
                               let delta = firstChoice["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                continuation.yield(ChatStreamChunk(delta: content))
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func embeddings(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        // DeepSeek uses OpenAI-compatible embeddings API
        let payload: [String: Any] = [
            "model": request.model,
            "input": request.input
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/embeddings") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw ProviderError.invalidResponse("Cannot parse embeddings response")
        }

        let embeddings = dataArray.compactMap { dict -> [Float]? in
            guard let embedding = dict["embedding"] as? [Double] else { return nil }
            return embedding.map { Float($0) }
        }

        let usage = extractUsage(from: json)
        return EmbeddingResponse(embeddings: embeddings, model: request.model, usage: usage)
    }

    private func extractUsage(from json: [String: Any]) -> UsageInfo {
        guard let usageDict = json["usage"] as? [String: Any],
              let prompt = usageDict["prompt_tokens"] as? Int,
              let completion = usageDict["completion_tokens"] as? Int,
              let total = usageDict["total_tokens"] as? Int else {
            return UsageInfo(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        }
        return UsageInfo(promptTokens: prompt, completionTokens: completion, totalTokens: total)
    }
}

// MARK: - Google Gemini Provider

public final class GoogleGeminiProvider: CloudProvider, @unchecked Sendable {
    private let apiKey: String
    private let endpoint: String

    public init(apiKey: String, endpoint: String = "https://generativelanguage.googleapis.com/v1beta") {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        var contents: [[String: Any]] = []

        if let system = request.systemPrompt {
            contents.append(["role": "user", "parts": [["text": system]]])
        }

        for msg in request.messages {
            let role = msg.role == "assistant" ? "model" : "user"
            contents.append(["role": role, "parts": [["text": msg.content]]])
        }

        let payload: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": request.temperature,
                "maxOutputTokens": request.maxTokens
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/models/\(request.model):generateContent?key=\(apiKey)") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw ProviderError.invalidResponse("Cannot parse Gemini response")
        }

        let usage = extractUsage(from: json)

        return ChatResponse(content: text, model: request.model, usage: usage)
    }

    public func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await chat(request: request)
                    continuation.yield(ChatStreamChunk(delta: response.content, isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func embeddings(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        // Use Gemini's embedding-001 model
        let embeddingModel = request.model.isEmpty ? "embedding-001" : request.model
        var allEmbeddings: [[Float]] = []

        // Gemini API processes one input at a time for embeddings
        for text in request.input {
            let payload: [String: Any] = [
                "model": "models/\(embeddingModel)",
                "content": [
                    "parts": [["text": text]]
                ]
            ]

            let data = try JSONSerialization.data(withJSONObject: payload)
            guard let url = URL(string: "\(endpoint)/models/\(embeddingModel):embedContent?key=\(apiKey)") else {
                fatalError("Failed to unwrap url")
            }
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = data

            let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }

            guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let embedding = json["embedding"] as? [String: Any],
                  let values = embedding["values"] as? [Double] else {
                throw ProviderError.invalidResponse("Cannot parse Gemini embeddings response")
            }

            allEmbeddings.append(values.map { Float($0) })
        }

        let usage = UsageInfo(promptTokens: request.input.count * 100, completionTokens: 0, totalTokens: request.input.count * 100)
        return EmbeddingResponse(embeddings: allEmbeddings, model: embeddingModel, usage: usage)
    }

    private func extractUsage(from json: [String: Any]) -> UsageInfo {
        guard let usageMetadata = json["usageMetadata"] as? [String: Any],
              let prompt = usageMetadata["promptTokenCount"] as? Int,
              let completion = usageMetadata["candidatesTokenCount"] as? Int else {
            return UsageInfo(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        }
        return UsageInfo(promptTokens: prompt, completionTokens: completion, totalTokens: prompt + completion)
    }
}

// MARK: - Vercel AI Provider

public final class VercelAIProvider: CloudProvider, @unchecked Sendable {
    private let apiKey: String
    private let endpoint: String

    public init(apiKey: String, endpoint: String = "https://api.vercel.com/v1") {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        // Vercel AI uses OpenAI-compatible API
        var messages = request.messages
        if let system = request.systemPrompt {
            messages.insert(ChatMessage(role: "system", content: system), at: 0)
        }

        let payload: [String: Any] = [
            "model": request.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": request.temperature,
            "max_tokens": request.maxTokens
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/chat/completions") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ProviderError.invalidResponse("Cannot parse Vercel AI response")
        }

        let usage = extractUsage(from: json)
        return ChatResponse(content: content, model: request.model, usage: usage)
    }

    public func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await chat(request: request)
                    continuation.yield(ChatStreamChunk(delta: response.content, isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func embeddings(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        throw ProviderError.notSupported("Vercel AI embeddings delegated to OpenAI")
    }

    private func extractUsage(from json: [String: Any]) -> UsageInfo {
        guard let usageDict = json["usage"] as? [String: Any],
              let prompt = usageDict["prompt_tokens"] as? Int,
              let completion = usageDict["completion_tokens"] as? Int,
              let total = usageDict["total_tokens"] as? Int else {
            return UsageInfo(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        }
        return UsageInfo(promptTokens: prompt, completionTokens: completion, totalTokens: total)
    }
}

// MARK: - AWS Bedrock Provider

public final class AWSBedrockProvider: CloudProvider, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.anigma.AnigmaCLIProviders", category: "AWSBedrockProvider")
    private let accessKeyId: String
    private let secretAccessKey: String
    private let region: String

    public init(accessKeyId: String, secretAccessKey: String, region: String = "us-east-1") {
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.region = region
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        // Simplified Bedrock implementation - full AWS Signature V4 needed for production
        throw ProviderError.notSupported("AWS Bedrock requires AWS SDK and Signature V4 - use aws-sdk-swift")
    }

    public func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        // STUB_TRACK: aws-bedrock-stream – AWS Bedrock streaming not implemented
        // ⚠️ WARNING: This creates a stream that will fail mid-conversation
        print("⚠️  STUB INVOKED: AWSBedrockProvider.streamChat()")
        print("   AWS Bedrock streaming is not yet implemented")
        print("   This stream will fail with ProviderError.notSupported when consumed")
        Self.logger.warning("AWS Bedrock streaming requested but not implemented")
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: ProviderError.notSupported("AWS Bedrock streaming not implemented"))
        }
    }

    public func embeddings(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        // STUB_TRACK: aws-bedrock-embeddings – AWS Bedrock embeddings not implemented
        print("⚠️  STUB INVOKED: AWSBedrockProvider.embeddings()")
        print("   AWS Bedrock embeddings are not yet implemented")
        Self.logger.warning("AWS Bedrock embeddings requested but not implemented")
        throw ProviderError.notSupported("AWS Bedrock embeddings not implemented")
    }
}

// MARK: - Azure OpenAI Provider

public final class AzureOpenAIProvider: CloudProvider, @unchecked Sendable {
    private let apiKey: String
    private let endpoint: String
    private let deploymentName: String

    public init(apiKey: String, endpoint: String, deploymentName: String) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.deploymentName = deploymentName
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        var messages = request.messages
        if let system = request.systemPrompt {
            messages.insert(ChatMessage(role: "system", content: system), at: 0)
        }

        let payload: [String: Any] = [
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": request.temperature,
            "max_tokens": request.maxTokens
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/openai/deployments/\(deploymentName)/chat/completions?api-version=2024-02-01") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ProviderError.invalidResponse("Cannot parse Azure OpenAI response")
        }

        let usage = extractUsage(from: json)
        return ChatResponse(content: content, model: deploymentName, usage: usage)
    }

    public func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await chat(request: request)
                    continuation.yield(ChatStreamChunk(delta: response.content, isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func embeddings(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        let payload: [String: Any] = ["input": request.input]
        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/openai/deployments/\(deploymentName)/embeddings?api-version=2024-02-01") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw ProviderError.invalidResponse("Cannot parse embeddings response")
        }

        let embeddings = dataArray.compactMap { dict -> [Float]? in
            guard let embedding = dict["embedding"] as? [Double] else { return nil }
            return embedding.map { Float($0) }
        }

        let usage = extractUsage(from: json)
        return EmbeddingResponse(embeddings: embeddings, model: deploymentName, usage: usage)
    }

    private func extractUsage(from json: [String: Any]) -> UsageInfo {
        guard let usageDict = json["usage"] as? [String: Any],
              let prompt = usageDict["prompt_tokens"] as? Int,
              let completion = usageDict["completion_tokens"] as? Int,
              let total = usageDict["total_tokens"] as? Int else {
            return UsageInfo(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        }
        return UsageInfo(promptTokens: prompt, completionTokens: completion, totalTokens: total)
    }
}

// MARK: - Ollama Cloud Provider

public final class OllamaCloudProvider: CloudProvider, @unchecked Sendable {
    private let apiKey: String
    private let endpoint: String

    public init(apiKey: String, endpoint: String = "https://cloud.ollama.ai/api") {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        var messages = request.messages
        if let system = request.systemPrompt {
            messages.insert(ChatMessage(role: "system", content: system), at: 0)
        }

        let payload: [String: Any] = [
            "model": request.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": false,
            "options": [
                "temperature": request.temperature,
                "num_predict": request.maxTokens
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/chat") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ProviderError.invalidResponse("Cannot parse Ollama response")
        }

        let usage = UsageInfo(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        return ChatResponse(content: content, model: request.model, usage: usage)
    }

    public func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await chat(request: request)
                    continuation.yield(ChatStreamChunk(delta: response.content, isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func embeddings(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        let payload: [String: Any] = [
            "model": request.model,
            "prompt": request.input.joined(separator: "\n")
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/embeddings") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let embedding = json["embedding"] as? [Double] else {
            throw ProviderError.invalidResponse("Cannot parse embeddings response")
        }

        let embeddings = [embedding.map { Float($0) }]
        let usage = UsageInfo(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        return EmbeddingResponse(embeddings: embeddings, model: request.model, usage: usage)
    }
}

// MARK: - Groq Provider

public final class GroqProvider: CloudProvider, @unchecked Sendable {
    private let apiKey: String
    private let endpoint: String

    public init(apiKey: String, endpoint: String = "https://api.groq.com/openai/v1") {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }

    public func chat(request: ChatRequest) async throws -> ChatResponse {
        var messages = request.messages
        if let system = request.systemPrompt {
            messages.insert(ChatMessage(role: "system", content: system), at: 0)
        }

        let payload: [String: Any] = [
            "model": request.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": request.temperature,
            "max_tokens": request.maxTokens
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let url = URL(string: "\(endpoint)/chat/completions") else {
            fatalError("Failed to unwrap url")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.requestFailed("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ProviderError.invalidResponse("Cannot parse Groq response")
        }

        let usage = extractUsage(from: json)
        return ChatResponse(content: content, model: request.model, usage: usage)
    }

    public func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await chat(request: request)
                    continuation.yield(ChatStreamChunk(delta: response.content, isComplete: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func embeddings(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        throw ProviderError.notSupported("Groq does not provide embeddings API")
    }

    private func extractUsage(from json: [String: Any]) -> UsageInfo {
        guard let usageDict = json["usage"] as? [String: Any],
              let prompt = usageDict["prompt_tokens"] as? Int,
              let completion = usageDict["completion_tokens"] as? Int,
              let total = usageDict["total_tokens"] as? Int else {
            return UsageInfo(promptTokens: 0, completionTokens: 0, totalTokens: 0)
        }
        return UsageInfo(promptTokens: prompt, completionTokens: completion, totalTokens: total)
    }
}

// MARK: - Provider Factory

public final class CloudProviderFactory: @unchecked Sendable {
    public init() {}

    public func createProvider(
        descriptor: ProviderDescriptor,
        environment: [String: String]
    ) throws -> any CloudProvider {
        switch descriptor.id {
        case "cloud-openai":
            guard let apiKey = environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
                throw ProviderError.missingAPIKey("OPENAI_API_KEY")
            }
            return OpenAIProvider(apiKey: apiKey)

        case "cloud-anthropic":
            guard let apiKey = environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty else {
                throw ProviderError.missingAPIKey("ANTHROPIC_API_KEY")
            }
            return AnthropicProvider(apiKey: apiKey)

        case "cloud-deepseek":
            guard let apiKey = environment["DEEPSEEK_API_KEY"], !apiKey.isEmpty else {
                throw ProviderError.missingAPIKey("DEEPSEEK_API_KEY")
            }
            return DeepSeekProvider(apiKey: apiKey)

        case "cloud-google":
            let apiKey = environment["GOOGLE_API_KEY"] ?? environment["GEMINI_API_KEY"]
            guard let apiKey, !apiKey.isEmpty else {
                throw ProviderError.missingAPIKey("GOOGLE_API_KEY or GEMINI_API_KEY")
            }
            return GoogleGeminiProvider(apiKey: apiKey)

        case "cloud-vercel":
            guard let apiKey = environment["VERCEL_API_KEY"], !apiKey.isEmpty else {
                throw ProviderError.missingAPIKey("VERCEL_API_KEY")
            }
            return VercelAIProvider(apiKey: apiKey)

        case "cloud-aws":
            guard let accessKey = environment["AWS_ACCESS_KEY_ID"],
                  let secretKey = environment["AWS_SECRET_ACCESS_KEY"],
                  !accessKey.isEmpty, !secretKey.isEmpty else {
                throw ProviderError.missingAPIKey("AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY")
            }
            let region = environment["AWS_REGION"] ?? "us-east-1"
            return AWSBedrockProvider(accessKeyId: accessKey, secretAccessKey: secretKey, region: region)

        case "cloud-azure":
            guard let apiKey = environment["AZURE_OPENAI_API_KEY"],
                  let endpoint = environment["AZURE_OPENAI_ENDPOINT"],
                  let deployment = environment["AZURE_OPENAI_DEPLOYMENT"],
                  !apiKey.isEmpty, !endpoint.isEmpty, !deployment.isEmpty else {
                throw ProviderError.missingAPIKey("AZURE_OPENAI_API_KEY, AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_DEPLOYMENT")
            }
            return AzureOpenAIProvider(apiKey: apiKey, endpoint: endpoint, deploymentName: deployment)

        case "cloud-ollama":
            guard let apiKey = environment["OLLAMA_API_KEY"], !apiKey.isEmpty else {
                throw ProviderError.missingAPIKey("OLLAMA_API_KEY")
            }
            let endpoint = environment["OLLAMA_ENDPOINT"] ?? "https://cloud.ollama.ai/api"
            return OllamaCloudProvider(apiKey: apiKey, endpoint: endpoint)

        case "cloud-groq":
            guard let apiKey = environment["GROQ_API_KEY"], !apiKey.isEmpty else {
                throw ProviderError.missingAPIKey("GROQ_API_KEY")
            }
            return GroqProvider(apiKey: apiKey)

        default:
            throw ProviderError.unsupportedProvider(descriptor.id)
        }
    }
}

// MARK: - Errors

public enum ProviderError: Error, LocalizedError {
    case requestFailed(String)
    case invalidResponse(String)
    case missingAPIKey(String)
    case unsupportedProvider(String)
    case notSupported(String)

    public var errorDescription: String? {
        switch self {
        case .requestFailed(let msg):
            return "Provider request failed: \(msg)"
        case .invalidResponse(let msg):
            return "Invalid provider response: \(msg)"
        case .missingAPIKey(let key):
            return "Missing API key: \(key)"
        case .unsupportedProvider(let id):
            return "Unsupported provider: \(id)"
        case .notSupported(let msg):
            return "Not supported: \(msg)"
        }
    }
}
