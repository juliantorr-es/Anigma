//
//  DocumentUnitDatabase.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import AnigmaCore
import CryptoKit
import DatabaseCore
import Foundation

/// Database operations for document units, embeddings, and retrieval
public actor DocumentUnitDatabase {
    private let dbActor: any DatabaseExecutor

    public init(dbActor: any DatabaseExecutor) {
        self.dbActor = dbActor
struct CreateDocumentUnitConfiguration: Sendable {
    let sourceArtifactPath: String
    let sourceArtifactHash: String
    let content: Data
    let contentType: String
    let acquisitionMethod: String
    let filePath: String?
    let chunkStart: Int
    let chunkEnd: Int?
    let chunkType: String
}

// Function signature should change to:
// func createDocumentUnit(config: CreateDocumentUnitConfiguration) async throws -> DocumentUnit
    init(
        sourceArtifactPath: String,
        sourceArtifactHash: String,
        content: Data,
        contentType: String,
        acquisitionMethod: String,
        filePath: String? = nil,
        chunkStart: Int = 0,
        chunkEnd: Int? = nil,
        chunkType: String = "full"
    ) {
        self.sourceArtifactPath = sourceArtifactPath
        self.sourceArtifactHash = sourceArtifactHash
        self.content = content
        self.contentType = contentType
        self.acquisitionMethod = acquisitionMethod
        self.filePath = filePath
        self.chunkStart = chunkStart
        self.chunkEnd = chunkEnd
        self.chunkType = chunkType
    }
}

// Function signature should be updated to:
// func createDocumentUnit(config: CreateDocumentUnitConfiguration) async throws -> String
        let fileSize = content.count
        let mimeType = detectMimeType(data: content, filePath: filePath)
        let encoding = detectEncoding(content)

        try await dbActor.execute(
            """
                INSERT INTO document_units (
                    id, source_artifact_path, source_artifact_hash, content_hash, content_type,
                    chunk_start, chunk_end, chunk_type, acquisition_timestamp, acquisition_method,
                    file_path, file_size, mime_type, encoding, content_preview, search_tokens
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                dbp(id), dbp(sourceArtifactPath), dbp(sourceArtifactHash), dbp(contentHash),
                dbp(contentType),
                dbp(chunkStart), dbp(chunkEnd), dbp(chunkType),
                dbp(Int(Date().timeIntervalSince1970)), dbp(acquisitionMethod),
                dbp(filePath), dbp(fileSize), dbp(mimeType), dbp(encoding), dbp(contentPreview),
                dbp(searchTokens)
            ])

        return id
    }

    /// Retrieve document unit by ID with full custody trail
    public func getDocumentUnit(id: String) async throws -> DocumentUnit? {
        let rows = try await dbActor.query(
            """
                SELECT
                    id, source_artifact_path, source_artifact_hash, content_hash, content_type,
                    chunk_start, chunk_end, chunk_type, acquisition_timestamp, acquisition_method,
                    processing_version, file_path, file_size, mime_type, encoding,
                    content_preview, search_tokens, created_at, updated_at
                FROM document_units
                WHERE id = ?
            """, parameters: [dbp(id)])

        guard let row = rows.first else { return nil }

        return DocumentUnit(
            id: row["id"]?.asString ?? "",
            sourceArtifactPath: row["source_artifact_path"]?.asString ?? "",
            sourceArtifactHash: row["source_artifact_hash"]?.asString ?? "",
            contentHash: row["content_hash"]?.asString ?? "",
            contentType: row["content_type"]?.asString ?? "",
            chunkStart: row["chunk_start"]?.asInt ?? 0,
            chunkEnd: row["chunk_end"]?.asInt,
            chunkType: row["chunk_type"]?.asString ?? "",
            acquisitionTimestamp: row["acquisition_timestamp"]?.asInt ?? 0,
            acquisitionMethod: row["acquisition_method"]?.asString ?? "",
            processingVersion: row["processing_version"]?.asString ?? "",
            filePath: row["file_path"]?.asString,
            fileSize: row["file_size"]?.asInt,
            mimeType: row["mime_type"]?.asString,
            encoding: row["encoding"]?.asString,
            contentPreview: row["content_preview"]?.asString ?? "",
            searchTokens: row["search_tokens"]?.asString ?? "",
            createdAt: row["created_at"]?.asInt ?? 0,
            updatedAt: row["updated_at"]?.asInt ?? 0
        )

        dimensions: Int,
        tokenizerIdentity: String? = nil
    ) async throws -> String {
        let argvJson = try JSONSerialization.data(withJSONObject: argv)
        let optionsJson = try JSONSerialization.data(withJSONObject: options)
        guard let argvString = String(data: argvJson, encoding: .utf8) else {
            fatalError("Failed to unwrap argvString")
        }
        guard let optionsString = String(data: optionsJson, encoding: .utf8) else {
struct GetOrCreateEmbeddingRecipeConfiguration: Sendable {
    let engine: String
    let modelHash: String
    let argv: [String]
    let options: [String: Any]
    let binaryHash: String
    let dimensions: Int
    let tokenizerIdentity: String
    
    init(
        engine: String,
        modelHash: String,
        argv: [String],
        options: [String: Any],
        binaryHash: String,
        dimensions: Int,
        tokenizerIdentity: String
    ) {
        self.engine = engine
        self.modelHash = modelHash
        self.argv = argv
        self.options = options
        self.binaryHash = binaryHash
        self.dimensions = dimensions
        self.tokenizerIdentity = tokenizerIdentity
    }
}

// Updated function signature:
// func getOrCreateEmbeddingRecipe(config: GetOrCreateEmbeddingRecipeConfiguration) async throws -> EmbeddingRecipe
            return first["id"]?.asString ?? ""
        }

        // Create new recipe
        let id = UUID().uuidString
        let name = "\(engine)-\(modelHash.prefix(8))"

        try await dbActor.execute(
            """
                INSERT INTO embedding_recipes (
                    id, name, engine, model_hash, argv, options, binary_hash, dimensions,
                    tokenizer_identity, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                dbp(id), dbp(name), dbp(engine), dbp(modelHash), dbp(argvString),
                dbp(optionsString), dbp(binaryHash), dbp(dimensions),
                dbp(tokenizerIdentity ?? "default"), dbp(Int(Date().timeIntervalSince1970))
            ])

        return id
    }

    // MARK: - Embedding Operations

    /// Store embedding with complete provenance linkage
    public func storeEmbedding(
        documentUnitId: String,
        embeddingRecipeId: String,
        vectorData: Data,
        artifactPath: String,
        artifactHash: String
    ) async throws -> String {
        let id = UUID().uuidString
        let vectorHash = sha256Hex(vectorData)
        let magnitude = computeVectorMagnitude(vectorData)

        try await dbActor.execute(
            """
                INSERT INTO embeddings (
                    id, document_unit_id, embedding_recipe_id, vector_blob, vector_hash,
                    artifact_path, artifact_hash, magnitude, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                dbp(id), dbp(documentUnitId), dbp(embeddingRecipeId),
                DatabaseParameter.text(vectorData.base64EncodedString()), dbp(vectorHash),
                dbp(artifactPath), dbp(artifactHash), dbp(Double(magnitude)),
                dbp(Int(Date().timeIntervalSince1970))
            ])

        return id
    }

    // MARK: - Vector Search Operations

    /// Brute-force cosine similarity search (deterministic MVP)
    public func searchEmbeddings(
        queryVector: Data,
        embeddingRecipeId: String? = nil,
        limit: Int = 10,
        threshold: Float = 0.7
    ) async throws -> [VectorSearchResult] {
        let queryMagnitude = computeVectorMagnitude(queryVector)
        let queryFloats = vectorDataToFloatArray(queryVector)

        let sql = """
                SELECT
                    e.id, e.document_unit_id, e.vector_blob, e.magnitude,
                    du.content_preview, du.file_path, du.content_type,
                    du.source_artifact_path, du.source_artifact_hash
                FROM embeddings e
                JOIN document_units du ON e.document_unit_id = du.id
                WHERE e.embedding_recipe_id = COALESCE(?, e.embedding_recipe_id)
            """

        let rows = try await dbActor.query(sql, parameters: [dbp(embeddingRecipeId)])

        var results: [VectorSearchResult] = []

        for row in rows {
            guard let vectorBlob = row["vector_blob"]?.asData else { continue }
            let targetMagnitude = Float(row["magnitude"]?.asDouble ?? 0.0)

            let similarity = cosineSimilarity(
                queryVector: queryFloats,
                queryMagnitude: queryMagnitude,
                targetVector: vectorDataToFloatArray(vectorBlob),
                targetMagnitude: targetMagnitude
            )

            if similarity >= threshold {
                results.append(
                    VectorSearchResult(
                        embeddingId: row["id"]?.asString ?? "",
                        documentUnitId: row["document_unit_id"]?.asString ?? "",
                        similarity: similarity,
                        contentPreview: row["content_preview"]?.asString ?? "",
                        filePath: row["file_path"]?.asString ?? "",
                        contentType: row["content_type"]?.asString ?? "",
                        sourceArtifactPath: row["source_artifact_path"]?.asString ?? "",
                        sourceArtifactHash: row["source_artifact_hash"]?.asString ?? ""
                    ))
            }
        }

        return results.sorted { $0.similarity > $1.similarity }.prefix(limit).map { $0 }
    }

    // MARK: - Full-Text Search

    /// Full-text search across document content
    public func searchContent(
        query: String,
        contentType: String? = nil,
        limit: Int = 10
    ) async throws -> [ContentSearchResult] {
        let sql = """
                SELECT
                    du.id, du.content_preview, du.file_path, du.content_type,
                    du.source_artifact_path, du.source_artifact_hash,
                    bm25(document_units_fts) as relevance
                FROM document_units du
                JOIN document_units_fts ON du.rowid = document_units_fts.rowid
                WHERE document_units_fts MATCH ?
                AND (? IS NULL OR du.content_type = ?)
                ORDER BY relevance
                LIMIT ?
            """

        let contentTypeParam: DatabaseParameter =
            contentType.map { DatabaseParameter.text($0) } ?? .null
        let rows = try await dbActor.query(
            sql,
            parameters: [
                DatabaseParameter.text(query),
                contentTypeParam,
                contentTypeParam,
                DatabaseParameter.int(limit)
            ])

        return rows.map { row in
            ContentSearchResult(
                documentUnitId: row["id"]?.asString ?? "",
                contentPreview: row["content_preview"]?.asString ?? "",
                filePath: row["file_path"]?.asString ?? "",
                contentType: row["content_type"]?.asString ?? "",
                sourceArtifactPath: row["source_artifact_path"]?.asString ?? "",
                sourceArtifactHash: row["source_artifact_hash"]?.asString ?? "",
                relevance: Float(row["relevance"]?.asDouble ?? 0.0)
            )
        }
    }

    /// Run an arbitrary SQL query through the underlying database actor.
    public func query(
        _ sql: String,
        parameters: [DatabaseParameter] = []
    ) async throws -> [DatabaseRow] {
        return try await dbActor.query(sql, parameters: parameters)
    }

    // MARK: - Private Helper Methods

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func tokenizeContent(_ data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8) else { return "" }
        // Simple tokenization - split on whitespace and punctuation
        let tokens = text.components(separatedBy: .whitespacesAndNewlines)
            .flatMap { $0.components(separatedBy: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        return tokens.joined(separator: " ")
    }

    private func detectMimeType(data: Data, filePath: String?) -> String {
        // Basic MIME type detection
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

    private func detectEncoding(_ data: Data) -> String? {
        // Simple encoding detection - check for UTF-8 validity
        if String(data: data, encoding: .utf8) != nil {
            return "utf-8"
        }
        return nil
    }

    private func computeVectorMagnitude(_ data: Data) -> Float {
        let floats = vectorDataToFloatArray(data)
        var sum: Float = 0
        for value in floats {
            sum += value * value
        }
        return sqrt(sum)
    }

    private func vectorDataToFloatArray(_ data: Data) -> [Float] {
        return data.withUnsafeBytes { pointer in
            Array(pointer.bindMemory(to: Float.self))
        }
    }

    private func cosineSimilarity(
        queryVector: [Float],
        queryMagnitude: Float,
        targetVector: [Float],
        targetMagnitude: Float
    ) -> Float {
        guard queryVector.count == targetVector.count,
            queryMagnitude > 0, targetMagnitude > 0
        else { return 0 }

        var dotProduct: Float = 0
        for i in 0..<queryVector.count {
            dotProduct += queryVector[i] * targetVector[i]
        }

        return dotProduct / (queryMagnitude * targetMagnitude)
    }
}

// MARK: - Data Models

public struct DocumentUnit: Sendable, Codable {
    public let id: String
    public let sourceArtifactPath: String
    public let sourceArtifactHash: String
    public let contentHash: String
    public let contentType: String
    public let chunkStart: Int
    public let chunkEnd: Int?
    public let chunkType: String
    public let acquisitionTimestamp: Int
    public let acquisitionMethod: String
    public let processingVersion: String
    public let filePath: String?
    public let fileSize: Int?
    public let mimeType: String?
    public let encoding: String?
    public let contentPreview: String
    public let searchTokens: String
    public let createdAt: Int
    public let updatedAt: Int
}

public struct VectorSearchResult: Sendable {
    public let embeddingId: String
    public let documentUnitId: String
    public let similarity: Float
    public let contentPreview: String
    public let filePath: String
    public let contentType: String
    public let sourceArtifactPath: String
    public let sourceArtifactHash: String
}

public struct ContentSearchResult: Sendable {
    public let documentUnitId: String
    public let contentPreview: String
    public let filePath: String
    public let contentType: String
    public let sourceArtifactPath: String
    public let sourceArtifactHash: String
    public let relevance: Float
}
