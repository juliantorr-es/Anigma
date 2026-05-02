import Foundation
import Darwin
import CathedralModule
import DatabaseCore
import AnigmaPrimitives
import struct ContextumModule.EmbeddingComputeResult
import protocol ContextumModule.EmbeddingComputing
import struct ContextumModule.ModelRegistryEntry
import protocol ContextumModule.ModelRegistryProtocol
import class ModelRegistry.ModelRegistryStore
import VectorumModule
import OSLog

private let httpTransportLogger = Logger(subsystem: "com.anigma.AnigmaDaemonCore", category: "HTTPTransport")

actor APIKeyManager {
    private let database: any DatabaseExecutor
    private let tokenManager: CapabilityTokenManager

    init(database: any DatabaseExecutor, tokenManager: CapabilityTokenManager) {
        self.database = database
        self.tokenManager = tokenManager
    }

    func initializeStorage() async throws {
        _ = try await database.query("SELECT 1")
    }

    func exchangeForKeyToken(_ apiKey: String, clientName: String) async throws -> CapabilityToken {
        let scopes = ["system.read", "job.submit", "job.read", "vault.read", "vault.write"]
        return await tokenManager.mintToken(clientName: "\(clientName):\(apiKey.prefix(8))", requestedScopes: scopes)
    }
}

actor HTTPServerManager {
    private var listener: UnixHTTPListener?
    private var acceptTask: Task<Void, Never>?
    private var socketPath: String?

    func start(configuration: DaemonConfiguration.DaemonConfig, daemon: DaemonServer) async throws {
        let path = (configuration.unixSocket as NSString).expandingTildeInPath
        self.socketPath = path
        httpTransportLogger.info("Starting daemon HTTP transport on unix socket '\(path, privacy: .public)'")

        let listener = try UnixHTTPListener(socketPath: path)
        self.listener = listener

        acceptTask = Task {
            for await connection in listener.connections {
                Task {
                    do {
                        let request = try await connection.readRequest()
                        httpTransportLogger.debug("Accepted HTTP request \(request.method, privacy: .public) \(request.path, privacy: .public)")
                        let response = await daemon.handleHTTPRequest(request)
                        try await connection.writeResponse(response)
                        try await connection.close()
                    } catch {
                        httpTransportLogger.error("HTTP connection failed: \(error.localizedDescription, privacy: .public)")
                        try? await connection.close()
                    }
                }
            }
        }
    }

    func stop() async {
        httpTransportLogger.info("Stopping daemon HTTP transport")
        acceptTask?.cancel()
        acceptTask = nil
        listener = nil

        if let socketPath {
            try? FileManager.default.removeItem(atPath: socketPath)
            self.socketPath = nil
        }
    }
}

actor JobEventHub {
    func publish() async {}
}

actor SignalManager {
    func cleanup() async {}
}

struct ResourceThresholds: Sendable {
    let maxMemoryMB: Int
    let maxCPUPercent: Double
    let maxDiskUsagePercent: Double
}

struct ResourceMonitorEvent: Sendable {
    let kind: String
    let message: String
}

actor ResourceMonitor {
    private let thresholds: ResourceThresholds
    private var handler: (@Sendable (ResourceMonitorEvent) async -> Void)?

    init(thresholds: ResourceThresholds) {
        self.thresholds = thresholds
    }

    func registerEventHandler(_ handler: @escaping @Sendable (ResourceMonitorEvent) async -> Void) async {
        self.handler = handler
        _ = thresholds
    }

    func startMonitoring() async {}

    func stopMonitoring() async {}
}

// MARK: - PlanCompiler Shim

public struct EvidenceDigest: Sendable, Codable {
    public let hash: String
    public let dependencies: [String]
    
    public init(hash: String = "", dependencies: [String] = []) {
        self.hash = hash
        self.dependencies = dependencies
    }
}

public struct PlanStep: Sendable, Codable {
    public let id: String
    public let operation: String
    
    public init(id: String = UUID().uuidString, operation: String = "") {
        self.id = id
        self.operation = operation
    }
}

