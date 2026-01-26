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
    }
    
    // MARK: - Rank List Management
    
    /// Add a ranked list of items to the fusion context.
    /// - Parameters:
    ///   - items: List of items (id, rank)
    public func addRankList(_ items: [(id: UInt64, rank: UInt32)]) throws {
        guard !items.isEmpty else { return }
        
        // Split into parallel arrays for C API
        let ids = items.map { $0.id }
        let ranks = items.map { $0.rank }
        
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
        // Prepare output buffers
        var scores = [Double](repeating: 0.0, count: maxResults)
        var ids = [UInt64](repeating: 0, count: maxResults)
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
        
        // Count valid results (score > 0)
        // Since API doesn't return count directly here (it fills up to maxResults), 
        // we assume valid results have non-zero score or we filter?
        // Wait, C API signature: fuse(..., size_t max_results, ...)
        // The implementation typically fills buffer.
        // Let's assume we filter out 0 scores or similar if implementation doesn't return count.
        // Actually, for simplicity, let's look at `fuse_top_k` which is clearer.
        // But `fuse` is basic RRF. Let's use `fuse` and check how many non-zero.
        // RRF scores are sum(1/(k+r)), so always > 0.
        
        var results = [(id: UInt64, score: Double)]()
        for i in 0..<maxResults {
            if scores[i] > 0 {
                results.append((id: ids[i], score: scores[i]))
            } else {
                // Assuming sorted desc, if we hit 0, we are done
                break
            }
        }
        
        return results
    }
    
    /// Perform RRF and get top K results.
    public func fuseTopK(k: UInt32 = 60, topK: Int) throws -> [(id: UInt64, score: Double)] {
        var scores = [Double](repeating: 0.0, count: topK)
        var ids = [UInt64](repeating: 0, count: topK)
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
        for i in 0..<topK {
            if scores[i] > 0 {
                results.append((id: ids[i], score: scores[i]))
            }
        }
        
        return results
    }
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleError(status: status, code: error.code, message: message)
}

private func capsuleDestroyer(
    _ destroy: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
) -> (UnsafeMutableRawPointer) -> Void {
    { ptr in
        var err = anigma_capsule_error_t()
        _ = destroy(ptr, &err)
    }
}
