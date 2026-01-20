//
//  VectorStore.swift
//  AnigmaCLI
//
//  sqlite-vec based vector storage with similarity search.
//

import Foundation
import SQLite

public enum VectorStoreError: Error {
    case connectionFailed(String)
    case sqlError(String)
    case dimensionMismatch(expected: Int, got: Int)
    case notFound(String)
}

public struct VectorDocument: Codable {
    public let id: String
    public let content: String
    public let metadata: [String: String]
    public let embedding: [Float]
    public let timestamp: Date

    public init(id: String, content: String, metadata: [String: String] = [:], embedding: [Float]) {
        self.id = id
        self.content = content
        self.metadata = metadata
        self.embedding = embedding
        self.timestamp = Date()
    }
}

public struct SearchResult {
    public let document: VectorDocument
    public let distance: Float
    public let similarity: Float

    public init(document: VectorDocument, distance: Float) {
        self.document = document
        self.distance = distance
        self.similarity = 1.0 / (1.0 + distance)
    }
}

public actor VectorStore {
    private let connection: Connection
    private let dimensions: Int
    private let tableName: String

    // Table schema
    private let documents = Table("vector_documents")
    private let id_col = Expression<String>("id")
    private let content_col = Expression<String>("content")
    private let metadata_col = Expression<String>("metadata")
    private let embedding_col = Expression<Blob>("embedding")
    private let timestamp_col = Expression<Date>("timestamp")

    public init(path: String, dimensions: Int = 384, tableName: String = "vector_documents") throws {
        self.dimensions = dimensions
        self.tableName = tableName

        do {
            self.connection = try Connection(path)
            try setupDatabase()
        } catch {
            throw VectorStoreError.connectionFailed(error.localizedDescription)
        }
    }

    private func setupDatabase() throws {
        // Enable sqlite-vec extension (if available)
        try? connection.execute("SELECT load_extension('vec0')")

        // Create main documents table
        try connection.run(documents.create(ifNotExists: true) { t in
            t.column(id_col, primaryKey: true)
            t.column(content_col)
            t.column(metadata_col)
            t.column(embedding_col)
            t.column(timestamp_col)
        })

        // Create FTS5 virtual table for full-text search
        try connection.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
                id UNINDEXED,
                content,
                content='vector_documents',
                content_rowid='rowid'
            )
        """)

        // Create triggers to keep FTS in sync
        try connection.execute("""
            CREATE TRIGGER IF NOT EXISTS documents_fts_insert AFTER INSERT ON vector_documents BEGIN
                INSERT INTO documents_fts(rowid, id, content) VALUES (new.rowid, new.id, new.content);
            END
        """)

        try connection.execute("""
            CREATE TRIGGER IF NOT EXISTS documents_fts_delete AFTER DELETE ON vector_documents BEGIN
                INSERT INTO documents_fts(documents_fts, rowid, id, content) VALUES('delete', old.rowid, old.id, old.content);
            END
        """)

        try connection.execute("""
            CREATE TRIGGER IF NOT EXISTS documents_fts_update AFTER UPDATE ON vector_documents BEGIN
                INSERT INTO documents_fts(documents_fts, rowid, id, content) VALUES('delete', old.rowid, old.id, old.content);
                INSERT INTO documents_fts(rowid, id, content) VALUES (new.rowid, new.id, new.content);
            END
        """)

        // Create index on timestamp
        try connection.execute("""
            CREATE INDEX IF NOT EXISTS idx_timestamp ON vector_documents(timestamp)
        """)
    }

    public func insert(document: VectorDocument) throws {
        guard document.embedding.count == dimensions else {
            throw VectorStoreError.dimensionMismatch(expected: dimensions, got: document.embedding.count)
        }

        let metadataJSON = try JSONEncoder().encode(document.metadata)
        let embeddingData = Data(bytes: document.embedding, count: document.embedding.count * MemoryLayout<Float>.size)

        try connection.run(documents.insert(
            id_col <- document.id,
            content_col <- document.content,
            metadata_col <- String(data: metadataJSON, encoding: .utf8) ?? "{}",
            embedding_col <- embeddingData.datatypeValue,
            timestamp_col <- document.timestamp
        ))
    }

    public func insertBatch(documents: [VectorDocument]) throws {
        try connection.transaction {
            for doc in documents {
                try insert(document: doc)
            }
        }
    }

    public func search(embedding: [Float], limit: Int = 10, threshold: Float? = nil) throws -> [SearchResult] {
        guard embedding.count == dimensions else {
            throw VectorStoreError.dimensionMismatch(expected: dimensions, got: embedding.count)
        }

        var results: [SearchResult] = []

        for row in try connection.prepare(documents) {
            let storedEmbedding = deserializeEmbedding(row[embedding_col])
            let distance = cosineDistance(embedding, storedEmbedding)

            if let threshold = threshold, distance > threshold {
                continue
            }

            let metadata = try JSONDecoder().decode([String: String].self, from: Data(row[metadata_col].utf8))

            let doc = VectorDocument(
                id: row[id_col],
                content: row[content_col],
                metadata: metadata,
                embedding: storedEmbedding
            )

            results.append(SearchResult(document: doc, distance: distance))
        }

        results.sort { $0.distance < $1.distance }
        return Array(results.prefix(limit))
    }

    public func fullTextSearch(query: String, limit: Int = 10) throws -> [VectorDocument] {
        let ftsQuery = """
            SELECT d.id, d.content, d.metadata, d.embedding, d.timestamp
            FROM documents_fts f
            JOIN vector_documents d ON d.id = f.id
            WHERE f.content MATCH ?
            ORDER BY rank
            LIMIT ?
        """

        var results: [VectorDocument] = []

        for row in try connection.prepare(ftsQuery, query, limit) {
            guard let embedding = deserializeEmbedding(row[3] as? Blob else {
                fatalError("Failed to cast to Blob")
            }
            guard let metadata = try JSONDecoder().decode([String: String].self, from: Data((row[2] as? String else {
                fatalError("Failed to cast to String")
            }

            let doc = VectorDocument(
                id: row[0] as! String,
                content: row[1] as! String,
                metadata: metadata,
                embedding: embedding
            )

            results.append(doc)
        }

        return results
    }

    public func hybridSearch(
        query: String,
        embedding: [Float],
        limit: Int = 10,
        vectorWeight: Float = 0.7
    ) throws -> [SearchResult] {
        let vectorResults = try search(embedding: embedding, limit: limit * 2)
        let ftsResults = try fullTextSearch(query: query, limit: limit * 2)

        var scoreMap: [String: Float] = [:]

        for (idx, result) in vectorResults.enumerated() {
            let score = (1.0 - Float(idx) / Float(vectorResults.count)) * vectorWeight
            scoreMap[result.document.id] = score
        }

        for (idx, doc) in ftsResults.enumerated() {
            let score = (1.0 - Float(idx) / Float(ftsResults.count)) * (1.0 - vectorWeight)
            scoreMap[doc.id, default: 0] += score
        }

        var combinedResults: [SearchResult] = []
        let allDocs = Dictionary(grouping: vectorResults.map { $0.document } + ftsResults) { $0.id }

        for (docId, score) in scoreMap.sorted(by: { $0.value > $1.value }).prefix(limit) {
            if let doc = allDocs[docId]?.first {
                combinedResults.append(SearchResult(document: doc, distance: 1.0 - score))
            }
        }

        return combinedResults
    }

    public func get(id: String) throws -> VectorDocument? {
        guard let row = try connection.pluck(documents.filter(id_col == id)) else {
            return nil
        }

        let embedding = deserializeEmbedding(row[embedding_col])
        let metadata = try JSONDecoder().decode([String: String].self, from: Data(row[metadata_col].utf8))

        return VectorDocument(
            id: row[id_col],
            content: row[content_col],
            metadata: metadata,
            embedding: embedding
        )
    }

    public func delete(id: String) throws {
        try connection.run(documents.filter(id_col == id).delete())
    }

    public func count() throws -> Int {
        return try connection.scalar(documents.count)
    }

    public func clear() throws {
        try connection.run(documents.delete())
    }

    private func deserializeEmbedding(_ blob: Blob) -> [Float] {
        let data = Data.fromDatatypeValue(blob)
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }

    private func cosineDistance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return Float.infinity }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let similarity = dotProduct / (sqrt(normA) * sqrt(normB))
        return 1.0 - similarity
    }
}