public enum PlanStatus: String, CaseIterable, Sendable, Codable {
    case blocked = "blocked"
    case approved = "approved"
    case executing = "executing"
    case completed = "completed"
    case failed = "failed"
}

public enum PlanReason: String, Sendable, Codable {
    case pending = "pending"
    case evidenceValidated = "evidence_validated"
}

public struct SimplePlan: Sendable, Codable {
    public let id: String
    public let operationType: String
    public let priority: String
    public let evidenceDigest: EvidenceDigest
    public let steps: [PlanStep]
    
    public init(
        id: String = UUID().uuidString,
        operationType: String,
        priority: String,
        evidenceDigest: EvidenceDigest = EvidenceDigest(),
        steps: [PlanStep] = []
    ) {
        self.id = id
        self.operationType = operationType
        self.priority = priority
        self.evidenceDigest = evidenceDigest
        self.steps = steps
    }
}

actor PlanCompiler {
    init(dbActor: any DatabaseCore.DatabaseExecutor, evidenceSubstrate: EvidenceSubstrate) {
        _ = dbActor
        _ = evidenceSubstrate
    }
    
    public func generatePlan(request: any Sendable) async throws -> SimplePlan {
        return SimplePlan(
            operationType: "unknown",
            priority: "medium"
        )
    }
    
    // For compatibility with code expecting generateEvidenceProducedPlan
    public func generateEvidenceProducedPlan(request: any Sendable) async throws -> SimplePlan {
        return SimplePlan(
            operationType: "unknown",
            priority: "medium"
        )
    }
}

// MARK: - PlanRequest Shim

public struct PlanRequest: Sendable {
    public let sessionId: String?
    public let operationType: String
    public let parameters: [String: String]
    public let priority: Priority
    
    public enum Priority: String, CaseIterable, Sendable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }
    
    public init(
        sessionId: String? = nil,
        operationType: String,
        parameters: [String: String] = [:],
        priority: Priority
    ) {
        self.sessionId = sessionId
        self.operationType = operationType
        self.parameters = parameters
        self.priority = priority
    }
}

public struct ConcreteEmbeddingComputing {
    public let base: DeterministicEmbeddingComputer

    public init(base: DeterministicEmbeddingComputer) {
        self.base = base
    }
}

extension ConcreteEmbeddingComputing: EmbeddingComputing {
    public func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        inputs: [String],
        normalize: Bool
    ) async throws -> EmbeddingComputeResult {
        let result = try await base.computeEmbeddings(
            modelID: modelID,
            modelVersion: modelVersion,
            inputs: inputs,
            normalize: normalize
        )
        return EmbeddingComputeResult(
            vectors: result.vectors,
            dimension: result.dimension,
            inputHashes: result.inputHashes
        )
    }
}

public actor ConcreteModelRegistry {
    private let registry: ModelRegistryStore

    public init(registry: ModelRegistryStore) {
        self.registry = registry
    }

    public func find(id: String) async throws -> ModelRegistryEntry? {
        guard let entry = try await registry.find(id: id) else {
            return nil
        }
        return ModelRegistryEntry(id: entry.id, spec: entry.spec)
    }

    public func recordUsage(_ id: String) async throws {
        try await registry.recordUsage(id)
    }
}

extension ConcreteModelRegistry: ModelRegistryProtocol {}

struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data?
}

struct HTTPResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data?
}

enum HTTPServerError: Error {
    case failedToCreateSocket
    case failedToBindSocket
    case failedToListen
    case failedToAccept
    case invalidRequest
    case connectionClosed
    case failedToWrite
}

final class UnixHTTPListener: @unchecked Sendable {
    private let socket: Int32
    private let socketPath: String

    init(socketPath: String) throws {
        self.socketPath = socketPath
        self.socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)

        guard socket >= 0 else {
            throw HTTPServerError.failedToCreateSocket
        }

