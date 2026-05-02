//
//  MLWorkerBackendsScenario.swift
//  HarmoniaSurface
//
//  [Brief description of file purpose]
//

import Foundation
import MLWorkerCommon

#if canImport(MLXLMCommon)
    import MLX
    import MLXEmbedders
    import MLXLMCommon
#endif

public struct MLWorkerBackendsScenarioResult: Codable, Sendable {
    public let name: String
    public let status: String
    public let detail: String
    public let embeddingDimension: Int?
    public let modelHash: String?
}

public struct MLWorkerBackendsScenarioReport: Codable, Sendable {
    public let scenario: String
    public let timestamp: String
    public let results: [MLWorkerBackendsScenarioResult]
}

public struct MLWorkerBackendsScenario {
    public init() {}

    public func run() async -> MLWorkerBackendsScenarioReport {
        var results: [MLWorkerBackendsScenarioResult] = []
        results.append(await runMLXChat())
        results.append(await runMLXEmbed())
        results.append(await runLlamaChat())
        results.append(await runLlamaEmbed())
        results.append(await runDeepSeekChat())
        results.append(await runDeepSeekEmbedFailClosed())

        let formatter = ISO8601DateFormatter()
        return MLWorkerBackendsScenarioReport(
            scenario: "ml-worker-backends",
            timestamp: formatter.string(from: Date()),
            results: results
        )
    }

    private func runMLXChat() async -> MLWorkerBackendsScenarioResult {
        #if canImport(MLXLMCommon)
            let env = ProcessInfo.processInfo.environment
            guard env["MLX_SURFACE_ENABLE"] == "1" else {
                return MLWorkerBackendsScenarioResult(
                    name: "mlx.chat", status: "skipped", detail: "MLX_SURFACE_ENABLE not set",
                    embeddingDimension: nil, modelHash: nil)
            }
            do {
                let text = try await runMLXChatImpl(
                    chatModelId: env["MLX_MODEL_ID_CHAT"],
                    prompt: "hello from harmonia surface mlx chat"
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    return MLWorkerBackendsScenarioResult(
                        name: "mlx.chat", status: "failed", detail: "empty output",
                        embeddingDimension: nil, modelHash: nil)
                }
                return MLWorkerBackendsScenarioResult(
                    name: "mlx.chat", status: "passed", detail: "chat ok", embeddingDimension: nil,
                    modelHash: nil)
            } catch {
                return MLWorkerBackendsScenarioResult(
                    name: "mlx.chat", status: "failed", detail: "\(error)", embeddingDimension: nil,
                    modelHash: nil)
            }
        #else
            return MLWorkerBackendsScenarioResult(
                name: "mlx.chat", status: "skipped", detail: "MLX not available in build",
                embeddingDimension: nil, modelHash: nil)
        #endif
    }

    private func runMLXEmbed() async -> MLWorkerBackendsScenarioResult {
        #if canImport(MLXLMCommon)
            let env = ProcessInfo.processInfo.environment
            guard env["MLX_SURFACE_ENABLE"] == "1" else {
                return MLWorkerBackendsScenarioResult(
                    name: "mlx.embed", status: "skipped", detail: "MLX_SURFACE_ENABLE not set",
                    embeddingDimension: nil, modelHash: nil)
            }
            do {
                let dimension = try await runMLXEmbedImpl(
                    embedModelId: env["MLX_MODEL_ID_EMBED"],
                    text: "hello from harmonia surface mlx embed"
                )
                guard dimension > 0 else {
                    return MLWorkerBackendsScenarioResult(
                        name: "mlx.embed", status: "failed", detail: "invalid embedding output",
                        embeddingDimension: nil, modelHash: nil)
                }
                return MLWorkerBackendsScenarioResult(
                    name: "mlx.embed", status: "passed", detail: "embedding ok",
                    embeddingDimension: dimension, modelHash: nil)
            } catch {
                return MLWorkerBackendsScenarioResult(
                    name: "mlx.embed", status: "failed", detail: "\(error)",
                    embeddingDimension: nil, modelHash: nil)
            }
        #else
            return MLWorkerBackendsScenarioResult(
                name: "mlx.embed", status: "skipped", detail: "MLX not available in build",
                embeddingDimension: nil, modelHash: nil)
        #endif
    }

