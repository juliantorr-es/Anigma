//
//  HTTPServerManager.swift
//  AnigmaDaemonCore
//
//  Manages the Hummingbird HTTP server lifecycle, replacing gRPC.
//

import Foundation
import Hummingbird
import NIOCore
import NIOPosix
import AnigmaPrimitives // Use Codable contracts from Primitives

#if canImport(HummingbirdTLS)
import HummingbirdTLS
#endif
#if canImport(NIOSSL)
import NIOSSL
#endif

extension HealthCheckResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension OpenSessionResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension StatusResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension SubmitJobResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension GetJobStatusResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension CancelJobResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension AnigmaListResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension AnigmaReceiptResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension AnigmaVerifyChainResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}

extension AnigmaIngestArtifactResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension AnigmaRetrieveArtifactResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension AnigmaGetJobStatusResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension AnigmaListJobsResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
extension AnigmaStreamTelemetryResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}

/// Simple CORS middleware
private struct CORSMiddleware: HBMiddleware {
    let allowedOrigins: [String]
    
    init(allowedOrigins: [String]) {
        self.allowedOrigins = allowedOrigins
    }
    
    func apply(to request: Request, context: some RequestContext, next: (Request, some RequestContext) async throws -> Response) async throws -> Response {
        let response = try await next(request, context)
        // Add CORS headers
        if let origin = request.headers["origin"].first, allowedOrigins.contains(origin) || allowedOrigins.contains("*") {
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
            response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
            response.headers["Access-Control-Max-Age"] = "86400"
        }
        // Handle preflight requests
        if request.method == .options {
            return Response(status: .noContent)
        }
        return response
    }
}

