//
//  MLWorker.swift
//  MLWorkerCommon
//
//  Direct in-process ML worker API for daemon integration.
//  Eliminates need for separate ml-worker executable process.
//

import Foundation
import CryptoKit
import ContractsCore

#if canImport(MLXLMCommon)
    import MLX
    import MLXEmbedders
    @preconcurrency import MLXLMCommon
#endif

#if canImport(CoreML)
    import CoreML
#endif

/// Direct in-process ML worker for daemon integration.
/// Executes ML tasks using backend runners without spawning separate processes.
public class MLWorker {
    private let engine: MLWorkerEngine
    private let backendRunner: BackendRunner
    private let mockMode: Bool
    private let metricsCollector: MLWorkerMetricsCollector?
    
    /// Initialize ML worker for specified engine.
    /// - Parameters:
    ///   - engine: ML engine to use (llama, mlx, deepseek, coreml). If nil, auto-detects available engine.
    ///   - mockMode: If true, uses MockBackendRunner regardless of engine availability
    ///   - enableMetrics: If true, collects performance metrics for operations
    public init(engine: MLWorkerEngine? = nil, mockMode: Bool = false, enableMetrics: Bool = true) {
        self.mockMode = mockMode
        
        // Determine which engine to use
        let resolvedEngine: MLWorkerEngine
        if let engine = engine {
            resolvedEngine = engine
        } else {
            resolvedEngine = MLEngineDetector.detectAvailableEngine(preference: .performance)
        }
        self.engine = resolvedEngine
        
        if mockMode {
            self.backendRunner = MockBackendRunner(engine: resolvedEngine)
        } else {
            switch resolvedEngine {
            case .mlx:
                self.backendRunner = MLXBackendRunner()
            case .llama:
                self.backendRunner = LlamaBackendRunner()
            case .deepseek:
                self.backendRunner = DeepSeekBackendRunner()
            case .coreml:
                self.backendRunner = CoreMLBackendRunner()
            }
        }
        
        self.metricsCollector = enableMetrics ? MLWorkerMetricsCollector() : nil
    }
    
    /// Perform ML task synchronously (in-process).
    /// - Parameter request: ML worker request
    /// - Returns: ML worker response
    public func performTask(_ request: MLWorkerRequest) throws -> MLWorkerResponse {
        let start = Date()
        let operationId = "\(request.requestId)-\(UUID().uuidString)"
        
        // Start metrics collection
        metricsCollector?.startOperation(
            operationId: operationId,
            engine: engine,
            task: request.task
        )
        
        // Validate engine matches worker configuration
        guard request.engine == engine else {
            metricsCollector?.endOperation(operationId: operationId, success: false)
            throw RuntimeError(
                "Engine mismatch: worker is configured for \(engine.rawValue) but request is for \(request.engine.rawValue)"
            )
        }
        
        // Use outputDirectory from request or create temporary directory
        let baseOutput = request.options.outputDirectory ?? createTemporaryDirectory().path
        let outputDir = URL(fileURLWithPath: baseOutput)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        var outputs: [MLWorkerArtifact] = []
        var processingError: Error?
        
        do {
            for input in request.inputs {
                let artifact: MLWorkerArtifact
                switch request.task {
                case .embed:
                    artifact = try processEmbedding(
                        request: request, input: input, outputDir: outputDir
                    )
                case .chat:
                    artifact = try processChat(
                        request: request, input: input, outputDir: outputDir
                    )
                case .summarize, .classify, .rerank, .transcribe, .other:
                    throw RuntimeError(
                        "Task \(request.task.rawValue) not yet implemented for in-process ML worker"
                    )
                }
                outputs.append(artifact)
            }
        } catch {
            processingError = error
        }
        
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        let estimatedTokens = estimateTokensProcessed(request: request)
        let estimatedMemory = estimateMemoryUsage(request: request)
        
        // End metrics collection
        metricsCollector?.endOperation(
            operationId: operationId,
            success: processingError == nil,
            tokensProcessed: estimatedTokens,
            tokensGenerated: nil,
            memoryUsed: estimatedMemory
        )
        
        // Propagate any error that occurred during processing
        if let error = processingError {
            throw error
        }
        
        let metrics = MLWorkerMetrics(
            durationMs: durationMs,
            tokensProcessed: estimatedTokens,
            memoryBytes: estimatedMemory
        )
        
        // Compute binary hash for provenance (hash of this executable's code)
        let binaryHash = try computeBinaryHash()
        let modelPath = resolveModelPath(for: engine)
        let modelHash = (try? computeFileHash(at: URL(fileURLWithPath: modelPath))) ?? "sha256:unknown"
        
        let engineMeta = MLWorkerEngineMetadata(
            binaryHash: binaryHash,
            version: "1.0",
            modelId: "\(engine.rawValue)-model",
            modelHash: modelHash,
            binaryVersion: binaryHash
        )
        
        return MLWorkerResponse(
            requestId: request.requestId,
            status: .completed,
            outputs: outputs,
            metrics: metrics,
            engineMeta: engineMeta
        )
    }
    
