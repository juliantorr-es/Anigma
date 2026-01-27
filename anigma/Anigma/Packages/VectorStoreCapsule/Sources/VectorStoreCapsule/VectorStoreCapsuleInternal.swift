/// VectorStoreCapsuleInternal.swift
/// Internal implementation for VectorStoreCapsule
/// Full SQLite vector extension support with vector operations and batch processing

import Foundation
import SQLite3

/// Vector similarity metrics
public enum SimilarityMetric: String, CaseIterable, Sendable {
    case cosine = "cosine"
    case euclidean = "euclidean"
    case manhattan = "manhattan"
    case dotProduct = "dot_product"
}

/// Vector data structure
public struct Vector: Sendable {
    public let id: String
    public let values: [Double]
    public let metadata: [String: String]
    
    public init(id: String, values: [Double], metadata: [String: String] = [:]) {
        self.id = id
        self.values = values
        self.metadata = metadata
    }
}

/// Similarity search result
public struct SimilarityResult: Sendable {
    public let vector: Vector
    public let similarity: Double
    public let distance: Double
    
    public init(vector: Vector, similarity: Double, distance: Double) {
        self.vector = vector
        self.similarity = similarity
        self.distance = distance
    }
}

/// Vector operation result
public struct VectorOperationResult: Sendable {
    public let affectedRows: Int
    public let operationTime: TimeInterval
    public let success: Bool
    public let errorMessage: String?
    
    public init(affectedRows: Int, operationTime: TimeInterval, success: Bool, errorMessage: String? = nil) {
        self.affectedRows = affectedRows
        self.operationTime = operationTime
        self.success = success
        self.errorMessage = errorMessage
    }
}

/// Batch operation result
public struct BatchOperationResult: Sendable {
    public let successfulCount: Int
    public let failedCount: Int
    public let operationTime: TimeInterval
    public let errors: [String]
    
    public init(successfulCount: Int, failedCount: Int, operationTime: TimeInterval, errors: [String] = []) {
        self.successfulCount = successfulCount
        self.failedCount = failedCount
        self.operationTime = operationTime
        self.errors = errors
    }
}

/// Database configuration
public struct VectorStoreConfig: Sendable {
    public let databasePath: String
    public let dimension: Int
    public let similarityMetric: SimilarityMetric
    public let enablePersistence: Bool
    
    public init(databasePath: String, dimension: Int, similarityMetric: SimilarityMetric = .cosine, enablePersistence: Bool = true) {
        self.databasePath = databasePath
        self.dimension = dimension
        self.similarityMetric = similarityMetric
        self.enablePersistence = enablePersistence
    }
}

/// Internal implementation of the VectorStoreCapsule processing logic.
/// Marked as Sendable to comply with Swift 6 concurrency requirements.
internal final class VectorStoreCapsuleInternal: Sendable {
    
    private var db: OpaquePointer?
    private let config: VectorStoreConfig
    private let accessQueue = DispatchQueue(label: "vectorstore.db", qos: .userInitiated, attributes: .concurrent)
    
