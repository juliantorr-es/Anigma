import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

/// Swift wrapper for the rank fusion capsule.
/// Provides reciprocal rank fusion (RRF) and other algorithms.
public final class RankFusionCapsuleWrapper {
    /// Capsule identity information.
    public static var identity: anigma_capsule_identity_t {
        anigma_rank_fusion_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    private let rankIDScratchPool = ReusableArrayPool<UInt64>(maxBuffers: 2)
    private let rankValueScratchPool = ReusableArrayPool<UInt32>(maxBuffers: 2)
    private let scoreScratchPool = ReusableArrayPool<Double>(maxBuffers: 2)
    private let fusedIDScratchPool = ReusableArrayPool<UInt64>(maxBuffers: 2)
    
    /// Create a new rank fusion capsule.
    public init() throws {
        var rawHandle: anigma_rank_fusion_capsule_t?
        var error = anigma_capsule_error_t()
        
        let status = anigma_rank_fusion_capsule_create(&rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw capsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: capsuleDestroyer(anigma_rank_fusion_capsule_destroy)
        )
    }
    
    deinit {
        handle?.invalidate()
        rankIDScratchPool.clear()
        rankValueScratchPool.clear()
        scoreScratchPool.clear()
        fusedIDScratchPool.clear()
    }
    
    // MARK: - Rank List Management
    
    /// Add a ranked list of items to the fusion context.
    /// - Parameters:
    ///   - items: List of items (id, rank)
    public func addRankList(_ items: [(id: UInt64, rank: UInt32)]) throws {
        guard !items.isEmpty else { return }

        let status = try rankIDScratchPool.withBuffer(minimumCapacity: items.count) { ids in
            return try rankValueScratchPool.withBuffer(minimumCapacity: items.count) { ranks in
                for item in items {
                    ids.append(item.id)
                    ranks.append(item.rank)
                }

                var error = anigma_capsule_error_t()
                let status = ids.withUnsafeBufferPointer { idsPtr in
                    ranks.withUnsafeBufferPointer { ranksPtr in
                        (try? handle?.withHandle { rawHandle -> anigma_status_t in
                            anigma_rank_fusion_capsule_add_rank_list(
                                rawHandle,
                                idsPtr.baseAddress,
                                ranksPtr.baseAddress,
                                items.count,
                                &error
                            )
                        }) ?? ANIGMA_ERR_INTERNAL
                    }
                }

                guard status == ANIGMA_OK else {
                    throw capsuleError(status: status, error: error)
                }
                return status
            }
        }
        _ = status
    }
    
    /// Clear all rank lists.
    public func clear() throws {
        var error = anigma_capsule_error_t()
        
        let status = (try? handle?.withHandle { rawHandle -> anigma_status_t in
            anigma_rank_fusion_capsule_clear(rawHandle, &error)
        }) ?? ANIGMA_ERR_INTERNAL
        
        guard status == ANIGMA_OK else {
            throw capsuleError(status: status, error: error)
        }
    }
    
    /// Get number of unique items across all lists.
    public func getUniqueCount() throws -> Int {
        var error = anigma_capsule_error_t()
        var count: size_t = 0
        
        let status = (try? handle?.withHandle { rawHandle -> anigma_status_t in
            anigma_rank_fusion_capsule_get_unique_count(rawHandle, &count, &error)
        }) ?? ANIGMA_ERR_INTERNAL
        
        guard status == ANIGMA_OK else {
            throw capsuleError(status: status, error: error)
        }
        
        return Int(count)
    }
    
    // MARK: - Fusion
    
    /// Perform Reciprocal Rank Fusion (RRF).
    /// - Parameters:
    ///   - k: RRF constant (typically 60)
    ///   - maxResults: Maximum number of results to return
    /// - Returns: Fused list of (id, score)
    public func fuse(k: UInt32 = 60, maxResults: Int = 100) throws -> [(id: UInt64, score: Double)] {
        try scoreScratchPool.withBuffer(minimumCapacity: maxResults) { scores in
            scores.append(contentsOf: repeatElement(0.0, count: maxResults))
            return try fusedIDScratchPool.withBuffer(minimumCapacity: maxResults) { ids in
                ids.append(contentsOf: repeatElement(UInt64(0), count: maxResults))

                var error = anigma_capsule_error_t()
                let status = scores.withUnsafeMutableBufferPointer { scoresPtr in
                    ids.withUnsafeMutableBufferPointer { idsPtr in
                        (try? handle?.withHandle { rawHandle -> anigma_status_t in
                            anigma_rank_fusion_capsule_fuse(
                                rawHandle,
                                k,
                                scoresPtr.baseAddress,
                                idsPtr.baseAddress,
                                maxResults,
                                &error
                            )
                        }) ?? ANIGMA_ERR_INTERNAL
                    }
                }

                guard status == ANIGMA_OK else {
                    throw capsuleError(status: status, error: error)
                }

                var results = [(id: UInt64, score: Double)]()
                results.reserveCapacity(maxResults)
                for i in 0..<maxResults {
                    if scores[i] > 0 {
                        results.append((id: ids[i], score: scores[i]))
                    } else {
                        break
                    }
                }

                return results
            }
        }
    }
    
    /// Perform RRF and get top K results.
    public func fuseTopK(k: UInt32 = 60, topK: Int) throws -> [(id: UInt64, score: Double)] {
        try scoreScratchPool.withBuffer(minimumCapacity: topK) { scores in
            scores.append(contentsOf: repeatElement(0.0, count: topK))
            return try fusedIDScratchPool.withBuffer(minimumCapacity: topK) { ids in
                ids.append(contentsOf: repeatElement(UInt64(0), count: topK))

                var error = anigma_capsule_error_t()
                let status = scores.withUnsafeMutableBufferPointer { scoresPtr in
                    ids.withUnsafeMutableBufferPointer { idsPtr in
                        (try? handle?.withHandle { rawHandle -> anigma_status_t in
                            anigma_rank_fusion_capsule_fuse_top_k(
                                rawHandle,
                                k,
                                topK,
                                scoresPtr.baseAddress,
                                idsPtr.baseAddress,
                                &error
                            )
                        }) ?? ANIGMA_ERR_INTERNAL
                    }
                }

                guard status == ANIGMA_OK else {
                    throw capsuleError(status: status, error: error)
                }

                var results = [(id: UInt64, score: Double)]()
                results.reserveCapacity(topK)
                for i in 0..<topK where scores[i] > 0 {
                    results.append((id: ids[i], score: scores[i]))
                }

                return results
            }
        }
    }
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleNativeError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleNativeError(status: status, code: error.code, message: message)
}

private func capsuleDestroyer(
    _ destroy: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
) -> (UnsafeMutableRawPointer) -> Void {
    { ptr in
        var err = anigma_capsule_error_t()
        _ = destroy(ptr, &err)
    }
}