    /// Perform ML task asynchronously.
    /// - Parameter request: ML worker request
    /// - Returns: ML worker response
    public func performTaskAsync(_ request: MLWorkerRequest) async throws -> MLWorkerResponse {
        // For now, just call synchronous version
        // In future, could run in background thread
        return try performTask(request)
    }
    
    // MARK: - Private Methods
    
    private func createTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("ml-worker-\(UUID().uuidString)")
    }
    
    private func processEmbedding(
        request: MLWorkerRequest,
        input: MLArtifactRef,
        outputDir: URL
    ) throws -> MLWorkerArtifact {
        let inputData = try Data(contentsOf: URL(fileURLWithPath: input.path))
        guard String(data: inputData, encoding: .utf8) != nil else {
            throw RuntimeError("Input file is not valid UTF-8 text")
        }
        
        // Prepare output path
        let dataPath = "embedding-\(request.task.rawValue)-\(input.hash).bin"
        let dataURL = outputDir.appendingPathComponent(dataPath)
        
        // Determine model path from environment or request
        let modelPath = resolveModelPath(for: engine)
        
        // Execute backend in-process
        let backendResult = try backendRunner.execute(
            modelPath: modelPath,
            task: request.task,
            inputFile: URL(fileURLWithPath: input.path),
            outputFile: dataURL,
            options: request.options,
            requestId: request.requestId
        )
        
        // Validate backend execution
        if backendResult.timedOut {
            throw RuntimeError(
                "Backend execution timed out after \(backendRunner.timeoutSeconds) seconds"
            )
        }
        
        if backendResult.exitCode != 0 {
            let stderr = String(data: backendResult.stderr, encoding: .utf8) ?? "Unable to decode stderr"
            throw RuntimeError(
                "Backend execution failed with exit code \(backendResult.exitCode): \(stderr)"
            )
        }
        
        // Verify output file was created
        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            throw RuntimeError("Backend did not produce expected output file: \(dataURL.path)")
        }
        
        // Read and validate embedding data
        let rawData = try Data(contentsOf: dataURL)
        let floatCount = rawData.count / 4  // float32 = 4 bytes
        
        if let expected = expectedEmbeddingDimension(for: engine), expected != floatCount {
            throw RuntimeError(
                "Embedding dimension mismatch for \(engine.rawValue): expected \(expected) floats, got \(floatCount)"
            )
        }
        
        // Capture raw backend output as separate artifact
        let rawOutputURL = outputDir.appendingPathComponent("\(dataPath).raw.log")
        try backendResult.stderr.write(to: rawOutputURL)
        
        // Create header with execution metadata
        let argv = try backendRunner.buildArgv(
            modelPath: modelPath,
            task: request.task,
            inputFile: URL(fileURLWithPath: input.path),
            outputFile: dataURL,
            options: request.options,
            requestId: request.requestId
        )
        
        let modelHash = (try? computeFileHash(at: URL(fileURLWithPath: modelPath))) ?? "sha256:unknown"
        
        let engineMetadata = EmbeddingEngineMetadata(
            engine: engine.rawValue,
            binaryHash: try computeBinaryHash(),
            modelHash: modelHash,
            argv: argv,
            env: collectBackendEnvVars(backendRunner.getEnvironmentAllowlist())
        )
        
        let header = EmbeddingHeader(
            schemaVersion: 1,
            dtype: "float32",
            shape: [1, floatCount],
            ordering: "row-major",
            tokenizer: "\(engine.rawValue)-tokenizer-v1",
            modelHash: modelHash,
            inputHash: input.hash,
            requestId: request.requestId,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            dataPath: dataPath,
            containerHash: "",  // Will be filled after computing
            engine: engineMetadata,
            embeddingDimension: floatCount
        )
        
        // Compute container hash over canonical representation
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var headerData = try encoder.encode(header)
        
        var canonicalData = Data()
        canonicalData.append(headerData)
        canonicalData.append(rawData)
        let containerHash = sha256Hex(canonicalData)
        
        // Update header with computed container hash
        let finalHeader = EmbeddingHeader(
            schemaVersion: header.schemaVersion,
            dtype: header.dtype,
            shape: header.shape,
            ordering: header.ordering,
            tokenizer: header.tokenizer,
            modelHash: header.modelHash,
            inputHash: header.inputHash,
            requestId: header.requestId,
            timestamp: header.timestamp,
            dataPath: header.dataPath,
            containerHash: containerHash,
            engine: header.engine,
            embeddingDimension: header.embeddingDimension
        )
        
        // Write final header
        headerData = try encoder.encode(finalHeader)
        let headerURL = outputDir.appendingPathComponent("\(dataPath).json")
        try headerData.write(to: headerURL)
        
        // Content hash is header + raw data (container hash)
        let contentHash = containerHash
        
        return MLWorkerArtifact(
            path: headerURL.path,
            hash: containerHash,
            normalizedHash: contentHash
        )
    }
    
    private func processChat(
        request: MLWorkerRequest,
        input: MLArtifactRef,
        outputDir: URL
    ) throws -> MLWorkerArtifact {
        let inputData = try Data(contentsOf: URL(fileURLWithPath: input.path))
        guard String(data: inputData, encoding: .utf8) != nil else {
            throw RuntimeError("Input file is not valid UTF-8 text")
        }
        
        let responsePath = "chat-\(request.task.rawValue)-\(input.hash).txt"
        let responseURL = outputDir.appendingPathComponent(responsePath)
        
        // Determine model path from environment or request
        let modelPath = resolveModelPath(for: engine)
        
        // Execute backend in-process
        let backendResult = try backendRunner.execute(
            modelPath: modelPath,
            task: request.task,
            inputFile: URL(fileURLWithPath: input.path),
            outputFile: responseURL,
            options: request.options,
            requestId: request.requestId
        )
        
        // Validate backend execution
        if backendResult.timedOut {
            throw RuntimeError(
                "Backend execution timed out after \(backendRunner.timeoutSeconds) seconds"
            )
        }
        
        if backendResult.exitCode != 0 {
            let stderr = String(data: backendResult.stderr, encoding: .utf8) ?? "Unable to decode stderr"
            throw RuntimeError(
                "Backend execution failed with exit code \(backendResult.exitCode): \(stderr)"
            )
        }
        
        // Verify output file was created
        guard FileManager.default.fileExists(atPath: responseURL.path) else {
            throw RuntimeError("Backend did not produce expected output file: \(responseURL.path)")
        }
        
        // Capture raw backend output
        let rawOutputURL = outputDir.appendingPathComponent("\(responsePath).raw.log")
        try backendResult.stderr.write(to: rawOutputURL)
        
        // Compute hash of response
        let responseData = try Data(contentsOf: responseURL)
        let responseHash = sha256Hex(responseData)
        
        return MLWorkerArtifact(
            path: responseURL.path,
            hash: responseHash
        )
    }
    
    private func resolveModelPath(for engine: MLWorkerEngine) -> String {
        let env = ProcessInfo.processInfo.environment
        
        switch engine {
        case .mlx:
            if let id = env["MLX_MODEL_ID"], !id.isEmpty {
                return id
            }
            if let path = env["MLX_MODEL_PATH"], !path.isEmpty {
                return path
            }
            return "mlx-community/Qwen3-4B-4bit"
        case .llama:
            if let envPath = env["LLAMA_MODEL_PATH"], !envPath.isEmpty {
                return envPath
            }
            // Check default locations
            let defaults = [
                "./models/\(engine.rawValue)/",
                "./models/",
                "/usr/local/share/\(engine.rawValue)/models/"
            ]
            
            for defaultPath in defaults {
                let url = URL(fileURLWithPath: defaultPath)
                if FileManager.default.fileExists(atPath: url.path) {
                    return url.path
                }
            }
            return "./models/llama/"
        case .deepseek:
            return "deepseek-chat"
        case .coreml:
            if let path = env["COREML_MODEL_PATH"], !path.isEmpty {
                return path
            }
            return "coreml-model"
        }
    }
    
    private func computeBinaryHash() throws -> String {
        // For in-process execution, compute hash of this module's code
        // For simplicity, use a constant for now
        return "in-process-ml-worker-v1"
    }
    
    private func estimateTokensProcessed(request: MLWorkerRequest) -> Int {
        return request.inputs.count * 512
    }
    
    private func estimateMemoryUsage(request: MLWorkerRequest) -> Int {
        return request.inputs.count * 512 * 4
    }

    private func computeFileHash(at url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else { return "sha256:missing" }
        
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            var hashes: [String] = []
            while let fileURL = enumerator?.nextObject() as? URL {
                if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]), values.isRegularFile == true {
                    if let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) {
                        hashes.append(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
                    }
                }
            }
            let combined = hashes.sorted().joined().data(using: .utf8)!
            return SHA256.hash(data: combined).map { String(format: "%02x", $0) }.joined()
        } else {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
    }
}

