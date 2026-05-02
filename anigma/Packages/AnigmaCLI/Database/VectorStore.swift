import Foundation
import AnigmaPrimitives
import DatabaseCore

/// PostgreSQL-backed vector storage for CLI embeddings and similarity search.
public actor VectorStore {
    public static let version: String = "postgres-1.0.0"

    private let connectionManager: PostgresConnectionManager
    private let dimension: Int
    private var isInitialized = false

    public struct Statistics: Sendable {
        public let totalChunks: Int64
        public let indexedFiles: Int64
        public let languages: [String: Int64]

        public init(totalChunks: Int64, indexedFiles: Int64, languages: [String: Int64]) {
            self.totalChunks = totalChunks
            self.indexedFiles = indexedFiles
            self.languages = languages
        }
    }

    public static func registerExtension(with _: UnsafeMutableRawPointer) throws {
        // PostgreSQL does not need an extension hook here.
    }

    public init(dbPath: String, dimension: Int = 384) async throws {
        self.connectionManager = PostgresConnectionManager(
            config: PostgresConnectionPoolConfig(connectionString: dbPath)
        )
        self.dimension = dimension
        try await initialize()
    }

    private func initialize() async throws {
        guard !isInitialized else { return }

        let schema = """
        CREATE TABLE IF NOT EXISTS embeddings (
            chunk_id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            metadata TEXT,
            vector_json TEXT NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        """
        _ = try await execute(schema)

        _ = try await execute("CREATE INDEX IF NOT EXISTS idx_embeddings_created ON embeddings(created_at DESC);")
        _ = try await execute("CREATE INDEX IF NOT EXISTS idx_embeddings_content ON embeddings USING gin (to_tsvector('english', content));")
        isInitialized = true
    }

    public func store(
        chunkId: String,
        content: String,
        vector: [Float],
        metadata: String? = nil
    ) async throws {
        guard vector.count == dimension else {
            throw VectorStoreError.vectorDimensionMismatch
        }

        let vectorJSON = try encodeVector(vector)
        let metadataValue = metadata ?? "__ANIGMA_NULL__"

        _ = try await execute(
            """
            INSERT INTO embeddings (chunk_id, content, metadata, vector_json)
            VALUES (?, ?, ?, ?)
            ON CONFLICT (chunk_id) DO UPDATE SET
                content = EXCLUDED.content,
                metadata = EXCLUDED.metadata,
                vector_json = EXCLUDED.vector_json,
                created_at = CURRENT_TIMESTAMP
            """,
            parameters: [chunkId, content, metadataValue, vectorJSON]
        )
    }

    public func searchText(_ query: String, limit: Int = 10) async throws -> [SearchResult] {
        let pattern = "%\(query)%"
        let rows = try await fetchRows(
            """
            SELECT
                chunk_id,
                content,
                metadata,
                EXTRACT(EPOCH FROM created_at)::double precision AS created_at_epoch
            FROM embeddings
            WHERE content ILIKE ? OR COALESCE(metadata, '') ILIKE ?
            ORDER BY created_at DESC
            LIMIT \(limit)
            """,
            parameters: [pattern, pattern]
        )

        return rows.compactMap { row in
            makeSearchResult(from: row, similarity: 1.0)
        }
    }

    public func searchVector(_ queryVector: [Float], limit: Int = 10) async throws -> [SearchResult] {
        guard queryVector.count == dimension else {
            throw VectorStoreError.vectorDimensionMismatch
        }

        let rows = try await fetchRows(
            """
            SELECT
                chunk_id,
                content,
                metadata,
                vector_json,
                EXTRACT(EPOCH FROM created_at)::double precision AS created_at_epoch
            FROM embeddings
            """,
            parameters: []
        )

        let scored: [(SearchResult, Float)] = rows.compactMap { row in
            guard
                let vectorJSON = stringValue(row["vector_json"]),
                let vector = try? decodeVector(vectorJSON)
            else {
                return nil
            }

            let similarity = cosineSimilarity(queryVector, vector)
            guard let result = makeSearchResult(from: row, similarity: similarity) else {
                return nil
            }
            return (result, similarity)
        }

        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
    }

    public func clear() async throws {
        _ = try await execute("DELETE FROM embeddings;")
    }

    public func statistics() async throws -> Statistics {
        let totalRows = try await fetchRows("SELECT COUNT(*) AS count FROM embeddings")
        let totalChunks = totalRows.first.flatMap { intValue($0["count"]) } ?? 0

        let fileRows = try await fetchRows("""
            SELECT COUNT(DISTINCT COALESCE(metadata::jsonb ->> 'file_path', '')) AS count
            FROM embeddings
        """)
        let indexedFiles = fileRows.first.flatMap { intValue($0["count"]) } ?? 0

        let languageRows = try await fetchRows("""
            SELECT COALESCE(metadata::jsonb ->> 'language', 'unknown') AS language, COUNT(*) AS count
            FROM embeddings
            GROUP BY COALESCE(metadata::jsonb ->> 'language', 'unknown')
        """)

        var languages: [String: Int64] = [:]
        for row in languageRows {
            guard let language = stringValue(row["language"]) else { continue }
            languages[language] = Int64(intValue(row["count"]) ?? 0)
        }

        return Statistics(totalChunks: Int64(totalChunks), indexedFiles: Int64(indexedFiles), languages: languages)
    }

    public enum VectorStoreError: Error {
        case databaseError(String)
        case vectorDimensionMismatch
        case invalidVector
    }

    private func execute(_ sql: String, parameters: [String] = []) async throws -> Int {
        let connection = try await connectionManager.acquireConnection()
        defer {
            Task { await connectionManager.releaseConnection(connection) }
        }

        let result = try await connection.executeQuery(sql, parameters: parameters, rlsContext: nil)
        return intValue(result["rowCount"]) ?? 0
    }

    private func fetchRows(
        _ sql: String,
        parameters: [String] = []
    ) async throws -> [[String: DatabaseCore.AnyCodable]] {
        let connection = try await connectionManager.acquireConnection()
        defer {
            Task { await connectionManager.releaseConnection(connection) }
        }

        let result = try await connection.executeQuery(sql, parameters: parameters, rlsContext: nil)
        return rowsValue(result["rows"])
    }

    private func rowsValue(_ value: DatabaseCore.AnyCodable?) -> [[String: DatabaseCore.AnyCodable]] {
        switch value {
        case .array(let array):
            return array.compactMap { entry in
                if case .dictionary(let dict) = entry {
                    return dict
                }
                return nil
            }
        default:
            return []
        }
    }

    private func stringValue(_ value: DatabaseCore.AnyCodable?) -> String? {
        switch value {
        case .string(let string):
            return string
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .date(let date):
            return ISO8601DateFormatter().string(from: date)
        case .array, .dictionary, .null, .none:
            return nil
        }
    }

    private func intValue(_ value: DatabaseCore.AnyCodable?) -> Int? {
        switch value {
        case .int(let int):
            return int
        case .double(let double):
            return Int(double)
        case .string(let string):
            return Int(string)
        default:
            return nil
        }
    }

    private func makeSearchResult(from row: [String: DatabaseCore.AnyCodable], similarity: Float) -> SearchResult? {
        guard
            let chunkId = stringValue(row["chunk_id"]),
            let content = stringValue(row["content"])
        else {
            return nil
        }

        let metadata = stringValue(row["metadata"])
        let createdAtEpoch = doubleValue(row["created_at_epoch"]) ?? Date().timeIntervalSince1970

        return SearchResult(
            chunkId: chunkId,
            content: content,
            metadata: metadata,
            similarity: similarity,
            createdAt: Date(timeIntervalSince1970: createdAtEpoch)
        )
    }

    private func doubleValue(_ value: DatabaseCore.AnyCodable?) -> Double? {
        switch value {
        case .double(let double):
            return double
        case .int(let int):
            return Double(int)
        case .string(let string):
            return Double(string)
        default:
            return nil
        }
    }

    private func encodeVector(_ vector: [Float]) throws -> String {
        let data = try JSONEncoder().encode(vector)
        guard let string = String(data: data, encoding: .utf8) else {
            throw VectorStoreError.invalidVector
        }
        return string
    }

    private func decodeVector(_ json: String) throws -> [Float] {
        guard let data = json.data(using: .utf8) else {
            throw VectorStoreError.invalidVector
        }
        return try JSONDecoder().decode([Float].self, from: data)
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
}

public struct SearchResult: Codable, Sendable {
    public let chunkId: String
    public let content: String
    public let metadata: String?
    public let similarity: Float
    public let createdAt: Date
}