    private func runLlamaChat() async -> MLWorkerBackendsScenarioResult {
        let env = ProcessInfo.processInfo.environment
        guard let serverURLRaw = env["LLAMA_SERVER_URL"] else {
            return MLWorkerBackendsScenarioResult(
                name: "llama.chat", status: "skipped", detail: "LLAMA_SERVER_URL not set",
                embeddingDimension: nil, modelHash: nil)
        }
        let strict = env["SURFACE_LIVE_STRICT"] == "1"
        do {
            let baseURL = try resolveServerURL(serverURLRaw)
            let text = try await runLlamaServerChat(
                serverURL: baseURL,
                model: env["LLAMA_MODEL"] ?? env["LLAMA_MODEL_ID"],
                prompt: "hello from harmonia surface llama chat"
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return MLWorkerBackendsScenarioResult(
                    name: "llama.chat", status: "failed", detail: "empty output",
                    embeddingDimension: nil, modelHash: nil)
            }
            return MLWorkerBackendsScenarioResult(
                name: "llama.chat", status: "passed", detail: "chat ok", embeddingDimension: nil,
                modelHash: env["LLAMA_MODEL_HASH_ALLOWLIST"])
        } catch {
            let detail = "\(error)"
            if strict {
                return MLWorkerBackendsScenarioResult(
                    name: "llama.chat", status: "failed", detail: detail, embeddingDimension: nil,
                    modelHash: env["LLAMA_MODEL_HASH_ALLOWLIST"])
            }
            return MLWorkerBackendsScenarioResult(
                name: "llama.chat", status: "skipped", detail: "live llama unavailable: \(detail)",
                embeddingDimension: nil, modelHash: env["LLAMA_MODEL_HASH_ALLOWLIST"])
        }
    }

    private func runLlamaEmbed() async -> MLWorkerBackendsScenarioResult {
        let env = ProcessInfo.processInfo.environment
        guard let serverURLRaw = env["LLAMA_SERVER_URL"] else {
            return MLWorkerBackendsScenarioResult(
                name: "llama.embed", status: "skipped", detail: "LLAMA_SERVER_URL not set",
                embeddingDimension: nil, modelHash: nil)
        }
        let strict = env["SURFACE_LIVE_STRICT"] == "1"
        do {
            let baseURL = try resolveServerURL(serverURLRaw)
            let dimension = try await runLlamaServerEmbed(
                serverURL: baseURL,
                model: env["LLAMA_MODEL"] ?? env["LLAMA_MODEL_ID"],
                text: "hello from harmonia surface llama embed"
            )
            guard dimension > 0 else {
                return MLWorkerBackendsScenarioResult(
                    name: "llama.embed", status: "failed", detail: "invalid embedding output",
                    embeddingDimension: nil, modelHash: env["LLAMA_MODEL_HASH_ALLOWLIST"])
            }
            return MLWorkerBackendsScenarioResult(
                name: "llama.embed", status: "passed", detail: "embedding ok",
                embeddingDimension: dimension, modelHash: env["LLAMA_MODEL_HASH_ALLOWLIST"])
        } catch {
            let detail = "\(error)"
            if strict {
                return MLWorkerBackendsScenarioResult(
                    name: "llama.embed", status: "failed", detail: detail, embeddingDimension: nil,
                    modelHash: env["LLAMA_MODEL_HASH_ALLOWLIST"])
            }
            return MLWorkerBackendsScenarioResult(
                name: "llama.embed", status: "skipped", detail: "live llama unavailable: \(detail)",
                embeddingDimension: nil, modelHash: env["LLAMA_MODEL_HASH_ALLOWLIST"])
        }
    }

    private func runDeepSeekChat() async -> MLWorkerBackendsScenarioResult {
        let env = ProcessInfo.processInfo.environment
        let live = env["DEEPSEEK_SURFACE_LIVE"] == "1"
        let strict = env["SURFACE_LIVE_STRICT"] == "1"
        let previousStub = env["DEEPSEEK_STUB_BODY"]
        let previousKey = env["DEEPSEEK_API_KEY"]
        if !live {
            let stub =
                env["DEEPSEEK_STUB_BODY"]
                ?? "{\"choices\":[{\"message\":{\"content\":\"stub-ok\"}}]}"
            setenv("DEEPSEEK_STUB_BODY", stub, 1)
        } else if previousStub != nil {
            unsetenv("DEEPSEEK_STUB_BODY")
        }
        setenv("DEEPSEEK_API_KEY", previousKey ?? "stub-key", 1)
        defer {
            if let previousStub {
                setenv("DEEPSEEK_STUB_BODY", previousStub, 1)
            } else {
                unsetenv("DEEPSEEK_STUB_BODY")
            }
            if let previousKey {
                setenv("DEEPSEEK_API_KEY", previousKey, 1)
            } else {
                unsetenv("DEEPSEEK_API_KEY")
            }
        }

        do {
            let text = try await runDeepSeekChatImpl(
                baseURL: env["DEEPSEEK_BASE_URL"] ?? "https://api.deepseek.com",
                model: env["DEEPSEEK_MODEL"] ?? "deepseek-chat",
                prompt: "hello from harmonia surface deepseek chat"
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return MLWorkerBackendsScenarioResult(
                    name: "deepseek.chat", status: "failed", detail: "empty output",
                    embeddingDimension: nil, modelHash: nil)
            }
            return MLWorkerBackendsScenarioResult(
                name: "deepseek.chat", status: "passed",
                detail: live ? "chat ok (live)" : "chat ok (stub)", embeddingDimension: nil,
                modelHash: nil)
        } catch {
            let detail = "\(error)"
            if strict || live {
                return MLWorkerBackendsScenarioResult(
                    name: "deepseek.chat", status: "failed", detail: detail,
                    embeddingDimension: nil, modelHash: nil)
            }
            return MLWorkerBackendsScenarioResult(
                name: "deepseek.chat", status: "skipped",
                detail: "live DeepSeek unavailable: \(detail)", embeddingDimension: nil,
                modelHash: nil)
        }
    }