// MARK: - Engine Detection

private enum MLEngineDetector {
    enum DetectionPreference {
        case performance
        case accuracy
        case efficiency
        case compatibility
    }
    
    static func detectAvailableEngine(preference: DetectionPreference = .performance) -> MLWorkerEngine {
        // Check environment variable for forced engine
        if let forcedEngine = ProcessInfo.processInfo.environment["ML_WORKER_ENGINE"],
           let engine = MLWorkerEngine(rawValue: forcedEngine) {
            return engine
        }
        
        // Check for MLX availability (requires MLXLMCommon)
        #if canImport(MLXLMCommon)
        if ProcessInfo.processInfo.environment["MLX_MODEL_ID"] != nil ||
           ProcessInfo.processInfo.environment["MLX_MODEL_PATH"] != nil {
            return .mlx
        }
        #endif
        
        // Check for llama.cpp availability
        let llamaBinary = ProcessInfo.processInfo.environment["LLAMA_BACKEND_BINARY"] ?? "llama-cli"
        if FileManager.default.fileExists(atPath: llamaBinary) ||
           ProcessInfo.processInfo.environment["LLAMA_SERVER_URL"] != nil {
            return .llama
        }
        
        // Check for DeepSeek API key
        if ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] != nil {
            return .deepseek
        }
        
