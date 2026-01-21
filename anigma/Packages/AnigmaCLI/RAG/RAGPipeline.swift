import Foundation
import SQLite3

@available(macOS 13.0, *)
public actor RAGPipeline {
    private let dbPath: String
    private var dbHandle: DBHandle?
    private var db: OpaquePointer? { dbHandle?.pointer }
    private let chunkSize: Int
    private let overlapSize: Int

    private final class DBHandle: @unchecked Sendable {
        let pointer: OpaquePointer

        init(pointer: OpaquePointer) {
            self.pointer = pointer
        }

        deinit {
            sqlite3_close(pointer)
        }
    }

    public init(dbPath: String, chunkSize: Int = 512, overlapSize: Int = 128) {
        self.dbPath = dbPath
        self.chunkSize = chunkSize
        self.overlapSize = overlapSize
    }

    public func initialize() async throws {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let dbPtr = db else {
            throw RAGError.databaseError("Failed to open database")
        }
        self.dbHandle = DBHandle(pointer: dbPtr)
        try await createTables()
    }

    private func createTables() async throws {
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
            "CREATE INDEX IF NOT EXISTS idx_chunks_file ON code_chunks(file_path)",
            "CREATE INDEX IF NOT EXISTS idx_chunks_language ON code_chunks(language)"
        ]

        for schema in schemas {
            try execute(schema)
        }
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
        }
    }

    private func insertChunk(_ chunk: CodeChunk) throws -> Int64 {
        let sql = "INSERT INTO code_chunks (file_path, content, start_line, end_line, language, chunk_type, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw RAGError.databaseError("Failed to prepare chunk insert")
        }

        sqlite3_bind_text(stmt, 1, chunk.filePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, chunk.content, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int64(stmt, 3, Int64(chunk.startLine))
        sqlite3_bind_int64(stmt, 4, Int64(chunk.endLine))
        sqlite3_bind_text(stmt, 5, chunk.language, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 6, chunk.chunkType, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 7, "{}", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw RAGError.databaseError("Failed to insert chunk")
        }

        return sqlite3_last_insert_rowid(db)
    }

    private func insertFTS(chunkId: Int64, chunk: CodeChunk) throws {
        let sql = "INSERT INTO code_chunks_fts (rowid, file_path, content, language, chunk_type) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw RAGError.databaseError("Failed to prepare FTS insert")
        }

        sqlite3_bind_int64(stmt, 1, chunkId)
        sqlite3_bind_text(stmt, 2, chunk.filePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 3, chunk.content, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 4, chunk.language, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 5, chunk.chunkType, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw RAGError.databaseError("Failed to insert FTS")
        }
    }

    public func search(query: String, limit: Int = 5, useVector: Bool = true) async throws -> [SearchResult] {
        return try searchFTS(query: query, limit: limit)
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
            throw RAGError.databaseError("Failed to prepare FTS search")
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

    private func execute(_ sql: String) throws {
        var errorMsg: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(db, sql, nil, nil, &errorMsg) == SQLITE_OK else {
            let msg = errorMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMsg)
            throw RAGError.databaseError(msg)
        }
    }

    // DBHandle handles closing
}

// CodeChunk, SearchResult, and SearchSource moved to VectorRAGPipeline.swift to avoid duplication

public enum RAGError: Error, CustomStringConvertible {
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
