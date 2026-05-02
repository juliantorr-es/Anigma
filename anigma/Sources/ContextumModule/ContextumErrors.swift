import Foundation

/// Comprehensive error taxonomy for Contextum operations
public enum ContextumError: Error, Equatable, Sendable {
    // MARK: - Validation Errors
    case invalidChunkBoundary(sourceID: String, start: Int, end: Int, reason: String)
    case invalidContentHash(hash: String, reason: String)
    case invalidCorrelationTuple(field: String, value: String?)
    case invalidEmbeddingDimensions(expected: Int, actual: Int, modelID: String)
    case invalidModelIdentity(modelID: String?, modelHash: String?, reason: String)
    case invalidQueryHash(hash: String)
    case invalidSourceID(sourceID: String)
    case invalidTokenCount(count: Int, reason: String)
    case invalidSpatialFilter(reason: String)

    // MARK: - State Errors
    case chunkAlreadyExists(chunkID: String, contentHash: String)
    case embeddingAlreadyExists(chunkHash: String, modelHash: String)
    case sourceAlreadyIngested(sourceID: String, artifactHash: String)
    case sourceNotFound(sourceID: String)
    case chunkNotFound(chunkID: String)
    case profileMemoryNotFound(id: String)
    case profileMemoryConflict(message: String)
    case profileMemoryEvidenceValidationFailed(message: String)
    case embeddingNotFound(chunkHash: String, modelHash: String)

    // MARK: - Resource Errors
    case budgetExceeded(budgetType: BudgetType, limit: Int, current: Int)
    case queueFull(queueType: QueueType, depth: Int, maxDepth: Int)
    case workerUnavailable(workerType: WorkerType, reason: String)
    case databaseUnavailable(reason: String)
    case databaseError(String)

    // MARK: - Execution Errors
    case mlWorkerExecutionFailed(jobID: String, errorCode: String, diagnostic: String)
    case mlWorkerFailure(String)
    case configurationError(String)
    case systemError(String)
    case chunkingFailed(sourceID: String, reason: String)
    case embeddingFailed(chunkHash: String, modelID: String, reason: String)
    case searchFailed(queryHash: String, mode: SearchMode, reason: String)
    case indexingFailed(artifactID: String, phase: IndexPhase, reason: String)

    // MARK: - Provenance Errors
    case missingReceipt(operation: String, subjectID: String)
    case missingEvidenceHead(receiptID: String)
    case provenanceChainBroken(chunkHash: String, expectedHash: String, actualHash: String?)
    case replayNotAllowed(runID: String)
    case missingPreflightData(runID: String)

    // MARK: - Degradation Errors (Non-Critical)
    case semanticSearchDegraded(reason: String)
    case indexingDegraded(artifactID: String, reason: String)

    // MARK: - Supporting Types
    public enum BudgetType: String, Sendable {
        case embeddingJobsPerRun = "embedding_jobs_per_run"
        case embeddingJobsGlobal = "embedding_jobs_global"
        case inFlightEmbeddings = "in_flight_embeddings"
    }

    public enum QueueType: String, Sendable {
        case embeddingQueue = "embedding_queue"
        case ingestQueue = "ingest_queue"
        case chunkQueue = "chunk_queue"
    }

    public enum WorkerType: String, Sendable {
        case mlWorker = "ml_worker"
        case databaseWorker = "database_worker"
    }

    public enum SearchMode: String, Sendable {
        case fullText = "full_text"
        case semantic = "semantic"
        case hybrid = "hybrid"
    }

    public enum IndexPhase: String, Sendable {
        case ingest = "ingest"
        case chunking = "chunking"
        case embedding = "embedding"
    }

    // MARK: - Error Properties

    public var isRecoverable: Bool {
        switch self {
        case .budgetExceeded, .queueFull, .workerUnavailable, .databaseUnavailable, .databaseError:
            return true
        case .semanticSearchDegraded, .indexingDegraded:
            return true
        case .mlWorkerExecutionFailed, .chunkingFailed, .embeddingFailed:
            return true
        default:
            return false
        }
    }

    public var isDegradation: Bool {
        switch self {
        case .semanticSearchDegraded, .indexingDegraded:
            return true
        default:
            return false
        }
    }

