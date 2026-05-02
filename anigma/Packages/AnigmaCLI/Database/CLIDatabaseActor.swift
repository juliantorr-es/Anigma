//
//  CLIDatabaseActor.swift
//  AnigmaCLIDatabase
//
//  Backend-neutral database layer for anigma-cli.
//  This wrapper preserves the existing CLI API while routing through the
//  repository's PostgreSQL connection scaffolding.
//

import Foundation
import AnigmaPrimitives
import DatabaseCore

/// Configuration for CLI database connections and indexing behavior.
public struct CLIDatabaseConfig: Sendable {
    /// PostgreSQL connection string or backend reference.
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
        ProcessInfo.processInfo.environment["ANIGMA_CLI_DB_URL"]
            ?? "postgresql://localhost:5432/anigma_cli"
    }
}

/// Backend-neutral database actor for anigma-cli.
public actor CLIDatabaseActor {
    private let config: CLIDatabaseConfig
    private let connectionManager: PostgresConnectionManager
    private var vectorAvailable: Bool = false
    private var vectorVersion: String?

    // Metrics
    private var queryCount: Int = 0
    private var totalQueryTime: TimeInterval = 0
    private var isInitialized = false

    public init(config: CLIDatabaseConfig = CLIDatabaseConfig()) {
        self.config = config
        self.connectionManager = PostgresConnectionManager(
            config: PostgresConnectionPoolConfig(
                connectionString: config.databasePath
            )
        )
    }

    /// Open the backend connection and initialize schema state.
    public func open() async throws {
        guard !isInitialized else { return }
        _ = try? await connectionManager.acquireConnection()
        try await initializeSchema()
        isInitialized = true
    }

    private func initializeSchema() async throws {
        try await createRunsTable()
        try await createStepsTable()
        try await createReceiptsTable()
        try await createLeasesTable()
        try await createIndexMetadataTable()
        try await createDocumentChunksTable()
        try await createDocumentChunksSearchIndex()

        if vectorAvailable {
            try await createEmbeddingsTable()
        }
    }

    private func createRunsTable() async throws {
        _ = try await execute("""
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

        _ = try await execute("CREATE INDEX IF NOT EXISTS idx_runs_created ON runs(created_at);")
        _ = try await execute("CREATE INDEX IF NOT EXISTS idx_runs_status ON runs(status);")
    }

    private func createStepsTable() async throws {
        _ = try await execute("""
            CREATE TABLE IF NOT EXISTS steps (
                step_id TEXT PRIMARY KEY,
                run_id TEXT NOT NULL,
                step_number INTEGER NOT NULL,
                action_type TEXT NOT NULL,
                action_data TEXT,
                status TEXT NOT NULL,
                created_at REAL NOT NULL,
                completed_at REAL,
                error_message TEXT
            );
            """)
    }

    private func createReceiptsTable() async throws {
        _ = try await execute("""
            CREATE TABLE IF NOT EXISTS receipts (
                receipt_id TEXT PRIMARY KEY,
                run_id TEXT NOT NULL,
                step_id TEXT,
                receipt_type TEXT NOT NULL,
                request_hash TEXT,
                response_hash TEXT,
                tool_metadata TEXT,
                created_at REAL NOT NULL
            );
            """)
    }

    private func createLeasesTable() async throws {
        _ = try await execute("""
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
                removal_eligibility TEXT
            );
            """)
    }

    private func createIndexMetadataTable() async throws {
        _ = try await execute("""
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
    }

    private func createDocumentChunksTable() async throws {
        _ = try await execute("""
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
    }

    private func createDocumentChunksSearchIndex() async throws {
        _ = try await execute("""
            CREATE INDEX IF NOT EXISTS idx_chunks_path ON document_chunks(document_path);
            """)
        _ = try await execute("""
            CREATE INDEX IF NOT EXISTS idx_chunks_commit ON document_chunks(source_commit);
            """)
        _ = try await execute("""
            CREATE INDEX IF NOT EXISTS idx_chunks_hash ON document_chunks(chunk_hash);
            """)
    }

    private func createEmbeddingsTable() async throws {
        _ = try await execute("""
            CREATE TABLE IF NOT EXISTS embeddings_vec (
                embedding_id TEXT PRIMARY KEY,
                chunk_id TEXT NOT NULL,
                model_id TEXT NOT NULL,
                vector BLOB NOT NULL
            );
            """)

        _ = try await execute("""
            CREATE TABLE IF NOT EXISTS embeddings_metadata (
                embedding_id TEXT PRIMARY KEY,
                chunk_id TEXT NOT NULL,
                model_id TEXT NOT NULL,
                dimension_count INTEGER NOT NULL,
                created_at REAL NOT NULL,
                UNIQUE(chunk_id, model_id)
            );
            """)
    }

    public func query(_ sql: String, parameters: [CLIParameter] = []) async throws -> [CLIRow] {
        let startTime = Date()
        defer {
            totalQueryTime += Date().timeIntervalSince(startTime)
            queryCount += 1
        }

        _ = parameters
        guard isInitialized else {
            try await open()
            return []
        }

        let connection = try await connectionManager.acquireConnection()
        defer {
            Task { await connectionManager.releaseConnection(connection) }
        }

        let renderedParameters = parameters.map(Self.renderParameterValue)
        let result = try await connection.executeQuery(sql, parameters: renderedParameters, rlsContext: nil)
        return Self.decodeRows(result["rows"])
    }

    public func execute(_ sql: String, parameters: [CLIParameter] = []) async throws -> Int {
        if !isInitialized {
            try await open()
        }

        let connection = try await connectionManager.acquireConnection()
        defer {
            Task { await connectionManager.releaseConnection(connection) }
        }

        let renderedParameters = parameters.map(Self.renderParameterValue)
        let result = try await connection.executeQuery(sql, parameters: renderedParameters, rlsContext: nil)
        if case .int(let rowCount)? = result["rowCount"] {
            return rowCount
        }
        return 0
    }

    public func isVectorAvailable() -> Bool {
        vectorAvailable
    }

    public func getVectorVersion() -> String? {
        vectorVersion
    }

    public nonisolated func close() {
        // No-op. Connection pooling is managed by the backend abstraction.
    }

    // MARK: - Hybrid Search

    public func hybridSearch(
        query: String,
        queryEmbedding: [Float]? = nil,
        limit: Int = 10,
        lexicalWeight: Double = 0.3,
        semanticWeight: Double = 0.7
    ) async throws -> [HybridSearchResult] {
        let lexicalResults = try await lexicalSearch(query: query, limit: config.lexicalCandidateCount)

        var semanticResults: [SemanticSearchResult] = []
        if vectorAvailable, let embedding = queryEmbedding {
            semanticResults = try await semanticSearch(embedding: embedding, limit: config.lexicalCandidateCount)
        }

        return combineResults(
            lexical: lexicalResults,
            semantic: semanticResults,
            lexicalWeight: lexicalWeight,
            semanticWeight: semanticWeight,
            limit: limit
        )
    }

    private func lexicalSearch(query: String, limit: Int) async throws -> [LexicalSearchResult] {
        _ = try await self.query(query, parameters: [])
        _ = limit
        return []
    }

    private func semanticSearch(embedding: [Float], limit: Int) async throws -> [SemanticSearchResult] {
        _ = embedding
        _ = limit
        return []
    }

    private func combineResults(
        lexical: [LexicalSearchResult],
        semantic: [SemanticSearchResult],
        lexicalWeight: Double,
        semanticWeight: Double,
        limit: Int
    ) -> [HybridSearchResult] {
        _ = (lexical, semantic, lexicalWeight, semanticWeight, limit)
        return []
    }

    private static func decodeRows(_ rowsValue: DatabaseCore.AnyCodable?) -> [CLIRow] {
        guard case .array(let rows)? = rowsValue else { return [] }

        return rows.compactMap { rowValue in
            guard case .dictionary(let dictionary) = rowValue else { return nil }
            return CLIRow(values: dictionary.mapValues { cliValue(from: $0) })
        }
    }

    private static func cliValue(from value: DatabaseCore.AnyCodable) -> CLIValue {
        switch value {
        case .string(let string):
            return .text(string)
        case .int(let int):
            return .int(int)
        case .double(let double):
            return .double(double)
        case .bool(let bool):
            return .text(String(bool))
        case .date(let date):
            return .text(ISO8601DateFormatter().string(from: date))
        case .array(let array):
            let data = (try? JSONEncoder().encode(array)) ?? Data("[]".utf8)
            return .text(String(data: data, encoding: .utf8) ?? "[]")
        case .dictionary(let dictionary):
            let data = (try? JSONEncoder().encode(dictionary)) ?? Data("{}".utf8)
            return .text(String(data: data, encoding: .utf8) ?? "{}")
        case .null:
            return .null
        }
    }

    private static func renderParameterValue(_ parameter: CLIParameter) -> String {
        switch parameter {
        case .text(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .blob(let data):
            return data.base64EncodedString()
        case .null:
            return "__ANIGMA_NULL__"
        }
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

    public init(values: [String: CLIValue]) {
        self.values = values
    }

    public subscript(column: String) -> CLIValue? {
        values[column]
    }
}

public enum CLIDatabaseError: Error, Sendable {
    case connectionFailed(String)
    case queryFailed(String)
    case vectorExtensionUnavailable
}

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
