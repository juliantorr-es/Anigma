//
//  DocumentUnitDatabase.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import AnigmaCore
@preconcurrency import CryptoKit
import DatabaseCore
@preconcurrency import Foundation

/// Database operations for document units, embeddings, and retrieval
public actor DocumentUnitDatabase {
    private let dbActor: any DatabaseCore.DatabaseExecutor

    public init(dbActor: any DatabaseCore.DatabaseExecutor) {
        self.dbActor = dbActor
    }

    // MARK: - Document Unit Operations

    /// Configuration for creating a document unit
    public struct CreateDocumentUnitConfiguration: Sendable {
        public let sourceArtifactPath: String
        public let sourceArtifactHash: String
        public let content: Data
        public let contentType: String
        public let acquisitionMethod: String
        public let filePath: String?
        public let chunkStart: Int
        public let chunkEnd: Int?
        public let chunkType: String

        public init(
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

    /// Create a new document unit
    public func createDocumentUnit(config: CreateDocumentUnitConfiguration) async throws -> String {
        let id = UUID().uuidString
        let contentHash = SHA256.hash(data: config.content).description
        let contentPreview = String(data: config.content.prefix(200), encoding: .utf8) ?? ""
        let searchTokens = extractSearchTokens(from: config.content)
        let fileSize = config.content.count
        let mimeType = detectMimeType(data: config.content, filePath: config.filePath)
        let encoding = detectEncoding(config.content)

        try await dbActor.execute(
            """
                INSERT INTO document_units (
                    id, source_artifact_path, source_artifact_hash, content_hash, content_type,
                    chunk_start, chunk_end, chunk_type, acquisition_timestamp, acquisition_method,
                    file_path, file_size, mime_type, encoding, content_preview, search_tokens
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                dbp(id), dbp(config.sourceArtifactPath), dbp(config.sourceArtifactHash), dbp(contentHash),
                dbp(config.contentType),
                dbp(config.chunkStart), dbp(config.chunkEnd), dbp(config.chunkType),
                dbp(Int(Date().timeIntervalSince1970)), dbp(config.acquisitionMethod),
                dbp(config.filePath), dbp(fileSize), dbp(mimeType), dbp(encoding), dbp(contentPreview),
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
    }

    /// Get or create embedding recipe for a document unit
    public func getOrCreateEmbeddingRecipe(
        documentUnitId: String,
        embeddingModel: String,
        embeddingVersion: String
    ) async throws -> String {
        let recipeId = "\(documentUnitId)-\(embeddingModel)-\(embeddingVersion)"
        
        // Check if recipe exists
        let rows = try await dbActor.query(
            "SELECT id FROM embedding_recipes WHERE id = ?",
            parameters: [dbp(recipeId)]
        )
        
        if rows.isEmpty {
            // Create new recipe
            try await dbActor.execute(
                """
                    INSERT INTO embedding_recipes (
                        id, document_unit_id, embedding_model, embedding_version, created_at
                    ) VALUES (?, ?, ?, ?, ?)
                """,
                parameters: [
                    dbp(recipeId),
                    dbp(documentUnitId),
                    dbp(embeddingModel),
                    dbp(embeddingVersion),
                    dbp(Int(Date().timeIntervalSince1970))
                ]
            )
        }
        
        return recipeId
    }

    /// Store embedding vector for a recipe
    public func storeEmbedding(
        recipeId: String,
        vector: [Float],
        metadata: [String: String]
    ) async throws {
        let vectorData = try JSONEncoder().encode(vector)
        let metadataData = try JSONEncoder().encode(metadata)
        
        try await dbActor.execute(
            """
                INSERT INTO embeddings (
                    recipe_id, vector, metadata, created_at
                ) VALUES (?, ?, ?, ?)
            """,
            parameters: [
                dbp(recipeId),
                dbp(vectorData),
                dbp(metadataData),
                dbp(Int(Date().timeIntervalSince1970))
            ]
        )
    }

    /// Search document units by content
    public func searchContent(
        query: String,
        limit: Int = 10
    ) async throws -> [ContentSearchResult] {
        let searchTokens = extractSearchTokens(from: Data(query.utf8))
        
        let rows = try await dbActor.query(
            """
                SELECT
                    id, content_preview, file_path, content_type,
                    source_artifact_path, source_artifact_hash
                FROM document_units
                WHERE search_tokens LIKE ?
                ORDER BY created_at DESC
                LIMIT ?
            """,
            parameters: [dbp("%\(searchTokens)%"), dbp(limit)]
        )
        
        return rows.map { row in
            ContentSearchResult(
                documentUnitId: row["id"]?.asString ?? "",
                contentPreview: row["content_preview"]?.asString ?? "",
                filePath: row["file_path"]?.asString ?? "",
                contentType: row["content_type"]?.asString ?? "",
                sourceArtifactPath: row["source_artifact_path"]?.asString ?? "",
                sourceArtifactHash: row["source_artifact_hash"]?.asString ?? "",
                relevance: 1.0 // Simple relevance scoring
            )
        }
    }

    /// Search embeddings by vector similarity
    public func searchEmbeddings(
        queryVector: [Float],
        limit: Int = 10
    ) async throws -> [VectorSearchResult] {
        // This is a simplified implementation
        // In production, you'd use a vector database extension
        
        let rows = try await dbActor.query(
            """
                SELECT
                    e.recipe_id,
                    du.id as document_unit_id,
                    du.content_preview,
                    du.file_path,
                    du.content_type,
                    du.source_artifact_path,
                    du.source_artifact_hash
                FROM embeddings e
                JOIN embedding_recipes er ON e.recipe_id = er.id
                JOIN document_units du ON er.document_unit_id = du.id
                ORDER BY e.created_at DESC
                LIMIT ?
            """,
            parameters: [dbp(limit)]
        )
        
        return rows.enumerated().map { index, row in
            VectorSearchResult(
                embeddingId: row["recipe_id"]?.asString ?? "",
                documentUnitId: row["document_unit_id"]?.asString ?? "",
                similarity: 1.0 - Float(index) * 0.1, // Simple similarity scoring
                contentPreview: row["content_preview"]?.asString ?? "",
                filePath: row["file_path"]?.asString ?? "",
                contentType: row["content_type"]?.asString ?? "",
                sourceArtifactPath: row["source_artifact_path"]?.asString ?? "",
                sourceArtifactHash: row["source_artifact_hash"]?.asString ?? ""
            )
        }
    }

    /// General query interface for document units
    public func query(
        predicate: String,
        parameters: [DatabaseCore.DatabaseParameter],
        limit: Int = 100
    ) async throws -> [DocumentUnit] {
        let rows = try await dbActor.query(
            """
                SELECT
                    id, source_artifact_path, source_artifact_hash, content_hash, content_type,
                    chunk_start, chunk_end, chunk_type, acquisition_timestamp, acquisition_method,
                    processing_version, file_path, file_size, mime_type, encoding,
                    content_preview, search_tokens, created_at, updated_at
                FROM document_units
                WHERE \(predicate)
                LIMIT ?
            """,
            parameters: parameters + [DatabaseCore.dbp(limit)]
        )
        
        return rows.compactMap { row in
            DocumentUnit(
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
        }
    }

    // MARK: - Helper Methods

    private func extractSearchTokens(from content: Data) -> String {
        // Simplified token extraction
        let text = String(data: content.prefix(1000), encoding: .utf8) ?? ""
        let tokens = text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(50)
            .joined(separator: " ")
        return tokens
    }

    private func detectMimeType(data: Data, filePath: String?) -> String? {
        // Simplified MIME type detection
        if let filePath = filePath {
            if filePath.hasSuffix(".txt") { return "text/plain" }
            if filePath.hasSuffix(".json") { return "application/json" }
            if filePath.hasSuffix(".swift") { return "text/x-swift" }
        }
        
        // Check data signature
        if data.starts(with: [0x25, 0x50, 0x44, 0x46]) { return "application/pdf" }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        
        return nil
    }

    private func detectEncoding(_ content: Data) -> String? {
        // Simplified encoding detection
        if String(data: content, encoding: .utf8) != nil { return "utf-8" }
        if String(data: content, encoding: .utf16) != nil { return "utf-16" }
        if String(data: content, encoding: .ascii) != nil { return "ascii" }
        return nil
    }

    private func dbp(_ value: Any?) -> DatabaseCore.DatabaseParameter {
        // Helper for database parameters
        if let s = value as? String { return .text(s) }
        if let i = value as? Int { return .int(i) }
        if let d = value as? Double { return .double(d) }
        if let data = value as? Data { return .blob(data) }
        return .null
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