//
//  CLIDatabaseActor.swift
//  AnigmaCLIDatabase
//
//  Specialized database layer for anigma-cli with FTS5 + sqlite-vec support.
//  Provides hybrid retrieval (lexical + vector), run/receipt storage, and worktree leases.
//

import Foundation
import SQLite3
import CSQLiteVec

/// Configuration for CLI database with FTS5 and optional sqlite-vec support.
public struct CLIDatabaseConfig: Sendable {
    public let databasePath: String
    public let enableVectorSearch: Bool
    public let vectorExtensionPath: String?
    public let vectorExtensionHash: String?
    public let lexicalCandidateCount: Int
    public let embeddingDimension: Int
    
    public var path: String { databasePath }

    public init(
        databasePath: String = defaultDatabasePath(),
        enableVectorSearch: Bool = true,
        vectorExtensionPath: String? = nil,
        vectorExtensionHash: String? = nil,
        lexicalCandidateCount: Int = 50,
        embeddingDimension: Int = 384
    ) {
        self.databasePath = databasePath
        self.enableVectorSearch = enableVectorSearch
        self.vectorExtensionPath = vectorExtensionPath
        self.vectorExtensionHash = vectorExtensionHash
        self.lexicalCandidateCount = lexicalCandidateCount
        self.embeddingDimension = embeddingDimension
    }

    public static let `default` = CLIDatabaseConfig()

    public static func defaultDatabasePath() -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let anigmaDir = homeDir.appendingPathComponent(".anigma")
        try? FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)
        return anigmaDir.appendingPathComponent("cli.db").path
    }
}

