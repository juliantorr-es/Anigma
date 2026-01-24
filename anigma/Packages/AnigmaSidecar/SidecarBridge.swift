//
//  SidecarBridge.swift
//  AnigmaSidecar
//
//  Exclusive bridge between AnigmaAuthority and anigmad daemon using native JSON over HTTP.
//  This eliminates SwiftProtobuf and grpc-swift dependencies.
//

import AnigmaPrimitives
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOPosix

public actor SidecarBridge {
    private let httpClient: HTTPClient
    private let socketPath: String

    // Session state
    private var clientId: String
    private var capabilityToken: Data
    private let clientName: String
    private let requestedScopes: [String]

    // Health monitoring
    private var heartbeatTask: Task<Void, Never>?
    private var isHealthy: Bool = true
    private var lastHeartbeatAt: Date?
    private var reconnectionAttempts: Int = 0
    private let maxReconnectionAttempts: Int = 3
    private let heartbeatInterval: TimeInterval = 30.0

    // Health Observers
    private var healthContinuations: [UUID: AsyncStream<HealthStatus>.Continuation] = [:]

    private init(
        httpClient: HTTPClient,
        socketPath: String,
        clientName: String,
        requestedScopes: [String]
    ) {
        self.httpClient = httpClient
        self.socketPath = socketPath
        self.clientName = clientName
        self.requestedScopes = requestedScopes
        self.clientId = ""
        self.capabilityToken = Data()
    }

    deinit {
        heartbeatTask?.cancel()
        try? httpClient.syncShutdown()
        healthContinuations.values.forEach { $0.finish() }
    }

    public static func create(
        socketPath: String? = nil,
        clientName: String = "AnigmaAuthority",
        scopes: [String]? = nil
    ) async throws -> SidecarBridge {
        let path = socketPath ?? SidecarConfig.defaultUnixSocketPath()

        let httpClient = HTTPClient(
            eventLoopGroupProvider: .singleton,
            configuration: .init()
        )

        let requestedScopes = scopes ?? [
            "job.submit", "job.status", "vault.read", "vault.write", "receipt.verify"
        ]

        let bridge = SidecarBridge(
            httpClient: httpClient,
            socketPath: path,
            clientName: clientName,
            requestedScopes: requestedScopes
        )

        try await bridge.openSession()
        await bridge.startHeartbeat()

        return bridge
    }

    private func makeRequestURL(_ path: String) -> String {
        let allowed = CharacterSet.urlHostAllowed
        let encodedSocket = socketPath.addingPercentEncoding(withAllowedCharacters: allowed) ?? socketPath
        return "http+unix://\(encodedSocket)\(path)"
    }

    private func openSession() async throws {
        let request = AnigmaOpenSessionRequest(
            requestedClientName: self.clientName,
            requestedScopes: self.requestedScopes
        )

        let response: AnigmaOpenSessionResponse = try await post("/session/open", body: request)

        guard !response.capabilityToken.isEmpty else {
            throw SidecarBridgeError.sessionFailed("Daemon did not issue a capability token.")
        }

        self.clientId = response.clientId
        self.capabilityToken = response.capabilityToken
    }

    private func makeContext() -> AnigmaRequestContext {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let nonce = Data(bytes).base64EncodedString()

        return AnigmaRequestContext(
            clientId: self.clientId,
            capabilityToken: self.capabilityToken,
            nonce: nonce
        )
    }

    public func submitJob(_ spec: AnigmaJobSpec) async throws -> AnigmaSubmitJobResponse {
        let request = AnigmaSubmitJobRequest(ctx: makeContext(), spec: spec)
        return try await post("/job/submit", body: request)
    }

    public func getStatus() async throws -> AnigmaStatusResponse {
        let request = AnigmaStatusRequest(ctx: makeContext())
        return try await post("/status", body: request)
    }

    public func getJobStatus(jobId: String) async throws -> AnigmaGetJobStatusResponse {
        let request = AnigmaGetJobStatusRequest(ctx: makeContext(), jobId: jobId)
        return try await post("/job/status", body: request)
    }

    public func listArtifacts(pageToken: String = "", pageSize: UInt32 = 0) async throws -> AnigmaListResponse {
        let request = AnigmaListRequest(ctx: makeContext(), pageToken: pageToken, pageSize: pageSize)
        return try await post("/artifacts/list", body: request)
    }

    public func cancelJob(jobId: String) async throws -> AnigmaCancelJobResponse {
        let request = AnigmaCancelJobRequest(ctx: makeContext(), jobId: jobId)
        return try await post("/job/cancel", body: request)
    }

    public func listTools() async throws -> AnigmaListToolsResponse {
        let request = AnigmaListToolsRequest(ctx: makeContext())
        return try await post("/tools/list", body: request)
    }

    public func onboardingStatus() async throws -> AnigmaOnboardingStatusResponse {
        let request = AnigmaOnboardingStatusRequest(ctx: makeContext())
        return try await post("/onboarding/status", body: request)
    }

    public func getReceipt(receiptHash: String) async throws -> AnigmaReceiptResponse {
        let request = AnigmaReceiptRequest(ctx: makeContext(), receiptHash: receiptHash)
        return try await post("/receipt/get", body: request)
    }

    public func ingestArtifact(
        data: Data,
        kind: String = "blob",
        mediaType: String = "application/octet-stream",
        filenameHint: String? = nil
    ) async throws -> AnigmaIngestArtifactResponse {
        let request = AnigmaIngestArtifactRequest(
            ctx: makeContext(),
            mediaType: mediaType,
            filenameHint: filenameHint,
            data: data,
            kind: kind
        )
        return try await post("/artifacts/ingest", body: request)
    }

    public func retrieveArtifact(hash: String) async throws -> AnigmaRetrieveArtifactResponse {
        let request = AnigmaRetrieveArtifactRequest(ctx: makeContext(), hash: hash)
        return try await post("/artifacts/retrieve", body: request)
    }

    public func verifyChain(headReceiptHash: String) async throws -> AnigmaVerifyChainResponse {
        let request = AnigmaVerifyChainRequest(ctx: makeContext(), headReceiptHash: headReceiptHash)
        return try await post("/chain/verify", body: request)
    }

    public func streamJobEvents(jobId: String) async throws -> AsyncThrowingStream<AnigmaJobEvent, Error> {
        let requestBody = AnigmaStreamJobEventsRequest(ctx: makeContext(), jobId: jobId)
        let data = try JSONEncoder().encode(requestBody)
        
        var request = HTTPClientRequest(url: makeRequestURL("/job/events/stream"))
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(data)
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        
        guard response.status == .ok else {
            throw SidecarBridgeError.unavailable(nil)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await buffer in response.body {
                        let str = String(buffer: buffer)
                        let lines = str.split(separator: "\n", omittingEmptySubsequences: true)
                        for line in lines {
                            if let data = String(line).data(using: .utf8),
                               let event = try? JSONDecoder().decode(AnigmaJobEvent.self, from: data) {
                                continuation.yield(event)
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

    public func bridgeMCP(inputStream: AsyncStream<String>) async throws -> AsyncThrowingStream<String, Error> {
        let byteStream = inputStream.map { ByteBuffer(string: $0) }
        
        var request = HTTPClientRequest(url: makeRequestURL("/mcp"))
        request.method = .POST
        request.body = .stream(byteStream, length: .unknown)
        
        let response = try await httpClient.execute(request, timeout: .hours(24))
        
        guard response.status == .ok else {
            throw SidecarBridgeError.unavailable(nil)
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await buffer in response.body {
                        let str = String(buffer: buffer)
                        continuation.yield(str)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Model Registry Operations

    public func listModels() async throws -> AnigmaListModelsResponse {
        let request = AnigmaListModelsRequest(ctx: makeContext())
        return try await post("/models/list", body: request)
    }

    public func installModel(modelId: String, repo: String? = nil, revision: String? = nil) async throws -> AnigmaInstallModelResponse {
        let request = AnigmaInstallModelRequest(
            ctx: makeContext(),
            modelId: modelId,
            repo: repo,
            revision: revision
        )
        return try await post("/models/install", body: request)
    }

    // MARK: - ML Operations

    public func chat(
        messages: [ChatMessage],
        model: String? = nil,
        temperature: Double = 0.7,
        provider: String? = nil,
        sessionId: String? = nil
    ) async throws -> String {
        let request = AnigmaChatRequest(
            ctx: makeContext(),
            messages: messages,
            model: model,
            temperature: temperature,
            provider: provider,
            sessionId: sessionId
        )
        let response: AnigmaChatResponse = try await post("/ml/chat", body: request)
        return response.message
    }

    public func embed(text: String, model: String, sessionId: String? = nil) async throws -> AnigmaEmbedResponse {
        let request = AnigmaEmbedRequest(
            ctx: makeContext(),
            text: text,
            model: model,
            sessionId: sessionId
        )
        return try await post("/ml/embed", body: request)
    }

    public func search(query: String, model: String, topK: Int = 10, threshold: Double = 0.7, sessionId: String? = nil) async throws -> AnigmaSearchResponse {
        let request = AnigmaSearchRequest(
            ctx: makeContext(),
            query: query,
            model: model,
            topK: topK,
            threshold: threshold,
            sessionId: sessionId
        )
        return try await post("/ml/search", body: request)
    }

    // MARK: - Evidence Operations

    public func getSessionEvidence(sessionId: String) async throws -> AnigmaSessionEvidenceResponse {
        let request = AnigmaSessionEvidenceRequest(
            ctx: makeContext(),
            sessionId: sessionId
        )
        return try await post("/evidence/session/\(sessionId)", body: request)
    }

    // MARK: - Plan Coordination

    public func submitPlan(operationType: String, parameters: [String: String], priority: String = "normal") async throws -> AnigmaPlanSubmitResponse {
        let request = AnigmaPlanSubmitRequest(
            ctx: makeContext(),
            operationType: operationType,
            sessionContext: nil,
            parameters: parameters,
            priority: priority
        )
        return try await post("/plan/submit", body: request)
    }

    // MARK: - Agent Operations

    public func runAgent(agentId: String, task: String, parameters: [String: String]? = nil) async throws -> AnigmaAgentRunResponse {
        let request = AnigmaAgentRunRequest(
            ctx: makeContext(),
            agentId: agentId,
            task: task,
            parameters: parameters
        )
        return try await post("/agents/run", body: request)
    }

    // MARK: - Export Operations

    public func startExport(format: String, documentIds: [String], options: [String: String]? = nil) async throws -> AnigmaExportStartResponse {
        let request = AnigmaExportStartRequest(
            ctx: makeContext(),
            format: format,
            documentIds: documentIds,
            options: options
        )
        return try await post("/export/start", body: request)
    }

    public func healthCheck() async throws -> Bool {
        do {
            var request = HTTPClientRequest(url: makeRequestURL("/health"))
            request.method = .GET
            let response = try await httpClient.execute(request, timeout: .seconds(5))
            
            if response.status == .ok {
                let bodyData = try await response.body.collect(upTo: 1 * 1024 * 1024)
                let health = try JSONDecoder().decode(AnigmaHealthResponse.self, from: bodyData)
                return health.ok
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - HTTP Helpers

    private func post<In: Encodable, Out: Decodable>(_ path: String, body: In) async throws -> Out {
        let data = try JSONEncoder().encode(body)
        
        var request = HTTPClientRequest(url: makeRequestURL(path))
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(data)
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        
        if response.status == .ok {
            let bodyData = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB limit
            return try JSONDecoder().decode(Out.self, from: bodyData)
        } else {
            throw SidecarBridgeError.unavailable(nil)
        }
    }

    private func get<Out: Decodable>(_ path: String) async throws -> Out {
        var request = HTTPClientRequest(url: makeRequestURL(path))
        request.method = .GET
        
        let response = try await httpClient.execute(request, timeout: .seconds(5))
        
        if response.status == .ok {
            let bodyData = try await response.body.collect(upTo: 1 * 1024 * 1024) // 1MB limit
            return try JSONDecoder().decode(Out.self, from: bodyData)
        } else {
            throw SidecarBridgeError.unavailable(nil)
        }
    }

    // MARK: - Heartbeat & Connectivity

    private func startHeartbeat() {
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(heartbeatInterval))
                let healthy = try? await healthCheck()
                self.isHealthy = healthy ?? false
                self.lastHeartbeatAt = Date()
                notifyHealthChange()
            }
        }
    }

    private func notifyHealthChange() {
        let status = self.healthStatus
        for continuation in healthContinuations.values {
            continuation.yield(status)
        }
    }

    public var healthStatus: HealthStatus {
        HealthStatus(
            isHealthy: isHealthy,
            lastHeartbeatAt: lastHeartbeatAt,
            reconnectionAttempts: reconnectionAttempts
        )
    }
}

public struct HealthStatus: Sendable {
    public let isHealthy: Bool
    public let lastHeartbeatAt: Date?
    public let reconnectionAttempts: Int
}

public enum SidecarBridgeError: Error, LocalizedError {
    case unavailable(Error?)
    case sessionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let error):
            return "Anigma daemon unavailable: \(error?.localizedDescription ?? "No details")"
        case .sessionFailed(let message):
            return "Failed to open session with Anigma daemon: \(message)"
        }
    }
}
