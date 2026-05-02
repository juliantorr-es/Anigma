import Foundation
#if canImport(Metal)
import Metal
#endif
import OSLog
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

/// Swift wrapper for the cosine similarity capsule.
/// Provides high-performance SIMD-accelerated similarity search.
public final class CosineSimilarityCapsuleWrapper {
    private static let logger = Logger(
        subsystem: "com.anigma.CosineSimilarityCapsule",
        category: "ComputeBackend"
    )
    private enum BoundaryMetric {
        static let create = "capsule.cosine.create"
        static let computeSingle = "capsule.cosine.compute_single"
        static let computeBatch = "capsule.cosine.compute_batch"
        static let precomputeQueryNorm = "capsule.cosine.precompute_query_norm"
        static let computeBatchWithNorm = "capsule.cosine.compute_batch_with_norm"
        static let computeBatchThreshold = "capsule.cosine.compute_batch_threshold"
        static let computeMatrix = "capsule.cosine.compute_matrix"
        static let queryBestSIMD = "capsule.cosine.query_best_simd"
    }
    
    /// Compute backend selection
    public enum ComputeBackend {
        case auto      // Let system choose best option
        case cpuOnly   // Force CPU computation
        case gpuOnly   // Force GPU computation (throws if unavailable)
        case hybrid    // Try GPU, fall back to CPU
    }

    public struct MetalCapabilitySignals: Sendable {
        public let deviceName: String
        public let registryID: UInt64
        public let hasUnifiedMemory: Bool
        public let isLowPower: Bool
        public let maxBufferLengthBytes: Int
        public let recommendedMaxWorkingSetSizeBytes: Int
        public let threadExecutionWidth: Int
        public let maxThreadsPerThreadgroup: Int
        public let minOffloadCount: Int
        public let minOffloadDimension: Int
    }
    
    /// Metal implementation (optional)
    private let metalImplementation: CosineSimilarityMetalBackend?

    private struct MetalDecision {
        let shouldAttemptGPU: Bool
        let reason: String
    }

    /// Reused scratch storage for flattened vectors in hot wrapper->capsule calls.
    private let flattenScratchPool = ReusableArrayPool<Float>(maxBuffers: 4)
    
    /// Capsule identity information.
    public static var identity: anigma_capsule_identity_t {
        anigma_cosine_similarity_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    
    /// Create a new cosine similarity capsule.
    public init() throws {
        var rawHandle: anigma_cosine_similarity_capsule_t?
        var error = anigma_capsule_error_t()
        
        CrossLanguageCallMetrics.record(boundary: BoundaryMetric.create)
        let status = anigma_cosine_similarity_capsule_create(&rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleNativeError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_cosine_similarity_capsule_destroy
        )

        #if canImport(Metal)
        self.metalImplementation = CosineSimilarityMetalBackend()
        #else
        self.metalImplementation = nil
        #endif
    }
    
    deinit {
        handle?.invalidate()
        flattenScratchPool.clear()
    }

    public func metalCapabilitySignals() -> MetalCapabilitySignals? {
        guard let snapshot = metalImplementation?.capabilitySnapshot() else {
            return nil
        }

        return MetalCapabilitySignals(
            deviceName: snapshot.deviceName,
            registryID: snapshot.registryID,
            hasUnifiedMemory: snapshot.hasUnifiedMemory,
            isLowPower: snapshot.isLowPower,
            maxBufferLengthBytes: snapshot.maxBufferLengthBytes,
            recommendedMaxWorkingSetSizeBytes: snapshot.recommendedMaxWorkingSetSizeBytes,
            threadExecutionWidth: snapshot.threadExecutionWidth,
            maxThreadsPerThreadgroup: snapshot.maxThreadsPerThreadgroup,
            minOffloadCount: snapshot.minOffloadCount,
            minOffloadDimension: snapshot.minOffloadDimension
        )
    }
    
    // MARK: - Single Operations
    
    /// Compute cosine similarity between two single vectors.
    public func computeSingle(
        query: [Float],
        candidate: [Float],
        simd: anigma_cosine_simd_t = ANIGMA_COSINE_SIMD_AUTO
    ) throws -> Float {
        guard query.count == candidate.count else {
            throw CapsuleNativeError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t())
        }
        
        var layout = anigma_cosine_vector_layout_t(
            dimension: query.count,
            stride: 1,
            alignment: 0,
            precision: ANIGMA_COSINE_PRECISION_SINGLE
        )
        
        var result: Float = 0.0
        var error = anigma_capsule_error_t()
        
        let status = query.withUnsafeBufferPointer { queryPtr in
            return candidate.withUnsafeBufferPointer { candPtr in
                return (try? handle?.withHandle { rawHandle in
                    CrossLanguageCallMetrics.record(boundary: BoundaryMetric.computeSingle)
                    return anigma_cosine_similarity_compute_single(
                        rawHandle,
                        queryPtr.baseAddress,
                        candPtr.baseAddress,
                        &layout,
                        &result,
                        simd,
                        &error
                    )
                }) ?? ANIGMA_ERR_INTERNAL
            }
        }
        
        guard status == ANIGMA_OK else {
            throw CapsuleNativeError(status: status, error: error)
        }
        
        return result
    }
    