        let parent = URL(fileURLWithPath: socketPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(atPath: socketPath)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.utf8CString
        let pathCapacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count <= pathCapacity else {
            Darwin.close(socket)
            throw HTTPServerError.failedToBindSocket
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
            raw.initialize(repeating: 0, count: pathCapacity)
            pathBytes.withUnsafeBufferPointer { buffer in
                if let baseAddress = buffer.baseAddress {
                    raw.update(from: baseAddress, count: buffer.count)
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult >= 0 else {
            Darwin.close(socket)
            throw HTTPServerError.failedToBindSocket
        }

        guard Darwin.listen(socket, SOMAXCONN) >= 0 else {
            Darwin.close(socket)
            throw HTTPServerError.failedToListen
        }
    }

    deinit {
        Darwin.close(socket)
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    var connections: AsyncStream<UnixHTTPConnection> {
        AsyncStream { continuation in
            Task {
                while !Task.isCancelled {
                    do {
                        continuation.yield(try await acceptConnection())
                    } catch {
                        continuation.finish()
                        break
                    }
                }
            }
        }
    }

    private func acceptConnection() async throws -> UnixHTTPConnection {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let clientSocket = Darwin.accept(self.socket, nil, nil)
                if clientSocket >= 0 {
                    httpTransportLogger.debug("Accepted unix socket client fd=\(clientSocket, privacy: .public)")
                    continuation.resume(returning: UnixHTTPConnection(socket: clientSocket))
                } else {
                    httpTransportLogger.error("Failed accepting unix socket client")
                    continuation.resume(throwing: HTTPServerError.failedToAccept)
                }
            }
        }
    }
}

final class UnixHTTPConnection: @unchecked Sendable {
    private let socket: Int32

    init(socket: Int32) {
        self.socket = socket
    }

    deinit {
        Darwin.close(socket)
    }

    func readRequest() async throws -> HTTPRequest {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var requestData = Data()
        let headerDelimiter = Data([13, 10, 13, 10])
        var headerEndIndex: Int?
        var contentLength = 0

        while true {
            let bytesRead: Int = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    let result = Darwin.read(self.socket, &buffer, buffer.count)
                    if result >= 0 {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: HTTPServerError.connectionClosed)
                    }
                }
            }

            guard bytesRead > 0 else {
                httpTransportLogger.error("Unix socket connection closed before complete request")
                throw HTTPServerError.connectionClosed
            }

            requestData.append(buffer, count: bytesRead)

            if headerEndIndex == nil, let range = requestData.range(of: headerDelimiter) {
                headerEndIndex = range.upperBound
                if let headerString = String(data: requestData[..<range.upperBound], encoding: .utf8) {
                    for line in headerString.components(separatedBy: "\r\n") where line.lowercased().hasPrefix("content-length:") {
                        let value = line.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces)
                        contentLength = Int(value ?? "0") ?? 0
                    }
                }
                if contentLength == 0 {
                    return try parseHTTPRequest(requestData)
                }
            }

            if let headerEndIndex, contentLength > 0, requestData.count - headerEndIndex >= contentLength {
                return try parseHTTPRequest(requestData)
            }
        }
    }

    func writeResponse(_ response: HTTPResponse) async throws {
        httpTransportLogger.debug("Writing HTTP response status=\(response.statusCode, privacy: .public)")
        var headers = response.headers
        headers["Content-Length"] = String(response.body?.count ?? 0)
        headers["Connection"] = "close"

        var responseString = "HTTP/1.1 \(response.statusCode) \(statusMessage(for: response.statusCode))\r\n"
        for (key, value) in headers {
            responseString += "\(key): \(value)\r\n"
        }
        responseString += "\r\n"

        guard let headerData = responseString.data(using: .utf8) else {
            throw HTTPServerError.failedToWrite
        }
        try await writeData(headerData)
        if let body = response.body {
            try await writeData(body)
        }
    }

    func close() async throws {
        _ = Darwin.close(socket)
    }

    private func writeData(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let written = data.withUnsafeBytes { buffer in
                    Darwin.write(self.socket, buffer.baseAddress, data.count)
                }
                if written >= 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HTTPServerError.failedToWrite)
                }
            }
        }
    }

    private func parseHTTPRequest(_ data: Data) throws -> HTTPRequest {
        guard let requestString = String(data: data, encoding: .utf8) else {
            throw HTTPServerError.invalidRequest
        }

        let parts = requestString.components(separatedBy: "\r\n\r\n")
        let head = parts.first ?? ""
        let bodyString = parts.count > 1 ? parts[1] : ""
        let lines = head.components(separatedBy: "\r\n")

        guard let firstLine = lines.first else {
            throw HTTPServerError.invalidRequest
        }

        let firstLineParts = firstLine.components(separatedBy: " ")
        guard firstLineParts.count >= 2 else {
            throw HTTPServerError.invalidRequest
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let headerParts = line.components(separatedBy: ": ")
            if headerParts.count == 2 {
                headers[headerParts[0]] = headerParts[1]
            }
        }

        return HTTPRequest(
            method: firstLineParts[0],
            path: firstLineParts[1],
            headers: headers,
            body: bodyString.isEmpty ? nil : Data(bodyString.utf8)
        )
    }

    private func statusMessage(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 202: return "Accepted"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}

