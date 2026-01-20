//
//  CLIMLIntegration.swift
//  AnigmaCLIML
//
//  ML inference and embedding integration for anigma-cli.
//  Bridges local MLWorker with database indexing and provider APIs.
//

import Foundation
import ContractsCore
import Crypto
import AnigmaCLICore
import AnigmaCLIDatabase
import AnigmaCLIProviders

/// ML integration for CLI with local-first inference and cloud fallback.
public actor CLIMLIntegration {
    private let db: CLIDatabaseActor
    private let indexManager: CLIIndexManager
    private let retrieval: CLIHybridRetrieval
    private let providerRegistry: ProviderRegistry

    private var localMLWorkerPath: String?
    private var preferredEmbeddingModel: String?
    private var preferredChatModel: String?

    // MLX providers for local inference
    private let mlxEmbedder: MLXEmbeddingProvider
    private let mlxChat: MLXChatProvider

    public init(
        database: CLIDatabaseActor,
        indexManager: CLIIndexManager,
        retrieval: CLIHybridRetrieval,
        providerRegistry: ProviderRegistry
    ) {
        self.db = database
        self.indexManager = indexManager
        self.retrieval = retrieval
        self.providerRegistry = providerRegistry
        self.mlxEmbedder = MLXEmbeddingProvider()
        self.mlxChat = MLXChatProvider()
    }

    // MARK: - Configuration

    public func configure(
        mlWorkerPath: String?,
        embeddingModel: String?,
        chatModel: String?
    ) {
        self.localMLWorkerPath = mlWorkerPath
        self.preferredEmbeddingModel = embeddingModel
        self.preferredChatModel = chatModel
    }

    // MARK: - Embedding Generation

    /// Generate embeddings for text using local model or cloud fallback.
    public func generateEmbedding(
        text: String,
        modelID: String? = nil
    ) async throws -> [Float] {
        let model = modelID ?? preferredEmbeddingModel ?? "all-minilm-l6-v2"

        #if canImport(AnigmaCLIML)
        // Try local MLX first
        do {
            // Load model if not already loaded
            let currentInfo = await mlxEmbedder.getModelInfo()
            if currentInfo?.modelID != model {
                try await mlxEmbedder.loadModel(modelID: model)
            }

            return try await mlxEmbedder.embed(text: text)
        } catch {
            logWarning("Local MLX embedding failed: \(error), falling back to cloud")
            // Fallback to cloud provider
            return try await generateCloudEmbedding(text: text, modelID: model)
        }
        #else
        // No local support, use cloud
        return try await generateCloudEmbedding(text: text, modelID: model)
        #endif
    }

    private func generateLocalEmbedding(
        text: String,
        modelID: String,
        mlPath: String
    ) async throws -> [Float] {
        let tempInput = try writeTempInput(text)
        defer { try? FileManager.default.removeItem(at: tempInput) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("anigma-cli-embed-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let request = MLWorkerRequest(
            requestId: UUID().uuidString,
            runId: "cli-embed",
            stepId: "embed",
            engine: .mlx,
            task: .embed,
            inputs: [MLArtifactRef(
                path: tempInput.path,
                hash: sha256Hex(text)
            )],
            options: MLTaskOptions(
                seed: 42,
                outputDirectory: outputDir.path
            )
        )

        let response = try await executeMLWorker(request: request, mlPath: mlPath)

        guard response.status == .completed else {
            throw CLIMLError.executionFailed(response.errorMessage ?? "ML worker failed")
        }

        guard let output = response.outputs.first else {
            throw CLIMLError.invalidOutput("No embedding output")
        }

        return try loadEmbeddingFloat32(fromHeaderPath: output.path)
    }

    private func generateCloudEmbedding(
        text: String,
        modelID: String
    ) async throws -> [Float] {
        // Find available cloud providers with embeddings capability
        let providers = providerRegistry.availableProviders(required: [.embeddings])
        guard let descriptor = providers.first else {
            throw CLIMLError.noProviderConfigured
        }
        
        let factory = CloudProviderFactory()
        let provider = try factory.createProvider(
            descriptor: descriptor,
            environment: ProcessInfo.processInfo.environment
        )
        
        let request = EmbeddingRequest(input: [text], model: modelID)
        let response = try await provider.embeddings(request: request)
        guard let embedding = response.embeddings.first else {
            throw CLIMLError.invalidOutput("No embedding returned")
        }
        return embedding
    }

    // MARK: - Chat/Inference

    /// Perform chat inference using local model or cloud fallback.
    public func chat(
        prompt: String,
        modelID: String? = nil,
        systemPrompt: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 2048
    ) async throws -> String {
        let model = modelID ?? preferredChatModel ?? "llama-3.1-8b-instruct"

        #if canImport(AnigmaCLIML)
        // Try local MLX first
        do {
            // Load model if not already loaded
            let currentInfo = await mlxChat.getModelInfo()
            if currentInfo?.modelID != model {
                try await mlxChat.loadModel(modelID: model)
            }

            return try await mlxChat.chat(
                prompt: prompt,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )
        } catch {
            logWarning("Local MLX chat failed: \(error), falling back to cloud")
            // Fallback to cloud provider
            return try await chatCloud(
                prompt: prompt,
                modelID: model,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )
        }
        #else
        // No local support, use cloud
        return try await chatCloud(
            prompt: prompt,
            modelID: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
        #endif
    }

    private func chatLocal(
        prompt: String,
        modelID: String,
        mlPath: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        let tempInput = try writeTempInput(prompt)
        defer { try? FileManager.default.removeItem(at: tempInput) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("anigma-cli-chat-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let request = MLWorkerRequest(
            requestId: UUID().uuidString,
            runId: "cli-chat",
            stepId: "chat",
            engine: .mlx,
            task: .chat,
            inputs: [MLArtifactRef(
                path: tempInput.path,
                hash: sha256Hex(prompt)
            )],
            options: MLTaskOptions(
                seed: 42,
                outputDirectory: outputDir.path
            )
        )

        let response = try await executeMLWorker(request: request, mlPath: mlPath)

        guard response.status == .completed else {
            throw CLIMLError.executionFailed(response.errorMessage ?? "ML worker failed")
        }

        guard let output = response.outputs.first else {
            throw CLIMLError.invalidOutput("No chat output")
        }

        return try String(contentsOfFile: output.path, encoding: .utf8)
    }

    private func chatCloud(
        prompt: String,
        modelID: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        // Find available cloud providers with chat capability
        let providers = providerRegistry.availableProviders(required: [.chat])
        guard let descriptor = providers.first else {
            throw CLIMLError.noProviderConfigured
        }
        
        let factory = CloudProviderFactory()
        let provider = try factory.createProvider(
            descriptor: descriptor,
            environment: ProcessInfo.processInfo.environment
        )
        
        let messages = [ChatMessage(role: "user", content: prompt)]
        let request = ChatRequest(
            messages: messages,
            model: modelID,
            temperature: temperature,
            maxTokens: maxTokens,
            systemPrompt: systemPrompt
        )
        let response = try await provider.chat(request: request)
        return response.content
    }

    // MARK: - Codebase Indexing with Embeddings

    /// Index codebase and generate embeddings for all chunks.
    public func indexCodebaseWithEmbeddings(
        repoRoot: String,
        commit: String,
        files: [String],
        embeddingModel: String? = nil,
        progressCallback: (@Sendable (String) -> Void)? = nil
    ) async throws -> IndexingWithEmbeddingsResult {
        let model = embeddingModel ?? preferredEmbeddingModel ?? "all-minilm-l6-v2"

        progressCallback?("Indexing codebase files...")

        // First, index the files (create chunks)
        let indexResult = try await indexManager.indexRepository(
            repoRoot: repoRoot,
            commit: commit,
            files: files
        )

        progressCallback?("Indexed \(indexResult.chunksCreated) chunks, generating embeddings...")

        // Generate embeddings for all chunks
        let embeddingsGenerated = try await indexManager.generateEmbeddings(
            modelID: model,
            dimension: 384
        ) // Default for all-minilm-l6-v2
            { [weak self] text in
                guard let self = self else {
                    throw CLIMLError.actorDeallocated
                }
                return try await self.generateEmbedding(text: text, modelID: model)
            }

        progressCallback?("Generated \(embeddingsGenerated) embeddings")

        return IndexingWithEmbeddingsResult(
            indexingResult: indexResult,
            embeddingsGenerated: embeddingsGenerated
        )
    }

    // MARK: - Retrieval with Hybrid Search

    /// Perform hybrid retrieval (lexical + vector) on indexed codebase.
    public func searchCodebase(
        query: String,
        limit: Int = 20,
        pathPrefix: String? = nil,
        useVector: Bool = true
    ) async throws -> [CLIRetrievalHit] {
        var queryVector: [Float]?

        if useVector {
            do {
                queryVector = try await generateEmbedding(text: query)
            } catch {
                logWarning("Failed to generate query embedding: \(error), using lexical only")
            }
        }

        let request = CLIRetrievalRequest(
            query: query,
            mode: queryVector != nil ? .hybrid : .lexical,
            limit: limit,
            pathPrefix: pathPrefix,
            modelID: preferredEmbeddingModel,
            queryVector: queryVector
        )

        return try await retrieval.search(request)
    }

    // MARK: - ML Worker Execution

    private func executeMLWorker(
        request: MLWorkerRequest,
        mlPath: String
    ) async throws -> MLWorkerResponse {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mlPath)
        process.arguments = ["--engine", request.engine.rawValue]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let encoder = JSONEncoder()
        let payload = try encoder.encode(request)
        stdinPipe.fileHandleForWriting.write(payload + Data("\n".utf8))
        stdinPipe.fileHandleForWriting.closeFile()

        process.waitUntilExit()

        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: stdout, encoding: .utf8),
              let line = output.split(separator: "\n").first else {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw CLIMLError.invalidOutput("No response from ML worker. stderr: \(stderr)")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(MLWorkerResponse.self, from: Data(line.utf8))
    }

    // MARK: - Utilities

    private func writeTempInput(_ text: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("anigma-cli-input-\(UUID().uuidString).txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func loadEmbeddingFloat32(fromHeaderPath path: String) throws -> [Float] {
        let headerURL = URL(fileURLWithPath: path)
        let headerData = try Data(contentsOf: headerURL)

        struct EmbeddingHeader: Codable {
            let dataPath: String
            let embeddingDimension: Int?
            let shape: [Int]?
        }

        let header = try JSONDecoder().decode(EmbeddingHeader.self, from: headerData)

        let dataURL: URL
        if header.dataPath.hasPrefix("/") {
            dataURL = URL(fileURLWithPath: header.dataPath)
        } else {
            dataURL = headerURL.deletingLastPathComponent().appendingPathComponent(header.dataPath)
        }

        let rawData = try Data(contentsOf: dataURL)
        let floatCount = rawData.count / MemoryLayout<Float>.size

        return rawData.withUnsafeBytes { raw in
            let buffer = raw.bindMemory(to: Float.self)
            return Array(buffer.prefix(floatCount))
        }
    }

    private func sha256Hex(_ text: String) -> String {
        let data = Data(text.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func logWarning(_ message: String) {
        fputs("[CLIMLIntegration] WARNING: \(message)\n", stderr)
    }
}

// MARK: - Supporting Types

public struct IndexingWithEmbeddingsResult: Sendable {
    public let indexingResult: IndexingResult
    public let embeddingsGenerated: Int

    public var totalChunks: Int {
        indexingResult.chunksCreated + indexingResult.chunksReused
    }
}

public enum CLIMLError: Error, LocalizedError {
    case executionFailed(String)
    case invalidOutput(String)
    case noProviderConfigured
    case cloudEmbeddingNotImplemented
    case cloudChatNotImplemented
    case actorDeallocated

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let msg):
            return "ML execution failed: \(msg)"
        case .invalidOutput(let msg):
            return "Invalid ML output: \(msg)"
        case .noProviderConfigured:
            return "No cloud provider configured"
        case .cloudEmbeddingNotImplemented:
            return "Cloud embedding provider not yet implemented"
        case .cloudChatNotImplemented:
            return "Cloud chat provider not yet implemented"
        case .actorDeallocated:
            return "ML integration actor was deallocated"
        }
    }
}
