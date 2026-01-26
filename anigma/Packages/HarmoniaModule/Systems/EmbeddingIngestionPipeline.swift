//
//  EmbeddingIngestionPipeline.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import ContractsCore
import DatabaseCore
@preconcurrency import Foundation
@preconcurrency import CryptoKit

/// Pipeline for ingesting embeddings with complete provenance tracking
/// Connects ML worker output to database storage with document unit creation
public actor EmbeddingIngestionPipeline {
    private let dbActor: DatabaseActor
    private let documentUnitDB: DocumentUnitDatabase
    private let mlWorkerPath: String

    public init(dbActor: DatabaseActor, mlWorkerPath: String = "./.build/debug/ml-worker") {
        self.dbActor = dbActor
        self.documentUnitDB = DocumentUnitDatabase(dbActor: dbActor)
        self.mlWorkerPath = mlWorkerPath
    }

    /// Ingest document content and generate embeddings with full provenance
    public func ingestDocument(
        content: Data,
        contentType: String,
        acquisitionMethod: String,
        filePath: String? = nil,
        engine: MLWorkerEngine = .mlx,
        chunkSize: Int = 1000
    ) async throws -> EmbeddingIngestionResult {
        let runId = "ingest-\(UUID().uuidString.lowercased())"

        // Step 1: Create source artifact (store original content)
        let sourceArtifactPath = try await storeSourceArtifact(
            content: content,
            runId: runId,
            filePath: filePath
        )

        // Step 2: Create document unit(s)
        let documentUnits = try await createDocumentUnits(
            content: content,
            contentType: contentType,
            sourceArtifactPath: sourceArtifactPath,
            acquisitionMethod: acquisitionMethod,
            filePath: filePath,
            chunkSize: chunkSize
        )

        // Step 3: Generate embeddings via ML worker
        let embeddingResults = try await generateEmbeddings(
            documentUnits: documentUnits,
            runId: runId,
            engine: engine
        )

        // Step 4: Store embeddings with provenance
        let storedEmbeddings = try await storeEmbeddings(embeddingResults)

        return EmbeddingIngestionResult(
            runId: runId,
            documentUnitsCreated: documentUnits.count,
            embeddingsGenerated: storedEmbeddings.count,
            sourceArtifactPath: sourceArtifactPath
        )
    }

    // MARK: - Private Implementation

    private func storeSourceArtifact(
        content: Data,
        runId: String,
        filePath: String?
    ) async throws -> String {
        let stepId = "source-storage"
        let outputDir = ".accessum-artifacts/\(runId)/ingestion/\(stepId)"

        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        guard let filename = filePath else {
            fatalError("Failed to unwrap filename")
        }
        let artifactPath = "\(outputDir)/\(filename)"

        try content.write(to: URL(fileURLWithPath: artifactPath))

        // Create Accessum-style metadata
        let metadata = SourceArtifactMetadata(
            runId: runId,
            stepId: stepId,
            filename: filename,
            contentType: detectMimeType(data: content, filePath: filePath),
            fileSize: content.count,
            acquisitionTimestamp: Int(Date().timeIntervalSince1970),
            filePath: filePath
        )

        let metadataPath = "\(artifactPath).json"
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: URL(fileURLWithPath: metadataPath))

        return artifactPath
    }

    private func createDocumentUnits(
        content: Data,
        contentType: String,
        sourceArtifactPath: String,
        acquisitionMethod: String,
        filePath: String?,
        chunkSize: Int
    ) async throws -> [String] {
        let sourceArtifactHash = sha256Hex(content)
        let chunks = splitContent(
            content,
            contentType: contentType,
            filePath: filePath,
            chunkSize: chunkSize
        )

        var unitIds: [String] = []
        for chunk in chunks {
            let unitId = try await documentUnitDB.createDocumentUnit(
                config: DocumentUnitDatabase.CreateDocumentUnitConfiguration(
                    sourceArtifactPath: sourceArtifactPath,
                    sourceArtifactHash: sourceArtifactHash,
                    content: chunk.data,
                    contentType: contentType,
                    acquisitionMethod: acquisitionMethod,
                    filePath: filePath,
                    chunkStart: chunk.start,
                    chunkEnd: chunk.end,
                    chunkType: chunk.kind
                )
            )
            unitIds.append(unitId)
        }

        return unitIds
    }

    private func generateEmbeddings(
        documentUnits: [String],
        runId: String,
        engine: MLWorkerEngine
    ) async throws -> [EmbeddingGenerationResult] {
        var results: [EmbeddingGenerationResult] = []

        for (index, documentUnitId) in documentUnits.enumerated() {
            let stepId = "embedding-\(index)"

            // Get document unit content
            guard let documentUnit = try await documentUnitDB.getDocumentUnit(id: documentUnitId) else {
            throw EmbeddingIngestionError.documentUnitNotFound(documentUnitId)
            }

            // Read source artifact to get content
            let contentData = try Data(contentsOf: URL(fileURLWithPath: documentUnit.sourceArtifactPath))

            // Create temporary input file for ML worker
            let tempInputPath = "/tmp/embedding-input-\(UUID().uuidString.lowercased()).txt"
            try contentData.write(to: URL(fileURLWithPath: tempInputPath))

            defer {
                try? FileManager.default.removeItem(atPath: tempInputPath)
            }

            // Run ML worker
            let request = MLWorkerRequest(
                requestId: "\(runId)-\(stepId)",
                runId: runId,
                stepId: stepId,
                engine: engine,
                task: .embed,
                inputs: [MLArtifactRef(path: tempInputPath, hash: documentUnit.contentHash)],
                options: MLTaskOptions(seed: 42)
            )

            let result = try await executeMLWorker(request: request)

            results.append(EmbeddingGenerationResult(
                documentUnitId: documentUnitId,
                request: request,
                response: result
            ))
        }

        return results
    }

    private func executeMLWorker(request: MLWorkerRequest) async throws -> MLWorkerResponse {
        let requestData = try JSONEncoder().encode(request)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mlWorkerPath)
        process.arguments = ["--engine", request.engine.rawValue]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Write request to stdin
        stdinPipe.fileHandleForWriting.write(requestData)
        stdinPipe.fileHandleForWriting.closeFile()

        process.waitUntilExit()

        // Read response
        let responseData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let response = try JSONDecoder().decode(MLWorkerResponse.self, from: responseData)

        guard case .completed = response.status else {
            throw EmbeddingIngestionError.mlWorkerFailed(response.requestId)
        }

        return response
    }

    private func storeEmbeddings(_ results: [EmbeddingGenerationResult]) async throws -> [String] {
        var storedEmbeddingIds: [String] = []

        for result in results {
            for output in result.response.outputs {
                // Parse embedding header to get recipe information
                let headerPath = "\(output.path).json"
                let headerData = try Data(contentsOf: URL(fileURLWithPath: headerPath))
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let header = try decoder.decode(EmbeddingHeader.self, from: headerData)

                // Create/get embedding recipe
                let recipeId = try await documentUnitDB.getOrCreateEmbeddingRecipe(
                    documentUnitId: result.documentUnitId,
                    embeddingModel: result.request.engine.rawValue,
                    embeddingVersion: header.modelHash
                )

                // Read vector data
                let vectorData = try Data(contentsOf: URL(fileURLWithPath: header.dataPath))
                let vector = vectorData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }

                // Store embedding
                try await documentUnitDB.storeEmbedding(
                    recipeId: recipeId,
                    vector: vector,
                    metadata: [
                        "artifactPath": output.path,
                        "artifactHash": output.hash
                    ]
                )

                storedEmbeddingIds.append(recipeId) // Placeholder ID since storeEmbedding doesn't return one
            }
        }

        return storedEmbeddingIds
    }

    // MARK: - Utility Methods

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func detectMimeType(data: Data, filePath: String?) -> String {
        // Basic MIME type detection - reuse from DocumentUnitDatabase
        if data.count >= 4 {
            let header = data.prefix(4)
            if header == Data([0x25, 0x50, 0x44, 0x46]) { return "application/pdf" }
            if header == Data([0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
            if header == Data([0xFF, 0xD8, 0xFF, 0xE0]) { return "image/jpeg" }
        }

        if let path = filePath {
            let ext = (path as NSString).pathExtension.lowercased()
            switch ext {
            case "txt": return "text/plain"
            case "json": return "application/json"
            case "swift": return "text/x-swift"
            case "md": return "text/markdown"
            default: break
            }
        }

        return "application/octet-stream"
    }

    private struct ContentChunk {
        let data: Data
        let start: Int
        let end: Int?
        let kind: String
    }

    private func splitContent(
        _ content: Data,
        contentType: String,
        filePath: String?,
        chunkSize: Int
    ) -> [ContentChunk] {
        guard !content.isEmpty else {
            return [ContentChunk(data: content, start: 0, end: 0, kind: "full")]
        }
        guard chunkSize > 0 else {
            return [ContentChunk(data: content, start: 0, end: content.count, kind: "full")]
        }

        if !isTextLike(contentType: contentType, filePath: filePath) {
            return [ContentChunk(data: content, start: 0, end: content.count, kind: "full")]
        }

        let bytes = [UInt8](content)
        var chunks: [ContentChunk] = []
        var chunkStart = 0

        while chunkStart < bytes.count {
            let maxEnd = min(chunkStart + chunkSize, bytes.count)
            var breakIndex = maxEnd

            if maxEnd < bytes.count {
                var scanIndex = maxEnd - 1
                while scanIndex > chunkStart {
                    if bytes[scanIndex] == 0x0A {
                        breakIndex = scanIndex + 1
                        break
                    }
                    scanIndex -= 1
                }
            }

            if breakIndex == chunkStart {
                breakIndex = maxEnd
            }

            let chunkData = content.subdata(in: chunkStart..<breakIndex)
            chunks.append(
                ContentChunk(
                    data: chunkData,
                    start: chunkStart,
                    end: breakIndex,
                    kind: "text"
                )
            )
            chunkStart = breakIndex
        }

        return chunks
    }

    private func isTextLike(contentType: String, filePath: String?) -> Bool {
        let lower = contentType.lowercased()
        if lower.hasPrefix("text/") { return true }
        if lower.contains("json") || lower.contains("xml") { return true }
        if lower.contains("markdown") { return true }
        if let path = filePath {
            let ext = (path as NSString).pathExtension.lowercased()
            return ["txt", "md", "swift", "json", "xml", "yaml", "yml"].contains(ext)
        }
        return false
    }
}

// MARK: - Data Models

public struct EmbeddingIngestionResult {
    public let runId: String
    public let documentUnitsCreated: Int
    public let embeddingsGenerated: Int
    public let sourceArtifactPath: String
}

private struct EmbeddingGenerationResult {
    let documentUnitId: String
    let request: MLWorkerRequest
    let response: MLWorkerResponse
}

private struct SourceArtifactMetadata: Codable {
    let runId: String
    let stepId: String
    let filename: String
    let contentType: String
    let fileSize: Int
    let acquisitionTimestamp: Int
    let filePath: String?

    var schemaVersion: Int { 1 }
    var timestamp: String { ISO8601DateFormatter().string(from: Date()) }
    var artifactType: String { "source_content" }
}

// MARK: - Error Types

public enum EmbeddingIngestionError: Error, LocalizedError {
    case documentUnitNotFound(String)
    case mlWorkerFailed(String)
    case invalidArtifact(String)

    public var errorDescription: String? {
        switch self {
        case .documentUnitNotFound(let id):
            return "Document unit not found: \(id)"
        case .mlWorkerFailed(let requestId):
            return "ML worker failed for request: \(requestId)"
        case .invalidArtifact(let path):
            return "Invalid artifact: \(path)"
        }
    }
}