/// Thread-safe database actor for anigma-cli with hybrid retrieval.
public actor CLIDatabaseActor {
    private let config: CLIDatabaseConfig
    private nonisolated(unsafe) var connection: OpaquePointer?
    private var vectorAvailable: Bool = false
    private var vectorVersion: String?

    // Metrics
    private var queryCount: Int = 0
    private var totalQueryTime: TimeInterval = 0

    public init(config: CLIDatabaseConfig = CLIDatabaseConfig()) {
        self.config = config
    }

    /// Open database and initialize schema.
    public func open() async throws {
        guard connection == nil else { return }

        var db: OpaquePointer?
        guard sqlite3_open(config.databasePath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw CLIDatabaseError.connectionFailed("Failed to open database: \(errMsg)")
        }
        connection = db

        // Configure SQLite for optimal performance
        try await configureSQLite()

        // Try to load vector extension if enabled
        if config.enableVectorSearch {
            await loadVectorExtension()
        }

        // Initialize schema
        try await initializeSchema()
    }

    private func configureSQLite() async throws {
        guard let _ = connection else { return }

        // Enable WAL mode for better concurrency
        try executeRaw("PRAGMA journal_mode=WAL;")

        // Set busy timeout
        try executeRaw("PRAGMA busy_timeout=5000;")

        // Enable foreign keys
        try executeRaw("PRAGMA foreign_keys=ON;")
    }

    private func loadVectorExtension() async {
        guard let db = connection else { return }

        // Load sqlite-vec extension
        var errMsg: UnsafeMutablePointer<Int8>?
        let result = sqlite3_vec_init(db, &errMsg, nil)

        if result == SQLITE_OK {
            vectorAvailable = true
            vectorVersion = await detectVectorVersion()
            logInfo("sqlite-vec loaded successfully (version: \(vectorVersion ?? "unknown"))")
        } else {
            let msg = errMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errMsg)
            logWarning("Failed to load sqlite-vec: \(msg)")
            vectorAvailable = false
        }
    }

    private func checkVectorAvailability() async -> Bool {
        // Try to detect if vec0 virtual table is available
        // This is a simple check that doesn't require loading extensions
        do {
            // Attempt to create a test vector table
            try executeRaw("CREATE VIRTUAL TABLE IF NOT EXISTS _vec_test USING vec0(embedding float[3]);")
            try executeRaw("DROP TABLE IF EXISTS _vec_test;")
            return true
        } catch {
            return false
        }
    }

    private func detectVectorVersion() async -> String? {
        // Query sqlite-vec version
        do {
            let rows = try await query("SELECT vec_version() as version")
            if let row = rows.first, let version = row["version"]?.asString {
                return version
            }
        } catch {
            // Fallback version detection
        }
        return "0.1.x"
    }

    private func initializeSchema() async throws {
        try await createRunsTable()
        try await createStepsTable()
        try await createReceiptsTable()
        try await createLeasesTable()
        try await createIndexMetadataTable()
        try await createDocumentChunksTable()
        try await createDocumentChunksFTS()

        if vectorAvailable {
            try await createEmbeddingsTable()
        }
    }

    // MARK: - Schema Creation

    private func createRunsTable() async throws {
        try executeRaw("""
            CREATE TABLE IF NOT EXISTS runs (
                run_id TEXT PRIMARY KEY,
                task_summary TEXT NOT NULL,
                task_details TEXT,
                mode TEXT NOT NULL,
                dry_run INTEGER NOT NULL,
                status TEXT NOT NULL,
                created_at REAL NOT NULL,
                completed_at REAL,
                spec_hash TEXT,
                worktree_path TEXT,
                base_commit TEXT
            );
            """)

        try executeRaw("CREATE INDEX IF NOT EXISTS idx_runs_created ON runs(created_at);")
        try executeRaw("CREATE INDEX IF NOT EXISTS idx_runs_status ON runs(status);")
    }

    private func createStepsTable() async throws {
        try executeRaw("""
            CREATE TABLE IF NOT EXISTS steps (
                step_id TEXT PRIMARY KEY,
                run_id TEXT NOT NULL,
                step_number INTEGER NOT NULL,
                action_type TEXT NOT NULL,
                action_data TEXT,
                status TEXT NOT NULL,
                created_at REAL NOT NULL,
                completed_at REAL,
                error_message TEXT,
                FOREIGN KEY(run_id) REFERENCES runs(run_id) ON DELETE CASCADE
            );
            """)

        try executeRaw("CREATE INDEX IF NOT EXISTS idx_steps_run ON steps(run_id, step_number);")
    }

    private func createReceiptsTable() async throws {
        try executeRaw("""
            CREATE TABLE IF NOT EXISTS receipts (
                receipt_id TEXT PRIMARY KEY,
                run_id TEXT NOT NULL,
                step_id TEXT,
                receipt_type TEXT NOT NULL,
                request_hash TEXT,
                response_hash TEXT,
                tool_metadata TEXT,
                created_at REAL NOT NULL,
                FOREIGN KEY(run_id) REFERENCES runs(run_id) ON DELETE CASCADE,
                FOREIGN KEY(step_id) REFERENCES steps(step_id) ON DELETE CASCADE
            );
            """)

        try executeRaw("CREATE INDEX IF NOT EXISTS idx_receipts_run ON receipts(run_id);")
        try executeRaw("CREATE INDEX IF NOT EXISTS idx_receipts_step ON receipts(step_id);")
    }

    private func createLeasesTable() async throws {
        try executeRaw("""
            CREATE TABLE IF NOT EXISTS worktree_leases (
                lease_id TEXT PRIMARY KEY,
                worktree_path TEXT NOT NULL UNIQUE,
                repo_root TEXT NOT NULL,
                base_commit TEXT,
                branch_name TEXT,
                run_id TEXT,
                created_at REAL NOT NULL,
                last_used_at REAL NOT NULL,
                intended_ttl_seconds INTEGER NOT NULL DEFAULT 259200,
                locked INTEGER NOT NULL DEFAULT 0,
                protected_reason TEXT,
                merged_status TEXT,
                removal_eligibility TEXT,
                FOREIGN KEY(run_id) REFERENCES runs(run_id) ON DELETE SET NULL
            );
            """)

        try executeRaw("CREATE INDEX IF NOT EXISTS idx_leases_repo ON worktree_leases(repo_root);")
        try executeRaw("CREATE INDEX IF NOT EXISTS idx_leases_run ON worktree_leases(run_id);")
    }

    private func createIndexMetadataTable() async throws {
        try executeRaw("""
            CREATE TABLE IF NOT EXISTS index_metadata (
                metadata_id TEXT PRIMARY KEY,
                repo_root TEXT NOT NULL,
                indexed_commit TEXT NOT NULL,
                chunk_count INTEGER NOT NULL,
                embedding_count INTEGER NOT NULL,
                chunking_params TEXT,
                embedding_model_id TEXT,
                embedding_model_hash TEXT,
                indexed_at REAL NOT NULL,
                UNIQUE(repo_root, indexed_commit)
            );
            """)

        try executeRaw("CREATE INDEX IF NOT EXISTS idx_index_meta_repo ON index_metadata(repo_root);")
    }

    private func createDocumentChunksTable() async throws {
        try executeRaw("""
            CREATE TABLE IF NOT EXISTS document_chunks (
                chunk_id TEXT PRIMARY KEY,
                document_path TEXT NOT NULL,
                section_title TEXT,
                chunk_text TEXT NOT NULL,
                chunk_hash TEXT NOT NULL,
                source_commit TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                created_at REAL NOT NULL
            );
            """)

        try executeRaw("CREATE INDEX IF NOT EXISTS idx_chunks_path ON document_chunks(document_path);")
        try executeRaw("CREATE INDEX IF NOT EXISTS idx_chunks_commit ON document_chunks(source_commit);")
        try executeRaw("CREATE INDEX IF NOT EXISTS idx_chunks_hash ON document_chunks(chunk_hash);")
    }

    private func createDocumentChunksFTS() async throws {
        // Create FTS5 virtual table for lexical search
        try executeRaw("""
            CREATE VIRTUAL TABLE IF NOT EXISTS document_chunks_fts USING fts5(
                chunk_text,
                section_title,
                content=document_chunks,
                content_rowid=rowid,
                tokenize='porter unicode61'
            );
            """)

        // Create triggers to keep FTS in sync
        try executeRaw("""
            CREATE TRIGGER IF NOT EXISTS document_chunks_ai AFTER INSERT ON document_chunks BEGIN
                INSERT INTO document_chunks_fts(rowid, chunk_text, section_title)
                VALUES (new.rowid, new.chunk_text, new.section_title);
            END;
            """)

        try executeRaw("""
            CREATE TRIGGER IF NOT EXISTS document_chunks_ad AFTER DELETE ON document_chunks BEGIN
                DELETE FROM document_chunks_fts WHERE rowid = old.rowid;
            END;
            """)

        try executeRaw("""
            CREATE TRIGGER IF NOT EXISTS document_chunks_au AFTER UPDATE ON document_chunks BEGIN
                DELETE FROM document_chunks_fts WHERE rowid = old.rowid;
                INSERT INTO document_chunks_fts(rowid, chunk_text, section_title)
                VALUES (new.rowid, new.chunk_text, new.section_title);
            END;
            """)
    }

    private func createEmbeddingsTable() async throws {
        // Create vec0 virtual table for vector search
        try executeRaw("""
            CREATE VIRTUAL TABLE IF NOT EXISTS embeddings_vec USING vec0(
                embedding_id TEXT PRIMARY KEY,
                chunk_id TEXT NOT NULL,
                model_id TEXT NOT NULL,
                vector FLOAT[\(config.embeddingDimension)]
            );
            """)

        // Create metadata table for embeddings
        try executeRaw("""
            CREATE TABLE IF NOT EXISTS embeddings_metadata (
                embedding_id TEXT PRIMARY KEY,
                chunk_id TEXT NOT NULL,
                model_id TEXT NOT NULL,
                dimension_count INTEGER NOT NULL,
                created_at REAL NOT NULL,
                UNIQUE(chunk_id, model_id),
                FOREIGN KEY(chunk_id) REFERENCES document_chunks(chunk_id) ON DELETE CASCADE
            );
            """)

        try executeRaw("CREATE INDEX IF NOT EXISTS idx_embeddings_meta_chunk ON embeddings_metadata(chunk_id);")
        try executeRaw("CREATE INDEX IF NOT EXISTS idx_embeddings_meta_model ON embeddings_metadata(model_id);")
    }

    // MARK: - Query Methods

    public func query(_ sql: String, parameters: [CLIParameter] = []) async throws -> [CLIRow] {
        guard let db = connection else {
            throw CLIDatabaseError.connectionFailed("Database not open")
        }

        let startTime = Date()
        defer {
            totalQueryTime += Date().timeIntervalSince(startTime)
            queryCount += 1
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw CLIDatabaseError.queryFailed("Failed to prepare: \(errMsg)")
        }
        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        try bindParameters(stmt: stmt, parameters: parameters)

        // Fetch rows
        var rows: [CLIRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(extractRow(stmt: stmt))
        }

        return rows
    }

    public func execute(_ sql: String, parameters: [CLIParameter] = []) async throws -> Int {
        guard let db = connection else {
            throw CLIDatabaseError.connectionFailed("Database not open")
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw CLIDatabaseError.queryFailed("Failed to prepare: \(errMsg)")
        }
        defer { sqlite3_finalize(stmt) }

        try bindParameters(stmt: stmt, parameters: parameters)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw CLIDatabaseError.queryFailed("Failed to execute: \(errMsg)")
        }

        return Int(sqlite3_changes(db))
    }

    private func executeRaw(_ sql: String) throws {
        guard let db = connection else {
            throw CLIDatabaseError.connectionFailed("Database not open")
        }

        var errMsg: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)

        if result != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errMsg)
            throw CLIDatabaseError.queryFailed("Execute failed: \(msg)")
        }
    }

    private func bindParameters(stmt: OpaquePointer?, parameters: [CLIParameter]) throws {
        for (index, param) in parameters.enumerated() {
            let idx = Int32(index + 1)
            switch param {
            case .text(let value):
                sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT)
            case .int(let value):
                sqlite3_bind_int64(stmt, idx, Int64(value))
            case .double(let value):
                sqlite3_bind_double(stmt, idx, value)
            case .blob(let data):
                _ = data.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(stmt, idx, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
                }
            case .null:
                sqlite3_bind_null(stmt, idx)
            }
        }
    }

    private func extractRow(stmt: OpaquePointer?) -> CLIRow {
        var values: [String: CLIValue] = [:]
        let columnCount = sqlite3_column_count(stmt)

        for i in 0..<columnCount {
            let columnName = String(cString: sqlite3_column_name(stmt, i))
            let columnType = sqlite3_column_type(stmt, i)

            switch columnType {
            case SQLITE_INTEGER:
                values[columnName] = .int(Int(sqlite3_column_int64(stmt, i)))
            case SQLITE_FLOAT:
                values[columnName] = .double(sqlite3_column_double(stmt, i))
            case SQLITE_TEXT:
                values[columnName] = .text(String(cString: sqlite3_column_text(stmt, i)))
            case SQLITE_BLOB:
                if let bytes = sqlite3_column_blob(stmt, i) {
                    let length = Int(sqlite3_column_bytes(stmt, i))
                    values[columnName] = .blob(Data(bytes: bytes, count: length))
                } else {
                    values[columnName] = .null
                }
            case SQLITE_NULL:
                values[columnName] = .null
            default:
                values[columnName] = .null
            }
        }

        return CLIRow(values: values)
    }

    // MARK: - Utilities

    public func isVectorAvailable() -> Bool {
        vectorAvailable
    }

    public func getVectorVersion() -> String? {
        vectorVersion
    }

    public nonisolated func close() {
        if let conn = connection {
            sqlite3_close_v2(conn)
        }
    }

    private func logInfo(_ message: String) {
        fputs("[CLIDatabase] \(message)\n", stderr)
    }

    private func logWarning(_ message: String) {
        fputs("[CLIDatabase] WARNING: \(message)\n", stderr)
    }

    // MARK: - Hybrid Search

    /// Perform hybrid search combining FTS5 (lexical) + vec0 (semantic)
    public func hybridSearch(
        query: String,
        queryEmbedding: [Float]? = nil,
        limit: Int = 10,
        lexicalWeight: Double = 0.3,
        semanticWeight: Double = 0.7
    ) async throws -> [HybridSearchResult] {
        // Step 1: Lexical search with FTS5
        let lexicalResults = try await lexicalSearch(query: query, limit: config.lexicalCandidateCount)

        // Step 2: If vector available and embedding provided, do semantic search
        var semanticResults: [SemanticSearchResult] = []
        if vectorAvailable, let embedding = queryEmbedding {
            semanticResults = try await semanticSearch(embedding: embedding, limit: config.lexicalCandidateCount)
        }

        // Step 3: Combine and rerank
        return try await combineResults(
            lexical: lexicalResults,
            semantic: semanticResults,
            lexicalWeight: lexicalWeight,
            semanticWeight: semanticWeight,
            limit: limit
        )
    }

    private func lexicalSearch(query queryText: String, limit: Int) async throws -> [LexicalSearchResult] {
        let sql = """
            SELECT
                dc.chunk_id,
                dc.document_path,
                dc.section_title,
                dc.chunk_text,
                fts.rank as score
            FROM document_chunks_fts fts
            JOIN document_chunks dc ON dc.rowid = fts.rowid
            WHERE document_chunks_fts MATCH ?
            ORDER BY rank
            LIMIT ?
            """

        let rows = try await query(sql, parameters: [.text(queryText), .int(limit)])

        return rows.compactMap { row in
            guard let chunkId = row["chunk_id"]?.asString,
                  let path = row["document_path"]?.asString,
                  let text = row["chunk_text"]?.asString,
                  let score = row["score"]?.asDouble else {
                return nil
            }

            return LexicalSearchResult(
                chunkId: chunkId,
                documentPath: path,
                sectionTitle: row["section_title"]?.asString,
                chunkText: text,
                score: score
            )
        }
    }

    private func semanticSearch(embedding: [Float], limit: Int) async throws -> [SemanticSearchResult] {
        // Convert embedding to vec0 format (blob of floats)
        let embeddingData = embedding.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }

        let sql = """
            SELECT
                em.chunk_id,
                dc.document_path,
                dc.section_title,
                dc.chunk_text,
                vec_distance_L2(ev.vector, ?) as distance
            FROM embeddings_vec ev
            JOIN embeddings_metadata em ON em.embedding_id = ev.embedding_id
            JOIN document_chunks dc ON dc.chunk_id = em.chunk_id
            ORDER BY distance
            LIMIT ?
            """

        let rows = try await query(sql, parameters: [.blob(embeddingData), .int(limit)])

        return rows.compactMap { row in
            guard let chunkId = row["chunk_id"]?.asString,
                  let path = row["document_path"]?.asString,
                  let text = row["chunk_text"]?.asString,
                  let distance = row["distance"]?.asDouble else {
                return nil
            }

            return SemanticSearchResult(
                chunkId: chunkId,
                documentPath: path,
                sectionTitle: row["section_title"]?.asString,
                chunkText: text,
                distance: distance
            )
        }
    }

    private func combineResults(
        lexical: [LexicalSearchResult],
        semantic: [SemanticSearchResult],
        lexicalWeight: Double,
        semanticWeight: Double,
        limit: Int
    ) async throws -> [HybridSearchResult] {
        var combined: [String: HybridSearchResult] = [:]

        // Normalize lexical scores (FTS rank is negative)
        let maxLexicalScore = lexical.map { abs($0.score) }.max() ?? 1.0

        for result in lexical {
            let normalizedScore = abs(result.score) / maxLexicalScore
            combined[result.chunkId] = HybridSearchResult(
                chunkId: result.chunkId,
                documentPath: result.documentPath,
                sectionTitle: result.sectionTitle,
                chunkText: result.chunkText,
                lexicalScore: normalizedScore,
                semanticScore: 0,
                combinedScore: normalizedScore * lexicalWeight
            )
        }

        // Normalize semantic scores (distance - lower is better, convert to similarity)
        let maxDistance = semantic.map { $0.distance }.max() ?? 1.0

        for result in semantic {
            let similarity = 1.0 - (result.distance / maxDistance)

            if var existing = combined[result.chunkId] {
                existing.semanticScore = similarity
                existing.combinedScore = existing.lexicalScore * lexicalWeight + similarity * semanticWeight
                combined[result.chunkId] = existing
            } else {
                combined[result.chunkId] = HybridSearchResult(
                    chunkId: result.chunkId,
                    documentPath: result.documentPath,
                    sectionTitle: result.sectionTitle,
                    chunkText: result.chunkText,
                    lexicalScore: 0,
                    semanticScore: similarity,
                    combinedScore: similarity * semanticWeight
                )
            }
        }

        return combined.values
            .sorted { $0.combinedScore > $1.combinedScore }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Supporting Types

public enum CLIParameter: Sendable {
    case text(String)
    case int(Int)
    case double(Double)
    case blob(Data)
    case null
}

public enum CLIValue: Sendable {
    case text(String)
    case int(Int)
    case double(Double)
    case blob(Data)
    case null

    public var asString: String? {
        if case .text(let v) = self { return v }
        return nil
    }

    public var asInt: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    public var asDouble: Double? {
        if case .double(let v) = self { return v }
        return nil
    }

    public var asData: Data? {
        if case .blob(let v) = self { return v }
        return nil
    }
}

public struct CLIRow: Sendable {
    public let values: [String: CLIValue]

    public subscript(column: String) -> CLIValue? {
        values[column]
    }
}

public enum CLIDatabaseError: Error, Sendable {
    case connectionFailed(String)
    case queryFailed(String)
    case vectorExtensionUnavailable
}

// MARK: - Search Result Types

public struct LexicalSearchResult: Sendable {
    public let chunkId: String
    public let documentPath: String
    public let sectionTitle: String?
    public let chunkText: String
    public let score: Double
}

public struct SemanticSearchResult: Sendable {
    public let chunkId: String
    public let documentPath: String
    public let sectionTitle: String?
    public let chunkText: String
    public let distance: Double
}

public struct HybridSearchResult: Sendable {
    public let chunkId: String
    public let documentPath: String
    public let sectionTitle: String?
    public let chunkText: String
    public var lexicalScore: Double
    public var semanticScore: Double
    public var combinedScore: Double
}

// SQLite constants
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: (@convention(c) (UnsafeMutableRawPointer?) -> Void).self)
