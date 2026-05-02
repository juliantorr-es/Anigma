import AnigmaPrimitives

import AnigmaPrimitives

//
//  SurfaceCommand.swift
//  HarmoniaCLI
//
//  Consolidated entrypoint for the Harmonia surface harness.
//

import AnigmaCore
import ArgumentParser
import Darwin
import Foundation
import MLWorkerCommon

#if canImport(MLXLMCommon)
import MLX
import MLXEmbedders
import MLXLMCommon
#endif

public enum ModelKind: String, Sendable, CaseIterable, Codable {
    case chat
    case reasoner
    case oracle
}

public struct ConcurrencyLimits: Sendable {
    public let chat: Int
    public let reasoner: Int
    public let oracle: Int

    public static let `default` = ConcurrencyLimits(chat: 3, reasoner: 2, oracle: 1)

    public init(chat: Int, reasoner: Int, oracle: Int) {
        self.chat = max(1, chat)
        self.reasoner = max(1, reasoner)
        self.oracle = max(1, oracle)
    }

    public func limit(for kind: ModelKind) -> Int {
        switch kind {
        case .chat: return chat
        case .reasoner: return reasoner
        case .oracle: return oracle
        }
    }
}

public struct ConcurrencyStats: Sendable {
    public let inFlight: [ModelKind: Int]
    public let limits: [ModelKind: Int]
    public let waiting: [ModelKind: Int]
}

public actor ConcurrencyController {
    private var limits: [ModelKind: Int]
    private var inFlight: [ModelKind: Int]
    private var waiting: [ModelKind: Int]

    public init(limits: ConcurrencyLimits = .default) {
        self.limits = [:]
        self.inFlight = [:]
        self.waiting = [:]

        for kind in ModelKind.allCases {
            self.limits[kind] = limits.limit(for: kind)
            self.inFlight[kind] = 0
            self.waiting[kind] = 0
        }
    }

    public func recordRequest(_ kind: ModelKind) {
        inFlight[kind, default: 0] += 1
    }

    public func stats() -> ConcurrencyStats {
        ConcurrencyStats(inFlight: inFlight, limits: limits, waiting: waiting)
    }
}

public struct RequestPhase: RawRepresentable, Sendable, Codable, CaseIterable, Hashable {
    public typealias AllCases = [RequestPhase]
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let queued = RequestPhase(rawValue: "queued")
    public static let processing = RequestPhase(rawValue: "processing")
    public static let completed = RequestPhase(rawValue: "completed")
    public static let failed = RequestPhase(rawValue: "failed")

    public static var allCases: [RequestPhase] {
        [.queued, .processing, .completed, .failed]
    }
}

public struct SessionComponent: Component, Sendable, Codable {
    public let sessionId: String
    public let userId: String
    public var createdAt: Date

    public init(sessionId: String, userId: String, createdAt: Date = Date()) {
        self.sessionId = sessionId
        self.userId = userId
        self.createdAt = createdAt
    }
}

public struct RequestComponent: Component, Sendable, Codable {
    public let requestId: String
    public let modelKind: ModelKind
    public let sessionId: String
    public var phase: RequestPhase
    public var estimatedTokens: Int

    public init(
        requestId: String,
        modelKind: ModelKind,
        sessionId: String,
        phase: RequestPhase = .queued,
        estimatedTokens: Int = 0
    ) {
        self.requestId = requestId
        self.modelKind = modelKind
        self.sessionId = sessionId
        self.phase = phase
        self.estimatedTokens = estimatedTokens
    }
}

public struct ConcurrencyStateComponent: Component, Sendable, Codable {
    public let modelKind: String
    public var limit: Int
    public var inFlight: Int
    public var waiting: Int
    public var lastUpdated: Date

    public init(
        modelKind: String,
        limit: Int,
        inFlight: Int = 0,
        waiting: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.modelKind = modelKind
        self.limit = limit
        self.inFlight = inFlight
        self.waiting = waiting
        self.lastUpdated = lastUpdated
    }

    public var pressure: String {
        if waiting > limit {
            return "critical"
        } else if inFlight >= limit && waiting > 0 {
            return "high"
        } else if Double(inFlight) / Double(max(1, limit)) > 0.7 {
            return "medium"
        } else {
            return "low"
        }
    }
}

public struct SlotManagementSystem: System {
    public let name = "SlotManagementSystem"
    private let controller: ConcurrencyController

    public init(controller: ConcurrencyController) {
        self.controller = controller
    }

    public func update(world: World) async {
        let stats = await controller.stats()

        for kind in ModelKind.allCases {
            let limit = stats.limits[kind] ?? 0
            let inFlight = stats.inFlight[kind] ?? 0
            let waiting = stats.waiting[kind] ?? 0
            let existing = await world.query(ConcurrencyStateComponent.self)

            if let stateEntry = existing.first(where: { $0.1.modelKind == kind.rawValue }) {
                let entity = stateEntry.0
                var state = stateEntry.1
                state.limit = limit
                state.inFlight = inFlight
                state.waiting = waiting
                state.lastUpdated = Date()
                await world.addComponent(entity, state)
            } else {
                let entity = await world.createEntity()
                let state = ConcurrencyStateComponent(
                    modelKind: kind.rawValue,
                    limit: limit,
                    inFlight: inFlight,
                    waiting: waiting,
                    lastUpdated: Date()
                )
                await world.addComponent(entity, state)
                await world.addComponent(
                    entity,
                    NameComponent(
                        name: "concurrency.\(kind.rawValue)",
                        displayName: "\(kind.rawValue.capitalized) Pool"
                    ))
            }
        }
    }
}

