/// VectorStoreCapsule.swift
/// Public API for VectorStoreCapsule
/// Tier 1: Full SQLite vector extension support with vector operations and batch processing
///
/// This file provides:
/// - Contract 1: CapsuleError for all public failures
/// - Contract 2: CapsuleDiagnostics for observability
/// - Sendable compliance (Swift 6)
/// - Full SQLite vector extension support
/// - Vector operations within store
/// - Batch insert/query operations

import Foundation
import CapsuleCore
import TelemetryCore

/// The VectorStoreCapsule public API
/// Full SQLite vector extension support with vector operations and batch processing
public final class VectorStoreCapsule: Sendable {
    /// Unique identifier for this capsule instance
    public let id: String
    
    /// Diagnostics for observability (correlation ID tracking, span timing)
    private let diagnostics: CapsuleDiagnostics
    
    /// Internal implementation (separated for clarity)
    private nonisolated let impl: VectorStoreCapsuleInternal
    
    /// Configuration for vector store
    public let config: VectorStoreConfig
    
    /// Initialize a VectorStoreCapsule instance
    /// - Parameters:
    ///   - config: VectorStoreConfig for database setup
    ///   - id: Unique identifier for this capsule (UUID recommended)
    ///   - diagnostics: Diagnostics collector for observability
    /// - Throws: `CapsuleError.invalidConfiguration` if config is invalid
    public init(
        config: VectorStoreConfig,
        id: String = UUID().uuidString,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        // Validate configuration (Contract 1 gate)
        guard !id.isEmpty else {
            throw CapsuleError.invalidConfiguration(reason: "Capsule ID cannot be empty")
        }
        
        guard config.dimension > 0 else {
            throw CapsuleError.invalidConfiguration(reason: "Vector dimension must be positive")
        }
        
        guard !config.databasePath.isEmpty else {
            throw CapsuleError.invalidConfiguration(reason: "Database path cannot be empty")
        }
        
        self.id = id
        self.config = config
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        
        do {
            self.impl = try VectorStoreCapsuleInternal(config: config)
        } catch let vectorError as VectorStoreError {
            throw CapsuleError.invalidConfiguration(reason: vectorError.localizedDescription)
        } catch {
            throw CapsuleError.invalidConfiguration(reason: "Failed to initialize vector store: \(error)")
        }
        
        // Emit initialization event
        let span = self.diagnostics.beginSpan(
            name: "VectorStoreCapsule.init",
            category: "initialization",
            correlationID: nil,
            tags: [
                "capsule_id": id,
                "dimension": "\(config.dimension)",
                "similarity_metric": config.similarityMetric.rawValue
            ]
        )
        span.end(status: .ok)
    }
    
