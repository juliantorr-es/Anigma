//
//  SidecarBridge.swift
//  AnigmaSidecar
//
//  Created by Gemini on 2026-01-10.
//
//  Exclusive bridge between AnigmaAuthority and anigmad daemon using native JSON over HTTP.
//  This eliminates SwiftProtobuf and grpc-swift dependencies.
//

import AnigmaPrimitives
import AsyncHTTPClient
import NIOHTTP1
import CryptoKit
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
        let path = socketPath ?? "/tmp/anigmad.sock" // Default path

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
        bridge.startHeartbeat()

        return bridge
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

    public func listArtifacts(pageToken: String = "", pageSize: UInt32 = 0) async throws -> AnigmaListResponse {
        let request = AnigmaListRequest(ctx: makeContext(), pageToken: pageToken, pageSize: pageSize)
        return try await post("/artifacts/list", body: request)
    }

    public func cancelJob(jobId: String) async throws -> AnigmaCancelJobResponse {
        let request = AnigmaCancelJobRequest(ctx: makeContext(), jobId: jobId)
        return try await post("/job/cancel", body: request)
    }

    public func getReceipt(receiptHash: String) async throws -> AnigmaReceiptResponse {
        let request = AnigmaReceiptRequest(ctx: makeContext(), receiptHash: receiptHash)
        return try await post("/receipt/get", body: request)
    }

    public func verifyChain(headReceiptHash: String) async throws -> AnigmaVerifyChainResponse {
        let request = AnigmaVerifyChainRequest(ctx: makeContext(), headReceiptHash: headReceiptHash)
        return try await post("/chain/verify", body: request)
    }

    public func streamJobEvents(jobId: String) async throws -> AsyncThrowingStream<AnigmaJobEvent, Error> {
        let request = AnigmaStreamJobEventsRequest(ctx: makeContext(), jobId: jobId)
        let data = try JSONEncoder().encode(request)
        let response = try await httpClient.execute(
            socketPath: socketPath,
            urlPath: "/job/events/stream",
            method: .POST,
            headers: ["Content-Type": "application/json"],
            body: .bytes(data),
            timeout: .seconds(30)
        )
        
        guard response.status == .ok else {
            throw SidecarBridgeError.unavailable(nil)
        }
        
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let stream = response.body
                    var buffer = ByteBuffer()
                    for try await chunk in stream {
                        buffer.writeBuffer(chunk)
                        // Process lines (NDJSON)
                        while let newlineIndex = buffer.readableBytesView.firstIndex(of: 0x0A) {
                            let lineLength = newlineIndex - buffer.readerIndex
                            guard let lineData = buffer.readData(length: lineLength) else {
                                break
                            }
                            // Consume newline
                            buffer.moveReaderIndex(forwardBy: 1)
                            
                            let event = try JSONDecoder().decode(AnigmaJobEvent.self, from: lineData)
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func bridgeMCP(inputStream: AsyncStream<String>) async throws -> AsyncThrowingStream<String, Error> {
        var request = HTTPClientRequest(url: "http://localhost/mcp")
        request.method = .POST
        request.body = .stream(length: nil) { writer in
            for await chunk in inputStream {
                var buffer = ByteBuffer(string: chunk)
                try await writer.writeBuffer(buffer)
            }
        }
        
        let response = try await httpClient.execute(request, timeout: .hours(24), socketPath: socketPath)
        
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

    public func healthCheck() async throws -> Bool {
        do {
            let response: AnigmaHealthResponse = try await get("/health")
            return response.ok
        } catch {
            return false
        }
    }

    // MARK: - HTTP Helpers

    private func post<In: Encodable, Out: Decodable>(_ path: String, body: In) async throws -> Out {
        let data = try JSONEncoder().encode(body)
        let response = try await httpClient.execute(
            socketPath: socketPath,
            urlPath: path,
            method: .POST,
            headers: ["Content-Type": "application/json"],
            body: .bytes(data),
            timeout: .seconds(30)
        )
        if response.status == .ok {
            let bodyData = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB limit
            return try JSONDecoder().decode(Out.self, from: bodyData)
        } else {
            throw SidecarBridgeError.unavailable(nil)
        }
    }

    private func get<Out: Decodable>(_ path: String) async throws -> Out {
        let response = try await httpClient.execute(
            socketPath: socketPath,
            urlPath: path,
            method: .GET,
            headers: [:],
            timeout: .seconds(5)
        )
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