    public var diagnosticPayload: [String: String] {
        switch self {
        case .invalidChunkBoundary(let sourceID, let start, let end, let reason):
            return [
                "error_type": "invalid_chunk_boundary",
                "source_id": sourceID,
                "byte_range_start": String(start),
                "byte_range_end": String(end),
                "reason": reason
            ]

        case .invalidContentHash(let hash, let reason):
            return [
                "error_type": "invalid_content_hash",
                "hash": hash,
                "reason": reason
            ]

        case .invalidCorrelationTuple(let field, let value):
            return [
                "error_type": "invalid_correlation_tuple",
                "field": field,
                "value": value ?? "nil"
            ]

        case .invalidEmbeddingDimensions(let expected, let actual, let modelID):
            return [
                "error_type": "invalid_embedding_dimensions",
                "expected": String(expected),
                "actual": String(actual),
                "model_id": modelID
            ]

        case .invalidModelIdentity(let modelID, let modelHash, let reason):
            return [
                "error_type": "invalid_model_identity",
                "model_id": modelID ?? "nil",
                "model_hash": modelHash ?? "nil",
                "reason": reason
            ]

        case .budgetExceeded(let budgetType, let limit, let current):
            return [
                "error_type": "budget_exceeded",
                "budget_type": budgetType.rawValue,
                "limit": String(limit),
                "current": String(current)
            ]

        case .queueFull(let queueType, let depth, let maxDepth):
            return [
                "error_type": "queue_full",
                "queue_type": queueType.rawValue,
                "depth": String(depth),
                "max_depth": String(maxDepth)
            ]

        case .workerUnavailable(let workerType, let reason):
            return [
                "error_type": "worker_unavailable",
                "worker_type": workerType.rawValue,
                "reason": reason
            ]

        case .mlWorkerExecutionFailed(let jobID, let errorCode, let diagnostic):
            return [
                "error_type": "mlworker_execution_failed",
                "job_id": jobID,
                "error_code": errorCode,
                "diagnostic": diagnostic
            ]

        case .semanticSearchDegraded(let reason):
            return [
                "error_type": "semantic_search_degraded",
                "reason": reason
            ]

        case .indexingDegraded(let artifactID, let reason):
            return [
                "error_type": "indexing_degraded",
                "artifact_id": artifactID,
                "reason": reason
            ]

        case .missingReceipt(let operation, let subjectID):
            return [
                "error_type": "missing_receipt",
                "operation": operation,
                "subject_id": subjectID
            ]

        case .provenanceChainBroken(let chunkHash, let expectedHash, let actualHash):
            return [
                "error_type": "provenance_chain_broken",
                "chunk_hash": chunkHash,
                "expected_hash": expectedHash,
                "actual_hash": actualHash ?? "nil"
            ]

        case .invalidSpatialFilter(let reason):
            return [
                "error_type": "invalid_spatial_filter",
                "reason": reason
            ]

        case .profileMemoryNotFound(let id):
            return [
                "error_type": "profile_memory_not_found",
                "profile_memory_id": id
            ]

        case .profileMemoryConflict(let message):
            return [
                "error_type": "profile_memory_conflict",
                "message": message
            ]

        case .profileMemoryEvidenceValidationFailed(let message):
            return [
                "error_type": "profile_memory_evidence_validation_failed",
                "message": message
            ]

        default:
            return [
                "error_type": String(describing: self)
            ]
        }
    }

    public var errorCode: String {
        switch self {
        case .invalidChunkBoundary: return "CTX_INVALID_CHUNK_BOUNDARY"
        case .invalidContentHash: return "CTX_INVALID_CONTENT_HASH"
        case .invalidCorrelationTuple: return "CTX_INVALID_CORRELATION"
        case .invalidEmbeddingDimensions: return "CTX_INVALID_EMBEDDING_DIM"
        case .invalidModelIdentity: return "CTX_INVALID_MODEL_IDENTITY"
        case .invalidQueryHash: return "CTX_INVALID_QUERY_HASH"
        case .invalidSourceID: return "CTX_INVALID_SOURCE_ID"
        case .invalidTokenCount: return "CTX_INVALID_TOKEN_COUNT"
        case .invalidSpatialFilter: return "CTX_INVALID_SPATIAL_FILTER"
        case .chunkAlreadyExists: return "CTX_CHUNK_DUPLICATE"
        case .embeddingAlreadyExists: return "CTX_EMBEDDING_DUPLICATE"
        case .sourceAlreadyIngested: return "CTX_SOURCE_DUPLICATE"
        case .sourceNotFound: return "CTX_SOURCE_NOT_FOUND"
        case .chunkNotFound: return "CTX_CHUNK_NOT_FOUND"
        case .profileMemoryNotFound: return "CTX_PROFILE_MEMORY_NOT_FOUND"
        case .profileMemoryConflict: return "CTX_PROFILE_MEMORY_CONFLICT"
        case .profileMemoryEvidenceValidationFailed: return "CTX_PROFILE_MEMORY_EVIDENCE_VALIDATION"
        case .embeddingNotFound: return "CTX_EMBEDDING_NOT_FOUND"
        case .budgetExceeded: return "CTX_BUDGET_EXCEEDED"
        case .queueFull: return "CTX_QUEUE_FULL"
        case .workerUnavailable: return "CTX_WORKER_UNAVAILABLE"
        case .databaseUnavailable: return "CTX_DATABASE_UNAVAILABLE"
        case .databaseError: return "CTX_DATABASE_ERROR"
        case .mlWorkerExecutionFailed: return "CTX_MLWORKER_FAILED"
        case .mlWorkerFailure: return "CTX_MLWORKER_FAILURE"
        case .configurationError: return "CTX_CONFIGURATION_ERROR"
        case .systemError: return "CTX_SYSTEM_ERROR"
        case .chunkingFailed: return "CTX_CHUNKING_FAILED"
        case .embeddingFailed: return "CTX_EMBEDDING_FAILED"
        case .searchFailed: return "CTX_SEARCH_FAILED"
        case .indexingFailed: return "CTX_INDEXING_FAILED"
        case .missingReceipt: return "CTX_MISSING_RECEIPT"
        case .missingEvidenceHead: return "CTX_MISSING_EVIDENCE_HEAD"
        case .provenanceChainBroken: return "CTX_PROVENANCE_BROKEN"
        case .replayNotAllowed: return "CTX_REPLAY_NOT_ALLOWED"
        case .missingPreflightData: return "CTX_MISSING_PREFLIGHT"
        case .semanticSearchDegraded: return "CTX_SEMANTIC_DEGRADED"
        case .indexingDegraded: return "CTX_INDEXING_DEGRADED"
        }
    }
}
