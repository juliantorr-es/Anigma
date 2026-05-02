//
//  EmbedTextContract.swift
//  AnigmaCore
//
//  Contract definition for EmbedTextContract in AnigmaCore.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import FoundationContracts
import EvidenceContracts
import Foundation

public struct EmbedTextInput: Codable, Sendable, Hashable {
    public let modelID: String
    public let modelVersion: String?
    public let texts: [String]

    public init(modelID: String, modelVersion: String?, texts: [String]) {
        self.modelID = modelID
        self.modelVersion = modelVersion
        self.texts = texts
    }
}

public struct EmbeddingVector: Codable, Sendable, Hashable {
    public let textHash: String
    public let vector: [Double]

    public init(textHash: String, vector: [Double]) {
        self.textHash = textHash
        self.vector = vector
    }
}

public struct EmbedTextOutput: Codable, Sendable, Hashable {
    public let modelID: String
    public let modelVersion: String?
    public let dimension: Int
    public let vectors: [EmbeddingVector]

    public init(modelID: String, modelVersion: String?, dimension: Int, vectors: [EmbeddingVector]) {
        self.modelID = modelID
        self.modelVersion = modelVersion
        self.dimension = dimension
        self.vectors = vectors
    }
}

public enum EmbedTextContract: ContractSpec {
    public static let id = ContractID(name: "pipeline.embed.text", major: 1, minor: 0, schemaHash: "v1.0")
    public static let inputSchemaVersion = 1
    public static let outputSchemaVersion = 1

    public static func validate(output: ArtifactEnvelope<EmbedTextOutput>) throws {
        guard !output.payload.vectors.isEmpty else {
            throw ContractValidationError.invalidSchema(
                code: "embed.empty_vectors",
                message: "No embedding vectors returned"
            )
        }
        for vector in output.payload.vectors {
            if vector.vector.count != output.payload.dimension {
                throw ContractValidationError.invalidSchema(
                    code: "embed.dimension_mismatch",
                    message: "Vector length \(vector.vector.count) != dimension \(output.payload.dimension)"
                )
            }
        }
    }

    public static func artifactKeyMetadata(input: ArtifactEnvelope<EmbedTextInput>) -> (modelID: String?, modelVersion: String?) {
        (input.payload.modelID, input.payload.modelVersion)
    }

    public static func execute(
        input: ArtifactEnvelope<EmbedTextInput>,
        ctx: ContractContext
    ) async throws -> ArtifactEnvelope<EmbedTextOutput> {
        guard let computer = ctx.embeddingComputer else {
            throw ContractExecutionError.deniedToolAccess(
                code: "embed.denied",
                message: "EmbeddingComputing not available in this context"
            )
        }
        let hashes = input.payload.texts.map { ContractKeyDerivation.blake3Hex(Data($0.utf8)) }
        let result = try await computer.computeEmbeddings(
            modelID: input.payload.modelID,
            modelVersion: input.payload.modelVersion,
            inputs: input.payload.texts,
            normalize: true
        )

        let vectors = zip(hashes, result.vectors).map { hash, vector in
            EmbeddingVector(textHash: hash, vector: vector)
        }

        let metrics = ExecutionMetrics(
            wallTimeMs: 0,
            toolCallCount: 0,
            retryCount: 0,
            executor: ctx.executorIdentity,
            cacheHit: false
        )

        let receipt = ContractReceipt.placeholder(
            contractID: Self.id,
            runID: ctx.runID,
            sessionID: ctx.sessionID,
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: metrics
        )

        let output = EmbedTextOutput(
            modelID: input.payload.modelID,
            modelVersion: input.payload.modelVersion,
            dimension: result.dimension,
            vectors: vectors
        )

        return ArtifactEnvelope(
            schemaVersion: outputSchemaVersion,
            payload: output,
            evidenceRefs: input.evidenceRefs,
            metrics: metrics,
            receipt: receipt
        )
    }
}
