//
//  CodeIndexStore.swift
//  HarmoniaModule
//
//  SQLite storage for indexed code chunks with FTS5 full-text search.
//  Separate database file for code indexing (isolated from general memory).
//

import Foundation
import GRDB

// MARK: - Code Index Configuration

/// Configuration for the code index store.
public struct CodeIndexConfig: Sendable {
    /// Path to SQLite database file.
    public let databasePath: String

    /// Whether to enable FTS5 full-text search.
    public let enableFTS: Bool

    /// Default configuration (stores in ~/.harmonia/code_index.db).
    public static let `default` = CodeIndexConfig(
        databasePath: "~/.harmonia/code_index.db",
        enableFTS: true
    )

    public init(
        databasePath: String = "~/.harmonia/code_index.db",
        enableFTS: Bool = true
    ) {
        self.databasePath = databasePath
        self.enableFTS = enableFTS
    }
}

// MARK: - Code Chunk Model

/// A semantic chunk of code extracted from a source file.
public struct CodeChunk: Sendable, Codable {
    /// Unique identifier (UUID).
    public let id: String

    /// File path relative to project root.
    public let path: String

    /// Programming language (e.g., "swift").
    public let language: String

    /// Symbol name (function name, class name, etc.).
    public let symbolName: String?

    /// Symbol kind (function, class, struct, enum, protocol, extension, property).
    public let symbolKind: String?

    /// Starting line number (1-indexed).
    public let startLine: Int

    /// Ending line number (inclusive).
    public let endLine: Int

    /// The chunk content (code snippet).
    public let content: String

    /// File hash for change detection (size + modification date).
    public let fileHash: String

    /// When this chunk was indexed.
    public let indexedAt: Date

    public init(
        id: String = UUID().uuidString,
        path: String,
        language: String,
        symbolName: String? = nil,
        symbolKind: String? = nil,
        startLine: Int,
        endLine: Int,
        content: String,
        fileHash: String,
        indexedAt: Date = Date()
    ) {
        self.id = id
        self.path = path
        self.language = language
        self.symbolName = symbolName
        self.symbolKind = symbolKind
        self.startLine = startLine
        self.endLine = endLine
        self.content = content
        self.fileHash = fileHash
        self.indexedAt = indexedAt
    }
}

// MARK: - GRDB Record Conformance

extension CodeChunk: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "code_chunks" }

    public enum Columns {
        static let id = Column("id")
        static let path = Column("path")
        static let language = Column("language")
        static let symbolName = Column("symbol_name")
        static let symbolKind = Column("symbol_kind")
        static let startLine = Column("start_line")
        static let endLine = Column("end_line")
        static let content = Column("content")
        static let fileHash = Column("file_hash")
        static let indexedAt = Column("indexed_at")
    }

    public init(row: Row) throws {
        id = row[Columns.id]
        path = row[Columns.path]
        language = row[Columns.language]
        symbolName = row[Columns.symbolName]
        symbolKind = row[Columns.symbolKind]
        startLine = row[Columns.startLine]
        endLine = row[Columns.endLine]
        content = row[Columns.content]
        fileHash = row[Columns.fileHash]
        indexedAt = row[Columns.indexedAt]
    }

    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.path] = path
        container[Columns.language] = language
        container[Columns.symbolName] = symbolName
        container[Columns.symbolKind] = symbolKind
        container[Columns.startLine] = startLine
        container[Columns.endLine] = endLine
        container[Columns.content] = content
        container[Columns.fileHash] = fileHash
        container[Columns.indexedAt] = indexedAt
    }
}

// MARK: - Code Index Store