public actor HTTPServerManager {
    private enum HTTPServerError: Error {
        case tlsConfigurationMissing
        case tlsNotAvailable
    }
    
    private var serverTasks: [Task<Void, Error>] = []
    private let group: EventLoopGroup

    public init() {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    }

    /// Start HTTP server on Unix domain socket and optionally TCP/TLS
    public func start(
        configuration: DaemonConfig,
        daemon: DaemonServer
    ) async throws {
        let socketPath = configuration.unixSocket
        let expandedPath = (socketPath as NSString).expandingTildeInPath
        try createSocketDirectory(expandedPath)
        try? FileManager.default.removeItem(atPath: expandedPath)

        let router = Router()
        
        // Add CORS middleware if origins specified
        if !configuration.corsAllowedOrigins.isEmpty {
            let corsMiddleware = CORSMiddleware(allowedOrigins: configuration.corsAllowedOrigins)
            router.middlewares.add(corsMiddleware)
        }

        // Health Check
        router.get("/health") { _, _ in
            let response = await daemon.handleHealthCheck()
            return response
        }

        // Open Session
        router.post("/session/open") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaOpenSessionRequest.self, context: context)
            let response = await daemon.handleOpenSession(
                requestedClientName: body.requestedClientName,
                requestedScopes: body.requestedScopes
            )
            return response
        }

        // API Key Exchange
        router.post("/auth/api-key") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaAPIKeyExchangeRequest.self, context: context)
            let response = try await daemon.handleAPIKeyExchange(
                apiKey: body.apiKey,
                clientName: body.clientName
            )
            return response
        }

        // Get Status
        router.post("/status") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaStatusRequest.self, context: context)
            return try await daemon.handleGetStatus(ctx: DaemonRequestContext(
                clientId: body.ctx.clientId,
                capabilityToken: body.ctx.capabilityToken,
                nonce: body.ctx.nonce
            ))
        }

        // Submit Job
        router.post("/job/submit") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaSubmitJobRequest.self, context: context)
            let inputs = body.spec.inputs.map { input in
                ArtifactRef(
                    hash: input.hash,
                    mediaType: input.mediaType,
                    sizeBytes: input.sizeBytes
                )
            }
            let spec = JobSpec(
                kind: body.spec.kind,
                configCanonical: body.spec.configCanonical,
                inputs: inputs
            )
            return try await daemon.handleSubmitJob(ctx: DaemonRequestContext(
                clientId: body.ctx.clientId,
                capabilityToken: body.ctx.capabilityToken,
                nonce: body.ctx.nonce
            ), spec: spec)
        }

        // List Artifacts
        router.post("/artifacts/list") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaListRequest.self, context: context)
            let pageToken = body.pageToken.isEmpty ? nil : body.pageToken
            let pageSize = body.pageSize == 0 ? nil : Int(body.pageSize)
            let result = try await daemon.handleListArtifacts(
                ctx: DaemonRequestContext(
                    clientId: body.ctx.clientId,
                    capabilityToken: body.ctx.capabilityToken,
                    nonce: body.ctx.nonce
                ),
                pageToken: pageToken,
                pageSize: pageSize
            )
            return AnigmaListResponse(
                artifacts: result.artifacts.map { ref in
                    AnigmaArtifactRef(
                        hash: ref.hash,
                        mediaType: ref.mediaType,
                        sizeBytes: ref.sizeBytes
                    )
                },
                nextPageToken: result.nextPageToken ?? "",
                error: nil
            )
        }

        // Ingest Artifact
        router.post("/artifacts/ingest") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaIngestArtifactRequest.self, context: context)
            // TODO: implement streaming ingestion
            // Design: Use HTTP chunked transfer encoding or multipart/form-data.
            // Option 1: Client sends POST with Transfer-Encoding: chunked, first chunk is JSON metadata,
            // subsequent chunks are raw binary data.
            // Option 2: Use multipart/form-data with two parts: metadata (JSON) and data (binary).
            // For now, small artifacts are supported via single request/response.
            let config = HandleIngestArtifactConfiguration(
                ctx: RequestContext(clientId: body.ctx.clientId, capabilityToken: body.ctx.capabilityToken, nonce: body.ctx.nonce),
                kind: body.kind,
                mime: body.mediaType,
                data: body.data,
                plaintextSha256: body.plaintextSha256 ?? "",
                chunkCount: 1,
                byteCount: body.data.count,
                filenameHint: body.filenameHint
            )
            let result = try await daemon.handleIngestArtifact(config: config)
            return AnigmaIngestArtifactResponse(
                artifact: AnigmaArtifactRef(hash: result.artifact.hash, mediaType: result.artifact.mediaType, sizeBytes: result.artifact.sizeBytes),
                receiptHash: result.receiptHash,
                error: nil
            )
        }

        // Retrieve Artifact
        router.post("/artifacts/retrieve") { request, context in
            // TODO: implement streaming retrieval
            // Design: Server responds with Transfer-Encoding: chunked and Content-Type: application/octet-stream.
            // Alternatively, use HTTP Range requests for partial retrieval.
            // For now, small artifacts are returned as base64 in JSON response.
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaRetrieveArtifactRequest.self, context: context)
            let (data, receiptHash) = try await daemon.handleRetrieveArtifact(
                ctx: DaemonRequestContext(
                    clientId: body.ctx.clientId,
                    capabilityToken: body.ctx.capabilityToken,
                    nonce: body.ctx.nonce
                ),
                hash: body.hash
            )
            return AnigmaRetrieveArtifactResponse(data: data, receiptHash: receiptHash, error: nil)
        }

        // Get Job Status
        router.post("/job/status") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaGetJobStatusRequest.self, context: context)
            let response = try await daemon.handleGetJobStatus(
                ctx: DaemonRequestContext(
                    clientId: body.ctx.clientId,
                    capabilityToken: body.ctx.capabilityToken,
                    nonce: body.ctx.nonce
                ),
                jobId: body.jobId
            )
            return AnigmaGetJobStatusResponse(
                jobId: response.jobId,
                state: response.state,
                progressPermille: response.progressPermille,
                outputs: response.outputs.map { ref in
                    AnigmaArtifactRef(hash: ref.hash, mediaType: ref.mediaType, sizeBytes: ref.sizeBytes)
                },
                finalReceiptHash: response.finalReceiptHash,
                error: response.error.map { AnigmaErrorStatus(code: $0.code, message: $0.message, detailJson: $0.detailJson) }
            )
        }

        // List Jobs
        router.post("/jobs/list") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaListJobsRequest.self, context: context)
            let pageToken = body.pageToken.isEmpty ? nil : body.pageToken
            let pageSize = body.pageSize == 0 ? nil : Int(body.pageSize)
            let result = try await daemon.handleListJobs(
                ctx: DaemonRequestContext(
                    clientId: body.ctx.clientId,
                    capabilityToken: body.ctx.capabilityToken,
                    nonce: body.ctx.nonce
                ),
                pageToken: pageToken,
                pageSize: pageSize,
                filterByState: body.filterByState
            )
            return AnigmaListJobsResponse(
                jobs: result.jobs.map { job in
                    AnigmaJob(
                        jobId: job.id,
                        spec: AnigmaJobSpec(
                            kind: job.spec.kind,
                            configCanonical: job.spec.configCanonical,
                            inputs: job.spec.inputs.map { input in
                                AnigmaArtifactRef(hash: input.hash, mediaType: input.mediaType, sizeBytes: input.sizeBytes)
                            }
                        ),
                        state: job.state.rawValue,
                        progressPermille: job.state == .succeeded ? 1000 : 0,
                        outputs: job.outputs.map { output in
                            AnigmaArtifactRef(hash: output.hash, mediaType: output.mediaType, sizeBytes: output.sizeBytes)
                        },
                        finalReceiptHash: job.receiptHash
                    )
                },
                nextPageToken: result.nextPageToken ?? "",
                error: nil
            )
        }

        // Stream Telemetry (placeholder)
        router.post("/telemetry/stream") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaStreamTelemetryRequest.self, context: context)
            // TODO: implement streaming telemetry
            return AnigmaStreamTelemetryResponse(
                ok: false,
                error: AnigmaErrorStatus(code: "UNIMPLEMENTED", message: "StreamTelemetry not yet implemented", detailJson: nil),
                receiptHash: nil
            )
        }

        // Cancel Job
        router.post("/job/cancel") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaCancelJobRequest.self, context: context)
            let response = try await daemon.handleCancelJob(
                ctx: DaemonRequestContext(
                    clientId: body.ctx.clientId,
                    capabilityToken: body.ctx.capabilityToken,
                    nonce: body.ctx.nonce
                ),
                jobId: body.jobId
            )
            return response
        }

        // Get Receipt
        router.post("/receipt/get") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaReceiptRequest.self, context: context)
            let result = await daemon.handleGetReceipt(
                ctx: DaemonRequestContext(
                    clientId: body.ctx.clientId,
                    capabilityToken: body.ctx.capabilityToken,
                    nonce: body.ctx.nonce
                ),
                receiptHash: body.receiptHash
            )
            let jsonString = (try? String(data: result.receipt?.deterministicJSON() ?? Data(), encoding: .utf8)) ?? ""
            return AnigmaReceiptResponse(
                receiptCanonicalJson: jsonString,
                error: result.error.map { AnigmaErrorStatus(code: $0.code, message: $0.message, detailJson: $0.detailJson) }
            )
        }

        // Verify Chain
        router.post("/chain/verify") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaVerifyChainRequest.self, context: context)
            let result = await daemon.handleVerifyChain(
                ctx: DaemonRequestContext(
                    clientId: body.ctx.clientId,
                    capabilityToken: body.ctx.capabilityToken,
                    nonce: body.ctx.nonce
                ),
                headReceiptHash: body.headReceiptHash
            )
            return AnigmaVerifyChainResponse(
                ok: result.ok,
                message: result.message,
                error: result.error.map { AnigmaErrorStatus(code: $0.code, message: $0.message, detailJson: $0.detailJson) }
            )
        }

        // Gemini Bridge: List Tools
        router.get("/v1/tools") { _, _ in
            return try await daemon.handleGeminiListTools()
        }

        // Gemini Bridge: Call Tool
        router.post("/v1/tools/call") { request, context in
            let body = try await request.decode(as: GeminiToolCallRequest.self, context: context)
            return try await daemon.handleGeminiCallTool(name: body.name, arguments: body.arguments)
        }

        // MCP Endpoint (Unified)
        router.post("/mcp") { request, context in
            let (stream, continuation) = AsyncStream<String>.makeStream()
            
            // Bridge request body to incomingStream
            Task {
                do {
                    for try await byteBuffer in request.body {
                        if let str = String(buffer: byteBuffer) {
                            // MCP often sends multiple messages in one chunk or messages ending in newline
                            let lines = str.split(separator: "\n", omittingEmptySubsequences: true)
                            for line in lines {
                                continuation.yield(String(line))
                            }
                        }
                    }
                } catch {
                    print("MCP bridge error: \(error)")
                }
                continuation.finish()
            }
            
            let transport = DaemonMCPTransport(incomingStream: stream)
            
            // Run MCP server session in background
            Task {
                try? await daemon.handleMCPConnection(transport: transport)
            }
            
            // Return outgoing messages from transport as streaming response
            return Response(
                status: .ok,
                headers: ["Content-Type": "application/x-ndjson"],
                body: .stream { writer in
                    for await message in transport.serverToClientStream {
                        try await writer.write(.byteBuffer(ByteBuffer(string: message + "\n")))
                    }
                }
            )
        }

        // Stream Job Events (SSE)
        router.post("/job/events/stream") { request, context in
            let body = try await request.decode(as: AnigmaPrimitives.AnigmaStreamJobEventsRequest.self, context: context)
            let ctx = DaemonRequestContext(
                clientId: body.ctx.clientId,
                capabilityToken: body.ctx.capabilityToken,
                nonce: body.ctx.nonce
            )
            let stream = try await daemon.handleStreamJobEvents(ctx: ctx, jobId: body.jobId)
            
            // Convert DaemonJobEvent to AnigmaJobEvent
            func convert(_ event: DaemonJobEvent) -> AnigmaPrimitives.AnigmaJobEvent {
                let output: AnigmaPrimitives.AnigmaArtifactRef?
                if let out = event.output {
                    output = AnigmaPrimitives.AnigmaArtifactRef(
                        hash: out.hash,
                        mediaType: out.mediaType,
                        sizeBytes: out.sizeBytes
                    )
                } else {
                    output = nil
                }
                let error: AnigmaPrimitives.AnigmaErrorStatus?
                if let err = event.error {
                    error = AnigmaPrimitives.AnigmaErrorStatus(
                        code: err.code,
                        message: err.message,
                        detailJson: err.detailJson
                    )
                } else {
                    error = nil
                }
                return AnigmaPrimitives.AnigmaJobEvent(
                    jobId: event.jobId,
                    type: event.type.rawValue,
                    message: event.message,
                    progressPermille: event.progressPermille,
                    output: output,
                    receiptHash: event.receiptHash ?? "",
                    error: error
                )
            }
            
            // Create streaming response
            let response = Response(
                status: .ok,
                headers: ["Content-Type": "application/x-ndjson"],
                body: .stream { writer in
                    for await event in stream {
                        let anigmaEvent = convert(event)
                        let data = try JSONEncoder().encode(anigmaEvent)
                        try await writer.write(.byteBuffer(ByteBuffer(bytes: data)))
                        // Add newline for NDJSON
                        try await writer.write(.byteBuffer(ByteBuffer(bytes: [0x0A])))
                    }
                }
            )
            return response
        }

        // Create Unix socket server
        let unixApp = Application(
            router: router,
            configuration: .init(address: .unixDomainSocket(path: expandedPath)),
            eventLoopGroupProvider: .shared(group)
        )

        // Hummingbird 2 uses a Task to run the application
        serverTasks.append(Task {
            try await unixApp.run()
        })

        print("  HTTP server: listening on \(expandedPath)")

        // Start TCP server if enabled
        if configuration.tcpEnabled {
            try await startTCPServer(configuration: configuration, router: router)
        }
    }

    private func startTCPServer(configuration: DaemonConfig, router: Router) async throws {
        let host = configuration.bindHost
        let port = configuration.bindPort
        
        let appConfiguration = Application.Configuration(address: .hostname(host, port: port))
        
        // Configure TLS if enabled
        var tlsConfiguration: TLSConfiguration?
        if configuration.tlsEnabled {
            #if canImport(NIOSSL) && canImport(HummingbirdTLS)
            guard let certPath = configuration.tlsCertificatePath,
                  let keyPath = configuration.tlsPrivateKeyPath else {
                throw HTTPServerError.tlsConfigurationMissing
            }
            let certificate = try NIOSSLCertificate(file: certPath, format: .pem)
            let privateKey = try NIOSSLPrivateKey(file: keyPath, format: .pem)
            tlsConfiguration = TLSConfiguration.makeServerConfiguration(
                certificateChain: [.certificate(certificate)],
                privateKey: .privateKey(privateKey)
            )
            #else
            throw HTTPServerError.tlsNotAvailable
            #endif
        }
        
        let app = Application(
            router: router,
            configuration: appConfiguration,
            eventLoopGroupProvider: .shared(group),
            tlsConfiguration: tlsConfiguration
        )
        
        serverTasks.append(Task {
            try await app.run()
        })
        
        let protocolStr = configuration.tlsEnabled ? "https" : "http"
        print("  HTTP server: listening on \(protocolStr)://\(host):\(port)")
    }

    public func stop() async {
        for task in serverTasks {
            task.cancel()
        }
        serverTasks.removeAll()
        try? await group.shutdownGracefully()
    }

// MARK: - Gemini Bridge Types

struct GeminiToolCallRequest: Codable {
    let name: String
    let arguments: [String: AnyCodable]
}

extension Dictionary: ResponseGenerator where Key == String, Value == AnyCodable {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