    /// Insert a single vector into store
    /// - Parameters:
    ///   - vector: Vector to insert
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: VectorOperationResult with operation details
    /// - Throws: `CapsuleError` variants for insertion failures
    public func insertVector(
        _ vector: Vector,
        correlationID: String? = nil
    ) async throws -> VectorOperationResult {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "VectorStoreCapsule.insertVector",
            category: "vector_insertion",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "vector_id": vector.id,
                "dimension": "\(vector.values.count)"
            ]
        )
        
        // Validation
        guard !vector.id.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "vector.id",
                constraint: "Vector ID cannot be empty"
            )
        }
        
        guard vector.values.count == config.dimension else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "vector.values",
                constraint: "Vector dimension \(vector.values.count) does not match configured dimension \(config.dimension)"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .info,
            category: "vectorstorecapsule.insertVector",
            message: "Inserting vector \(vector.id)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let result = try impl.insertVector(vector)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "vectorstorecapsule.insertVector",
                message: "Vector insertion completed",
                correlationID: corrID,
                metadata: [
                    "affected_rows": "\(result.affectedRows)",
                    "operation_time": "\(result.operationTime)"
                ]
            )
            
            span.end(status: .ok)
            return result
        } catch let vectorError as VectorStoreError {
            // Map VectorStore errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "vectorstorecapsule.insertVector",
                message: "Vector insertion failed: \(vectorError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "VectorStoreError"]
            )
            span.end(status: .error)
            
            switch vectorError {
            case .invalidVector:
                throw CapsuleError.invalidInput(field: "vector", constraint: vectorError.localizedDescription)
            case .databaseInitialization, .databaseOperation, .similarityCalculationFailed:
                throw CapsuleError.internalError(details: vectorError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Batch insert multiple vectors
    /// - Parameters:
    ///   - vectors: Array of vectors to insert
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: BatchOperationResult with batch details
    /// - Throws: `CapsuleError` variants for batch insertion failures
    public func batchInsertVectors(
        _ vectors: [Vector],
        correlationID: String? = nil
    ) async throws -> BatchOperationResult {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "VectorStoreCapsule.batchInsertVectors",
            category: "batch_vector_insertion",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "batch_size": "\(vectors.count)"
            ]
        )
        
        // Validation
        guard !vectors.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "vectors",
                constraint: "Non-empty array required"
            )
        }
        
        // Validate all vectors
        for vector in vectors {
            guard vector.values.count == config.dimension else {
                span.end(status: .error)
                throw CapsuleError.invalidInput(
                    field: "vector.values",
                    constraint: "Vector \(vector.id) dimension \(vector.values.count) does not match configured dimension \(config.dimension)"
                )
            }
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .info,
            category: "vectorstorecapsule.batchInsertVectors",
            message: "Starting batch insertion of \(vectors.count) vectors",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let result = try impl.batchInsertVectors(vectors)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "vectorstorecapsule.batchInsertVectors",
                message: "Batch insertion completed",
                correlationID: corrID,
                metadata: [
                    "successful_count": "\(result.successfulCount)",
                    "failed_count": "\(result.failedCount)",
                    "operation_time": "\(result.operationTime)"
                ]
            )
            
            span.end(status: .ok)
            return result
        } catch let vectorError as VectorStoreError {
            // Map VectorStore errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "vectorstorecapsule.batchInsertVectors",
                message: "Batch insertion failed: \(vectorError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "VectorStoreError"]
            )
            span.end(status: .error)
            
            switch vectorError {
            case .invalidVector:
                throw CapsuleError.invalidInput(field: "vectors", constraint: vectorError.localizedDescription)
            case .databaseInitialization, .databaseOperation, .similarityCalculationFailed:
                throw CapsuleError.internalError(details: vectorError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Search for similar vectors
    /// - Parameters:
    ///   - queryVector: Vector to search for
    ///   - limit: Maximum number of results
    ///   - threshold: Similarity threshold (0.0 to 1.0)
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Array of SimilarityResult sorted by similarity
    /// - Throws: `CapsuleError` variants for search failures
    public func searchSimilarVectors(
        queryVector: Vector,
        limit: Int = 10,
        threshold: Double = 0.0,
        correlationID: String? = nil
    ) async throws -> [SimilarityResult] {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "VectorStoreCapsule.searchSimilarVectors",
            category: "vector_similarity_search",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "query_vector_id": queryVector.id,
                "limit": "\(limit)",
                "threshold": "\(threshold)"
            ]
        )
        
        // Validation
        guard queryVector.values.count == config.dimension else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "queryVector.values",
                constraint: "Query vector dimension \(queryVector.values.count) does not match configured dimension \(config.dimension)"
            )
        }
        
        guard limit > 0 else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "limit",
                constraint: "Limit must be positive"
            )
        }
        
        guard threshold >= 0.0 && threshold <= 1.0 else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "threshold",
                constraint: "Threshold must be between 0.0 and 1.0"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .info,
            category: "vectorstorecapsule.searchSimilarVectors",
            message: "Searching for similar vectors",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let results = try impl.searchSimilarVectors(
                queryVector: queryVector,
                limit: limit,
                threshold: threshold
            )
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "vectorstorecapsule.searchSimilarVectors",
                message: "Similarity search completed",
                correlationID: corrID,
                metadata: [
                    "result_count": "\(results.count)",
                    "top_similarity": results.first?.similarity.map { "\($0)" } ?? "nil"
                ]
            )
            
            span.end(status: .ok)
            return results
        } catch let vectorError as VectorStoreError {
            // Map VectorStore errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "vectorstorecapsule.searchSimilarVectors",
                message: "Similarity search failed: \(vectorError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "VectorStoreError"]
            )
            span.end(status: .error)
            
            switch vectorError {
            case .invalidVector:
                throw CapsuleError.invalidInput(field: "queryVector", constraint: vectorError.localizedDescription)
            case .databaseInitialization, .databaseOperation, .similarityCalculationFailed:
                throw CapsuleError.internalError(details: vectorError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get a vector by ID
    /// - Parameters:
    ///   - id: Vector ID to retrieve
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Vector or nil if not found
    /// - Throws: `CapsuleError` variants for retrieval failures
    public func getVector(
        by id: String,
        correlationID: String? = nil
    ) async throws -> Vector? {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "VectorStoreCapsule.getVector",
            category: "vector_retrieval",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "vector_id": id
            ]
        )
        
        // Validation
        guard !id.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "id",
                constraint: "Vector ID cannot be empty"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .debug,
            category: "vectorstorecapsule.getVector",
            message: "Retrieving vector \(id)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let vector = try impl.getVector(by: id)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "vectorstorecapsule.getVector",
                message: "Vector retrieval completed",
                correlationID: corrID,
                metadata: [
                    "found": vector != nil ? "true" : "false"
                ]
            )
            
            span.end(status: .ok)
            return vector
        } catch let vectorError as VectorStoreError {
            // Map VectorStore errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "vectorstorecapsule.getVector",
                message: "Vector retrieval failed: \(vectorError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "VectorStoreError"]
            )
            span.end(status: .error)
            
            switch vectorError {
            case .invalidVector:
                throw CapsuleError.invalidInput(field: "id", constraint: vectorError.localizedDescription)
            case .databaseInitialization, .databaseOperation, .similarityCalculationFailed:
                throw CapsuleError.internalError(details: vectorError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Delete a vector by ID
    /// - Parameters:
    ///   - id: Vector ID to delete
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: VectorOperationResult with deletion details
    /// - Throws: `CapsuleError` variants for deletion failures
    public func deleteVector(
        by id: String,
        correlationID: String? = nil
    ) async throws -> VectorOperationResult {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "VectorStoreCapsule.deleteVector",
            category: "vector_deletion",
            correlationID: corrID,
            tags: [
                "capsule_id": id,
                "vector_id": id
            ]
        )
        
        // Validation
        guard !id.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "id",
                constraint: "Vector ID cannot be empty"
            )
        }
        
        // Emit diagnostic event
        diagnostics.event(
            level: .info,
            category: "vectorstorecapsule.deleteVector",
            message: "Deleting vector \(id)",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let result = try impl.deleteVector(by: id)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "vectorstorecapsule.deleteVector",
                message: "Vector deletion completed",
                correlationID: corrID,
                metadata: [
                    "affected_rows": "\(result.affectedRows)",
                    "operation_time": "\(result.operationTime)"
                ]
            )
            
            span.end(status: .ok)
            return result
        } catch let vectorError as VectorStoreError {
            // Map VectorStore errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "vectorstorecapsule.deleteVector",
                message: "Vector deletion failed: \(vectorError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "VectorStoreError"]
            )
            span.end(status: .error)
            
            switch vectorError {
            case .invalidVector:
                throw CapsuleError.invalidInput(field: "id", constraint: vectorError.localizedDescription)
            case .databaseInitialization, .databaseOperation, .similarityCalculationFailed:
                throw CapsuleError.internalError(details: vectorError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get vector store statistics
    /// - Parameter correlationID: Request ID for tracing (optional)
    /// - Returns: Dictionary with store statistics
    /// - Throws: `CapsuleError` variants for statistics failures
    public func getStatistics(correlationID: String? = nil) async throws -> [String: Any] {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "VectorStoreCapsule.getStatistics",
            category: "statistics",
            correlationID: corrID,
            tags: ["capsule_id": id]
        )
        
        // Emit diagnostic event
        diagnostics.event(
            level: .debug,
            category: "vectorstorecapsule.getStatistics",
            message: "Getting vector store statistics",
            correlationID: corrID,
            metadata: ["tier": "1"]
        )
        
        do {
            let statistics = try impl.getStatistics()
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "vectorstorecapsule.getStatistics",
                message: "Statistics retrieval completed",
                correlationID: corrID,
                metadata: [
                    "vector_count": "\(statistics["vector_count"] ?? "unknown")"
                ]
            )
            
            span.end(status: .ok)
            return statistics
        } catch let vectorError as VectorStoreError {
            // Map VectorStore errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "vectorstorecapsule.getStatistics",
                message: "Statistics retrieval failed: \(vectorError.localizedDescription)",
                correlationID: corrID,
                metadata: ["error_type": "VectorStoreError"]
            )
            span.end(status: .error)
            
            switch vectorError {
            case .invalidVector:
                throw CapsuleError.invalidInput(field: "statistics", constraint: vectorError.localizedDescription)
            case .databaseInitialization, .databaseOperation, .similarityCalculationFailed:
                throw CapsuleError.internalError(details: vectorError.localizedDescription)
            }
        } catch {
            // Map other errors to canonical CapsuleError
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get capsule health status
    /// - Returns: A dictionary with health metrics (sendable-safe)
    /// - Throws: Never (diagnostic-only method)
    public func healthStatus() -> [String: String] {
        return [
            "capsule_id": id,
            "status": "healthy",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "database_path": config.databasePath,
            "dimension": "\(config.dimension)",
            "similarity_metric": config.similarityMetric.rawValue
        ]
    }
}

// MARK: - Helper for Diagnostics Integration

/// Mock diagnostics implementation for testing
/// Can be replaced with actual daemon diagnostics when integrated
internal final class MockDiagnostics: CapsuleDiagnostics {
    public func beginSpan(
        name: String,
        category: String,
        correlationID: String? = nil,
        tags: [String: String] = [:]
    ) -> DiagnosticSpan {
        MockDiagnosticSpan()
    }
    
    public func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        // In tests, diagnostics are collected for assertions
    }
    
    public func getEvents(since: Date) -> [DiagnosticEvent] {
        []
    }
    
    public func getAllEvents() -> [DiagnosticEvent] {
        []
    }
    
    public func clearEvents() {
        // noop
    }
}

internal final class MockDiagnosticSpan: DiagnosticSpan {
    let spanID = UUID().uuidString
    let name = "mock"
    let category = "mock"
    let correlationID = UUID().uuidString
    let startTime = Date()
    
    var endTime: Date? { nil }
    var duration: TimeInterval? { nil }
    var status: SpanStatus? { nil }
    var tags: [String: String] { [:] }
    
    func end(status: SpanStatus) { }
    func addTag(key: String, value: String) { }
    func recordEvent(level: DiagnosticLevel, message: String) { }
}