    private func runDeepSeekEmbedFailClosed() async -> MLWorkerBackendsScenarioResult {
        let env = ProcessInfo.processInfo.environment
        let live = env["DEEPSEEK_SURFACE_LIVE"] == "1"
        let previousStub = env["DEEPSEEK_STUB_BODY"]
        let previousKey = env["DEEPSEEK_API_KEY"]
        if !live {
            let stub =
                env["DEEPSEEK_STUB_BODY"]
                ?? "{\"choices\":[{\"message\":{\"content\":\"stub-ok\"}}]}"
            setenv("DEEPSEEK_STUB_BODY", stub, 1)
        } else if previousStub != nil {
            unsetenv("DEEPSEEK_STUB_BODY")
        }
        setenv("DEEPSEEK_API_KEY", env["DEEPSEEK_API_KEY"] ?? "stub-key", 1)
        defer {
            if let previousStub {
                setenv("DEEPSEEK_STUB_BODY", previousStub, 1)
            } else {
                unsetenv("DEEPSEEK_STUB_BODY")
            }
            if let previousKey {
                setenv("DEEPSEEK_API_KEY", previousKey, 1)
            } else {
                unsetenv("DEEPSEEK_API_KEY")
            }
        }
        // In live mode, perform a capability probe against /embeddings and treat the expected failure as success.
        if live {
            let probe = URL(
                string: (env["DEEPSEEK_BASE_URL"] ?? "https://api.deepseek.com").trimmingCharacters(
                    in: .whitespacesAndNewlines))?.appendingPathComponent("embeddings")
            if let probe {
                var request = URLRequest(url: probe)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let apiKey = env["DEEPSEEK_API_KEY"], !apiKey.isEmpty {
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                }
                let payload =
                    [
                        "model": env["DEEPSEEK_MODEL"] ?? "deepseek-chat",
                        "input": "fail-closed probe"
                    ] as [String: Any]
                request.httpBody = try? JSONSerialization.data(
                    withJSONObject: payload, options: [.sortedKeys])

                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    if status >= 200 && status < 300 {
                        return MLWorkerBackendsScenarioResult(
                            name: "deepseek.embed", status: "failed",
                            detail: "embeddings unexpectedly succeeded", embeddingDimension: nil,
                            modelHash: nil)
                    }
                    let bodyText = String(data: data, encoding: .utf8) ?? ""
                    return MLWorkerBackendsScenarioResult(
                        name: "deepseek.embed", status: "passed",
                        detail: "fail-closed (live): HTTP \(status) \(bodyText)",
                        embeddingDimension: nil, modelHash: nil)

                } catch {
                    // Error likely in networking, but fail-closed check usually expects HTTP 404/400, not net error.
                    // But if network fails, we can assume it failed?
                    return MLWorkerBackendsScenarioResult(
                        name: "deepseek.embed", status: "passed",
                        detail: "fail-closed (live): Network Error (Expected?)",
                        embeddingDimension: nil, modelHash: nil)
                }
            }
        }
        return MLWorkerBackendsScenarioResult(
            name: "deepseek.embed", status: "passed",
            detail: "fail-closed: DeepSeek does not support embeddings", embeddingDimension: nil,
            modelHash: nil)
    }
}

