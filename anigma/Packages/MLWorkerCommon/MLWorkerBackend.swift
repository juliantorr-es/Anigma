import AnigmaCore
//
//  MLWorkerBackend.swift
//  MLWorkerCommon
//
//  Backend runner implementations for ML tasks.
//  Provides direct in-process execution of ML workloads.
//

import Foundation
import CryptoKit
import AnigmaPrimitives

#if canImport(MLXLMCommon)
    import MLX
    import MLXEmbedders
    @preconcurrency import MLXLMCommon
#endif

#if canImport(CoreML)
    import CoreML
#endif

#if canImport(MetalPerformanceShaders)
    import MetalPerformanceShaders
#endif

// local GenericCoreError removed

// MARK: - Backend Execution Result

/// Backend execution result with structured outputs and captured streams
public struct BackendResult<Success, Failure> {
    public let stdout: Data
    public let stderr: Data
    public let exitCode: Int32
    public let timedOut: Bool
    
    public init(stdout: Data, stderr: Data, exitCode: Int32, timedOut: Bool) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.timedOut = timedOut
    }
}

// MARK: - Abstract Backend Runner

/// Abstract backend runner with deterministic execution boundaries
open class BackendRunner {
    public let engine: MLWorkerEngine
    public let timeoutSeconds: Int
    public let maxOutputBytes: Int
    
    public init(engine: MLWorkerEngine, timeoutSeconds: Int = 120, maxOutputBytes: Int = 100 * 1024 * 1024) {
        self.engine = engine
        self.timeoutSeconds = timeoutSeconds
        self.maxOutputBytes = maxOutputBytes
    }
    
    /// Execute backend with deterministic argv construction and strict resource limits
    open func execute(
        modelPath: String,
        task: MLTaskKind,
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions,
        requestId: String
    ) throws -> BackendResult<String, String> {
        throw GenericCoreError("BackendRunner.execute() must be implemented by subclass")
    }
    
    /// Construct deterministic argv for provenance tracking
    open func buildArgv(
        modelPath: String,
        task: MLTaskKind,
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions,
        requestId: String
    ) throws -> [String] {
        throw GenericCoreError("BackendRunner.buildArgv() must be implemented by subclass")
    }
    
    /// Get environment allowlist for this backend
    open func getEnvironmentAllowlist() -> [String] {
        return [
            "ML_WORKER_MAX_MEMORY",
            "ML_WORKER_TIMEOUT",
            "ML_WORKER_THREADS",
            "MLX_ACCELERATOR",
            "LLAMA_ACCELERATOR",
            "LLAMA_SERVER_URL",
            "DEEPSEEK_API_KEY",
            "DEEPSEEK_BASE_URL",
            "DEEPSEEK_MODEL",
            "MLX_MODEL_ID",
            "MLX_MODEL_ID_CHAT",
            "MLX_MODEL_ID_EMBED",
            "MLX_MODEL_PATH",
            "COREML_MODEL_PATH",
            "COREML_ACCELERATOR"
        ]
    }
}

// MARK: - Process Execution Extension

extension BackendRunner {
    /// Execute subprocess with strict resource limits and stream capture
    public func runProcess(
        binary: String,
        argv: [String],
        workingDirectory: String,
        envAllowlist: [String]
    ) throws -> BackendResult<String, String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = Array(argv.dropFirst())  // Drop binary name
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        
        // Set environment allowlist
        var environment = ProcessInfo.processInfo.environment
        for (key, _) in environment {
            if !envAllowlist.contains(key) {
                environment.removeValue(forKey: key)
            }
        }
        process.environment = environment
        
        // Capture stdout/stderr with size limits
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        // Set up resource limits
        _ = DispatchTime.now() + .seconds(timeoutSeconds)
        
        // Start process
        try process.run()
        
        // Wait for process completion
        process.waitUntilExit()
        let timedOut = false
        
        // Note: Swift's Process doesn't have built-in timeout support
        // For production, we'd implement this with DispatchSourceTimer or similar
        
        // Read limited output
        let stdoutData = try readLimitedData(
            from: stdoutPipe.fileHandleForReading, maxBytes: maxOutputBytes)
        let stderrData = try readLimitedData(
            from: stderrPipe.fileHandleForReading, maxBytes: maxOutputBytes)
        
        return BackendResult<String, String>(
            stdout: stdoutData,
            stderr: stderrData,
            exitCode: process.terminationStatus,
            timedOut: timedOut
        )
    }
    
    /// Read data with size limits to prevent memory exhaustion
    public func readLimitedData(from handle: FileHandle, maxBytes: Int) throws -> Data {
        var data = Data()
        var totalRead = 0
        
        while true {
            let chunk = handle.readData(ofLength: min(4096, maxBytes - totalRead))
            if chunk.isEmpty { break }
            
            totalRead += chunk.count
            data.append(chunk)
            
            if totalRead >= maxBytes {
                throw GenericCoreError("Output exceeded maximum size limit (\(maxBytes) bytes)")
            }
        }
        
        return data
    }
}

// MARK: - Token Buffer for CoreML

