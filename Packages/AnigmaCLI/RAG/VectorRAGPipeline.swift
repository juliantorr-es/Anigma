import Foundation
import SQLite3
import CSQLiteVec

/// Extended RAG pipeline with vector embedding support
@available(macOS 13.0, *)
public actor VectorRAGPipeline {
    private let dbPath: String
    private var dbHandle: DBHandle?
    private var db: OpaquePointer? { dbHandle?.pointer }
    private let chunkSize: Int
    private let overlapSize: Int
    private let embeddingProvider: EmbeddingProviderProtocol?

    private final class DBHandle: @unchecked Sendable {
        let pointer: OpaquePointer

        init(pointer: OpaquePointer) {
            self.pointer = pointer
        }

        deinit {
            sqlite3_close(pointer)
        }
    }

    public init(
        dbPath: String,
        chunkSize: Int = 512,
        overlapSize: Int = 128,
        embeddingProvider: EmbeddingProviderProtocol? = nil
    ) {
        self.dbPath = dbPath
        self.chunkSize = chunkSize
        self.overlapSize = overlapSize
        self.embeddingProvider = embeddingProvider
    }

    public func initialize() async throws {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let dbPtr = db else {
            throw VectorRAGError.databaseError("Failed to open database")
        }

        // Initialize sqlite-vec
        var errMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_vec_init(dbPtr, &errMsg, nil)
        if result != SQLITE_OK {
            let message = errMsg.map { String(cString: $0) } ?? "Unknown error initializing sqlite-vec"
            sqlite3_free(errMsg)
            sqlite3_close(dbPtr)
            throw VectorRAGError.databaseError(message)
        }

        self.dbHandle = DBHandle(pointer: dbPtr)
        try await createTables()
    }

    private func createTables() async throws {
        // Load sqlite-vec extension
        try loadVecExtension()

        let schemas = [
            """
            CREATE TABLE IF NOT EXISTS code_chunks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_path TEXT NOT NULL,
                content TEXT NOT NULL,
                start_line INTEGER NOT NULL,
                end_line INTEGER NOT NULL,
                language TEXT,
                chunk_type TEXT,
                metadata TEXT,
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            )
            """,
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS code_chunks_fts USING fts5(
                file_path, content, language, chunk_type,
                tokenize = 'porter unicode61'
            )
            """,
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS code_embeddings USING vec0(
                chunk_id INTEGER PRIMARY KEY,
                embedding FLOAT[384]
            )
            """,
            "CREATE INDEX IF NOT EXISTS idx_chunks_file ON code_chunks(file_path)",
            "CREATE INDEX IF NOT EXISTS idx_chunks_language ON code_chunks(language)"
        ]

        for schema in schemas {
            try execute(schema)
        }
    }

    private func loadVecExtension() throws {
        // sqlite-vec is compiled into the CSQLiteVec module
        // The extension is automatically available
    }

    public func chunkFile(path: String, content: String, language: String) async throws -> [CodeChunk] {
        let lines = content.components(separatedBy: .newlines)
        var chunks: [CodeChunk] = []
        var currentChunk: [String] = []
        var startLine = 1

        for (index, line) in lines.enumerated() {
            currentChunk.append(line)

            if currentChunk.count >= chunkSize {
                let chunkContent = currentChunk.joined(separator: "\n")
                chunks.append(CodeChunk(
                    filePath: path,
                    content: chunkContent,
                    startLine: startLine,
                    endLine: index + 1,
                    language: language,
                    chunkType: detectChunkType(content: chunkContent)
                ))

                let overlap = min(overlapSize, currentChunk.count)
                currentChunk = Array(currentChunk.suffix(overlap))
                startLine = index + 1 - overlap
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(CodeChunk(
                filePath: path,
                content: currentChunk.joined(separator: "\n"),
                startLine: startLine,
                endLine: lines.count,
                language: language,
                chunkType: detectChunkType(content: currentChunk.joined(separator: "\n"))
            ))
        }

        return chunks
    }

    private func detectChunkType(content: String) -> String {
        if content.contains("func ") || content.contains("def ") { return "function" }
        if content.contains("class ") || content.contains("struct ") { return "type" }
        if content.contains("import ") { return "import" }
        if content.contains("//") || content.contains("/*") { return "comment" }
        return "code"
    }

    public func indexChunks(_ chunks: [CodeChunk]) async throws {
        for chunk in chunks {
            let chunkId = try insertChunk(chunk)
            try insertFTS(chunkId: chunkId, chunk: chunk)

            // Generate and store embedding if provider available
            if let provider = embeddingProvider {
                let embedding = try await provider.generateEmbedding(text: chunk.content)
                try insertEmbedding(chunkId: chunkId, embedding: embedding)
            }
        }
    }

    private func insertChunk(_ chunk: CodeChunk) throws -> Int64 {
        let sql = "INSERT INTO code_chunks (file_path, content, start_line, end_line, language, chunk_type, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorRAGError.databaseError("Failed to prepare chunk insert")
        }

        sqlite3_bind_text(stmt, 1, chunk.filePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, chunk.content, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int64(stmt, 3, Int64(chunk.startLine))
        sqlite3_bind_int64(stmt, 4, Int64(chunk.endLine))
        sqlite3_bind_text(stmt, 5, chunk.language, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 6, chunk.chunkType, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 7, "{}", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw VectorRAGError.databaseError("Failed to insert chunk")
        }

        return sqlite3_last_insert_rowid(db)
    }

    private func insertFTS(chunkId: Int64, chunk: CodeChunk) throws {
        let sql = "INSERT INTO code_chunks_fts (rowid, file_path, content, language, chunk_type) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorRAGError.databaseError("Failed to prepare FTS insert")
        }

        sqlite3_bind_int64(stmt, 1, chunkId)
        sqlite3_bind_text(stmt, 2, chunk.filePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 3, chunk.content, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 4, chunk.language, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 5, chunk.chunkType, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw VectorRAGError.databaseError("Failed to insert FTS")
        }
    }

    private func insertEmbedding(chunkId: Int64, embedding: [Float]) throws {
        // Convert embedding to blob
        let data = embedding.withUnsafeBytes { Data($0) }

        let sql = "INSERT INTO code_embeddings (chunk_id, embedding) VALUES (?, ?)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorRAGError.databaseError("Failed to prepare embedding insert")
        }

        sqlite3_bind_int64(stmt, 1, chunkId)
        _ = data.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw VectorRAGError.databaseError("Failed to insert embedding")
        }
    }

    public func search(query: String, limit: Int = 5, useVector: Bool = true) async throws -> [SearchResult] {
        if useVector, let provider = embeddingProvider {
            return try await searchHybrid(query: query, limit: limit, provider: provider)
        } else {
            return try searchFTS(query: query, limit: limit)
        }
    }

    private func searchFTS(query: String, limit: Int) throws -> [SearchResult] {
        let sql = """
            SELECT c.id, c.file_path, c.content, c.start_line, c.end_line, c.language, c.chunk_type, fts.rank
            FROM code_chunks_fts fts JOIN code_chunks c ON fts.rowid = c.id
            WHERE code_chunks_fts MATCH ? ORDER BY rank LIMIT ?
            """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorRAGError.databaseError("Failed to prepare FTS search")
        }

        sqlite3_bind_text(stmt, 1, query, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [SearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(SearchResult(
                chunkId: sqlite3_column_int64(stmt, 0),
                filePath: String(cString: sqlite3_column_text(stmt, 1)),
                content: String(cString: sqlite3_column_text(stmt, 2)),
                startLine: Int(sqlite3_column_int64(stmt, 3)),
                endLine: Int(sqlite3_column_int64(stmt, 4)),
                language: String(cString: sqlite3_column_text(stmt, 5)),
                chunkType: String(cString: sqlite3_column_text(stmt, 6)),
                score: Double(sqlite3_column_double(stmt, 7)),
                source: .fts
            ))
        }

        return results
    }

    private func searchHybrid(query: String, limit: Int, provider: EmbeddingProviderProtocol) async throws -> [SearchResult] {
        // Get FTS results
        let ftsResults = try searchFTS(query: query, limit: limit * 2)

        // Get vector results
        let queryEmbedding = try await provider.generateEmbedding(text: query)
        let vectorResults = try searchVector(embedding: queryEmbedding, limit: limit * 2)

        // Merge and re-rank
        var merged = [Int64: SearchResult]()
        for result in ftsResults {
            merged[result.chunkId] = result
        }
        for result in vectorResults {
            if var existing = merged[result.chunkId] {
                existing.score = (existing.score + result.score) / 2.0
                existing.source = .hybrid
                merged[result.chunkId] = existing
            } else {
                merged[result.chunkId] = result
            }
        }

        return Array(merged.values)
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    private func searchVector(embedding: [Float], limit: Int) throws -> [SearchResult] {
        let data = embedding.withUnsafeBytes { Data($0) }

        let sql = """
            SELECT c.id, c.file_path, c.content, c.start_line, c.end_line, c.language, c.chunk_type,
                   vec_distance_cosine(e.embedding, ?) as distance
            FROM code_embeddings e
            JOIN code_chunks c ON e.chunk_id = c.id
            ORDER BY distance
            LIMIT ?
            """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorRAGError.databaseError("Failed to prepare vector search")
        }

        _ = data.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 1, bytes.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [SearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let distance = sqlite3_column_double(stmt, 7)
            results.append(SearchResult(
                chunkId: sqlite3_column_int64(stmt, 0),
                filePath: String(cString: sqlite3_column_text(stmt, 1)),
                content: String(cString: sqlite3_column_text(stmt, 2)),
                startLine: Int(sqlite3_column_int64(stmt, 3)),
                endLine: Int(sqlite3_column_int64(stmt, 4)),
                language: String(cString: sqlite3_column_text(stmt, 5)),
                chunkType: String(cString: sqlite3_column_text(stmt, 6)),
                score: 1.0 - distance, // Convert distance to similarity
                source: .vector
            ))
        }

        return results
    }

    private func execute(_ sql: String) throws {
        var errorMsg: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(db, sql, nil, nil, &errorMsg) == SQLITE_OK else {
            let msg = errorMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMsg)
            throw VectorRAGError.databaseError(msg)
        }
    }

    // Deinit handled by DBHandle
}