// MARK: - Missing Service Shims (Phase 4 Implementation)

public struct EvidenceViolation: Sendable, Codable {
    public let type: String
    public let message: String
    public let severity: String
    
    public init(type: String = "", message: String = "", severity: String = "") {
        self.type = type
        self.message = message
        self.severity = severity
    }
}

public struct PlanVerificationResult: Sendable, Codable {
    public let isValid: Bool
    public let violations: [EvidenceViolation]
    public let dependencyCount: Int
    public let error: AnigmaErrorStatus?
    
    public init(isValid: Bool = true, violations: [EvidenceViolation] = [], dependencyCount: Int = 0, error: AnigmaErrorStatus? = nil) {
        self.isValid = isValid
        self.violations = violations
        self.dependencyCount = dependencyCount
        self.error = error
    }
}

public struct LeaseInfo: Sendable, Codable {
    public let leaseId: String
    public let expiresAt: Date
    public let resource: String
    
    public init(leaseId: String = "", expiresAt: Date = Date(), resource: String = "") {
        self.leaseId = leaseId
        self.expiresAt = expiresAt
        self.resource = resource
    }
}

public struct LeaseVerificationResult: Sendable {
    public let isValid: Bool
    public let reason: String
    
    public init(isValid: Bool, reason: String = "") {
        self.isValid = isValid
        self.reason = reason
    }
}

public actor PlanVerifier {
    public init() {}
    
    public func verifyPlan(planId: String) async throws -> PlanVerificationResult {
        return PlanVerificationResult(
            isValid: true,
            violations: [],
            dependencyCount: 0,
            error: nil
        )
    }
}

public actor LeaseManager {
    public init() {}
    
    public func acquireLease(resource: String, duration: TimeInterval) async throws -> LeaseInfo {
        return LeaseInfo(
            leaseId: UUID().uuidString,
            expiresAt: Date().addingTimeInterval(duration),
            resource: resource
        )
    }
    
    public func releaseLease(leaseId: String) async throws {}
    
    public func verifyLease(planId: String, context: DaemonRequestContext? = nil) async throws -> LeaseVerificationResult {
        return LeaseVerificationResult(isValid: true, reason: "")
    }
}

public actor ContextumCoordinator {
    public init() {}
    
    public func transformDocument(request: AnigmaWebDocumentTransformRequest) async throws -> String {
        return "transformed"
    }
}

// MARK: - EvidenceSubstrate Extension

extension EvidenceSubstrate {
    public func bindOutputsToEvidence(planId: String, outputs: [String: Any]) async throws -> String {
        return "bound"
    }
}

// MARK: - CathedralFacade Extension  
extension CathedralFacade {
    public func generate(prompt: String, options: [String: Any] = [:]) async throws -> String {
        return "generated"
    }
    
    public func generateComplianceReport(planId: String) async throws -> String {
        return "report"
    }
}

// MARK: - Request Type Extensions

extension AnigmaWebGenerateRequest {
    public var options: [String: Any] {
        var opts: [String: Any] = [:]
        if let maxTokens = self.maxTokens {
            opts["maxTokens"] = maxTokens
        }
        return opts
    }
}

extension AnigmaWebDocumentTransformRequest {
    public var options: [String: Any] {
        return [:]
    }
}
