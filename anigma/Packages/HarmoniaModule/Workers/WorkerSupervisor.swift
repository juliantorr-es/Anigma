//
//  WorkerSupervisor.swift
//  HarmoniaModule
//
//  Supervises MLX/llama worker processes and exposes a unified dispatch API.
//

import AnigmaCore
@preconcurrency import CryptoKit
@preconcurrency import Foundation
import MLWorkerCommon

public enum WorkerError: Error, Sendable {
    case engineUnavailable(MLWorkerEngine)
    case workerFailed(MLWorkerEngine, reason: String)
    case policyViolation(String)
    case resourceLimited(String)
}

public actor WorkerSupervisor {
    private enum Constants {
        static let failureBackoff: TimeInterval = 1.0
        static let maxConcurrencyPerEngine: Int = 4
        static let maxQueueDepthPerEngine: Int = 64
        static let healthCheckInterval: TimeInterval = 30.0
        static let maxHealthFailures: Int = 3
        static let maxRestartsInWindow: Int = 5
        static let restartWindow: TimeInterval = 600.0
        static let rssSampleInterval: TimeInterval = 2.0
        static let rssConsecutiveLimit: Int = 3
        static let ewmaAlpha: Double = 0.3
    }

    public init() {}

    private var enginePools: [MLWorkerEngine: EnginePool] = [:]

    public func dispatch(request: MLWorkerRequest) async throws -> MLWorkerResponse {
        logInfo(
            "Dispatching ML worker request \(request.requestId) for engine \(request.engine.rawValue)",
            category: "WorkerSupervisor")
        try enforceLimits(for: request.engine)
        incrementPending(for: request.engine)
        defer { decrementPending(for: request.engine) }

        let worker = try await nextHandle(for: request.engine)

        incrementActive(for: request.engine)
        defer { decrementActive(for: request.engine) }

        let response = try await worker.send(request: request)
        if response.status == .failed {
            logError(
                "Worker \(request.engine.rawValue) reported failure for request \(request.requestId)",
                category: "WorkerSupervisor")
        }
        return response
    }

    private func enforceLimits(for engine: MLWorkerEngine) throws {
        let pool = enginePools[engine] ?? EnginePool()
        if pool.pendingRequests + pool.activeRequests >= Constants.maxQueueDepthPerEngine {
            throw WorkerError.resourceLimited("Queue depth exceeded for engine \(engine.rawValue)")
        }
        if pool.activeRequests >= Constants.maxConcurrencyPerEngine {
            throw WorkerError.resourceLimited(
                "Concurrency limit reached for engine \(engine.rawValue)")
        }
    }

    private func incrementPending(for engine: MLWorkerEngine) {
        var pool = enginePools[engine] ?? EnginePool()
        pool.pendingRequests += 1
        enginePools[engine] = pool
    }

    private func decrementPending(for engine: MLWorkerEngine) {
        var pool = enginePools[engine] ?? EnginePool()
        pool.pendingRequests = max(0, pool.pendingRequests - 1)
        enginePools[engine] = pool
    }

    private func incrementActive(for engine: MLWorkerEngine) {
        var pool = enginePools[engine] ?? EnginePool()
        pool.activeRequests += 1
        enginePools[engine] = pool
    }

    private func decrementActive(for engine: MLWorkerEngine) {
        var pool = enginePools[engine] ?? EnginePool()
        pool.activeRequests = max(0, pool.activeRequests - 1)
        enginePools[engine] = pool
    }

    private func nextHandle(for engine: MLWorkerEngine) async throws -> WorkerHandle {
        var pool = enginePools[engine] ?? EnginePool()
        pool.cleanDeadHandles()

        var extraEnv: [String: String] = [:]
        if engine == .llama {
            let serverInfo = try await ensureLlamaServer(for: engine, pool: &pool)
            extraEnv["LLAMA_SERVER_URL"] = serverInfo.url.absoluteString
        }

        if let handle = pool.leastLoadedHandle() {
            enginePools[engine] = pool
            return handle
        }

        if let backoffUntil = pool.backoffUntil, backoffUntil > Date() {
            let wait = backoffUntil.timeIntervalSinceNow
            if wait > 0 {
                logInfo(
                    "Backoff active for \(engine.rawValue); waiting \(wait)s before restarting worker",
                    category: "WorkerSupervisor")
                try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                pool.cleanDeadHandles()
                if let handle = pool.leastLoadedHandle() {
                    enginePools[engine] = pool
                    return handle
                }
            }
        }

        let handle = try WorkerHandle(engine: engine, env: extraEnv) { [weak self] engine, error in
            Task {
                await self?.recordWorkerFailure(engine: engine, error: error)
            }
        }

        pool.handles.append(handle)
        pool.backoffUntil = nil
        enginePools[engine] = pool
        return handle
    }

    private struct LlamaServerInfo {
        let process: Process
        let url: URL
        let binaryHash: String
        let modelPath: String
        let modelHash: String
        var lastHealthCheck: Date
        var isWarmed: Bool
        var consecutiveHealthFailures: Int
        var lastWarmupLatencyMs: Double?
        var lastWarmupDimension: Int?
        var rollingHealthLatencyMs: Double?
        var rollingEmbedLatencyMs: Double?
        var lastErrorSummary: String?
        var lastWarmupAt: Date?
        var restartTimestamps: [Date]
        var rssConsecutive: Int
    }

    private func ensureLlamaServer(for engine: MLWorkerEngine, pool: inout EnginePool) async throws
        -> LlamaServerInfo {
        if var info = pool.llamaServer, info.process.isRunning {
            // Lightweight health check to avoid stale servers
            if Date().timeIntervalSince(info.lastHealthCheck) > Constants.healthCheckInterval {
                if try await !isLlamaServerHealthy(info: &info) {
                    if info.consecutiveHealthFailures >= Constants.maxHealthFailures {
                        info = try restartLlamaServer(previous: info)
                    }
                } else {
                    info.lastHealthCheck = Date()
                }
                pool.llamaServer = info
            }
            try enforceLlamaResourceCaps(info: &info)
            try await warmupLlamaServer(info: &info)
            pool.llamaServer = info
            return info
        }
        var info = try startLlamaServer()
        try enforceLlamaResourceCaps(info: &info)
        try await warmupLlamaServer(info: &info)
        pool.llamaServer = info
        return info
    }

    private func restartLlamaServer(previous: LlamaServerInfo) throws -> LlamaServerInfo {
        var prev = previous
        prev.restartTimestamps.append(Date())
        // Trim window
        prev.restartTimestamps = prev.restartTimestamps.filter {
            Date().timeIntervalSince($0) <= Constants.restartWindow
        }
        if prev.restartTimestamps.count > Constants.maxRestartsInWindow {
            throw WorkerError.workerFailed(.llama, reason: "llama-server restart budget exceeded")
        }
        let delay = backoffDelay(for: prev)
        if delay > 0 {
            Thread.sleep(forTimeInterval: delay)
        }
        var restarted = try startLlamaServer()
        restarted.restartTimestamps = prev.restartTimestamps
        return restarted
    }

    private func startLlamaServer() throws -> LlamaServerInfo {
        let env = ProcessInfo.processInfo.environment
        let binaryPath = env["LLAMA_SERVER_BINARY"] ?? "llama-server"
        let modelPath =
            env["LLAMA_SERVER_MODEL"] ?? env["LLAMA_MODEL_PATH"] ?? env["LLAMA_DEFAULT_MODEL"] ?? ""
        guard !modelPath.isEmpty else {
            throw WorkerError.workerFailed(
                .llama, reason: "LLAMA_SERVER_MODEL/LLAMA_MODEL_PATH not set")
        }
        let host = env["LLAMA_SERVER_HOST"] ?? "127.0.0.1"
        let port = Int(env["LLAMA_SERVER_PORT"] ?? "8080") ?? 8080
        guard let url = URL(string: "http://\(host):\(port)") else {
            fatalError("Failed to unwrap url")
        }

        let executableURL = URL(fileURLWithPath: binaryPath).standardizedFileURL
        let binaryHash = try WorkerHandle.publicValidateBinaryHash(
            for: .llama, at: executableURL, allowlistEnvKey: "LLAMA_SERVER_BINARY_HASH_ALLOWLIST")
        let modelHash = try computeFileHash(at: URL(fileURLWithPath: modelPath))
        if let modelAllow = env["LLAMA_MODEL_HASH_ALLOWLIST"] {
            let allow = modelAllow.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if !allow.isEmpty && !allow.contains(modelHash) {
                throw WorkerError.workerFailed(
                    .llama, reason: "model hash \(modelHash) not in allowlist")
            }
        }

        var args: [String] = [
            "--model", modelPath,
            "--host", host,
            "--port", "\(port)",
            "--embedding"
        ]
        if let extra = env["LLAMA_SERVER_EXTRA_ARGS"], !extra.isEmpty {
            args.append(contentsOf: extra.split(separator: " ").map(String.init))
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = args
        process.environment = env

        try process.run()
        logInfo(
            "Started llama-server at \(url) with hash \(binaryHash)", category: "WorkerSupervisor")
        return LlamaServerInfo(
            process: process,
            url: url,
            binaryHash: binaryHash,
            modelPath: modelPath,
            modelHash: modelHash,
            lastHealthCheck: Date(),
            isWarmed: false,
            consecutiveHealthFailures: 0,
            lastWarmupLatencyMs: nil,
            lastWarmupDimension: nil,
            rollingHealthLatencyMs: nil,
            rollingEmbedLatencyMs: nil,
            lastErrorSummary: nil,
            lastWarmupAt: nil,
            restartTimestamps: [],
            rssConsecutive: 0
        )
    }

    private func isLlamaServerHealthy(info: inout LlamaServerInfo) async throws -> Bool {
        var request = URLRequest(url: info.url.appendingPathComponent("health"))
        request.timeoutInterval = 10.0
        let start = Date()
        let (data, response) = try await timedSession().data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        let latencyMs = Date().timeIntervalSince(start) * 1000
        if (200..<300).contains(http.statusCode), !data.isEmpty {
            info.rollingHealthLatencyMs = ewma(
                previous: info.rollingHealthLatencyMs, new: latencyMs)
            info.consecutiveHealthFailures = 0
            // Embed sanity check
            do {
                let embedResult = try await probeLlamaEmbed(info: &info)
                info.rollingEmbedLatencyMs = ewma(
                    previous: info.rollingEmbedLatencyMs, new: embedResult.latencyMs)
                if let expected = info.lastWarmupDimension, expected != embedResult.dimension {
                    info.lastErrorSummary =
                        "embed dimension mismatch expected=\(expected) got=\(embedResult.dimension)"
                    info.consecutiveHealthFailures += 1
                    return false
                }
                info.lastHealthCheck = Date()
                return true
            } catch {
                info.lastErrorSummary = "\(error)"
                info.consecutiveHealthFailures += 1
                return false
            }
        }
        let bodyHash = sha256Hex(data)
        let summary = "HTTP \(http.statusCode) bodyHash=\(bodyHash)"
        info.lastErrorSummary = summary
        info.consecutiveHealthFailures += 1
        logError("llama-server health check failed: \(summary)", category: "WorkerSupervisor")
        return false
    }

    private func warmupLlamaServer(info: inout LlamaServerInfo) async throws {
        if info.isWarmed { return }
        let env = ProcessInfo.processInfo.environment
        let warmupText = env["LLAMA_SERVER_WARMUP_TEXT"] ?? "anigma warmup"
        guard !warmupText.isEmpty else { return }

        var request = URLRequest(url: info.url.appendingPathComponent("/embedding"))
        request.httpMethod = "POST"
        request.timeoutInterval = 5.0
        let payload: [String: Any] = [
            "model": info.modelPath,
            "input": warmupText
        ]
        request.httpBody = try JSONSerialization.data(
            withJSONObject: payload, options: [.sortedKeys])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let start = Date()
        let (data, response) = try await timedSession().data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        if (200..<300).contains(statusCode) {
            let dim = try? Self.decodeEmbeddingDimension(from: data)
            info.isWarmed = true
            info.lastHealthCheck = Date()
            let latencyMs = Date().timeIntervalSince(start) * 1000
            info.lastWarmupLatencyMs = latencyMs
            info.lastWarmupAt = Date()
            if let dim {
                info.lastWarmupDimension = dim
                info.rollingEmbedLatencyMs = ewma(previous: info.rollingEmbedLatencyMs, new: latencyMs)
                logInfo(
                    "llama-server warmup ok: modelHash=\(info.modelHash) binaryHash=\(info.binaryHash) latencyMs=\(latencyMs) dim=\(dim)",
                    category: "WorkerSupervisor")
            }
        } else {
            logError(
                "llama-server warmup failed: HTTP \(statusCode) body=\(String(data: data, encoding: .utf8) ?? "<non-utf8>")",
                category: "WorkerSupervisor")
            throw WorkerError.workerFailed(
                .llama, reason: "llama-server warmup failed with HTTP \(statusCode)")
        }
    }

    private func enforceLlamaResourceCaps(info: inout LlamaServerInfo) throws {
        let env = ProcessInfo.processInfo.environment
        guard let capStr = env["LLAMA_SERVER_RSS_SOFT_CAP_MB"], let cap = Int(capStr), cap > 0
        else { return }
        guard let rssMb = sampleRSS(for: info.process.processIdentifier) else { return }
        if rssMb > cap {
            info.rssConsecutive += 1
        } else {
            info.rssConsecutive = 0
        }
        if info.rssConsecutive >= Constants.rssConsecutiveLimit {
            logError(
                "llama-server RSS cap exceeded: \(rssMb)MB > \(cap)MB", category: "WorkerSupervisor"
            )
            info = try restartLlamaServer(previous: info)
        }
    }

    private func sampleRSS(for pid: pid_t) -> Int? {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-o", "rss=", "-p", "\(pid)"]
        let pipe = Pipe()
        ps.standardOutput = pipe
        do {
            try ps.run()
        } catch {
            return nil
        }
        ps.waitUntilExit()
        guard ps.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard
            let str = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            let kb = Int(str)
        else { return nil }
        return kb / 1024
    }

    private static func decodeEmbeddingDimension(from data: Data) throws -> Int {
        struct EmbedResponse: Decodable {
            struct Item: Decodable { let embedding: [Double] }
            let data: [Item]
        }
        let decoded = try JSONDecoder().decode(EmbedResponse.self, from: data)
        guard let first = decoded.data.first?.embedding, !first.isEmpty else {
            throw WorkerError.workerFailed(
                .llama, reason: "llama-server warmup returned empty embedding")
        }
        return first.count
    }

    private func ewma(previous: Double?, new: Double, alpha: Double = Constants.ewmaAlpha) -> Double {
        guard let prev = previous else { return new }
        return alpha * new + (1 - alpha) * prev
    }

    private func backoffDelay(for info: LlamaServerInfo) -> Double {
        let failures = max(1, info.consecutiveHealthFailures)
        let base = pow(2.0, Double(min(failures, 6)))  // capped
        let jitter = deterministicJitter(seed: info.binaryHash + info.modelHash)
        return base * (0.8 + 0.4 * jitter)
    }

    private func deterministicJitter(seed: String) -> Double {
        let digest = SHA256.hash(data: Data(seed.utf8))
        let val = digest.prefix(8).reduce(0 as UInt64) { ($0 << 8) | UInt64($1) }
        return Double(val % 10_000) / 10_000.0
    }

    private func timedSession(request: TimeInterval = 10, resource: TimeInterval = 15) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = request
        config.timeoutIntervalForResource = resource
        return URLSession(configuration: config)
    }

    private func probeLlamaEmbed(info: inout LlamaServerInfo) async throws -> (
        dimension: Int, latencyMs: Double
    ) {
        var request = URLRequest(url: info.url.appendingPathComponent("/embedding"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": info.modelPath,
            "input": "healthcheck"
        ]
        request.httpBody = try JSONSerialization.data(
            withJSONObject: payload, options: [.sortedKeys])
        let start = Date()
        let (data, response) = try await timedSession().data(for: request)
        let latencyMs = Date().timeIntervalSince(start) * 1000
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyHash = sha256Hex(data)
            throw WorkerError.workerFailed(
                .llama,
                reason: "llama-server embed probe failed: HTTP \(status) bodyHash=\(bodyHash)")
        }
        let dimension = try Self.decodeEmbeddingDimension(from: data)
        info.lastWarmupDimension = info.lastWarmupDimension ?? dimension
        return (dimension, latencyMs)
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func computeFileHash(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func recordWorkerFailure(engine: MLWorkerEngine, error: Error) async {
        var pool = enginePools[engine] ?? EnginePool()
        pool.cleanDeadHandles()
        pool.backoffUntil = Date().addingTimeInterval(Constants.failureBackoff)
        enginePools[engine] = pool
        logError("Worker for \(engine.rawValue) exited: \(error)", category: "WorkerSupervisor")
    }

    private struct EnginePool {
        var handles: [WorkerHandle] = []
        var pendingRequests: Int = 0
        var activeRequests: Int = 0
        var backoffUntil: Date?
        var llamaServer: LlamaServerInfo?

        mutating func cleanDeadHandles() {
            handles.removeAll { !$0.isAlive }
        }

        func leastLoadedHandle() -> WorkerHandle? {
            handles
                .filter { $0.isAlive }
                .sorted { $0.inFlight < $1.inFlight }
                .first
        }
    }

    private final class WorkerHandle: @unchecked Sendable {
        let engine: MLWorkerEngine
        let process: Process
        let stdinPipe: Pipe
        let stdoutPipe: Pipe
        var buffer = Data()
        var continuations: [String: CheckedContinuation<MLWorkerResponse, Error>] = [:]
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        var alive = true
        var inFlight = 0
        private var lastHealthCheck = Date()

        var isAlive: Bool { alive && process.isRunning }

        init(
            engine: MLWorkerEngine, env: [String: String] = [:],
            failureHandler: @escaping @Sendable (MLWorkerEngine, Error) -> Void
        ) throws {
            self.engine = engine
            encoder.outputFormatting = []

            let executableURL = Self.executableURL(for: engine)
            let binaryHash = try Self.validateBinaryHash(for: engine, at: executableURL)

            let process = Process()
            process.executableURL = executableURL
            process.arguments = ["--engine", engine.rawValue]
            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = Pipe()
            var fullEnv = ProcessInfo.processInfo.environment
            env.forEach { fullEnv[$0] = $1 }
            process.environment = fullEnv

            self.process = process
            self.stdinPipe = stdinPipe
            self.stdoutPipe = stdoutPipe

            try process.run()
            startReading(failureHandler: failureHandler)
            logInfo(
                "Started worker for \(engine.rawValue) with binary hash \(binaryHash)",
                category: "WorkerSupervisor")
        }

        deinit {
            process.terminate()
        }

        static func executableURL(for engine: MLWorkerEngine) -> URL {
            let envKey = engine == .mlx ? "MLX_WORKER_BINARY" : "LLAMA_WORKER_BINARY"
            let executable =
                ProcessInfo.processInfo.environment[envKey]
                ?? ProcessInfo.processInfo.environment["ML_WORKER_BINARY"]
                ?? ".build/debug/ml-worker"

            return URL(
                fileURLWithPath: executable,
                relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            ).standardizedFileURL
        }

        static func publicValidateBinaryHash(
            for engine: MLWorkerEngine, at url: URL, allowlistEnvKey: String? = nil
        ) throws -> String {
            try validateBinaryHash(for: engine, at: url, allowlistEnvKey: allowlistEnvKey)
        }

        private static func validateBinaryHash(
            for engine: MLWorkerEngine, at url: URL, allowlistEnvKey: String? = nil
        ) throws -> String {
            let hash = try hashForBinary(at: url)
            // Engine-specific allowlist, then global
            var allowlist: [String] = []
            let env = ProcessInfo.processInfo.environment
            if engine == .llama, let specific = env["LLAMA_WORKER_BINARY_HASH_ALLOWLIST"] {
                allowlist.append(
                    contentsOf: specific.split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    })
            }
            if engine == .mlx, let specific = env["MLX_WORKER_BINARY_HASH_ALLOWLIST"] {
                allowlist.append(
                    contentsOf: specific.split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    })
            }
            if let global = env["ML_WORKER_BINARY_HASH_ALLOWLIST"] {
                allowlist.append(
                    contentsOf: global.split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    })
            }
            if let extraKey = allowlistEnvKey, let specific = env[extraKey] {
                allowlist.append(
                    contentsOf: specific.split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    })
            }
            if !allowlist.isEmpty && !allowlist.contains(hash) {
                throw WorkerError.workerFailed(
                    engine, reason: "binary hash \(hash) not in allowlist")
            }
            return hash
        }

        private static func hashForBinary(at url: URL) throws -> String {
            let data = try Data(contentsOf: url)
            let digest = SHA256.hash(data: data)
            return digest.map { String(format: "%02x", $0) }.joined()
        }

        func send(request: MLWorkerRequest) async throws -> MLWorkerResponse {
            guard process.isRunning else {
                throw WorkerError.workerFailed(engine, reason: "process exited")
            }
            // Basic health guard: ensure we saw recent traffic
            if Date().timeIntervalSince(lastHealthCheck) > Constants.healthCheckInterval {
                throw WorkerError.workerFailed(
                    engine, reason: "worker unhealthy (no recent activity)")
            }

            inFlight += 1
            defer { inFlight = max(0, inFlight - 1) }

            let data = try encoder.encode(request)
            let line = (String(data: data, encoding: .utf8) ?? "") + "\n"

            return try await withCheckedThrowingContinuation { continuation in
                continuations[request.requestId] = continuation
                stdinPipe.fileHandleForWriting.write(Data(line.utf8))
            }
        }

        private func startReading(
            failureHandler: @escaping @Sendable (MLWorkerEngine, Error) -> Void
        ) {
            stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                guard let self = self else { return }
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                self.buffer.append(chunk)
                while let range = self.buffer.range(of: Data("\n".utf8)) {
                    let lineData = self.buffer.subdata(in: 0..<range.lowerBound)
                    self.buffer.removeSubrange(0...range.lowerBound)
                    self.handleLine(lineData)
                }
            }

            process.terminationHandler = { [weak self] _ in
                self?.alive = false
                let error = WorkerError.workerFailed(self?.engine ?? .mlx, reason: "process exited")
                self?.drainContinuations(with: error)
                failureHandler(self?.engine ?? .mlx, error)
            }
        }

        private func handleLine(_ data: Data) {
            lastHealthCheck = Date()
            guard let json = String(data: data, encoding: .utf8),
                let response = try? decoder.decode(MLWorkerResponse.self, from: Data(json.utf8)),
                let continuation = continuations.removeValue(forKey: response.requestId)
            else {
                return
            }
            continuation.resume(returning: response)
        }

        private func drainContinuations(with error: Error) {
            continuations.values.forEach { $0.resume(throwing: error) }
            continuations.removeAll()
        }
    }
}

private final class WarmupResult: @unchecked Sendable {
    var statusCode: Int = -1
    var error: Error?
    var dim: Int?
}