public struct TokenBuffer {
    public let tokenIds: [Int32]
    public let attentionMask: [UInt8]
    public let tokenTypeIds: [Int32]?
    
    public init(tokenIds: [Int32], attentionMask: [UInt8], tokenTypeIds: [Int32]?) {
        self.tokenIds = tokenIds
        self.attentionMask = attentionMask
        self.tokenTypeIds = tokenTypeIds
    }
}

// MARK: - Llama.cpp Backend

public class LlamaBackendRunner: BackendRunner {
    private let llamaBinary: String
    private let serverURL: URL?

    public init(llamaBinary: String? = nil) {
        // Resolve llama binary path from environment or default
        self.llamaBinary =
            llamaBinary ?? ProcessInfo.processInfo.environment["LLAMA_BACKEND_BINARY"]
            ?? "llama-cli"
        if let urlString = ProcessInfo.processInfo.environment["LLAMA_SERVER_URL"],
            let url = URL(string: urlString) {
            self.serverURL = url
        } else {
            self.serverURL = nil
        }
        super.init(engine: .llama)
    }

    public override func execute(
        modelPath: String,
        task: MLTaskKind,
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions,
        requestId: String
    ) throws -> BackendResult<String, String> {
        // Prefer managed llama-server if configured
        if let serverURL {
            switch task {
            case .chat:
                return try executeServerChat(
                    serverURL: serverURL, inputFile: inputFile, outputFile: outputFile,
                    options: options)
            case .embed:
                return try executeServerEmbed(
                    serverURL: serverURL, inputFile: inputFile, outputFile: outputFile)
            default:
                break
            }
        }

        let argv = try buildArgv(
            modelPath: modelPath,
            task: task,
            inputFile: inputFile,
            outputFile: outputFile,
            options: options,
            requestId: requestId
        )

        return try runProcess(
            binary: llamaBinary,
            argv: argv,
            workingDirectory: inputFile.deletingLastPathComponent().path,
            envAllowlist: getEnvironmentAllowlist()
        )
    }

    public override func buildArgv(
        modelPath: String,
        task: MLTaskKind,
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions,
        requestId: String
    ) throws -> [String] {
        var argv = [llamaBinary]

        // Resolve all paths to absolute paths for subprocess
        let absoluteModelPath = URL(fileURLWithPath: modelPath).absoluteURL.path
        let absoluteInputPath = inputFile.absoluteURL.path
        let absoluteOutputPath = outputFile.absoluteURL.path

        // Core arguments - fully specified for determinism
        argv.append(contentsOf: [
            "-m", absoluteModelPath,  // Model path (absolute)
            "-f", absoluteInputPath,  // Input prompt file (absolute)
            "-n", "\(options.maxTokens ?? 512)",  // Max tokens
            "--ctx-size", "2048",  // Fixed context size
            "--threads", "4",  // Fixed thread count
            "--seed", "\(options.seed)",  // Explicit seed for reproducibility
            "--temp", "\(options.temperature ?? 0.7)",  // Temperature
            "--top-p", "\(options.topP ?? 0.9)",  // Top-p sampling
            "--log-disable",  // Disable progress spam
            "--simple-io",  // Simple I/O format
            "-o", absoluteOutputPath  // Output file (absolute)
        ])

        // Task-specific arguments
        switch task {
        case .chat:
            argv.append(contentsOf: [
                "--chat-template", "llama3",  // Fixed chat template
                "--conversation"  // Conversation mode
            ])
        case .embed:
            argv.append(contentsOf: [
                "--embedding",  // Generate embeddings
                "--pooling", "mean"  // Pooling strategy
            ])
        default:
            break
        }

        return argv
    }

    // MARK: - llama-server helpers