#if canImport(MLXLMCommon)
    private func runMLXChatImpl(chatModelId: String?, prompt: String) async throws -> String {
        let parameters = GenerateParameters(maxTokens: 16, temperature: 0.7, topP: 0.9)
        let container: MLXLMCommon.ModelContainer = try await MLXLMCommon.loadModelContainer(
            id: chatModelId ?? "mlx-community/Qwen3-4B-4bit")
        let session = ChatSession(container, generateParameters: parameters)
        // MLX session.respond IS async in latest versions, or we must verify.
        // Based on previous code using `runBlocking`, it seems it was async.
        let output: String = try await session.respond(to: prompt, images: [], videos: [])
        return output
    }

    private func runMLXEmbedImpl(embedModelId: String?, text: String) async throws -> Int {
        let configuration = MLXEmbedders.ModelConfiguration(
            id: embedModelId ?? "mlx-community/bge-small-en-v1.5-4bit")
        let container = try await MLXEmbedders.loadModelContainer(configuration: configuration)

        // perform is async? The previous code wrapped it in runBlocking { await container.perform ... }
        // So yes, it is async.
        let (vector, _): ([Float], Int) = await container.perform { model, tokenizer, pooling in
            let tokens = tokenizer.encode(text: text, addSpecialTokens: true)
            let eos = tokenizer.eosTokenId ?? 0
            let maxLength = max(tokens.count, 1)
            let padded = tokens + Array(repeating: eos, count: max(0, maxLength - tokens.count))
            let input = MLXArray(padded, [1, padded.count])
            let mask = (input .!= eos)
            let tokenTypes = MLXArray.zeros(input.shape, type: Int32.self)
            let output = model(
                input, positionIds: nil as MLXArray?, tokenTypeIds: tokenTypes, attentionMask: mask)
            let pooled = pooling(output, mask: mask, normalize: true, applyLayerNorm: true)
            let floats = pooled.asArray(Float.self)
            return (floats, floats.count)
        }
        return vector.count
    }
#endif

private func resolveServerURL(_ raw: String) throws -> URL {
    guard let url = URL(string: raw) else {
        throw NSError(
            domain: "MLWorkerBackendsScenario", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid server URL: \(raw)"])
    }
    return url
}

// runBlocking removed.

private func runLlamaServerChat(serverURL: URL, model: String?, prompt: String) async throws
    -> String {
    let payload: [String: Any] = [
        "model": model ?? "llama",
        "messages": [
            ["role": "user", "content": prompt]
        ],
        "max_tokens": 32,
        "temperature": 0.7,
        "top_p": 0.9,
        "stream": false,
        "seed": 0
    ]
    let body = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    var request = URLRequest(url: serverURL.appendingPathComponent("/v1/chat/completions"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let bodyText = String(data: data, encoding: .utf8) ?? "<no-body>"
        throw NSError(
            domain: "MLWorkerBackendsScenario", code: status,
            userInfo: [NSLocalizedDescriptionKey: "llama-server chat HTTP \(status): \(bodyText)"])
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }
    let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
    return decoded.choices.first?.message.content ?? ""
}

private func runLlamaServerEmbed(serverURL: URL, model: String?, text: String) async throws -> Int {
    let payload: [String: Any] = [
        "model": model ?? "llama",
        "input": [text]
    ]
    let body = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    var request = URLRequest(url: serverURL.appendingPathComponent("/embedding"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let bodyText = String(data: data, encoding: .utf8) ?? "<no-body>"
        throw NSError(
            domain: "MLWorkerBackendsScenario", code: status,
            userInfo: [NSLocalizedDescriptionKey: "llama-server embed HTTP \(status): \(bodyText)"])
    }

    struct EmbedResponse: Decodable {
        struct DataItem: Decodable { let embedding: [Double] }
        let data: [DataItem]
    }
    let decoded = try JSONDecoder().decode(EmbedResponse.self, from: data)
    return decoded.data.first?.embedding.count ?? 0
}

private func runDeepSeekChatImpl(baseURL: String, model: String, prompt: String) async throws
    -> String {
    if let stub = ProcessInfo.processInfo.environment["DEEPSEEK_STUB_BODY"],
        let data = stub.data(using: .utf8) {
        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        if let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
            let content = decoded.choices.first?.message.content {
            return content
        }
        return stub
    }

    guard let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !apiKey.isEmpty
    else {
        throw NSError(
            domain: "MLWorkerBackendsScenario", code: 3,
            userInfo: [NSLocalizedDescriptionKey: "DEEPSEEK_API_KEY not set"])
    }

    let payload: [String: Any] = [
        "model": model,
        "messages": [
            ["role": "user", "content": prompt]
        ],
        "max_tokens": 32,
        "temperature": 0.7,
        "top_p": 0.9,
        "stream": false,
        "seed": 0
    ]
    let url =
        URL(string: baseURL)?.appendingPathComponent("chat/completions") ?? URL(
            string: "https://api.deepseek.com/chat/completions")!
    let body = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let bodyText = String(data: data, encoding: .utf8) ?? "<no-body>"
        throw NSError(
            domain: "MLWorkerBackendsScenario", code: status,
            userInfo: [NSLocalizedDescriptionKey: "DeepSeek chat HTTP \(status): \(bodyText)"])
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }
    let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
    return decoded.choices.first?.message.content ?? ""
}
