//
//  CathedralMLServices.swift
//  CathedralModule
//
//  ML service integration for Cathedral evidence-driven operations
//

import Foundation
import ContextumModule
import enum ContractsCore.OperationExecutionStatus

// MARK: - ML Service Protocol

/// Protocol for ML service integration with Cathedral
public protocol CathedralMLService: Sendable {
    func executeOperation(_ operation: MLOperation) async throws -> MLServiceResult
}

// MARK: - ML Service Result

public struct MLServiceResult: Sendable, Codable {
    public let operationId: String
    public let operationType: MLOperationType
    public let status: OperationExecutionStatus
    public let data: [String: String]
    public let executionTimeMs: Int64
    public let modelUsed: String?
    public let tokensUsed: Int?

    public init(
        operationId: String,
        operationType: MLOperationType,
        status: OperationExecutionStatus,
        data: [String: String],
        executionTimeMs: Int64,
        modelUsed: String? = nil,
        tokensUsed: Int? = nil
    ) {
        self.operationId = operationId
        self.operationType = operationType
        self.status = status
        self.data = data
        self.executionTimeMs = executionTimeMs
        self.modelUsed = modelUsed
        self.tokensUsed = tokensUsed
    }
}

// MARK: - Embedding Service

/// Embedding service using EmbeddingComputing protocol
public actor EmbeddingMLService: CathedralMLService {
    private let embeddingComputing: EmbeddingComputing
    private let modelRegistry: ModelRegistryProtocol

    public init(
        embeddingComputing: EmbeddingComputing,
        modelRegistry: ModelRegistryProtocol
    ) {
        self.embeddingComputing = embeddingComputing
        self.modelRegistry = modelRegistry
    }

    public func executeOperation(_ operation: MLOperation) async throws -> MLServiceResult {
        let startTime = Date()

        guard operation.type == .embedding else {
            throw MLServiceError.invalidOperationType("Expected embedding, got \(operation.type.rawValue)")
        }

        // Extract parameters
        guard let text = operation.parameters["text"],
              let modelID = operation.parameters["model"] else {
            throw MLServiceError.missingParameters("text and model required")
        }

        // Validate model exists
        guard let entry = try await modelRegistry.find(id: modelID) else {
            throw MLServiceError.modelNotFound(modelID)
        }

        // Compute embeddings
        let result = try await embeddingComputing.computeEmbeddings(
            modelID: modelID,
            modelVersion: entry.spec.metadata["version"],
            inputs: [text],
            normalize: true
        )

        guard let vector = result.vectors.first else {
            throw MLServiceError.computationFailed("No embedding vector returned")
        }

        // Record usage
        try await modelRegistry.recordUsage(modelID)

        let executionTime = Int64(Date().timeIntervalSince(startTime) * 1000)

        // Encode vector as base64
        let floatVector = vector.map { Float($0) }
        let vectorData = floatVector.withUnsafeBytes { rawBuffer -> Data in
            guard let baseAddress = rawBuffer.baseAddress, rawBuffer.count > 0 else {
                return Data()
            }
            return Data(bytes: baseAddress, count: rawBuffer.count)
        }
        let vectorBase64 = vectorData.base64EncodedString()

        return MLServiceResult(
            operationId: operation.id,
            operationType: .embedding,
            status: .success,
            data: [
                "vector": vectorBase64,
                "dimension": String(result.dimension),
                "inputHash": result.inputHashes.first ?? ""
            ],
            executionTimeMs: executionTime,
            modelUsed: modelID
        )
    }
}

// MARK: - Retrieval Service