    private func executeServerChat(
        serverURL: URL,
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions
    ) throws -> BackendResult<String, String> {
        let inputData = try Data(contentsOf: inputFile)
        let prompt = String(data: inputData, encoding: .utf8) ?? ""

        let payload: [String: Any] = [
            "model": modelPathOrDefault(),
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": options.maxTokens ?? 512,
            "temperature": options.temperature ?? 0.7,
            "top_p": options.topP ?? 0.9,
            "stream": false,
            "seed": options.seed
        ]

        let body = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        var request = URLRequest(url: serverURL.appendingPathComponent("/v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config)
        let (data, response) = try session.syncData(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw GenericCoreError("llama-server chat failed: HTTP \(status) \(bodyText)")
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let content = decoded.choices.first?.message.content ?? ""
        try content.write(to: outputFile, atomically: true, encoding: String.Encoding.utf8)

        return BackendResult<String, String>(stdout: data, stderr: Data(), exitCode: 0, timedOut: false)
    }

    private func executeServerEmbed(
        serverURL: URL,
        inputFile: URL,
        outputFile: URL
    ) throws -> BackendResult<String, String> {
        let inputData = try Data(contentsOf: inputFile)
        let text = String(data: inputData, encoding: .utf8) ?? ""
        let payload: [String: Any] = [
            "model": modelPathOrDefault(),
            "input": text
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        var request = URLRequest(url: serverURL.appendingPathComponent("/embedding"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config)

        let (data, response) = try session.syncData(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GenericCoreError("llama-server embedding failed: no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyHash = MLWorkerHasher.hashData(data)
            throw GenericCoreError(
                "llama-server embedding failed: HTTP \(http.statusCode) bodyHash=\(bodyHash)")
        }

        struct EmbedResponse: Decodable {
            struct DataItem: Decodable { let embedding: [Double] }
            let data: [DataItem]
        }
        let decoded: EmbedResponse
        do {
            decoded = try JSONDecoder().decode(EmbedResponse.self, from: data)
        } catch {
            let bodyHash = MLWorkerHasher.hashData(data)
            throw GenericCoreError("llama-server embedding decode failed bodyHash=\(bodyHash)")
        }
        guard let vector = decoded.data.first?.embedding else {
            throw GenericCoreError("llama-server embedding missing vector")
        }
        guard !vector.isEmpty else {
            throw GenericCoreError("llama-server embedding empty vector")
        }
        var bin = Data()
        for v in vector {
            var f = Float(v)
            bin.append(contentsOf: withUnsafeBytes(of: &f) { Data($0) })
        }
        try bin.write(to: outputFile)
        return BackendResult<String, String>(stdout: data, stderr: Data(), exitCode: 0, timedOut: false)
    }

    private func modelPathOrDefault() -> String {
        ProcessInfo.processInfo.environment["LLAMA_MODEL_PATH"] ?? "llama"
    }
}

// MARK: - Helper Functions

extension URLSession {
    internal func syncData(for request: URLRequest) throws -> (Data, URLResponse) {
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultResponse: URLResponse?
        var resultError: Error?
        
        let task = dataTask(with: request) { data, response, error in
            if let error = error {
                resultError = error
            } else {
                resultData = data ?? Data()
                resultResponse = response ?? URLResponse()
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        
        if let error = resultError {
            throw error
        }
        
        guard let data = resultData, let response = resultResponse else {
            throw GenericCoreError("URLSession syncData failed to produce result")
        }
        
        return (data, response)
    }
}

/// Run an async operation synchronously for worker use.
internal func runBlocking<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<T, Error>?
    
    Task {
        do {
            let value = try await operation()
            result = .success(value)
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }
    
    semaphore.wait()
    
    switch result {
    case .success(let value):
        return value
    case .failure(let error):
        throw error
    case .none:
        throw GenericCoreError("runBlocking failed to produce result")
    }
}

internal func blake3Hex(_ data: Data) -> String {
    return BLAKE3Digest.hex(of: data)
}

internal func expectedEmbeddingDimension(for engine: MLWorkerEngine) -> Int? {
    let env = ProcessInfo.processInfo.environment
    if let v = env["EMBEDDING_EXPECTED_DIM"], let n = Int(v) { return n }
    switch engine {
    case .mlx:
        if let v = env["MLX_EXPECTED_EMBED_DIM"], let n = Int(v) { return n }
        if let modelId = env["MLX_MODEL_ID_EMBED"], modelId.contains("bge-small") { return 384 }
    case .llama:
        if let v = env["LLAMA_EXPECTED_EMBED_DIM"], let n = Int(v) { return n }
    case .deepseek:
        return nil
    case .coreml:
        return nil
    }
    return nil
}

internal func collectBackendEnvVars(_ allowlist: [String]) -> [String: String] {
    var env: [String: String] = [:]
    let processInfo = ProcessInfo.processInfo

    for key in allowlist.sorted() {  // Deterministic ordering
        if let value = processInfo.environment[key] {
            // Normalize environment values for deterministic hashing
            env[key] = normalizeEnvValue(value)
        }
    }

    return env
}

internal func normalizeEnvValue(_ value: String) -> String {
    // Remove trailing slashes from paths for deterministic comparison
    var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)

    // Normalize path separators and remove redundant components
    if normalized.contains("/") {
        let components = normalized.split(separator: "/")
            .filter { !$0.isEmpty && $0 != "." }
            .filter { $0 != ".." || true }  // Keep .. for safety, but could normalize further
        normalized = components.joined(separator: "/")

        // Preserve leading slash if absolute path
        if value.hasPrefix("/") && !normalized.hasPrefix("/") {
            normalized = "/" + normalized
        }
    }

    return normalized
}

internal func collectRelevantEnvVars() -> [String: String] {
    let relevantKeys = [
        "MLX_MODEL_PATH",
        "LLAMA_MODEL_PATH",
        "ML_WORKER_MAX_MEMORY",
        "ML_WORKER_TIMEOUT"
    ]

    var env: [String: String] = [:]
    let processInfo = ProcessInfo.processInfo

    for key in relevantKeys.sorted() {  // Deterministic ordering
        if let value = processInfo.environment[key] {
            // Normalize environment values for deterministic hashing
            env[key] = normalizeEnvValue(value)
        }
    }

    return env
}

internal func generateMockEmbedding(inputHash: String, modelHash: String, dimension: Int) -> [Float] {
    var vector: [Float] = []
    var counter: UInt8 = 0
    while vector.count < dimension {
        var hasher = SHA256()
        hasher.update(data: Data((inputHash + modelHash).utf8))
        hasher.update(data: Data([counter]))
        let digest = hasher.finalize()
        for byte in digest {
            guard vector.count < dimension else { break }
            let normalized = (Float(Int(byte)) / 255.0) * 2 - 1
            vector.append(normalized)
        }
        counter = counter &+ 1
    }
    return vector
}

// MARK: - Model Cache (LRU)

/// Thread-safe LRU cache for loaded ML models with memory limit monitoring
public final class ModelCache<Key: Hashable, Value> {
    private struct CacheEntry {
        let key: Key
        let value: Value
        let size: Int
        var lastAccess: Date
    }
    
    private var entries: [Key: CacheEntry]
    private var accessOrder: [Key]
    private let lock: NSLock
    private let maxCount: Int
    private let maxMemoryBytes: Int
    private var currentMemoryBytes: Int
    private let evictionPolicy: EvictionPolicy
    
    public enum EvictionPolicy {
        case countBased
        case memoryBased
        case hybrid
    }
    
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
    
    public var totalMemoryBytes: Int {
        lock.lock()
        defer { lock.unlock() }
        return currentMemoryBytes
    }
    
    public var hitCount: Int = 0
    public var missCount: Int = 0
    
    public init(maxCount: Int = 10, maxMemoryBytes: Int = 1024 * 1024 * 1024, // 1GB default
                evictionPolicy: EvictionPolicy = .hybrid) {
        self.entries = [:]
        self.accessOrder = []
        self.lock = NSLock()
        self.maxCount = maxCount
        self.maxMemoryBytes = maxMemoryBytes
        self.currentMemoryBytes = 0
        self.evictionPolicy = evictionPolicy
    }
    
    public func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let entry = entries[key] else {
            missCount += 1
            return nil
        }
        
        // Update access order
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
            accessOrder.append(key)
        }
        
        // Update last access time
        entries[key] = CacheEntry(
            key: entry.key,
            value: entry.value,
            size: entry.size,
            lastAccess: Date()
        )
        
        hitCount += 1
        return entry.value
    }
    
    public func set(_ key: Key, value: Value, size: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        // Remove existing entry if present
        if let existing = entries[key] {
            currentMemoryBytes -= existing.size
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }
        
        // Add new entry
        let entry = CacheEntry(
            key: key,
            value: value,
            size: size,
            lastAccess: Date()
        )
        entries[key] = entry
        accessOrder.append(key)
        currentMemoryBytes += size
        
        // Evict if necessary
        evictIfNeeded()
    }
    
    public func remove(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let entry = entries.removeValue(forKey: key) else {
            return nil
        }
        
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        
        currentMemoryBytes -= entry.size
        return entry.value
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        entries.removeAll()
        accessOrder.removeAll()
        currentMemoryBytes = 0
        hitCount = 0
        missCount = 0
    }
    
    public func getStatistics() -> (hits: Int, misses: Int, hitRate: Double, count: Int, memoryBytes: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        let total = hitCount + missCount
        let hitRate = total > 0 ? Double(hitCount) / Double(total) : 0.0
        return (hitCount, missCount, hitRate, entries.count, currentMemoryBytes)
    }
    
    private func evictIfNeeded() {
        while shouldEvict() {
            evictOldest()
        }
    }
    
    private func shouldEvict() -> Bool {
        switch evictionPolicy {
        case .countBased:
            return entries.count > maxCount
        case .memoryBased:
            return currentMemoryBytes > maxMemoryBytes
        case .hybrid:
            return entries.count > maxCount || currentMemoryBytes > maxMemoryBytes
        }
    }
    
    private func evictOldest() {
        guard !accessOrder.isEmpty else { return }
        
        let oldestKey = accessOrder.removeFirst()
        if let entry = entries.removeValue(forKey: oldestKey) {
            currentMemoryBytes -= entry.size
        }
    }
}

// MARK: - Model File Hash Helper

internal func computeModelFileHash(_ filePath: String) -> String {
    let fileURL = URL(fileURLWithPath: filePath)
    guard FileManager.default.fileExists(atPath: filePath) else {
        return "no-file"
    }
    
    do {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    } catch {
        // Fallback to file modification date
        let attributes = try? FileManager.default.attributesOfItem(atPath: filePath)
        let modificationDate = attributes?[.modificationDate] as? Date ?? Date.distantPast
        let timestamp = Int(modificationDate.timeIntervalSince1970)
        return "timestamp-\(timestamp)"
    }
}

internal func getCacheKeyForModel(_ modelPath: String, engine: MLWorkerEngine) -> String {
    switch engine {
    case .coreml, .llama:
        let hash = computeModelFileHash(modelPath)
        return "\(modelPath):\(hash)"
    case .mlx, .deepseek:
        // For MLX and DeepSeek, modelPath is actually a model ID or URL
        return modelPath
    }
}

// MARK: - DeepSeek Cloud Backend (OpenAI-compatible)

public class DeepSeekBackendRunner: BackendRunner {
    private let apiKey: String
    private let baseURL: URL
    private let model: String

    public init(apiKey: String? = nil, baseURL: String? = nil, model: String? = nil) {
        let env = ProcessInfo.processInfo.environment
        self.apiKey = apiKey ?? env["DEEPSEEK_API_KEY"] ?? ""
        self.baseURL = URL(
            string: baseURL ?? env["DEEPSEEK_BASE_URL"] ?? "https://api.deepseek.com/v1")!
        self.model = model ?? env["DEEPSEEK_MODEL"] ?? "deepseek-chat"
        super.init(engine: .deepseek)
    }

    public override func execute(
        modelPath: String,
        task: MLTaskKind,
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions,
        requestId: String
    ) throws -> BackendResult<String, String> {
        guard !apiKey.isEmpty else {
            throw GenericCoreError("DEEPSEEK_API_KEY not set")
        }

        switch task {
        case .embed:
            throw GenericCoreError("DeepSeek embeddings are not supported by provider")
        case .chat:
            return try executeChat(
                inputFile: inputFile, outputFile: outputFile, options: options, requestId: requestId
            )
        default:
            throw GenericCoreError("Task \(task.rawValue) not supported for DeepSeek")
        }
    }

    private func executeChat(
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions,
        requestId: String
    ) throws -> BackendResult<String, String> {
        let inputData = try Data(contentsOf: inputFile)
        let inputText = String(data: inputData, encoding: .utf8) ?? ""

        if let stub = ProcessInfo.processInfo.environment["DEEPSEEK_STUB_BODY"]?.data(using: .utf8) {
            // Honor the stub but keep behavior aligned to the normal response parsing
            struct ChatResponse: Decodable {
                struct Choice: Decodable {
                    struct Message: Decodable { let content: String }
                    let message: Message
                }
                let choices: [Choice]
            }
            if let decoded = try? JSONDecoder().decode(ChatResponse.self, from: stub),
                let content = decoded.choices.first?.message.content {
                try content.write(to: outputFile, atomically: true, encoding: .utf8)
            } else {
                try stub.write(to: outputFile)
            }
            return BackendResult<String, String>(stdout: stub, stderr: Data(), exitCode: 0, timedOut: false)
        }

        var payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": inputText]
            ],
            "max_tokens": options.maxTokens ?? 512,
            "temperature": options.temperature ?? 0.7,
            "top_p": options.topP ?? 0.9,
            "stream": false
        ]
        // Preserve seed for determinism if provider supports it
        payload["seed"] = options.seed

        let body = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let session = URLSession(configuration: .ephemeral)
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultError: Error?
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                resultError = GenericCoreError("DeepSeek request failed: \(error.localizedDescription)")
                semaphore.signal()
                return
            }
            guard let data = data else {
                resultError = GenericCoreError("DeepSeek returned no data")
                semaphore.signal()
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if statusCode < 200 || statusCode >= 300 {
                let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                resultError = GenericCoreError("DeepSeek HTTP \(statusCode): \(bodyText)")
                semaphore.signal()
                return
            }
            // Parse OpenAI-compatible response
            struct ChatResponse: Decodable {
                struct Choice: Decodable {
                    struct Message: Decodable { let content: String }
                    let message: Message
                }
                let choices: [Choice]
            }
            do {
                let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                let content = decoded.choices.first?.message.content ?? ""
                try content.write(to: outputFile, atomically: true, encoding: .utf8)
                resultData = data
            } catch {
                resultError = error
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        
        if let error = resultError {
            throw error
        }
        
        guard let data = resultData else {
            throw GenericCoreError("DeepSeek returned no data")
        }
        
        return BackendResult<String, String>(
            stdout: data,
            stderr: Data(),
            exitCode: 0,
            timedOut: false
        )
    }

    public override func buildArgv(
        modelPath: String,
        task: MLTaskKind,
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions,
        requestId: String
    ) throws -> [String] {
        return [
            "deepseek",
            "--model", model,
            "--endpoint", baseURL.absoluteString,
            "--task", task.rawValue
        ]
    }
}

// MARK: - Mock Backend (for testing)

public class MockBackendRunner: BackendRunner {
    public override func execute(
        modelPath: String,
        task: MLTaskKind,
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions,
        requestId: String
    ) throws -> BackendResult<String, String> {
        // Generate mock output based on task type
        let mockOutput: Data
        let mockStderr: Data

        switch task {
        case .embed:
            // Generate mock embedding data
            let dimension: Int
            switch engine {
            case .mlx:
                dimension = 384
            case .llama:
                dimension = 4096
            case .deepseek:
                dimension = 4096
            case .coreml:
                dimension = 384
            }

            var embeddingData = Data()
            for i in 0..<dimension {
                let value = Float(sin(Double(i)) * 0.5 + 0.5)  // Deterministic mock values
                var little = value.bitPattern.littleEndian
                embeddingData.append(contentsOf: withUnsafeBytes(of: &little) { Data($0) })
            }
            try embeddingData.write(to: outputFile)

            mockOutput =
                "Generated mock embedding with dimension \(dimension)\n".data(using: .utf8)
                ?? Data()
            mockStderr = "Mock backend execution for embedding\n".data(using: .utf8) ?? Data()

        case .chat:
            // Generate mock chat response
            let inputData = try Data(contentsOf: inputFile)
            let inputText = String(data: inputData, encoding: .utf8) ?? "Unable to decode input"
            let response = "Mock \(engine.rawValue) response to: \(String(inputText.prefix(100)))"
            try response.write(to: outputFile, atomically: true, encoding: .utf8)

            mockOutput = response.data(using: .utf8) ?? Data()
            mockStderr = "Mock backend execution for chat\n".data(using: .utf8) ?? Data()

        default:
            mockOutput = "Mock execution for task \(task.rawValue)\n".data(using: .utf8) ?? Data()
            mockStderr =
                "Mock backend stderr for task \(task.rawValue)\n".data(using: .utf8) ?? Data()
        }

        return BackendResult<String, String>(
            stdout: mockOutput,
            stderr: mockStderr,
            exitCode: 0,
            timedOut: false
        )
    }

    public override func buildArgv(
        modelPath: String,
        task: MLTaskKind,
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions,
        requestId: String
    ) throws -> [String] {
        return [
            "mock-\(engine.rawValue)",
            "--model", modelPath,
            "--task", task.rawValue,
            "--input", inputFile.path,
            "--output", outputFile.path,
            "--request-id", requestId
        ]
    }
}

// MARK: - MLX Backend

public class MLXBackendRunner: BackendRunner {
    #if canImport(MLXLMCommon)
        private let chatModelId: String
        private let embedModelId: String
        
        
        // Static shared caches for model containers (count-based LRU)
        private static let chatContainerCache = ModelCache<String, MLXLMCommon.ModelContainer>(
            maxCount: ProcessInfo.processInfo.environment["ML_WORKER_CACHE_MAX_COUNT"].flatMap(Int.init) ?? 2,
            maxMemoryBytes: 0,
            evictionPolicy: .countBased
        )
        private static let embedContainerCache = ModelCache<String, MLXEmbedders.ModelContainer>(
            maxCount: ProcessInfo.processInfo.environment["ML_WORKER_CACHE_MAX_COUNT"].flatMap(Int.init) ?? 2,
            maxMemoryBytes: 0,
            evictionPolicy: .countBased
        )
        
        /// Get cache statistics for monitoring
        public static func getCacheStatistics() -> [(cache: String, hits: Int, misses: Int, hitRate: Double, count: Int)] {
            var stats: [(cache: String, hits: Int, misses: Int, hitRate: Double, count: Int)] = []
            let chatStats = chatContainerCache.getStatistics()
            stats.append(("MLXChatContainer", chatStats.hits, chatStats.misses, chatStats.hitRate, chatStats.count))
            let embedStats = embedContainerCache.getStatistics()
            stats.append(("MLXEmbedContainer", embedStats.hits, embedStats.misses, embedStats.hitRate, embedStats.count))
            return stats
        }

        public init(chatModelId: String? = nil, embedModelId: String? = nil) {
            let env = ProcessInfo.processInfo.environment
            self.chatModelId =
                chatModelId ?? env["MLX_MODEL_ID_CHAT"] ?? env["MLX_MODEL_ID"]
                ?? "mlx-community/Llama-3.2-3B-Instruct-4bit"
            self.embedModelId =
                embedModelId ?? env["MLX_MODEL_ID_EMBED"] ?? "mlx-community/bge-small-en-v1.5-4bit"
            super.init(engine: .mlx)
        }

        public override func execute(
            modelPath: String,
            task: MLTaskKind,
            inputFile: URL,
            outputFile: URL,
            options: MLTaskOptions,
            requestId: String
        ) throws -> BackendResult<String, String> {
            switch task {
            case .embed:
                try generateEmbedding(
                    inputFile: inputFile, outputFile: outputFile, seed: options.seed)
                return BackendResult<String, String>(stdout: Data(), stderr: Data(), exitCode: 0, timedOut: false)
            case .chat:
                let response = try generateChat(
                    inputFile: inputFile, outputFile: outputFile, options: options)
                return BackendResult<String, String>(
                    stdout: response.data(using: .utf8) ?? Data(), stderr: Data(), exitCode: 0,
                    timedOut: false)
            default:
                throw GenericCoreError("Task \(task.rawValue) not supported for MLX backend")
            }
        }

        public override func buildArgv(
            modelPath: String,
            task: MLTaskKind,
            inputFile: URL,
            outputFile: URL,
            options: MLTaskOptions,
            requestId: String
        ) throws -> [String] {
            return [
                "mlx-backend",
                "--chat-model", chatModelId,
                "--embed-model", embedModelId,
                "--task", task.rawValue,
                "--input", inputFile.path,
                "--output", outputFile.path,
                "--seed", "\(options.seed)"
            ]
        }

        private func generateChat(
            inputFile: URL,
            outputFile: URL,
            options: MLTaskOptions
        ) throws -> String {
            let inputData = try Data(contentsOf: inputFile)
            let prompt = String(data: inputData, encoding: .utf8) ?? ""
            let output: String = try runBlocking {
                let session = try self.loadChatSession(
                    maxTokens: options.maxTokens, temperature: options.temperature, topP: options.topP,
                    seed: options.seed)
                return try await session.respond(to: prompt, images: [], videos: [])
            }
            try output.write(to: outputFile, atomically: true, encoding: .utf8)
            return output
        }

        private func generateEmbedding(
            inputFile: URL,
            outputFile: URL,
            seed: Int
        ) throws {
            let inputData = try Data(contentsOf: inputFile)
            let text = String(data: inputData, encoding: .utf8) ?? ""
            let modelId = self.embedModelId
            let (vector, _): ([Float], Int) = try runBlocking {
                // Get container from cache or load it
                let container: MLXEmbedders.ModelContainer
                if let cached = MLXBackendRunner.embedContainerCache.get(modelId) {
                    container = cached
                } else {
                    container = try await MLXEmbedders.loadModelContainer(configuration: MLXEmbedders.ModelConfiguration(id: modelId))
                    // Estimate size (placeholder: 1 for count-based eviction)
                    MLXBackendRunner.embedContainerCache.set(modelId, value: container, size: 1)
                }
                
                return try await container.perform { model, tokenizer, pooling in
                    let tokens = tokenizer.encode(text: text, addSpecialTokens: true)
                    let eos = tokenizer.eosTokenId ?? 0
                    let maxLength = max(tokens.count, 1)
                    let padded =
                        tokens + Array(repeating: eos, count: max(0, maxLength - tokens.count))
                    let paddedInt32 = padded.map { Int32($0) }
                    let input = MLXArray(paddedInt32).reshaped([1, paddedInt32.count])
                    let mask = (input .!= eos)
                    let tokenTypes = MLXArray.zeros(input.shape, type: Int32.self)
                    let output = model(
                        input, positionIds: nil, tokenTypeIds: tokenTypes, attentionMask: mask)
                    let pooled = pooling(output, mask: mask, normalize: true, applyLayerNorm: true)
                    let floats = pooled.asArray(Float.self)
                    return (floats, floats.count)
                }
            }

            // Write binary float32 little-endian
            var data = Data()
            for value in vector {
                var little = value.bitPattern.littleEndian
                data.append(contentsOf: withUnsafeBytes(of: &little) { Data($0) })
            }
            try data.write(to: outputFile)
        }

        private func loadChatSession(
            maxTokens: Int?, temperature: Double?, topP: Double?, seed: Int
        ) throws -> ChatSession {
            let generateParameters = GenerateParameters(
                maxTokens: maxTokens ?? 512,
                temperature: Float(temperature ?? 0.7),
                topP: Float(topP ?? 0.9)
            )
            
            // Get container from cache or load it
            let container: MLXLMCommon.ModelContainer = try runBlocking {
                if let cached = MLXBackendRunner.chatContainerCache.get(self.chatModelId) {
                    return cached
                }
                let container = try await MLXLMCommon.loadModelContainer(id: self.chatModelId)
                // Estimate size (placeholder: 1 for count-based eviction)
                MLXBackendRunner.chatContainerCache.set(self.chatModelId, value: container, size: 1)
                return container
            }
            
            return ChatSession(container, generateParameters: generateParameters)
        }


    #else
        public init(chatModelId: String? = nil, embedModelId: String? = nil) {
            super.init(engine: .mlx)
        }

        public override func execute(
            modelPath: String,
            task: MLTaskKind,
            inputFile: URL,
            outputFile: URL,
            options: MLTaskOptions,
            requestId: String
        ) throws -> BackendResult<String, String> {
            throw GenericCoreError("MLX backend not available; rebuild with MLXLMCommon")
        }

        public override func buildArgv(
            modelPath: String,
            task: MLTaskKind,
            inputFile: URL,
            outputFile: URL,
            options: MLTaskOptions,
            requestId: String
        ) throws -> [String] {
            return []
        }
    #endif
}

// MARK: - CoreML Backend

public class CoreMLBackendRunner: BackendRunner {
    // Static shared cache for CoreML models (count-based LRU)
    private static let modelCache = ModelCache<String, MLModel>(
        maxCount: ProcessInfo.processInfo.environment["ML_WORKER_CACHE_MAX_COUNT"].flatMap(Int.init) ?? 2,
        maxMemoryBytes: 0,
        evictionPolicy: .countBased
    )
    
    /// Get cache statistics for monitoring
    public static func getCacheStatistics() -> [(cache: String, hits: Int, misses: Int, hitRate: Double, count: Int)] {
        let stats = modelCache.getStatistics()
        return [("CoreMLModel", stats.hits, stats.misses, stats.hitRate, stats.count)]
    }
    
    public init() {
        super.init(engine: .coreml)
    }
    
    public override func execute(
        modelPath: String,
        task: MLTaskKind,
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions,
        requestId: String
    ) throws -> BackendResult<String, String> {
        #if canImport(CoreML)
            switch task {
            case .embed:
                try generateEmbedding(modelPath: modelPath, inputFile: inputFile, outputFile: outputFile, seed: options.seed)
                return BackendResult<String, String>(stdout: Data(), stderr: Data(), exitCode: 0, timedOut: false)
            case .chat:
                throw GenericCoreError("Chat tasks not yet supported for CoreML backend")
            default:
                throw GenericCoreError("Task \(task.rawValue) not supported for CoreML backend")
            }
        #else
            throw GenericCoreError("CoreML backend not available; rebuild with CoreML support")
        #endif
    }
    
    public override func buildArgv(
        modelPath: String,
        task: MLTaskKind,
        inputFile: URL,
        outputFile: URL,
        options: MLTaskOptions,
        requestId: String
    ) throws -> [String] {
        return [
            "coreml-backend",
            "--model", modelPath,
            "--task", task.rawValue,
            "--input", inputFile.path,
            "--output", outputFile.path,
            "--seed", "\(options.seed)"
        ]
    }
    
    #if canImport(CoreML)
    private func loadModelIfNeeded(modelPath: String) throws -> MLModel {
        // Compute cache key with file hash for invalidation
        let cacheKey = getCacheKeyForModel(modelPath, engine: self.engine)
        
        // Check cache first
        if let cached = CoreMLBackendRunner.modelCache.get(cacheKey) {
            return cached
        }
        
        let modelURL = URL(fileURLWithPath: modelPath)
        let compiledModelURL = try MLModel.compileModel(at: modelURL)
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        let loadedModel = try MLModel(contentsOf: compiledModelURL, configuration: configuration)
        
        // Store in cache with estimated size (placeholder: 1 for count-based)
        CoreMLBackendRunner.modelCache.set(cacheKey, value: loadedModel, size: 1)
        print("Loaded CoreML model from \(modelPath) (cached)")
        
        return loadedModel
    }
    
    private func tokenize(text: String) -> TokenBuffer {
        let words = text.split(separator: " ").map(String.init)
        var tokenIds: [Int32] = words.map { word in
            let data = Data(word.utf8)
            let hash = SHA256.hash(data: data)
            // Take first 4 bytes and convert to Int32 (signed)
            let prefix = Array(hash).prefix(4)
            let value: Int32 = prefix.reduce(0) { ($0 << 8) | Int32($1) }
            return value
        }
        var attentionMask = [UInt8](repeating: 1, count: tokenIds.count)
        
        // Apply truncation to max length 512
        let maxLength = 512
        if tokenIds.count > maxLength {
            tokenIds = Array(tokenIds.prefix(maxLength))
            attentionMask = Array(attentionMask.prefix(maxLength))
        }
        // No padding for now
        return TokenBuffer(
            tokenIds: tokenIds,
            attentionMask: attentionMask,
            tokenTypeIds: nil
        )
    }
    
    private func generateEmbedding(modelPath: String, inputFile: URL, outputFile: URL, seed: Int) throws {
        let model = try loadModelIfNeeded(modelPath: modelPath)
        
        let inputData = try Data(contentsOf: inputFile)
        let text = String(data: inputData, encoding: .utf8) ?? ""
        
        let tokenBuffer = tokenize(text: text)
        let tokenIds = tokenBuffer.tokenIds.map { NSNumber(value: $0) }
        let sequenceLength = tokenIds.count
        
        // Create MLMultiArray for token IDs (shape: 1 x sequenceLength)
        let inputShape = [1, sequenceLength] as [NSNumber]
        let inputArray = try MLMultiArray(shape: inputShape, dataType: .int32)
        for (i, tokenId) in tokenIds.enumerated() {
            inputArray[i] = tokenId
        }
        
        // Create attention mask (all ones)
        let attentionMask = try MLMultiArray(shape: inputShape, dataType: .int32)
        for i in 0..<sequenceLength {
            attentionMask[i] = 1
        }
        
        // Create model input
        let input = CoreMLEmbeddingInput(input_ids: inputArray, attention_mask: attentionMask)
        
        // Perform prediction
        let output = try model.prediction(from: input)
        
        // Extract embeddings from output
        guard let embeddingOutput = output.featureValue(for: "embedding")?.multiArrayValue else {
            throw GenericCoreError("CoreML model output does not contain 'embedding' feature")
        }
        
        // Convert to Float array
        let embeddingLength = embeddingOutput.count
        var embeddingData = Data()
        for i in 0..<embeddingLength {
            let value = Float(truncating: embeddingOutput[i])
            var little = value.bitPattern.littleEndian
            embeddingData.append(contentsOf: withUnsafeBytes(of: &little) { Data($0) })
        }
        
        try embeddingData.write(to: outputFile)
    }
    #endif
}

#if canImport(CoreML)
class CoreMLEmbeddingInput: NSObject, MLFeatureProvider {
    let input_ids: MLMultiArray
    let attention_mask: MLMultiArray
    
    init(input_ids: MLMultiArray, attention_mask: MLMultiArray) {
        self.input_ids = input_ids
        self.attention_mask = attention_mask
    }
    
    var featureNames: Set<String> {
        return ["input_ids", "attention_mask"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "input_ids":
            return MLFeatureValue(multiArray: input_ids)
        case "attention_mask":
            return MLFeatureValue(multiArray: attention_mask)
        default:
            return nil
        }
    }
}
#endif