        // Check for CoreML availability
        #if canImport(CoreML)
        if ProcessInfo.processInfo.environment["COREML_MODEL_PATH"] != nil {
            return .coreml
        }
        #endif
        
        // Default to mock/llama
        return .llama
    }
    
    static func getAvailableEngines() -> [MLWorkerEngine] {
        var available: [MLWorkerEngine] = []
        
        #if canImport(MLXLMCommon)
        available.append(.mlx)
        #endif
        
        let llamaBinary = ProcessInfo.processInfo.environment["LLAMA_BACKEND_BINARY"] ?? "llama-cli"
        if FileManager.default.fileExists(atPath: llamaBinary) ||
           ProcessInfo.processInfo.environment["LLAMA_SERVER_URL"] != nil {
            available.append(.llama)
        }
        
        if ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] != nil {
            available.append(.deepseek)
        }
        
        #if canImport(CoreML)
        if ProcessInfo.processInfo.environment["COREML_MODEL_PATH"] != nil {
            available.append(.coreml)
        }
        #endif
        
        return available.isEmpty ? [.llama] : available
    }
}

// MARK: - Metrics Collection

private class MLWorkerMetricsCollector {
    private var operationMetrics: [String: OperationMetrics] = [:]
    private let lock = NSLock()
    private var operationCount = 0
    