/// SQLite store for indexed code chunks with FTS5 full-text search.
public actor CodeIndexStore {
    private let config: CodeIndexConfig
    private var dbPool: DatabasePool?
    private var isInitialized = false

    public init(config: CodeIndexConfig = .default) {
        self.config = config
    }

    /// Initialize the database connection and create tables.
    public func initialize() throws {
        guard !isInitialized else { return }

        let databasePath = expandDatabasePath(config.databasePath)
        let databaseURL = URL(fileURLWithPath: databasePath)

        // Ensure parent directory exists
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var configuration = Configuration()
        configuration.prepareDatabase { db in
            // Enable write-ahead logging for better concurrency
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            // Enable foreign keys
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        dbPool = try DatabasePool(path: databaseURL.path, configuration: configuration)

        // Create tables
        try migrate()

        isInitialized = true
    }

    /// Creates or migrates database schema.
    private func migrate() throws {
        guard let pool = dbPool else {
            throw CodeIndexError.databaseNotInitialized
        }

        try pool.write { db in
            // Create code_chunks table
            try db.create(table: "code_chunks", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("path", .text).notNull().indexed()
                t.column("language", .text).notNull().indexed()
                t.column("symbol_name", .text)
                t.column("symbol_kind", .text)
                t.column("start_line", .integer).notNull()
                t.column("end_line", .integer).notNull()
                t.column("content", .text).notNull()
                t.column("file_hash", .text).notNull().indexed()
                t.column("indexed_at", .datetime).notNull().defaults(to: "CURRENT_TIMESTAMP")
            }

            // Create FTS5 virtual table for full-text search
            if config.enableFTS {
                try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS code_chunks_fts USING fts5(
                    path,
                    language,
                    symbol_name,
                    symbol_kind,
                    content,
                    content='code_chunks',
                    content_rowid='rowid'
                )
                """)

                // Create triggers to keep FTS index updated
                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS code_chunks_ai AFTER INSERT ON code_chunks BEGIN
                    INSERT INTO code_chunks_fts(rowid, path, language, symbol_name, symbol_kind, content)
                    VALUES (new.rowid, new.path, new.language, new.symbol_name, new.symbol_kind, new.content);
                END;
                """)

                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS code_chunks_ad AFTER DELETE ON code_chunks BEGIN
                    INSERT INTO code_chunks_fts(code_chunks_fts, rowid, path, language, symbol_name, symbol_kind, content)
                    VALUES('delete', old.rowid, old.path, old.language, old.symbol_name, old.symbol_kind, old.content);
                END;
                """)

                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS code_chunks_au AFTER UPDATE ON code_chunks BEGIN
                    INSERT INTO code_chunks_fts(code_chunks_fts, rowid, path, language, symbol_name, symbol_kind, content)
                    VALUES('delete', old.rowid, old.path, old.language, old.symbol_name, old.symbol_kind, old.content);
                    INSERT INTO code_chunks_fts(rowid, path, language, symbol_name, symbol_kind, content)
                    VALUES (new.rowid, new.path, new.language, new.symbol_name, new.symbol_kind, new.content);
                END;
                """)
            }

            // Create index for faster file lookups
            try db.create(index: "idx_code_chunks_path", on: "code_chunks", columns: ["path"], ifNotExists: true)
            try db.create(index: "idx_code_chunks_file_hash", on: "code_chunks", columns: ["file_hash"], ifNotExists: true)
        }
    }

    /// Index a file by storing its semantic chunks.
    /// - Parameters:
    ///   - path: File path relative to project root.
    ///   - language: Programming language (e.g., "swift").
    ///   - chunks: Array of code chunks extracted from the file.
    ///   - fileHash: Hash of file content for change detection.
    /// - Returns: Number of chunks inserted.
    @discardableResult
    public func indexFile(
        path: String,
        language: String,
        chunks: [CodeChunk],
        fileHash: String
    ) throws -> Int {
        guard let pool = dbPool else {
            throw CodeIndexError.databaseNotInitialized
        }

        // Delete existing chunks for this file
        _ = try pool.write { db in
            try CodeChunk
                .filter(CodeChunk.Columns.path == path)
                .deleteAll(db)
        }

        // Insert new chunks
        var inserted = 0
        try pool.write { db in
            for chunk in chunks {
                try chunk.insert(db)
                inserted += 1
            }
        }

        return inserted
    }

    /// Search code chunks using full-text search.
    /// - Parameters:
    ///   - query: FTS5 search query (supports operators: AND, OR, NOT, prefix*).
    ///   - limit: Maximum number of results.
    /// - Returns: Array of matching code chunks.
    public func searchChunks(query: String, limit: Int = 50) throws -> [CodeChunk] {
        guard let pool = dbPool else {
            throw CodeIndexError.databaseNotInitialized
        }

        guard config.enableFTS else {
            throw CodeIndexError.ftsNotEnabled
        }

        return try pool.read { db in
            let sql = """
            SELECT c.* FROM code_chunks c
            JOIN code_chunks_fts f ON c.rowid = f.rowid
            WHERE code_chunks_fts MATCH ?
            ORDER BY rank
            LIMIT ?
            """
            return try CodeChunk.fetchAll(db, sql: sql, arguments: [query, limit])
        }
    }

    /// Get all chunks for a specific file.
    /// - Parameter path: File path.
    /// - Returns: Array of code chunks for that file.
    public func getChunksForFile(path: String) throws -> [CodeChunk] {
        guard let pool = dbPool else {
            throw CodeIndexError.databaseNotInitialized
        }

        return try pool.read { db in
            try CodeChunk
                .filter(CodeChunk.Columns.path == path)
                .order(CodeChunk.Columns.startLine)
                .fetchAll(db)
        }
    }

    /// Delete all chunks for a file.
    /// - Parameter path: File path.
    /// - Returns: Number of chunks deleted.
    @discardableResult
    public func deleteFileChunks(path: String) throws -> Int {
        guard let pool = dbPool else {
            throw CodeIndexError.databaseNotInitialized
        }

        return try pool.write { db in
            try CodeChunk
                .filter(CodeChunk.Columns.path == path)
                .deleteAll(db)
        }
    }

    /// Compute a hash for file change detection.
    /// - Parameter fileURL: URL to the file.
    /// - Returns: Hash string combining file size and modification date.
    public static func computeFileHash(for fileURL: URL) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let size = attributes[.size] as? Int64,
              let modDate = attributes[.modificationDate] as? Date else {
            throw CodeIndexError.cannotComputeFileHash
        }
        // Simple hash combining size and timestamp
        return "\(size):\(modDate.timeIntervalSince1970)"
    }

    /// Expand database path (supports ~ for home directory).
    private func expandDatabasePath(_ path: String) -> String {
        if path.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return home + path.dropFirst(1)
        }
        return path
    }

    /// Close the database connection.
    public func close() {
        dbPool = nil
        isInitialized = false
    }
}

// MARK: - Errors

public enum CodeIndexError: LocalizedError {
    case databaseNotInitialized
    case ftsNotEnabled
    case cannotComputeFileHash

    public var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "Database not initialized. Call initialize() first."
        case .ftsNotEnabled:
            return "FTS5 full-text search is not enabled in configuration."
        case .cannotComputeFileHash:
            return "Cannot compute file hash (missing size or modification date)."
        }
    }
}
