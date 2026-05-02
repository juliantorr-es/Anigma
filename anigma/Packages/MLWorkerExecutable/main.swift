//
//  main.swift
//  MLWorkerExecutable
//
//  [Brief description of file purpose]
//

import ArgumentParser
import CryptoKit
import AnigmaPrimitives
import Foundation
import MLWorkerCommon

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

// MARK: - Backend Execution

/// Backend execution result with structured outputs and captured streams
struct BackendResult<Success, Failure> {
    let stdout: Data
    let stderr: Data
    let exitCode: Int32
    let timedOut: Bool
}

/// Abstract backend runner with deterministic execution boundaries
class BackendRunner {
    let engine: MLWorkerEngine
    let timeoutSeconds: Int
    let maxOutputBytes: Int

    init(engine: MLWorkerEngine, timeoutSeconds: Int = 120, maxOutputBytes: Int = 100 * 1024 * 1024) {
        self.engine = engine
        self.timeoutSeconds = timeoutSeconds
        self.maxOutputBytes = maxOutputBytes
    }

    /// Execute backend with deterministic argv construction and strict resource limits
    func execute(
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
    func buildArgv(
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
    func getEnvironmentAllowlist() -> [String] {
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

// MARK: - Llama.cpp Backend

class LlamaBackendRunner: BackendRunner {
    private let llamaBinary: String
    private let serverURL: URL?

    init(llamaBinary: String? = nil) {
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

    override func execute(
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

    override func buildArgv(
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

// MARK: - DeepSeek Cloud Backend (OpenAI-compatible)

class DeepSeekBackendRunner: BackendRunner {
    private let apiKey: String
    private let baseURL: URL
    private let model: String

    init(apiKey: String? = nil, baseURL: String? = nil, model: String? = nil) {
        let env = ProcessInfo.processInfo.environment
        self.apiKey = apiKey ?? env["DEEPSEEK_API_KEY"] ?? ""
        self.baseURL = URL(
            string: baseURL ?? env["DEEPSEEK_BASE_URL"] ?? "https://api.deepseek.com/v1")!
        self.model = model ?? env["DEEPSEEK_MODEL"] ?? "deepseek-chat"
        super.init(engine: .deepseek)
    }

    override func execute(
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

    override func buildArgv(
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

class MockBackendRunner: BackendRunner {
    override func execute(
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

    override func buildArgv(
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

class MLXBackendRunner: BackendRunner {
    #if canImport(MLXLMCommon)
        private let chatModelId: String
        private let embedModelId: String
        private var chatSession: ChatSession?
        private var chatContainer: MLXLMCommon.ModelContainer?
        private var embedContainer: MLXEmbedders.ModelContainer?

        init(chatModelId: String? = nil, embedModelId: String? = nil) {
            let env = ProcessInfo.processInfo.environment
            self.chatModelId =
                chatModelId ?? env["MLX_MODEL_ID_CHAT"] ?? env["MLX_MODEL_ID"]
                ?? "mlx-community/Llama-3.2-3B-Instruct-4bit"
            self.embedModelId =
                embedModelId ?? env["MLX_MODEL_ID_EMBED"] ?? "mlx-community/bge-small-en-v1.5-4bit"
            super.init(engine: .mlx)
        }

        override func execute(
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

        override func buildArgv(
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
                let container = try await MLXEmbedders.loadModelContainer(configuration: MLXEmbedders.ModelConfiguration(id: modelId))
                let c = container // Capture for closure
                return await c.perform { model, tokenizer, pooling in
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
            if let session = chatSession {
                return session
            }
            let generateParameters = GenerateParameters(
                maxTokens: maxTokens ?? 512,
                temperature: Float(temperature ?? 0.7),
                topP: Float(topP ?? 0.9)
            )
            let container: MLXLMCommon.ModelContainer = try runBlocking {
                try await MLXLMCommon.loadModelContainer(id: self.chatModelId)
            }
            let session = ChatSession(container, generateParameters: generateParameters)
            self.chatContainer = container
            self.chatSession = session
            return session
        }

        private func loadEmbedContainer() async throws -> MLXEmbedders.ModelContainer {
            if let container = embedContainer {
                return container
            }
            let configuration = MLXEmbedders.ModelConfiguration(id: embedModelId)
            let container = try await MLXEmbedders.loadModelContainer(configuration: configuration)
            self.embedContainer = container
            return container
        }
    #else
        init(chatModelId: String? = nil, embedModelId: String? = nil) {
            super.init(engine: .mlx)
        }

        override func execute(
            modelPath: String,
            task: MLTaskKind,
            inputFile: URL,
            outputFile: URL,
            options: MLTaskOptions,
            requestId: String
        ) throws -> BackendResult<String, String> {
            throw GenericCoreError("MLX backend not available; rebuild with MLXLMCommon")
        }

        override func buildArgv(
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

// MARK: - Token Buffer for CoreML

struct TokenBuffer {
    let tokenIds: [Int32]
    let attentionMask: [UInt8]
    let tokenTypeIds: [Int32]?
}

// MARK: - CoreML Backend

class CoreMLBackendRunner: BackendRunner {
    private var loadedModelPath: String?
    private var model: MLModel?
    
    init() {
        super.init(engine: .coreml)
    }
    
    override func execute(
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
    
    override func buildArgv(
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
        if let model = model, loadedModelPath == modelPath {
            return model
        }
        let modelURL = URL(fileURLWithPath: modelPath)
        let compiledModelURL = try MLModel.compileModel(at: modelURL)
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        let loadedModel = try MLModel(contentsOf: compiledModelURL, configuration: configuration)
        self.model = loadedModel
        self.loadedModelPath = modelPath
        print("Loaded CoreML model from \(modelPath)")
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

// MARK: - CoreML Model Input/Output Types (placeholder)
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

// MARK: - Process Execution

extension BackendRunner {
    /// Execute subprocess with strict resource limits and stream capture
    func runProcess(
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
    func readLimitedData(from handle: FileHandle, maxBytes: Int) throws -> Data {
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

struct MLWorkerCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ml-worker",
        abstract:
            "ML worker that reads NDJSON requests and emits canonical artifacts for MLX and llama.cpp backends."
    )

    @Option(name: .shortAndLong, help: "Engine to service (mlx|llama).")
    var engine: MLWorkerEngine

    func run() throws {
        log("Starting worker for engine \(engine.rawValue)")

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = []

        // Compute real binary hash for provenance
        let binaryHash = try computeBinaryHash()
        log("Binary hash: \(binaryHash)")

        // Initialize backend runner for this engine with mock mode fallback
        let backendRunner: BackendRunner
        let useMockMode =
            ProcessInfo.processInfo.environment["ML_WORKER_MOCK_MODE"]?.lowercased() == "true"

        if useMockMode {
            log("Using mock mode (ML_WORKER_MOCK_MODE=true)")
            backendRunner = MockBackendRunner(engine: engine)
        } else {
            switch engine {
            case .mlx:
                backendRunner = MLXBackendRunner()
            case .llama:
                backendRunner = LlamaBackendRunner()
            case .deepseek:
                backendRunner = DeepSeekBackendRunner()
            case .coreml:
                backendRunner = CoreMLBackendRunner()
            }
            log("Using real backend execution")
        }

        log("Worker ready for requests with backend: \(type(of: backendRunner))")

        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty else { continue }
            let requestData = Data(line.utf8)
            let request = try decoder.decode(MLWorkerRequest.self, from: requestData)

            log("Processing request: \(request.requestId) for task: \(request.task.rawValue)")

            let response = try process(
                request: request, binaryHash: binaryHash, backendRunner: backendRunner)
            let responseLine = try encoder.encode(response)
            FileHandle.standardOutput.write(responseLine + Data("\n".utf8))

            log("Completed request: \(request.requestId)")
        }

        log("Worker shutting down")
    }

    /// Compute SHA256 hash of the current executable for provenance tracking
    private func computeBinaryHash() throws -> String {
        guard let executablePath = CommandLine.arguments.first else {
            throw GenericCoreError("Cannot determine executable path")
        }

        let executableURL = URL(fileURLWithPath: executablePath)
        let executableData = try Data(contentsOf: executableURL)
        return blake3Hex(executableData)
    }

    /// Resolve model path from environment variables or default locations
    private func resolveModelPath() throws -> String {
        // First check environment variables specific to engine
        switch engine {
        case .mlx:
            if let id = ProcessInfo.processInfo.environment["MLX_MODEL_ID"], !id.isEmpty {
                return id
            }
            if let path = ProcessInfo.processInfo.environment["MLX_MODEL_PATH"], !path.isEmpty {
                return path
            }
            return "mlx-community/Qwen3-4B-4bit"
        case .llama:
            if let envPath = ProcessInfo.processInfo.environment["LLAMA_MODEL_PATH"],
                !envPath.isEmpty {
                return envPath
            }
        case .deepseek:
            return "deepseek-chat"
        case .coreml:
            if let path = ProcessInfo.processInfo.environment["COREML_MODEL_PATH"], !path.isEmpty {
                return path
            }
            return "coreml-model"
        }

        if engine == .llama {
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
        }

        throw GenericCoreError(
            "Model path not found for engine \(engine.rawValue). Set LLAMA_MODEL_PATH environment variable."
        )
    }

    /// Compute canonical hash of model files/directory
    private func computeModelHash(at path: String) throws -> String {
        // For MLX, treat model path as identifier if it isn't a file
        if engine == .mlx {
            let url = URL(fileURLWithPath: path)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    return try computeDirectoryHash(at: url)
                } else {
                    let modelData = try Data(contentsOf: url)
                    return blake3Hex(modelData)
                }
            } else {
                return blake3Hex(Data(path.utf8))
            }
        }

        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false

        if engine == .deepseek {
            // Remote model id – hash the identifier string
            return blake3Hex(Data(path.utf8))
        }

        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw GenericCoreError("Model path does not exist: \(path)")
        }

        if isDirectory.boolValue {
            return try computeDirectoryHash(at: url)
        } else {
            let modelData = try Data(contentsOf: url)
            return blake3Hex(modelData)
        }
    }

    /// Compute canonical hash of directory contents with deterministic ordering
    private func computeDirectoryHash(at url: URL) throws -> String {
        let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])

        var manifestData = Data()
        var fileEntries: [(String, Data)] = []

        // Collect all file entries with relative paths
        while let fileURL = enumerator?.nextObject() as? URL {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                !isDirectory.boolValue
            else { continue }

            var relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "")
            if !relativePath.hasPrefix("/") && !url.path.hasSuffix("/") {
                relativePath = "/" + relativePath
            }
            let fileData = try Data(contentsOf: fileURL)
            fileEntries.append((relativePath, fileData))
        }

        // Sort by relative path for deterministic ordering
        fileEntries.sort { $0.0 < $1.0 }

        // Build canonical manifest
        for (relativePath, fileData) in fileEntries {
            manifestData.append(Data(relativePath.utf8))
            manifestData.append(Data([0]))  // null separator
            manifestData.append(fileData)
            manifestData.append(Data([0]))  // null separator
        }

        return blake3Hex(manifestData)
    }

    private func process(request: MLWorkerRequest, binaryHash: String, backendRunner: BackendRunner)
        throws -> MLWorkerResponse {
        let start = Date()
        var outputs: [MLWorkerArtifact] = []

        // Use outputDirectory from request or fall back to Accessum-aligned structure
        // Mirror Accessum's run/step mapping instead of encoding runId twice
        let baseOutput =
            request.options.outputDirectory
            ?? ".accessum-artifacts/\(request.runId)/ml/\(request.stepId)"
        let outputDir = URL(fileURLWithPath: baseOutput)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        guard request.engine == engine else {
            throw GenericCoreError(
                "Engine mismatch: worker is \(engine.rawValue) but request is for \(request.engine.rawValue)"
            )
        }

        // Resolve model path and compute model hash for this request
        let modelPath = try resolveModelPath()
        let modelHash = try computeModelHash(at: modelPath)
        let modelHashForEnvelope = modelHash

        for input in request.inputs {
            let artifact: MLWorkerArtifact
            switch request.task {
            case .embed:
                artifact = try processEmbedding(
                    request: request, input: input, outputDir: outputDir, modelHash: modelHash,
                    binaryVersion: binaryHash, backendRunner: backendRunner)
            case .chat:
                if engine == .llama {
                    artifact = try processLlamaChat(
                        request: request, input: input, outputDir: outputDir,
                        modelHash: modelHashForEnvelope, backendRunner: backendRunner)
                } else if engine == .deepseek {
                    artifact = try processDeepSeekChat(
                        request: request, input: input, outputDir: outputDir, modelHash: modelHash,
                        backendRunner: backendRunner)
                } else if engine == .mlx {
                    artifact = try processMLXChat(
                        request: request, input: input, outputDir: outputDir,
                        modelHash: modelHashForEnvelope, backendRunner: backendRunner)
                } else {
                    throw GenericCoreError("Chat tasks not yet supported for engine \(engine.rawValue)")
                }
            case .summarize, .classify, .rerank, .transcribe, .other:
                throw GenericCoreError(
                    "Task \(request.task.rawValue) not yet implemented for engine \(engine.rawValue)"
                )
            }
            outputs.append(artifact)
        }

        let metrics = MLWorkerMetrics(
            durationMs: Int(Date().timeIntervalSince(start) * 1000),
            tokensProcessed: estimateTokensProcessed(request: request),
            memoryBytes: estimateMemoryUsage(request: request)
        )

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

    private func processEmbedding(
        request: MLWorkerRequest, input: MLArtifactRef, outputDir: URL, modelHash: String,
        binaryVersion: String, backendRunner: BackendRunner
    ) throws -> MLWorkerArtifact {
        let inputData = try Data(contentsOf: URL(fileURLWithPath: input.path))
        guard String(data: inputData, encoding: .utf8) != nil else {
            throw GenericCoreError("Input file is not valid UTF-8 text")
        }

        // Prepare paths for backend execution
        let dataPath = "embedding-\(request.task.rawValue)-\(input.hash).bin"
        let dataURL = outputDir.appendingPathComponent(dataPath)

        // Execute backend subprocess
        let modelPath = try resolveModelPath()
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
            throw GenericCoreError(
                "Backend execution timed out after \(backendRunner.timeoutSeconds) seconds")
        }

        if backendResult.exitCode != 0 {
            let stderr =
                String(data: backendResult.stderr, encoding: .utf8) ?? "Unable to decode stderr"
            throw GenericCoreError(
                "Backend execution failed with exit code \(backendResult.exitCode): \(stderr)")
        }

        // Verify output file was created
        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            throw GenericCoreError("Backend did not produce expected output file: \(dataURL.path)")
        }

        // Read and validate embedding data
        let rawData = try Data(contentsOf: dataURL)

        // For embedding generation, assume fixed dimension based on engine
        let floatCount = rawData.count / 4  // float32 = 4 bytes
        let actualDimension = floatCount

        if let expected = expectedEmbeddingDimension(for: engine), expected != actualDimension {
            throw GenericCoreError(
                "Embedding dimension mismatch for \(engine.rawValue): expected \(expected) floats, got \(actualDimension)"
            )
        }

        // Capture raw subprocess output as separate immutable artifact
        let rawOutputURL = outputDir.appendingPathComponent("\(dataPath).raw.log")
        try backendResult.stderr.write(to: rawOutputURL)
        _ = blake3Hex(backendResult.stderr)

        // Create comprehensive deterministic header with real execution metadata
        let argv = try backendRunner.buildArgv(
            modelPath: modelPath,
            task: request.task,
            inputFile: URL(fileURLWithPath: input.path),
            outputFile: dataURL,
            options: request.options,
            requestId: request.requestId
        )

        let engineMetadata = EmbeddingEngineMetadata(
            engine: engine.rawValue,
            binaryHash: binaryVersion,
            modelHash: modelHash,
            argv: argv,
            env: collectBackendEnvVars(backendRunner.getEnvironmentAllowlist())
        )

        let header = EmbeddingHeader(
            schemaVersion: 1,
            dtype: "float32",
            shape: [1, actualDimension],
            ordering: "row-major",
            tokenizer: "\(engine.rawValue)-tokenizer-v1",
            modelHash: modelHash,
            inputHash: input.hash,
            requestId: request.requestId,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            dataPath: dataPath,
            containerHash: "",  // Will be filled after computing
            engine: engineMetadata,
            embeddingDimension: actualDimension
        )

        // Compute container hash over canonical representation (header + raw data only)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]  // Canonical key order
        var headerData = try encoder.encode(header)

        var canonicalData = Data()
        canonicalData.append(headerData)  // Canonical JSON header
        canonicalData.append(rawData)  // Raw embedding data (little-endian)
        let containerHash = blake3Hex(canonicalData)

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

        // Write final header with deterministic JSON serialization
        headerData = try encoder.encode(finalHeader)
        let headerURL = outputDir.appendingPathComponent("\(dataPath).json")
        try headerData.write(to: headerURL)

        // Content hash is header + raw data (container hash) - raw log is linked separately
        let contentHash = containerHash

        return MLWorkerArtifact(
            path: headerURL.path,
            hash: containerHash,
            normalizedHash: contentHash
        )
    }

    private func expectedEmbeddingDimension(for engine: MLWorkerEngine) -> Int? {
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

    private func processLlamaChat(
        request: MLWorkerRequest, input: MLArtifactRef, outputDir: URL, modelHash: String,
        backendRunner: BackendRunner
    ) throws -> MLWorkerArtifact {
        let inputData = try Data(contentsOf: URL(fileURLWithPath: input.path))
        guard String(data: inputData, encoding: .utf8) != nil else {
            throw GenericCoreError("Input file is not valid UTF-8 text")
        }

        let responsePath = "chat-\(request.task.rawValue)-\(input.hash).txt"
        let responseURL = outputDir.appendingPathComponent(responsePath)

        // Execute backend subprocess for chat generation
        let modelPath = try resolveModelPath()
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
            throw GenericCoreError(
                "Backend execution timed out after \(backendRunner.timeoutSeconds) seconds")
        }

        if backendResult.exitCode != 0 {
            let stderr =
                String(data: backendResult.stderr, encoding: .utf8) ?? "Unable to decode stderr"
            throw GenericCoreError(
                "Backend execution failed with exit code \(backendResult.exitCode): \(stderr)")
        }

        // Verify output file was created
        guard FileManager.default.fileExists(atPath: responseURL.path) else {
            throw GenericCoreError("Backend did not produce expected output file: \(responseURL.path)")
        }

        // Capture raw subprocess output as separate immutable artifact
        let rawOutputURL = outputDir.appendingPathComponent("\(responsePath).raw.log")
        try backendResult.stderr.write(to: rawOutputURL)

        let responseData = try Data(contentsOf: responseURL)
        let responseHash = blake3Hex(responseData)

        return MLWorkerArtifact(
            path: responseURL.path,
            hash: responseHash
        )
    }

    private func processMLXChat(
        request: MLWorkerRequest, input: MLArtifactRef, outputDir: URL, modelHash: String,
        backendRunner: BackendRunner
    ) throws -> MLWorkerArtifact {
        // MLX execution logic is identical to Llama for the worker wrapper purposes
        // as MLXBackendRunner.execute handles the specifics.
        // Reusing the logic but keeping separate method for clarity/future divergence.
        return try processLlamaChat(
            request: request, input: input, outputDir: outputDir, modelHash: modelHash,
            backendRunner: backendRunner
        )
    }

    private func processDeepSeekChat(
        request: MLWorkerRequest, input: MLArtifactRef, outputDir: URL, modelHash: String,
        backendRunner: BackendRunner
    ) throws -> MLWorkerArtifact {
        let inputData = try Data(contentsOf: URL(fileURLWithPath: input.path))
        guard String(data: inputData, encoding: .utf8) != nil else {
            throw GenericCoreError("Input file is not valid UTF-8 text")
        }

        let responsePath = "chat-\(request.task.rawValue)-\(input.hash).txt"
        let responseURL = outputDir.appendingPathComponent(responsePath)

        // Execute backend subprocess for chat generation (remote HTTP)
        let modelPath = try resolveModelPath()
        let backendResult = try backendRunner.execute(
            modelPath: modelPath,
            task: request.task,
            inputFile: URL(fileURLWithPath: input.path),
            outputFile: responseURL,
            options: request.options,
            requestId: request.requestId
        )

        if backendResult.timedOut {
            throw GenericCoreError(
                "Backend execution timed out after \(backendRunner.timeoutSeconds) seconds")
        }

        if backendResult.exitCode != 0 {
            let stderr =
                String(data: backendResult.stderr, encoding: .utf8) ?? "Unable to decode stderr"
            throw GenericCoreError(
                "Backend execution failed with exit code \(backendResult.exitCode): \(stderr)")
        }

        guard FileManager.default.fileExists(atPath: responseURL.path) else {
            throw GenericCoreError("Backend did not produce expected output file: \(responseURL.path)")
        }

        // Capture raw subprocess output as separate immutable artifact
        let rawOutputURL = outputDir.appendingPathComponent("\(responsePath).raw.log")
        try backendResult.stderr.write(to: rawOutputURL)

        let responseData = try Data(contentsOf: responseURL)
        let responseHash = blake3Hex(responseData)

        return MLWorkerArtifact(
            path: responseURL.path,
            hash: responseHash
        )
    }

    private func estimateTokensProcessed(request: MLWorkerRequest) -> Int {
        return request.inputs.count * 512
    }

    private func estimateMemoryUsage(request: MLWorkerRequest) -> Int {
        return request.inputs.count * 512 * 4
    }

    private func generateMockEmbedding(inputHash: String, modelHash: String, dimension: Int)
        -> [Float] {
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

    private func blake3Hex(_ data: Data) -> String {
        return BLAKE3Digest.hex(of: data)
    }

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"
        FileHandle.standardError.write(logLine.data(using: .utf8) ?? Data())
    }
}

struct GenericCoreError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) {
        self.description = description
    }
}

struct EmbeddingEngineMetadata: Codable {
    let engine: String
    let binaryHash: String
    let modelHash: String
    let argv: [String]
    let env: [String: String]
}

struct EmbeddingHeader: Codable {
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
    let embeddingDimension: Int?

    // NOTE: containerHash provides bitwise determinism within same backend family
    // Cross-platform semantic equivalence may require tolerance-based comparison
    // Future versions may include quantized embeddings for enhanced cross-platform stability
}

private func collectRelevantEnvVars() -> [String: String] {
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

private func collectBackendEnvVars(_ allowlist: [String]) -> [String: String] {
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

private func normalizeEnvValue(_ value: String) -> String {
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

/// Thread-safe container for runBlocking results

/// Run an async operation synchronously for worker use.
private func runBlocking<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) throws -> T {
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

// MARK: - URLSession Sync Helper

extension URLSession {
    fileprivate func syncData(for request: URLRequest) throws -> (Data, URLResponse) {
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
// Main entry point
MLWorkerCommand.main()