/// Retrieval service using SemanticSearchSystem
public actor RetrievalMLService: CathedralMLService {
    private let searchSystem: SemanticSearchSystem
    private let embeddingComputing: EmbeddingComputing
    private let modelRegistry: ModelRegistryProtocol
    private let database: ContextumDatabase

    public init(
        searchSystem: SemanticSearchSystem,
        embeddingComputing: EmbeddingComputing,
        modelRegistry: ModelRegistryProtocol,
        database: ContextumDatabase
    ) {
        self.searchSystem = searchSystem
        self.embeddingComputing = embeddingComputing
        self.modelRegistry = modelRegistry
        self.database = database
    }

    public func executeOperation(_ operation: MLOperation) async throws -> MLServiceResult {
        let startTime = Date()

        guard operation.type == .retrieval else {
            throw MLServiceError.invalidOperationType("Expected retrieval, got \(operation.type.rawValue)")
        }

        // Extract parameters
        guard let query = operation.parameters["query"],
              let modelID = operation.parameters["model"] else {
            throw MLServiceError.missingParameters("query and model required")
        }

        let topK = Int(operation.parameters["topK"] ?? "10") ?? 10
        let threshold = Float(operation.parameters["threshold"] ?? "0.7") ?? 0.7

        // Validate model exists
        guard let entry = try await modelRegistry.find(id: modelID) else {
            throw MLServiceError.modelNotFound(modelID)
        }

        // Compute query embedding
        let embeddingResult = try await embeddingComputing.computeEmbeddings(
            modelID: modelID,
            modelVersion: entry.spec.metadata["version"],
            inputs: [query],
            normalize: true
        )

        guard let queryEmbedding = embeddingResult.vectors.first else {
            throw MLServiceError.computationFailed("No query embedding returned")
        }

        // Perform semantic search
        let searchRequest = SemanticSearchSystem.SearchRequest(
            queryText: query,
            queryEmbedding: queryEmbedding.map { Float($0) },
            embeddingModelId: modelID,
            embeddingModelHash: entry.spec.canonicalHash,
            limit: topK,
            minSimilarity: threshold,
            workflowId: operation.sessionId,
            runId: operation.id
        )

        let results = try await searchSystem.search(
            request: searchRequest,
            database: database
        )

        // Record usage
        try await modelRegistry.recordUsage(modelID)

        let executionTime = Int64(Date().timeIntervalSince(startTime) * 1000)

        // Encode results
        let resultsJSON = try encodeResults(results)

        return MLServiceResult(
            operationId: operation.id,
            operationType: .retrieval,
            status: .success,
            data: [
                "results": resultsJSON,
                "resultCount": String(results.count),
                "queryHash": embeddingResult.inputHashes.first ?? ""
            ],
            executionTimeMs: executionTime,
            modelUsed: modelID
        )
    }

    private func encodeResults(_ results: [SemanticSearchSystem.SearchResult]) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(results)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

// MARK: - Generation Service (Placeholder)

/// Generation service for text generation (placeholder for future implementation)
public actor GenerationMLService: CathedralMLService {
    public init() {}

    public func executeOperation(_ operation: MLOperation) async throws -> MLServiceResult {
        guard operation.type == .generation else {
            throw MLServiceError.invalidOperationType("Expected generation, got \(operation.type.rawValue)")
        }

        let prompt = operation.parameters["prompt"] ?? operation.parameters["text"] ?? ""
        let maxTokens = Int(operation.parameters["maxTokens"] ?? "128") ?? 128
        let temperature = Double(operation.parameters["temperature"] ?? "0.7") ?? 0.7
        let modelID = operation.parameters["model"]
        let generated = prompt.isEmpty
            ? "No prompt provided."
            : String(prompt.prefix(max(1, min(prompt.count, maxTokens / 2))))

        return MLServiceResult(
            operationId: operation.id,
            operationType: .generation,
            status: .success,
            data: [
                "generated": generated,
                "promptLength": String(prompt.count),
                "maxTokens": String(maxTokens),
                "temperature": String(temperature),
                "note": "Deterministic Cathedral generation path"
            ],
            executionTimeMs: 100,
            modelUsed: modelID
        )
    }
}

// MARK: - Classification Service (Placeholder)

/// Classification service (placeholder for future implementation)
public actor ClassificationMLService: CathedralMLService {
    public init() {}

    public func executeOperation(_ operation: MLOperation) async throws -> MLServiceResult {
        guard operation.type == .classification else {
            throw MLServiceError.invalidOperationType("Expected classification, got \(operation.type.rawValue)")
        }

        let text = operation.parameters["text"] ?? operation.parameters["input"] ?? ""
        let labels = operation.parameters["labels"]?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } ?? []
        let selectedClass = labels.first ?? (text.isEmpty ? "unknown" : "informational")
        let confidence = labels.isEmpty ? "0.5" : "0.85"

        return MLServiceResult(
            operationId: operation.id,
            operationType: .classification,
            status: .success,
            data: [
                "class": selectedClass,
                "confidence": confidence,
                "inputLength": String(text.count),
                "labelCount": String(labels.count),
                "note": "Deterministic Cathedral classification path"
            ],
            executionTimeMs: 50
        )
    }
}

// MARK: - Service Router

/// Routes ML operations to appropriate service
public actor MLServiceRouter: CathedralMLService {
    private let embeddingService: EmbeddingMLService
    private let retrievalService: RetrievalMLService
    private let generationService: GenerationMLService
    private let classificationService: ClassificationMLService

    public init(
        embeddingService: EmbeddingMLService,
        retrievalService: RetrievalMLService,
        generationService: GenerationMLService,
        classificationService: ClassificationMLService
    ) {
        self.embeddingService = embeddingService
        self.retrievalService = retrievalService
        self.generationService = generationService
        self.classificationService = classificationService
    }

    public func executeOperation(_ operation: MLOperation) async throws -> MLServiceResult {
        switch operation.type {
        case .embedding:
            return try await embeddingService.executeOperation(operation)
        case .retrieval:
            return try await retrievalService.executeOperation(operation)
        case .generation:
            return try await generationService.executeOperation(operation)
        case .classification:
            return try await classificationService.executeOperation(operation)
        case .transformation:
            throw MLServiceError.unsupportedOperation("Transformation not yet supported")
        }
    }
}

// MARK: - ML Service Errors

public enum MLServiceError: Error, LocalizedError {
    case invalidOperationType(String)
    case missingParameters(String)
    case modelNotFound(String)
    case computationFailed(String)
    case unsupportedOperation(String)

    public var errorDescription: String? {
        switch self {
        case .invalidOperationType(let details):
            return "Invalid operation type: \(details)"
        case .missingParameters(let details):
            return "Missing parameters: \(details)"
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .computationFailed(let details):
            return "Computation failed: \(details)"
        case .unsupportedOperation(let details):
            return "Unsupported operation: \(details)"
        }
    }
}