    // MARK: - Batch Operations

    private func withPreparedBatch<R>(
        query: [Float],
        candidates: [[Float]],
        _ body: (Int, Int, inout [Float]) throws -> R
    ) throws -> R {
        guard !candidates.isEmpty else {
            var empty: [Float] = []
            return try body(query.count, 0, &empty)
        }

        let dimension = query.count
        let count = candidates.count

        return try flattenScratchPool.withBuffer(minimumCapacity: count * dimension) { flattenedCandidates in
            for cand in candidates {
                guard cand.count == dimension else {
                    throw CapsuleNativeError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t())
                }
                flattenedCandidates.append(contentsOf: cand)
            }
            return try body(dimension, count, &flattenedCandidates)
        }
    }

    private static func queryMagnitude(for query: [Float]) -> Float {
        var sum = 0.0
        for value in query {
            let scalar = Double(value)
            sum += scalar * scalar
        }
        return Float(sum.squareRoot())
    }

    private func metalDecision(
        backend: ComputeBackend,
        count: Int,
        dimension: Int
    ) -> MetalDecision {
        guard let metalImplementation else {
            return MetalDecision(shouldAttemptGPU: false, reason: "Metal backend unavailable")
        }

        let assessment = metalImplementation.assessWorkload(count: count, dimension: dimension)
        switch backend {
        case .cpuOnly:
            return MetalDecision(shouldAttemptGPU: false, reason: "backend=cpuOnly")
        case .auto:
            return MetalDecision(
                shouldAttemptGPU: assessment.shouldOffload,
                reason: assessment.reason
            )
        case .gpuOnly, .hybrid:
            return MetalDecision(
                shouldAttemptGPU: assessment.isSupported,
                reason: assessment.reason
            )
        }
    }

    /// Compute similarities for a batch of candidates.
    public func computeBatch(
        query: [Float],
        candidates: [[Float]],
        simd: anigma_cosine_simd_t = ANIGMA_COSINE_SIMD_AUTO
    ) throws -> [Float] {
        try computeBatchWithNorm(
            query: query,
            queryNorm: Self.queryMagnitude(for: query),
            candidates: candidates,
            simd: simd,
            backend: .cpuOnly
        )
    }

    public func computeBatch(
        query: [Float],
        candidates: [[Float]],
        simd: anigma_cosine_simd_t = ANIGMA_COSINE_SIMD_AUTO,
        backend: ComputeBackend
    ) throws -> [Float] {
        try withPreparedBatch(query: query, candidates: candidates) { dimension, count, flattenedCandidates in
            guard count > 0 else { return [] }

            var results = [Float](repeating: 0.0, count: count)
            var error = anigma_capsule_error_t()

            let layout = anigma_cosine_vector_layout_t(
                dimension: dimension,
                stride: dimension, // Stride in elements (1 vector)
                alignment: 0,
                precision: ANIGMA_COSINE_PRECISION_SINGLE
            )

            let decision = metalDecision(
                backend: backend,
                count: count,
                dimension: dimension
            )

            if decision.shouldAttemptGPU,
               let metalImplementation,
               let gpuResults = metalImplementation.computeBatch(
                    query: query,
                    candidates: flattenedCandidates,
                    count: count,
                    dimension: dimension
               ) {
                return gpuResults
            }

            if backend == .gpuOnly {
                throw CapsuleNativeError(
                    status: ANIGMA_ERR_NOT_IMPLEMENTED,
                    code: ANIGMA_ERR_NOT_IMPLEMENTED,
                    message: "Metal backend unavailable for this workload: \(decision.reason)"
                )
            }

            if backend != .cpuOnly {
                Self.logger.debug(
                    "Using CPU fallback for computeBatch backend=\(String(describing: backend), privacy: .public) reason=\(decision.reason, privacy: .public)"
                )
            }

            let status = query.withUnsafeBufferPointer { queryPtr in
                return flattenedCandidates.withUnsafeBufferPointer { candPtr in
                    var descriptor = anigma_cosine_batch_descriptor_t(
                        count: count,
                        vectors: candPtr.baseAddress,
                        layout: layout
                    )
                    
                    return results.withUnsafeMutableBufferPointer { resPtr in
                        return (try? handle?.withHandle { rawHandle in
                            CrossLanguageCallMetrics.record(boundary: BoundaryMetric.computeBatch)
                            return anigma_cosine_similarity_compute_batch(
                                rawHandle,
                                queryPtr.baseAddress,
                                &descriptor,
                                resPtr.baseAddress,
                                simd,
                                &error
                            )
                        }) ?? ANIGMA_ERR_INTERNAL
                    }
                }
            }

            guard status == ANIGMA_OK else {
                throw CapsuleNativeError(status: status, error: error)
            }

            return results
        }
    }

    public func precomputeQueryNorm(
        query: [Float],
        simd: anigma_cosine_simd_t = ANIGMA_COSINE_SIMD_AUTO
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
                throw CapsuleNativeError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t())
            }

            try handle?.withHandle { rawHandle in
                CrossLanguageCallMetrics.record(boundary: BoundaryMetric.precomputeQueryNorm)
                let status = anigma_cosine_similarity_precompute_query_norm(
                    rawHandle,
                    UnsafeRawPointer(queryBase),
                    &layout,
                    &queryNorm,
                    simd,
                    &error
                )
                guard status == ANIGMA_OK else {
                    throw CapsuleNativeError(status: status, error: error)
                }
            }
        }

        return queryNorm
    }

    public func computeBatchWithNorm(
        query: [Float],
        queryNorm: Float,
        candidates: [[Float]],
        simd: anigma_cosine_simd_t = ANIGMA_COSINE_SIMD_AUTO,
        backend: ComputeBackend = .auto
    ) throws -> [Float] {
        try withPreparedBatch(query: query, candidates: candidates) { dimension, count, flattenedCandidates in
            guard count > 0 else { return [] }

            var results = [Float](repeating: 0.0, count: count)
            var error = anigma_capsule_error_t()

            let layout = anigma_cosine_vector_layout_t(
                dimension: dimension,
                stride: dimension,
                alignment: 0,
                precision: ANIGMA_COSINE_PRECISION_SINGLE
            )

            let decision = metalDecision(
                backend: backend,
                count: count,
                dimension: dimension
            )

            if decision.shouldAttemptGPU,
               let metalImplementation,
               let gpuResults = metalImplementation.computeBatchWithNorm(
                    query: query,
                    queryNorm: queryNorm,
                    candidates: flattenedCandidates,
                    count: count,
                    dimension: dimension
               ) {
                return gpuResults
            }

            if backend == .gpuOnly {
                throw CapsuleNativeError(
                    status: ANIGMA_ERR_NOT_IMPLEMENTED,
                    code: ANIGMA_ERR_NOT_IMPLEMENTED,
                    message: "Metal backend unavailable for this workload: \(decision.reason)"
                )
            }

            if backend != .cpuOnly {
                Self.logger.debug(
                    "Using CPU fallback for computeBatchWithNorm backend=\(String(describing: backend), privacy: .public) reason=\(decision.reason, privacy: .public)"
                )
            }

            let status = query.withUnsafeBufferPointer { queryPtr in
                return flattenedCandidates.withUnsafeBufferPointer { candPtr in
                    guard let queryBase = queryPtr.baseAddress,
                          let candidateBase = candPtr.baseAddress else {
                        return ANIGMA_ERR_INVALID_ARG
                    }

                    var descriptor = anigma_cosine_batch_descriptor_t(
                        count: count,
                        vectors: candidateBase,
                        layout: layout
                    )

                    return results.withUnsafeMutableBufferPointer { resPtr in
                        return (try? handle?.withHandle { rawHandle in
                            CrossLanguageCallMetrics.record(boundary: BoundaryMetric.computeBatchWithNorm)
                            return anigma_cosine_similarity_compute_batch_with_norm(
                                rawHandle,
                                UnsafeRawPointer(queryBase),
                                queryNorm,
                                &descriptor,
                                resPtr.baseAddress,
                                simd,
                                &error
                            )
                        }) ?? ANIGMA_ERR_INTERNAL
                    }
                }
            }

            guard status == ANIGMA_OK else {
                throw CapsuleNativeError(status: status, error: error)
            }

            return results
        }
    }

    public func computeBatchThreshold(
        query: [Float],
        candidates: [[Float]],
        minSimilarity: Float,
        simd: anigma_cosine_simd_t = ANIGMA_COSINE_SIMD_AUTO,
        backend: ComputeBackend = .auto
    ) throws -> (similarities: [Float], passedCount: Int) {
        try withPreparedBatch(query: query, candidates: candidates) { dimension, count, flattenedCandidates in
            guard count > 0 else { return ([], 0) }

            var results = [Float](repeating: -2.0, count: count)
            var passedCount: Int = 0
            var error = anigma_capsule_error_t()

            let layout = anigma_cosine_vector_layout_t(
                dimension: dimension,
                stride: dimension,
                alignment: 0,
                precision: ANIGMA_COSINE_PRECISION_SINGLE
            )

            let decision = metalDecision(
                backend: backend,
                count: count,
                dimension: dimension
            )

            if decision.shouldAttemptGPU,
               let metalImplementation,
               let gpuResult = metalImplementation.computeBatchThreshold(
                    query: query,
                    candidates: flattenedCandidates,
                    count: count,
                    dimension: dimension,
                    minSimilarity: minSimilarity
               ) {
                return (similarities: gpuResult.results, passedCount: gpuResult.passedCount)
            }

            if backend == .gpuOnly {
                throw CapsuleNativeError(
                    status: ANIGMA_ERR_NOT_IMPLEMENTED,
                    code: ANIGMA_ERR_NOT_IMPLEMENTED,
                    message: "Metal backend unavailable for this workload: \(decision.reason)"
                )
            }

            if backend != .cpuOnly {
                Self.logger.debug(
                    "Using CPU fallback for computeBatchThreshold backend=\(String(describing: backend), privacy: .public) reason=\(decision.reason, privacy: .public)"
                )
            }

            let status = query.withUnsafeBufferPointer { queryPtr in
                return flattenedCandidates.withUnsafeBufferPointer { candPtr in
                    var descriptor = anigma_cosine_batch_descriptor_t(
                        count: count,
                        vectors: candPtr.baseAddress,
                        layout: layout
                    )

                    return results.withUnsafeMutableBufferPointer { resPtr in
                        return (try? handle?.withHandle { rawHandle in
                            CrossLanguageCallMetrics.record(boundary: BoundaryMetric.computeBatchThreshold)
                            return anigma_cosine_similarity_compute_batch_threshold(
                                rawHandle,
                                queryPtr.baseAddress,
                                &descriptor,
                                minSimilarity,
                                resPtr.baseAddress,
                                &passedCount,
                                simd,
                                &error
                            )
                        }) ?? ANIGMA_ERR_INTERNAL
                    }
                }
            }

            guard status == ANIGMA_OK else {
                throw CapsuleNativeError(status: status, error: error)
            }

            return (similarities: results, passedCount: passedCount)
        }
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
            guard q.count == dimension else { throw CapsuleNativeError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t()) }
        }
        for c in candidates {
            guard c.count == dimension else { throw CapsuleNativeError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t()) }
        }
        
        return try flattenScratchPool.withBuffer(minimumCapacity: queries.count * dimension) { flattenedQueries in
            for query in queries {
                flattenedQueries.append(contentsOf: query)
            }

            return try flattenScratchPool.withBuffer(minimumCapacity: candidates.count * dimension) { flattenedCandidates in
                for candidate in candidates {
                    flattenedCandidates.append(contentsOf: candidate)
                }

                var results = [Float](repeating: 0.0, count: queries.count * candidates.count)
                var error = anigma_capsule_error_t()

                let layout = anigma_cosine_vector_layout_t(
                    dimension: dimension,
                    stride: dimension,
                    alignment: 0,
                    precision: ANIGMA_COSINE_PRECISION_SINGLE
                )

                let status = flattenedQueries.withUnsafeBufferPointer { qPtr in
                    return flattenedCandidates.withUnsafeBufferPointer { cPtr in
                        var qDesc = anigma_cosine_batch_descriptor_t(count: queries.count, vectors: qPtr.baseAddress, layout: layout)
                        var cDesc = anigma_cosine_batch_descriptor_t(count: candidates.count, vectors: cPtr.baseAddress, layout: layout)
                        
                        return results.withUnsafeMutableBufferPointer { resPtr in
                            return (try? handle?.withHandle { rawHandle in
                                CrossLanguageCallMetrics.record(boundary: BoundaryMetric.computeMatrix)
                                return anigma_cosine_similarity_compute_matrix(
                                    rawHandle,
                                    &qDesc,
                                    &cDesc,
                                    resPtr.baseAddress,
                                    simd,
                                    &error
                                )
                            }) ?? ANIGMA_ERR_INTERNAL
                        }
                    }
                }

                guard status == ANIGMA_OK else {
                    throw CapsuleNativeError(status: status, error: error)
                }

                return results
            }
        }
    }
    
    // MARK: - Utilities
    
    public static func bestSIMD() -> anigma_cosine_simd_t {
        CrossLanguageCallMetrics.record(boundary: BoundaryMetric.queryBestSIMD)
        return anigma_cosine_similarity_query_best_simd()
    }
}