public protocol EmbeddingProviderProtocol: Sendable {
    func generateEmbedding(text: String) async throws -> [Float]
}

public struct CodeChunk: Sendable {
    public let filePath: String
    public let content: String
    public let startLine: Int
    public let endLine: Int
    public let language: String
    public let chunkType: String

    public init(filePath: String, content: String, startLine: Int, endLine: Int, language: String, chunkType: String) {
        self.filePath = filePath
        self.content = content
        self.startLine = startLine
        self.endLine = endLine
        self.language = language
        self.chunkType = chunkType
    }
}

public struct SearchResult: Sendable {
    public let chunkId: Int64
    public let filePath: String
    public let content: String
    public let startLine: Int
    public let endLine: Int
    public let language: String
    public let chunkType: String
    public var score: Double
    public var source: SearchSource
}

public enum SearchSource: Sendable {
    case fts
    case vector
    case hybrid
}

public enum VectorRAGError: Error, CustomStringConvertible {
    case databaseError(String)
    case embeddingError(String)
    case invalidQuery(String)

    public var description: String {
        switch self {
        case .databaseError(let msg): return "Database error: \(msg)"
        case .embeddingError(let msg): return "Embedding error: \(msg)"
        case .invalidQuery(let msg): return "Invalid query: \(msg)"
        }
    }
}
