import Foundation
import SQLite3

/// Vector storage using sqlite-vec extension
public actor VectorStore {
    private var dbHandle: DBHandle?
    private var db: OpaquePointer? { dbHandle?.pointer }
    private let dbPath: String
    private let dimension: Int

    private final class DBHandle: @unchecked Sendable {
        let pointer: OpaquePointer

        init(pointer: OpaquePointer) {
            self.pointer = pointer
        }

        deinit {
            sqlite3_close(pointer)
        }
    }

    public enum VectorStoreError: Error {
        case databaseError(String)
        case vectorDimensionMismatch
        case invalidVector
    }

    public init(dbPath: String, dimension: Int = 384) async throws {
        self.dbPath = dbPath
        self.dimension = dimension

        try await openDatabase()
        try await createTables()
    }

    // Deinit handled by DBHandle

    private func openDatabase() async throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        if sqlite3_open_v2(dbPath, &db, flags, nil) != SQLITE_OK {
            throw VectorStoreError.databaseError("Failed to open database")
        }
        guard let dbPtr = db else {
             throw VectorStoreError.databaseError("Failed to open database (null pointer)")
        }
        self.dbHandle = DBHandle(pointer: dbPtr)

        var error: UnsafeMutablePointer<CChar>?
        sqlite3_exec(self.db, "SELECT load_extension('vec0')", nil, nil, &error)
        if let error = error {
            sqlite3_free(error)
        }
    }

    private func createTables() async throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS embeddings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chunk_id TEXT UNIQUE NOT NULL,
            content TEXT NOT NULL,
            metadata TEXT,
            created_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS embedding_vectors (
            chunk_id TEXT PRIMARY KEY,
            vector BLOB NOT NULL,
            FOREIGN KEY(chunk_id) REFERENCES embeddings(chunk_id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_embeddings_created ON embeddings(created_at);

        CREATE VIRTUAL TABLE IF NOT EXISTS embeddings_fts USING fts5(
            content,
            chunk_id UNINDEXED,
            content='embeddings',
            content_rowid='id'
        );

        CREATE TRIGGER IF NOT EXISTS embeddings_fts_insert AFTER INSERT ON embeddings BEGIN
            INSERT INTO embeddings_fts(rowid, content, chunk_id)
            VALUES (new.id, new.content, new.chunk_id);
        END;

        CREATE TRIGGER IF NOT EXISTS embeddings_fts_delete AFTER DELETE ON embeddings BEGIN
            DELETE FROM embeddings_fts WHERE rowid = old.id;
        END;

        CREATE TRIGGER IF NOT EXISTS embeddings_fts_update AFTER UPDATE ON embeddings BEGIN
            UPDATE embeddings_fts SET content = new.content WHERE rowid = new.id;
        END;
        """

        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let errorMsg = error.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(error)
            throw VectorStoreError.databaseError(errorMsg)
        }
    }

    public func store(
        chunkId: String,
        content: String,
        vector: [Float],
        metadata: String? = nil
    ) throws {
        guard vector.count == dimension else {
            throw VectorStoreError.vectorDimensionMismatch
        }

        let now = Date().timeIntervalSince1970

        let insertSQL = """
        INSERT OR REPLACE INTO embeddings (chunk_id, content, metadata, created_at)
        VALUES (?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError("Failed to prepare insert statement")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, chunkId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, content, -1, SQLITE_TRANSIENT)
        if let metadata = metadata {
            sqlite3_bind_text(stmt, 3, metadata, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        sqlite3_bind_double(stmt, 4, now)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw VectorStoreError.databaseError("Failed to insert embedding")
        }

        try storeVector(chunkId: chunkId, vector: vector)
    }

    private func storeVector(chunkId: String, vector: [Float]) throws {
        let vectorSQL = """
        INSERT OR REPLACE INTO embedding_vectors (chunk_id, vector)
        VALUES (?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, vectorSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError("Failed to prepare vector statement")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, chunkId, -1, SQLITE_TRANSIENT)

        let vectorData = vector.withUnsafeBytes { Data($0) }
        _ = vectorData.withUnsafeBytes { ptr in
            sqlite3_bind_blob(stmt, 2, ptr.baseAddress, Int32(vectorData.count), SQLITE_TRANSIENT)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw VectorStoreError.databaseError("Failed to store vector")
        }
    }

    public func searchText(_ query: String, limit: Int = 10) throws -> [SearchResult] {
        let sql = """
        SELECT e.chunk_id, e.content, e.metadata, e.created_at
        FROM embeddings_fts fts
        JOIN embeddings e ON fts.rowid = e.id
        WHERE embeddings_fts MATCH ?
        ORDER BY rank
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError("Failed to prepare search statement")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, query, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [SearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let chunkId = String(cString: sqlite3_column_text(stmt, 0))
            let content = String(cString: sqlite3_column_text(stmt, 1))
            let metadata = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let createdAt = sqlite3_column_double(stmt, 3)

            results.append(SearchResult(
                chunkId: chunkId,
                content: content,
                metadata: metadata,
                similarity: 1.0,
                createdAt: Date(timeIntervalSince1970: createdAt)
            ))
        }

        return results
    }

    public func searchVector(_ queryVector: [Float], limit: Int = 10) throws -> [SearchResult] {
        guard queryVector.count == dimension else {
            throw VectorStoreError.vectorDimensionMismatch
        }

        let sql = """
        SELECT e.chunk_id, e.content, e.metadata, e.created_at, v.vector
        FROM embeddings e
        JOIN embedding_vectors v ON e.chunk_id = v.chunk_id
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseError("Failed to prepare vector search")
        }
        defer { sqlite3_finalize(stmt) }

        var results: [(SearchResult, Float)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let chunkId = String(cString: sqlite3_column_text(stmt, 0))
            let content = String(cString: sqlite3_column_text(stmt, 1))
            let metadata = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let createdAt = sqlite3_column_double(stmt, 3)

            if let vectorPtr = sqlite3_column_blob(stmt, 4) {
                let vectorSize = sqlite3_column_bytes(stmt, 4)
                let vectorData = Data(bytes: vectorPtr, count: Int(vectorSize))
                let vector = vectorData.withUnsafeBytes {
                    Array(UnsafeBufferPointer<Float>(
                        start: $0.baseAddress?.assumingMemoryBound(to: Float.self),
                        count: Int(vectorSize) / MemoryLayout<Float>.size
                    ))
                }

                let similarity = cosineSimilarity(queryVector, vector)
                results.append((
                    SearchResult(
                        chunkId: chunkId,
                        content: content,
                        metadata: metadata,
                        similarity: similarity,
                        createdAt: Date(timeIntervalSince1970: createdAt)
                    ),
                    similarity
                ))
            }
        }

        return results.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }

    public func clear() throws {
        let sql = "DELETE FROM embeddings; DELETE FROM embedding_vectors;"
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let errorMsg = error.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(error)
            throw VectorStoreError.databaseError(errorMsg)
        }
    }
}

public struct SearchResult: Codable, Sendable {
    public let chunkId: String
    public let content: String
    public let metadata: String?
    public let similarity: Float
    public let createdAt: Date
}