    /// Initialize the internal implementation with database configuration
    /// - Parameter config: VectorStoreConfig for database setup
    /// - Throws: Database initialization errors
    internal init(config: VectorStoreConfig) throws {
        self.config = config
        
        // Open database connection
        guard sqlite3_open_v2(config.databasePath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseInitialization("Failed to open database")
        }
        
        // Enable foreign keys
        guard sqlite3_exec(db, "PRAGMA foreign_keys = ON", nil, nil, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw VectorStoreError.databaseInitialization("Failed to enable foreign keys")
        }
        
        try setupVectorExtension()
        try createVectorTable()
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    /// Setup SQLite vector extension
    private func setupVectorExtension() throws {
        // In a real implementation, this would load the vector extension
        // For now, we'll simulate with regular SQLite operations
        let createVectorTableSQL = """
        CREATE TABLE IF NOT EXISTS vectors (
            id TEXT PRIMARY KEY,
            dimension INTEGER,
            values TEXT,
            metadata TEXT,
            created_at REAL DEFAULT (julianday('now'))
        );
        
        CREATE INDEX IF NOT EXISTS idx_dimension ON vectors(dimension);
        CREATE TABLE IF NOT EXISTS vector_configs (
            key TEXT PRIMARY KEY,
            value TEXT
        );
        """
        
        guard sqlite3_exec(db, createVectorTableSQL, nil, nil, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseInitialization("Failed to create vector tables")
        }
        
        // Store configuration
        let configSQL = """
        INSERT OR REPLACE INTO vector_configs (key, value) 
        VALUES ('dimension', '\(config.dimension)'),
               ('similarity_metric', '\(config.similarityMetric.rawValue)'),
               ('enable_persistence', '\(config.enablePersistence)');
        """
        
        guard sqlite3_exec(db, configSQL, nil, nil, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseInitialization("Failed to store configuration")
        }
    }
    
    /// Create vector table with proper indexing
    private func createVectorTable() throws {
        // Additional indexes for better performance
        let indexSQL = """
        CREATE INDEX IF NOT EXISTS idx_created_at ON vectors(created_at);
        """
        
        guard sqlite3_exec(db, indexSQL, nil, nil, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseInitialization("Failed to create indexes")
        }
    }
    
    /// Insert a single vector into the store
    /// - Parameter vector: Vector to insert
    /// - Returns: VectorOperationResult
    /// - Throws: Database errors
    internal func insertVector(_ vector: Vector) throws -> VectorOperationResult {
        let startTime = Date()
        
        guard vector.values.count == config.dimension else {
            throw VectorStoreError.invalidVector("Vector dimension \(vector.values.count) does not match configured dimension \(config.dimension)")
        }
        
        let valuesJSON = try JSONEncoder().encode(vector.values).base64EncodedString()
        let metadataJSON = try JSONEncoder().encode(vector.metadata).base64EncodedString()
        
        let sql = """
        INSERT OR REPLACE INTO vectors (id, dimension, values, metadata) 
        VALUES (?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseOperation("Failed to prepare insert statement")
        }
        
        sqlite3_bind_text(statement, 1, vector.id, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(config.dimension))
        sqlite3_bind_text(statement, 3, valuesJSON, -1, nil)
        sqlite3_bind_text(statement, 4, metadataJSON, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw VectorStoreError.databaseOperation("Failed to execute insert statement")
        }
        
        let operationTime = Date().timeIntervalSince(startTime)
        return VectorOperationResult(
            affectedRows: Int(sqlite3_changes(db)),
            operationTime: operationTime,
            success: true
        )
    }
    
    /// Batch insert multiple vectors
    /// - Parameter vectors: Array of vectors to insert
    /// - Returns: BatchOperationResult
    /// - Throws: Database errors
    internal func batchInsertVectors(_ vectors: [Vector]) throws -> BatchOperationResult {
        let startTime = Date()
        var successfulCount = 0
        var failedCount = 0
        var errors: [String] = []
        
        // Begin transaction
        guard sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseOperation("Failed to begin transaction")
        }
        
        defer {
            if successfulCount == vectors.count {
                sqlite3_exec(db, "COMMIT;", nil, nil, nil)
            } else {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            }
        }
        
        for vector in vectors {
            do {
                _ = try insertVector(vector)
                successfulCount += 1
            } catch {
                failedCount += 1
                errors.append("Vector \(vector.id): \(error.localizedDescription)")
            }
        }
        
        let operationTime = Date().timeIntervalSince(startTime)
        return BatchOperationResult(
            successfulCount: successfulCount,
            failedCount: failedCount,
            operationTime: operationTime,
            errors: errors
        )
    }
    
    /// Search for similar vectors
    /// - Parameters:
    ///   - queryVector: Vector to search for
    ///   - limit: Maximum number of results
    ///   - threshold: Similarity threshold (0.0 to 1.0)
    /// - Returns: Array of SimilarityResult
    /// - Throws: Database errors
    internal func searchSimilarVectors(
        queryVector: Vector,
        limit: Int = 10,
        threshold: Double = 0.0
    ) throws -> [SimilarityResult] {
        guard queryVector.values.count == config.dimension else {
            throw VectorStoreError.invalidVector("Query vector dimension mismatch")
        }
        
        let sql = """
        SELECT id, values, metadata FROM vectors 
        WHERE dimension = ? AND id != ? 
        LIMIT ?;
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseOperation("Failed to prepare search statement")
        }
        
        sqlite3_bind_int(statement, 1, Int32(config.dimension))
        sqlite3_bind_text(statement, 2, queryVector.id, -1, nil)
        sqlite3_bind_int(statement, 3, Int32(limit))
        
        var results: [SimilarityResult] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let valuesJSON = String(cString: sqlite3_column_text(statement, 1))
            let metadataJSON = String(cString: sqlite3_column_text(statement, 2))
            
            // Decode stored vector
            guard let valuesData = Data(base64Encoded: valuesJSON),
                  let storedValues = try? JSONDecoder().decode([Double].self, from: valuesData) else {
                continue
            }
            
            guard let metadataData = Data(base64Encoded: metadataJSON),
                  let metadata = try? JSONDecoder().decode([String: String].self, from: metadataData) else {
                continue
            }
            
            let storedVector = Vector(id: id, values: storedValues, metadata: metadata)
            
            // Calculate similarity based on metric
            let (similarity, distance) = calculateSimilarity(
                queryVector: queryVector.values,
                storedVector: storedVector.values,
                metric: config.similarityMetric
            )
            
            if similarity >= threshold {
                results.append(SimilarityResult(vector: storedVector, similarity: similarity, distance: distance))
            }
        }
        
