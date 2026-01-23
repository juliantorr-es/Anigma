import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

/// Swift wrapper for the cosine similarity capsule.
/// Provides high-performance SIMD-accelerated similarity search.
public final class CosineSimilarityCapsuleWrapper {
    /// Capsule identity information.
    public static var identity: anigma_capsule_identity_t {
        anigma_cosine_similarity_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    
    /// Create a new cosine similarity capsule.
    public init() throws {
        var rawHandle: anigma_cosine_similarity_capsule_t?
        var error = anigma_capsule_error_t()
        
        let status = anigma_cosine_similarity_capsule_create(&rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_cosine_similarity_capsule_destroy
        )
    }
    
    deinit {
        handle?.invalidate()
    }
    
    // MARK: - Single Operations
    
    /// Compute cosine similarity between two single vectors.
    public func computeSingle(
        query: [Float],
        candidate: [Float],
        simd: anigma_cosine_simd_t = ANIGMA_COSINE_SIMD_AUTO
    ) throws -> Float {
        guard query.count == candidate.count else {
            throw CapsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t())
        }
        
        let layout = anigma_cosine_vector_layout_t(
            dimension: query.count,
            stride: 1,
            alignment: 0,
            precision: ANIGMA_COSINE_PRECISION_SINGLE
        )
        
        var result: Float = 0.0
        var error = anigma_capsule_error_t()
        
        let status = query.withUnsafeBufferPointer { queryPtr in
            candidate.withUnsafeBufferPointer { candPtr in
                handle?.withHandle { rawHandle in
                    anigma_cosine_similarity_compute_single(
                        rawHandle,
                        queryPtr.baseAddress,
                        candPtr.baseAddress,
                        &layout,
                        &result,
                        simd,
                        &error
                    )
                } ?? ANIGMA_ERR_INTERNAL
            }
        }
        
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
        
        return result
    }
    
    // MARK: - Batch Operations
    
    /// Compute similarities for a batch of candidates.
    public func computeBatch(
        query: [Float],
        candidates: [[Float]],
        simd: anigma_cosine_simd_t = ANIGMA_COSINE_SIMD_AUTO
    ) throws -> [Float] {
        guard !candidates.isEmpty else { return [] }
        let dimension = query.count
        let count = candidates.count
        
        // Flatten candidates
        var flattenedCandidates = [Float]()
        flattenedCandidates.reserveCapacity(count * dimension)
        for cand in candidates {
            guard cand.count == dimension else {
                throw CapsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t())
            }
            flattenedCandidates.append(contentsOf: cand)
        }
        
        var results = [Float](repeating: 0.0, count: count)
        var error = anigma_capsule_error_t()
        
        let layout = anigma_cosine_vector_layout_t(
            dimension: dimension,
            stride: dimension, // Stride in elements (1 vector)
            alignment: 0,
            precision: ANIGMA_COSINE_PRECISION_SINGLE
        )
        
        let status = query.withUnsafeBufferPointer { queryPtr in
            flattenedCandidates.withUnsafeBufferPointer { candPtr in
                let descriptor = anigma_cosine_batch_descriptor_t(
                    count: count,
                    vectors: candPtr.baseAddress,
                    layout: layout
                )
                
                return results.withUnsafeMutableBufferPointer { resPtr in
                    handle?.withHandle { rawHandle in
                        anigma_cosine_similarity_compute_batch(
                            rawHandle,
                            queryPtr.baseAddress,
                            &descriptor,
                            resPtr.baseAddress,
                            simd,
                            &error
                        )
                    } ?? ANIGMA_ERR_INTERNAL
                }
            }
        }
        
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
        
        return results
    }
    
    // MARK: - Matrix Operations
    
    /// Compute all-to-all similarity matrix.
    public func computeMatrix(
        queries: [[Float]],
        candidates: [[Float]],
        simd: anigma_cosine_simd_t = ANIGMA_COSINE_SIMD_AUTO
    ) throws -> [Float] {
        guard !queries.isEmpty && !candidates.isEmpty else { return [] }
        let dimension = queries[0].count
        
        // Validate dimensions
        for q in queries {
            guard q.count == dimension else { throw CapsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t()) }
        }
        for c in candidates {
            guard c.count == dimension else { throw CapsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t()) }
        }
        
        // Flatten inputs
        let flattenedQueries = queries.flatMap { $0 }
        let flattenedCandidates = candidates.flatMap { $0 }
        
        var results = [Float](repeating: 0.0, count: queries.count * candidates.count)
        var error = anigma_capsule_error_t()
        
        let layout = anigma_cosine_vector_layout_t(
            dimension: dimension,
            stride: dimension,
            alignment: 0,
            precision: ANIGMA_COSINE_PRECISION_SINGLE
        )
        
        let status = flattenedQueries.withUnsafeBufferPointer { qPtr in
            flattenedCandidates.withUnsafeBufferPointer { cPtr in
                let qDesc = anigma_cosine_batch_descriptor_t(count: queries.count, vectors: qPtr.baseAddress, layout: layout)
                let cDesc = anigma_cosine_batch_descriptor_t(count: candidates.count, vectors: cPtr.baseAddress, layout: layout)
                
                return results.withUnsafeMutableBufferPointer { resPtr in
                    handle?.withHandle { rawHandle in
                        anigma_cosine_similarity_compute_matrix(
                            rawHandle,
                            &qDesc,
                            &cDesc,
                            resPtr.baseAddress,
                            simd,
                            &error
                        )
                    } ?? ANIGMA_ERR_INTERNAL
                }
            }
        }
        
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
        
        return results
    }
    
    // MARK: - Utilities
    
    public static func bestSIMD() -> anigma_cosine_simd_t {
        anigma_cosine_similarity_query_best_simd()
    }
}
