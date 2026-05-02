import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

/// Thread-safe wrapper for cosine similarity capsule with SIMD optimization.
/// Follows "Swift governs, C++ computes" capsule architecture.
public actor ContextumCosineSimilarityCapsuleWrapper {
    private var handle: CapsuleHandle<AnyObject>?
    private static let _shared = try? ContextumCosineSimilarityCapsuleWrapper()
    public static var shared: ContextumCosineSimilarityCapsuleWrapper? {
        _shared
    }
    
    /// Initialize a cosine similarity capsule.
    /// Creates a placeholder handle (stateless operations can use null handle).
    public init() throws {
        var rawHandle: anigma_cosine_similarity_capsule_t?
        var error = anigma_capsule_error_t()
        
        let status = anigma_cosine_similarity_capsule_create(&rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw cosineCapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_cosine_similarity_capsule_destroy
        )
    }
    
    deinit {
        handle?.invalidate()
    }
    
    // MARK: - Single Vector Operations
    
    /// Compute cosine similarity between two single vectors.
    /// - Parameters:
    ///   - query: Query vector as array of Float
    ///   - candidate: Candidate vector as array of Float
    ///   - simd: SIMD optimization hint (default .auto)
    /// - Returns: Cosine similarity score in range [-1.0, 1.0]
    /// - Throws: CapsuleError if dimensions mismatch or invalid layout
    public func computeSingle(
        query: [Float],
        candidate: [Float],
        simd: anigma_cosine_simd_t = anigma_cosine_simd_t(0)
    ) throws -> Float {
        guard query.count == candidate.count else {
            throw CapsuleNativeError(
                status: ANIGMA_ERR_INVALID_ARG,
                code: ANIGMA_ERR_INVALID_ARG,
                message: "Query and candidate dimensions must match"
            )
        }
        guard query.count > 0 else {
            throw CapsuleNativeError(
                status: ANIGMA_ERR_INVALID_ARG,
                code: ANIGMA_ERR_INVALID_ARG,
                message: "Vector dimension must be greater than zero"
            )
        }
        
        var layout = anigma_cosine_vector_layout_t(
            dimension: query.count,
            stride: 1,
            alignment: 0,
            precision: ANIGMA_COSINE_PRECISION_SINGLE
        )
        
        var similarity: Float = 0.0
        var error = anigma_capsule_error_t()
        
        try query.withUnsafeBufferPointer { queryPtr in
            try candidate.withUnsafeBufferPointer { candidatePtr in
                guard let queryBase = queryPtr.baseAddress,
                      let candidateBase = candidatePtr.baseAddress else {
                    throw CapsuleNativeError(
                        status: ANIGMA_ERR_INVALID_ARG,
                        code: ANIGMA_ERR_INVALID_ARG,
                        message: "Empty vector"
                    )
                }
                
                try handle?.withHandle { rawHandle in
                    let status = anigma_cosine_similarity_compute_single(
                        rawHandle,
                        UnsafeRawPointer(queryBase),
                        UnsafeRawPointer(candidateBase),
                        &layout,
                        &similarity,
                        simd,
                        &error
                    )
                    guard status == ANIGMA_OK else {
                        throw cosineCapsuleError(status: status, error: error)
                    }
                }
            }
        }
        
        return similarity
    }
    
    // MARK: - Batch Operations (Single Query, Multiple Candidates)
    
    /// Compute cosine similarities between one query vector and multiple candidates.
    /// - Parameters:
    ///   - query: Query vector as array of Float
    ///   - candidates: Array of candidate vectors, each as array of Float
    ///   - simd: SIMD optimization hint (default .auto)
    /// - Returns: Array of similarity scores parallel to candidates
    /// - Throws: CapsuleError if dimensions mismatch or invalid layout
    public func computeBatch(
        query: [Float],
        candidates: [[Float]],
        simd: anigma_cosine_simd_t = anigma_cosine_simd_t(0)
    ) throws -> [Float] {
        guard !candidates.isEmpty else { return [] }
        guard query.count == candidates[0].count else {
            throw CapsuleNativeError(
                status: ANIGMA_ERR_INVALID_ARG,
                code: ANIGMA_ERR_INVALID_ARG,
                message: "Query and candidate dimensions must match"
            )
        }
        
        let dimension = query.count
        let count = candidates.count
        
        // Flatten candidates into contiguous memory
        let flatCandidates = candidates.flatMap { $0 }
        
        var layout = anigma_cosine_vector_layout_t(
            dimension: dimension,
            stride: dimension,
            alignment: 0,
            precision: ANIGMA_COSINE_PRECISION_SINGLE
        )
        
        var similarities = [Float](repeating: 0.0, count: count)
        var error = anigma_capsule_error_t()
        
        try query.withUnsafeBufferPointer { queryPtr in
            try flatCandidates.withUnsafeBufferPointer { candidatesPtr in
                guard let queryBase = queryPtr.baseAddress,
                      let candidatesBase = candidatesPtr.baseAddress else {
                    throw CapsuleNativeError(
                        status: ANIGMA_ERR_INVALID_ARG,
                        code: ANIGMA_ERR_INVALID_ARG,
                        message: "Empty vector"
                    )
                }
                
                var batchDesc = anigma_cosine_batch_descriptor_t(
                    count: count,
                    vectors: UnsafeRawPointer(candidatesBase),
                    layout: layout
                )
                
                try handle?.withHandle { rawHandle in
                    let status = anigma_cosine_similarity_compute_batch(
                        rawHandle,
                        UnsafeRawPointer(queryBase),
                        &batchDesc,
                        &similarities,
                        simd,
                        &error
                    )
                    guard status == ANIGMA_OK else {
                        throw cosineCapsuleError(status: status, error: error)
                    }
                }
            }
        }
        
        return similarities
    }
    
    /// Compute cosine similarities with early stopping (top‑k threshold).
    /// - Parameters:
    ///   - query: Query vector as array of Float
    ///   - candidates: Array of candidate vectors
    ///   - minSimilarity: Minimum similarity threshold (candidates below threshold may be skipped)
    ///   - simd: SIMD optimization hint (default .auto)
    /// - Returns: Tuple of (similarities, passedCount)
    ///   - similarities: Array of scores, untested candidates set to -2.0
    ///   - passedCount: Number of candidates passing the threshold
    /// - Throws: CapsuleError if dimensions mismatch or invalid layout
    public func computeBatchThreshold(
        query: [Float],
        candidates: [[Float]],
        minSimilarity: Float,
        simd: anigma_cosine_simd_t = anigma_cosine_simd_t(0)
    ) throws -> (similarities: [Float], passedCount: Int) {
        guard !candidates.isEmpty else { return ([], 0) }
        guard query.count == candidates[0].count else {
            throw CapsuleNativeError(
                status: ANIGMA_ERR_INVALID_ARG,
                code: ANIGMA_ERR_INVALID_ARG,
                message: "Query and candidate dimensions must match"
            )
        }
        
        let dimension = query.count
        let count = candidates.count
        
        // Flatten candidates into contiguous memory
        let flatCandidates = candidates.flatMap { $0 }
        
        var layout = anigma_cosine_vector_layout_t(
            dimension: dimension,
            stride: dimension,
            alignment: 0,
            precision: ANIGMA_COSINE_PRECISION_SINGLE
        )
        
        var similarities = [Float](repeating: -2.0, count: count)
        var passedCount: size_t = 0
        var error = anigma_capsule_error_t()
        
        try query.withUnsafeBufferPointer { queryPtr in
            try flatCandidates.withUnsafeBufferPointer { candidatesPtr in
                guard let queryBase = queryPtr.baseAddress,
                      let candidatesBase = candidatesPtr.baseAddress else {
                    throw CapsuleNativeError(
                        status: ANIGMA_ERR_INVALID_ARG,
                        code: ANIGMA_ERR_INVALID_ARG,
                        message: "Empty vector"
                    )
                }
                
                var batchDesc = anigma_cosine_batch_descriptor_t(
                    count: count,
                    vectors: UnsafeRawPointer(candidatesBase),
                    layout: layout
                )
                
                try handle?.withHandle { rawHandle in
                    let status = anigma_cosine_similarity_compute_batch_threshold(
                        rawHandle,
                        UnsafeRawPointer(queryBase),
                        &batchDesc,
                        minSimilarity,
                        &similarities,
                        &passedCount,
                        simd,
                        &error
                    )
                    guard status == ANIGMA_OK else {
                        throw cosineCapsuleError(status: status, error: error)
                    }
                }
            }
        }
        
        return (similarities, Int(passedCount))
    }
    
    // MARK: - Optimized Batch Operations with Precomputed Query Norm
    
    /// Precompute query norm for repeated batch operations.
    /// - Parameters:
    ///   - query: Query vector as array of Float
    ///   - simd: SIMD optimization hint (default .auto)
    /// - Returns: Precomputed query norm √(Σ query[i]²)
    /// - Throws: CapsuleError if layout invalid
    public func precomputeQueryNorm(
        query: [Float],
        simd: anigma_cosine_simd_t = anigma_cosine_simd_t(0)
    ) throws -> Float {
        var layout = anigma_cosine_vector_layout_t(
            dimension: query.count,
            stride: 1,
            alignment: 0,
            precision: ANIGMA_COSINE_PRECISION_SINGLE
        )
        
        var queryNorm: Float = 0.0
        var error = anigma_capsule_error_t()
        
        try query.withUnsafeBufferPointer { queryPtr in
            guard let queryBase = queryPtr.baseAddress else {
                throw CapsuleNativeError(
                    status: ANIGMA_ERR_INVALID_ARG,
                    error: anigma_capsule_error_t(
                        code: ANIGMA_ERR_INVALID_ARG,
                        message: "Empty vector",
                        detail: nil,
                        aux: 0
                    )
                )
            }
            
            try handle?.withHandle { rawHandle in
                let status = anigma_cosine_similarity_precompute_query_norm(
                    rawHandle,
                    UnsafeRawPointer(queryBase),
                    &layout,
                    &queryNorm,
                    simd,
                    &error
                )
                guard status == ANIGMA_OK else {
                    throw cosineCapsuleError(status: status, error: error)
                }
            }
        }
        
        return queryNorm
    }
    
    /// Compute batch similarities using precomputed query norm.
    /// More efficient than `computeBatch` when query is reused.
    /// - Parameters:
    ///   - query: Query vector (must be same as used for `precomputeQueryNorm`)
    ///   - queryNorm: Precomputed query norm
    ///   - candidates: Array of candidate vectors
    ///   - simd: SIMD optimization hint (default .auto)
    /// - Returns: Array of similarity scores parallel to candidates
    /// - Throws: CapsuleError if dimensions mismatch or invalid layout
    public func computeBatchWithNorm(
        query: [Float],
        queryNorm: Float,
        candidates: [[Float]],
        simd: anigma_cosine_simd_t = anigma_cosine_simd_t(0)
    ) throws -> [Float] {
        guard !candidates.isEmpty else { return [] }
        guard query.count == candidates[0].count else {
            throw CapsuleNativeError(
                status: ANIGMA_ERR_INVALID_ARG,
                code: ANIGMA_ERR_INVALID_ARG,
                message: "Query and candidate dimensions must match"
            )
        }
        
        let dimension = query.count
        let count = candidates.count
        
        // Flatten candidates into contiguous memory
        let flatCandidates = candidates.flatMap { $0 }
        
        var layout = anigma_cosine_vector_layout_t(
            dimension: dimension,
            stride: dimension,
            alignment: 0,
            precision: ANIGMA_COSINE_PRECISION_SINGLE
        )
        
        var similarities = [Float](repeating: 0.0, count: count)
        var error = anigma_capsule_error_t()
        
        try query.withUnsafeBufferPointer { queryPtr in
            try flatCandidates.withUnsafeBufferPointer { candidatesPtr in
                guard let queryBase = queryPtr.baseAddress,
                      let candidatesBase = candidatesPtr.baseAddress else {
                    throw CapsuleNativeError(
                        status: ANIGMA_ERR_INVALID_ARG,
                        code: ANIGMA_ERR_INVALID_ARG,
                        message: "Empty vector"
                    )
                }
                
                var batchDesc = anigma_cosine_batch_descriptor_t(
                    count: count,
                    vectors: UnsafeRawPointer(candidatesBase),
                    layout: layout
                )
                
                try handle?.withHandle { rawHandle in
                    let status = anigma_cosine_similarity_compute_batch_with_norm(
                        rawHandle,
                        UnsafeRawPointer(queryBase),
                        queryNorm,
                        &batchDesc,
                        &similarities,
                        simd,
                        &error
                    )
                    guard status == ANIGMA_OK else {
                        throw cosineCapsuleError(status: status, error: error)
                    }
                }
            }
        }
        
        return similarities
    }
    
    // MARK: - Matrix Operations (All-to-All Similarity)
    
    /// Compute similarity matrix between two sets of vectors.
    /// Result is row‑major matrix [queries.count × candidates.count].
    /// - Parameters:
    ///   - queries: Array of query vectors
    ///   - candidates: Array of candidate vectors
    ///   - simd: SIMD optimization hint (default .auto)
    /// - Returns: Row‑major matrix where element [i][j] = similarity(queries[i], candidates[j])
    /// - Throws: CapsuleError if dimensions mismatch or invalid layout
    public func computeMatrix(
        queries: [[Float]],
        candidates: [[Float]],
        simd: anigma_cosine_simd_t = anigma_cosine_simd_t(0)
    ) throws -> [Float] {
        guard !queries.isEmpty && !candidates.isEmpty else { return [] }
        let queryDim = queries[0].count
        let candidateDim = candidates[0].count
        guard queryDim == candidateDim else {
            throw CapsuleNativeError(
                status: ANIGMA_ERR_INVALID_ARG,
                code: ANIGMA_ERR_INVALID_ARG,
                message: "Query and candidate dimensions must match"
            )
        }
        
        let dimension = queryDim
        let queryCount = queries.count
        let candidateCount = candidates.count
        
        // Flatten vectors into contiguous memory
        let flatQueries = queries.flatMap { $0 }
        let flatCandidates = candidates.flatMap { $0 }
        
        var layout = anigma_cosine_vector_layout_t(
            dimension: dimension,
            stride: dimension,
            alignment: 0,
            precision: ANIGMA_COSINE_PRECISION_SINGLE
        )
        
        let matrixSize = queryCount * candidateCount
        var matrix = [Float](repeating: 0.0, count: matrixSize)
        var error = anigma_capsule_error_t()
        
        try flatQueries.withUnsafeBufferPointer { queriesPtr in
            try flatCandidates.withUnsafeBufferPointer { candidatesPtr in
                guard let queriesBase = queriesPtr.baseAddress,
                      let candidatesBase = candidatesPtr.baseAddress else {
                    throw CapsuleNativeError(
                        status: ANIGMA_ERR_INVALID_ARG,
                        code: ANIGMA_ERR_INVALID_ARG,
                        message: "Empty vector"
                    )
                }
                
                var queryBatch = anigma_cosine_batch_descriptor_t(
                    count: queryCount,
                    vectors: UnsafeRawPointer(queriesBase),
                    layout: layout
                )
                var candidateBatch = anigma_cosine_batch_descriptor_t(
                    count: candidateCount,
                    vectors: UnsafeRawPointer(candidatesBase),
                    layout: layout
                )
                
                try handle?.withHandle { rawHandle in
                    let status = anigma_cosine_similarity_compute_matrix(
                        rawHandle,
                        &queryBatch,
                        &candidateBatch,
                        &matrix,
                        simd,
                        &error
                    )
                    guard status == ANIGMA_OK else {
                        throw cosineCapsuleError(status: status, error: error)
                    }
                }
            }
        }
        
        return matrix
    }
    
    // MARK: - Utility Functions
    
    /// Query optimal SIMD level for current hardware.
    /// - Returns: Best available SIMD capability.
    public static func queryBestSIMD() -> anigma_cosine_simd_t {
        return anigma_cosine_similarity_query_best_simd()
    }
    
    /// Compute cosine similarity between two vectors without creating a capsule instance.
    /// - Parameters:
    ///   - query: Query vector as array of Float
    ///   - candidate: Candidate vector as array of Float
    ///   - simd: SIMD optimization hint (default .auto)
    /// - Returns: Cosine similarity score in range [-1.0, 1.0]
    /// - Throws: CapsuleError if dimensions mismatch or invalid layout
    public static func computeSimilarity(
        query: [Float],
        candidate: [Float],
        simd: anigma_cosine_simd_t = anigma_cosine_simd_t(0)
    ) throws -> Float {
        guard query.count == candidate.count else {
            throw CapsuleNativeError(
                status: ANIGMA_ERR_INVALID_ARG,
                code: ANIGMA_ERR_INVALID_ARG,
                message: "Query and candidate dimensions must match"
            )
        }
        guard query.count > 0 else {
            throw CapsuleNativeError(
                status: ANIGMA_ERR_INVALID_ARG,
                code: ANIGMA_ERR_INVALID_ARG,
                message: "Vector dimension must be greater than zero"
            )
        }
        
        var layout = anigma_cosine_vector_layout_t(
            dimension: query.count,
            stride: 1,
            alignment: 0,
            precision: ANIGMA_COSINE_PRECISION_SINGLE
        )
        
        var similarity: Float = 0.0
        var error = anigma_capsule_error_t()
        
        try query.withUnsafeBufferPointer { queryPtr in
            try candidate.withUnsafeBufferPointer { candidatePtr in
                guard let queryBase = queryPtr.baseAddress,
                      let candidateBase = candidatePtr.baseAddress else {
                    throw CapsuleNativeError(
                        status: ANIGMA_ERR_INVALID_ARG,
                        code: ANIGMA_ERR_INVALID_ARG,
                        message: "Empty vector"
                    )
                }
                
                let status = anigma_cosine_similarity_compute_single(
                    nil, // stateless operation
                    UnsafeRawPointer(queryBase),
                    UnsafeRawPointer(candidateBase),
                    &layout,
                    &similarity,
                    simd,
                    &error
                )
                guard status == ANIGMA_OK else {
                    throw cosineCapsuleError(status: status, error: error)
                }
            }
        }
        
        return similarity
    }
    
    /// Query performance characteristics for given parameters.
    /// - Parameters:
    ///   - dimension: Vector dimension
    ///   - batchSize: Number of vectors in batch
    ///   - simd: SIMD level to test
    /// - Returns: Estimated operations per second (approximate)
    /// - Throws: CapsuleError if parameters invalid
    public func queryPerformance(
        dimension: Int,
        batchSize: Int,
        simd: anigma_cosine_simd_t
    ) throws -> Double {
        var estimatedOps: Double = 0.0
        var error = anigma_capsule_error_t()
        
        let status = anigma_cosine_similarity_query_performance(
            dimension,
            batchSize,
            simd,
            &estimatedOps,
            &error
        )
        guard status == ANIGMA_OK else {
            throw cosineCapsuleError(status: status, error: error)
        }
        
        return estimatedOps
    }
    
    /// Validate vector layout for given SIMD level.
    /// - Parameters:
    ///   - layout: Vector layout to validate
    ///   - simd: SIMD level to test
    /// - Throws: CapsuleError if layout invalid for given SIMD
    public func validateLayout(
        _ layout: anigma_cosine_vector_layout_t,
        simd: anigma_cosine_simd_t
    ) throws {
        var error = anigma_capsule_error_t()
        var mutableLayout = layout
        
        let status = anigma_cosine_similarity_validate_layout(
            &mutableLayout,
            simd,
            &error
        )
        guard status == ANIGMA_OK else {
            throw cosineCapsuleError(status: status, error: error)
        }
    }
}

private func cosineCapsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleNativeError {
    let message = error.message.map { String(cString: $0) } ?? "Cosine capsule error"
    return CapsuleNativeError(status: status, code: error.code, message: message)
}