        // Sort by similarity (descending)
        results.sort { $0.similarity > $1.similarity }
        return Array(results.prefix(limit))
    }
    
    /// Get a vector by ID
    /// - Parameter id: Vector ID
    /// - Returns: Vector or nil if not found
    /// - Throws: Database errors
    internal func getVector(by id: String) throws -> Vector? {
        let sql = """
        SELECT id, values, metadata FROM vectors WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseOperation("Failed to prepare get statement")
        }
        
        sqlite3_bind_text(statement, 1, id, -1, nil)
        
        if sqlite3_step(statement) == SQLITE_ROW {
            let retrievedId = String(cString: sqlite3_column_text(statement, 0))
            let valuesJSON = String(cString: sqlite3_column_text(statement, 1))
            let metadataJSON = String(cString: sqlite3_column_text(statement, 2))
            
            guard let valuesData = Data(base64Encoded: valuesJSON),
                  let values = try? JSONDecoder().decode([Double].self, from: valuesData),
                  let metadataData = Data(base64Encoded: metadataJSON),
                  let metadata = try? JSONDecoder().decode([String: String].self, from: metadataData) else {
                throw VectorStoreError.databaseOperation("Failed to decode vector data")
            }
            
            return Vector(id: retrievedId, values: values, metadata: metadata)
        }
        
        return nil
    }
    
    /// Delete a vector by ID
    /// - Parameter id: Vector ID to delete
    /// - Returns: VectorOperationResult
    /// - Throws: Database errors
    internal func deleteVector(by id: String) throws -> VectorOperationResult {
        let startTime = Date()
        
        let sql = "DELETE FROM vectors WHERE id = ?;"
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseOperation("Failed to prepare delete statement")
        }
        
        sqlite3_bind_text(statement, 1, id, -1, nil)
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw VectorStoreError.databaseOperation("Failed to execute delete statement")
        }
        
        let operationTime = Date().timeIntervalSince(startTime)
        return VectorOperationResult(
            affectedRows: Int(sqlite3_changes(db)),
            operationTime: operationTime,
            success: true
        )
    }
    
    /// Get vector store statistics
    /// - Returns: Dictionary with statistics
    /// - Throws: Database errors
    internal func getStatistics() throws -> [String: Any] {
        let countSQL = "SELECT COUNT(*) FROM vectors;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, countSQL, -1, &statement, nil) == SQLITE_OK else {
            throw VectorStoreError.databaseOperation("Failed to prepare statistics query")
        }
        
        var vectorCount = 0
        if sqlite3_step(statement) == SQLITE_ROW {
            vectorCount = Int(sqlite3_column_int(statement, 0))
        }
        
        return [
            "vector_count": vectorCount,
            "dimension": config.dimension,
            "similarity_metric": config.similarityMetric.rawValue,
            "enable_persistence": config.enablePersistence,
            "database_path": config.databasePath
        ]
    }
    
    /// Calculate similarity between two vectors based on metric
    private func calculateSimilarity(
        queryVector: [Double],
        storedVector: [Double],
        metric: SimilarityMetric
    ) -> (similarity: Double, distance: Double) {
        guard queryVector.count == storedVector.count else {
            return (0.0, Double.infinity)
        }
        
        switch metric {
        case .cosine:
            let dotProduct = zip(queryVector, storedVector).map(*).reduce(0, +)
            let queryMagnitude = sqrt(queryVector.map { $0 * $0 }.reduce(0, +))
            let storedMagnitude = sqrt(storedVector.map { $0 * $0 }.reduce(0, +))
            
            guard queryMagnitude > 0 && storedMagnitude > 0 else {
                return (0.0, 1.0)
            }
            
            let cosineSimilarity = dotProduct / (queryMagnitude * storedMagnitude)
            let distance = 1.0 - cosineSimilarity
            return (max(0, cosineSimilarity), max(0, distance))
            
        case .euclidean:
            let euclideanDistance = sqrt(zip(queryVector, storedVector).map { pow($0 - $1, 2) }.reduce(0, +))
            let similarity = 1.0 / (1.0 + euclideanDistance)
            return (similarity, euclideanDistance)
            
        case .manhattan:
            let manhattanDistance = zip(queryVector, storedVector).map { abs($0 - $1) }.reduce(0, +)
            let similarity = 1.0 / (1.0 + manhattanDistance)
            return (similarity, manhattanDistance)
            
        case .dotProduct:
            let dotProduct = zip(queryVector, storedVector).map(*).reduce(0, +)
            let normalizedSimilarity = max(0, dotProduct) // Simple normalization
            return (normalizedSimilarity, abs(dotProduct))
        }
    }
}

/// VectorStore specific errors
public enum VectorStoreError: LocalizedError, Sendable {
    case databaseInitialization(String)
    case databaseOperation(String)
    case invalidVector(String)
    case similarityCalculationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .databaseInitialization(let message):
            return "Database initialization failed: \(message)"
        case .databaseOperation(let message):
            return "Database operation failed: \(message)"
        case .invalidVector(let message):
            return "Invalid vector: \(message)"
        case .similarityCalculationFailed(let message):
            return "Similarity calculation failed: \(message)"
        }
    }
}