    struct OperationMetrics {
        let operationId: String
        let engine: MLWorkerEngine
        let task: MLTaskKind
        var startTime: Date?
        var endTime: Date?
        var tokensProcessed: Int?
        var tokensGenerated: Int?
        var memoryUsed: Int?
        var success: Bool?
        
        var duration: TimeInterval? {
            guard let start = startTime, let end = endTime else { return nil }
            return end.timeIntervalSince(start)
        }
    }
    
    func startOperation(operationId: String, engine: MLWorkerEngine, task: MLTaskKind) {
        lock.lock()
        defer { lock.unlock() }
        
        operationMetrics[operationId] = OperationMetrics(
            operationId: operationId,
            engine: engine,
            task: task,
            startTime: Date()
        )
    }
    
    func endOperation(operationId: String, success: Bool, tokensProcessed: Int? = nil, tokensGenerated: Int? = nil, memoryUsed: Int? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        guard var metrics = operationMetrics[operationId] else { return }
        metrics.endTime = Date()
        metrics.success = success
        metrics.tokensProcessed = tokensProcessed
        metrics.tokensGenerated = tokensGenerated
        metrics.memoryUsed = memoryUsed
        operationMetrics[operationId] = metrics
        
        // Log or report metrics
        logMetrics(metrics)
        
        operationCount += 1
        if operationCount % 10 == 0 {
            logCacheStatistics()
        }
    }
    
    private func logMetrics(_ metrics: OperationMetrics) {
        let durationStr = metrics.duration.map { String(format: "%.2fms", $0 * 1000) } ?? "N/A"
        print("[MLWorkerMetrics] \(metrics.engine.rawValue).\(metrics.task.rawValue): \(durationStr), success: \(metrics.success ?? false)")
    }
    
    func logCacheStatistics() {
        // Collect cache stats from all backend runners
        var allStats: [String] = []
        
        #if canImport(MLXLMCommon)
        let mlxStats = MLXBackendRunner.getCacheStatistics()
        for stat in mlxStats {
            allStats.append("[Cache] \(stat.cache): hits=\(stat.hits), misses=\(stat.misses), hitRate=\(String(format: "%.2f", stat.hitRate)), count=\(stat.count)")
        }
        #endif
        
        #if canImport(CoreML)
        let coremlStats = CoreMLBackendRunner.getCacheStatistics()
        for stat in coremlStats {
            allStats.append("[Cache] \(stat.cache): hits=\(stat.hits), misses=\(stat.misses), hitRate=\(String(format: "%.2f", stat.hitRate)), count=\(stat.count)")
        }
        #endif
        
        if !allStats.isEmpty {
            print(allStats.joined(separator: "\n"))
        }
    }
    
    func getMetricsSummary() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        
        var summary: [String: Any] = [:]
        var engineStats: [String: [String: Any]] = [:]
        
        for metrics in operationMetrics.values {
            let engineKey = metrics.engine.rawValue
            var engineStat = engineStats[engineKey] ?? ["count": 0, "totalDuration": 0.0, "successCount": 0]
            engineStat["count"] = (engineStat["count"] as? Int ?? 0) + 1
            if let duration = metrics.duration {
                engineStat["totalDuration"] = (engineStat["totalDuration"] as? Double ?? 0.0) + duration
            }
            if metrics.success == true {
                engineStat["successCount"] = (engineStat["successCount"] as? Int ?? 0) + 1
            }
            engineStats[engineKey] = engineStat
        }
        
        summary["engines"] = engineStats
        summary["totalOperations"] = operationMetrics.count
        return summary
    }
}

// MARK: - Embedding Types for Internal Use

private struct EmbeddingEngineMetadata: Codable {
    let engine: String
    let binaryHash: String
    let modelHash: String
    let argv: [String]
    let env: [String: String]
}

private struct EmbeddingHeader: Codable {
    let schemaVersion: Int
    let dtype: String
    let shape: [Int]
    let ordering: String
    let tokenizer: String
    let modelHash: String
    let inputHash: String
    let requestId: String
    let timestamp: String
    let dataPath: String
    let containerHash: String
    let engine: EmbeddingEngineMetadata
    let embeddingDimension: Int
}