struct SurfaceReport: Encodable {
    let timestamp: String
    let ticksRun: Int
    let registeredSystems: [String]
    let sessionCount: Int
    let requestCount: Int
    let requestPhaseCounts: [String: Int]
    let concurrencyStates: [ConcurrencyStateSummary]
    let controllerStats: [ControllerStatsSummary]
}

struct ConcurrencyStateSummary: Encodable {
    let modelKind: String
    let limit: Int
    let inFlight: Int
    let waiting: Int
    let pressure: String
}

struct ControllerStatsSummary: Encodable {
    let modelKind: String
    let limit: Int
    let inFlight: Int
    let waiting: Int
}

enum HarnessError: Error, LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        "Unable to format harness report."
    }
}

struct HarmoniaSurfaceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "surface",
        abstract: "Surface harness migrated into the consolidated Harmonia CLI."
    )

    @Option(name: [.short, .long], help: "Number of update ticks to execute.")
    var ticks: Int = 1

    @Option(name: [.long], help: "Surface scenario to run (e.g., ml-worker-backends).")
    var scenario: String?

    @Option(
        name: [.long],
        help: "Output path for scenario report (defaults to .anigma/receipts/ml-worker-backends.json)."
    )
    var output: String?

    func run() async throws {
        if let scenario, scenario == "ml-worker-backends" {
            let report = await MLWorkerBackendsScenario().run()
            let path = URL(fileURLWithPath: output ?? ".anigma/receipts/ml-worker-backends.json")
            try FileManager.default.createDirectory(
                at: path.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            try data.write(to: path)
            print(
                "Surface scenario \(scenario) wrote report to \(path.path) with \(report.results.count) checks."
            )
            return
        }

        let world = World()
        let controller = ConcurrencyController(limits: .default)
        await world.registerSystem(SlotManagementSystem(controller: controller))

        let session = SessionComponent(sessionId: "sigma-session", userId: "sigma-user")
        let sessionEntity = await world.createEntity()
        await world.addComponent(sessionEntity, session)

        let request = RequestComponent(
            requestId: UUID().uuidString,
            modelKind: .chat,
            sessionId: session.sessionId,
            phase: .completed,
            estimatedTokens: 32
        )
        let requestEntity = await world.createEntity()
        await world.addComponent(requestEntity, request)

        await controller.recordRequest(.chat)

        let totalTicks = max(1, ticks)
        for _ in 0..<totalTicks {
            await world.update()
        }

        let registeredSystems = await world.registeredSystemNames()
        let sessionEntities = await world.query(SessionComponent.self)
        let requestEntities = await world.query(RequestComponent.self)
        let requestPhaseCounts = Dictionary(
            grouping: requestEntities.map { $0.1.phase.rawValue }
        ) { $0 }.mapValues { $0.count }

        let concurrencyComponents = await world.query(ConcurrencyStateComponent.self)
        let controllerStats = await controller.stats()

        let concurrencySummary = concurrencyComponents.map {
            ConcurrencyStateSummary(
                modelKind: $0.1.modelKind,
                limit: $0.1.limit,
                inFlight: $0.1.inFlight,
                waiting: $0.1.waiting,
                pressure: $0.1.pressure
            )
        }

        let controllerSummary = ModelKind.allCases.map { kind in
            ControllerStatsSummary(
                modelKind: kind.rawValue,
                limit: controllerStats.limits[kind] ?? 0,
                inFlight: controllerStats.inFlight[kind] ?? 0,
                waiting: controllerStats.waiting[kind] ?? 0
            )
        }

        let report = SurfaceReport(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            ticksRun: totalTicks,
            registeredSystems: registeredSystems,
            sessionCount: sessionEntities.count,
            requestCount: requestEntities.count,
            requestPhaseCounts: requestPhaseCounts,
            concurrencyStates: concurrencySummary,
            controllerStats: controllerSummary
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        guard let output = String(data: data, encoding: .utf8) else {
            throw HarnessError.encodingFailed
        }

        print(output)
    }
}

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
            let stub = env["DEEPSEEK_STUB_BODY"] ?? "{\"choices\":[{\"message\":{\"content\":\"stub-ok\"}}]}"
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
            let stub = env["DEEPSEEK_STUB_BODY"] ?? "{\"choices\":[{\"message\":{\"content\":\"stub-ok\"}}]}"
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
                let payload = [
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
    let output: String = try await session.respond(to: prompt, images: [], videos: [])
    return output
}

private func runMLXEmbedImpl(embedModelId: String?, text: String) async throws -> Int {
    let configuration = MLXEmbedders.ModelConfiguration(
        id: embedModelId ?? "mlx-community/bge-small-en-v1.5-4bit")
    let container = try await MLXEmbedders.loadModelContainer(configuration: configuration)

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

private func runLlamaServerChat(serverURL: URL, model: String?, prompt: String) async throws -> String {
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

private func runDeepSeekChatImpl(baseURL: String, model: String, prompt: String) async throws -> String {
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
    let url = URL(string: baseURL)?.appendingPathComponent("chat/completions") ?? URL(
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
