import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore
import BLAKE3

/// Wrapper for rank fusion capsule that performs reciprocal rank fusion (RRF).
/// Maps string chunk IDs to 64-bit integer IDs using BLAKE3 hash (first 8 bytes).
public actor RankFusionCapsuleWrapper {
    private var handle: CapsuleHandle<AnyObject>?
    private var stringToIntMap: [String: UInt64] = [:]
    private var intToStringMap: [UInt64: String] = [:]
    
    public init() throws {
        var rawHandle: anigma_rank_fusion_capsule_t?
        var error = anigma_capsule_error_t()
        
        let status = anigma_rank_fusion_capsule_create(&rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_rank_fusion_capsule_destroy
        )
    }
    
    deinit {
        handle?.invalidate()
    }
    
    /// Perform reciprocal rank fusion on multiple rank lists.
    /// - Parameters:
    ///   - rankLists: Array of dictionaries mapping chunk ID strings to ranks (0-based positions).
    ///   - k: RRF constant (typically 60).
    /// - Returns: Dictionary mapping chunk ID strings to fused scores.
    public func fuse(rankLists: [[String: Int]], k: Int = 60) throws -> [String: Double] {
        guard !rankLists.isEmpty else { return [:] }
        
        // Clear previous data and mappings
        try clear()
        
        // Add each rank list
        for rankList in rankLists {
            try addRankList(rankList)
        }
        
        // Get unique count to allocate buffers
        let uniqueCount = try getUniqueCount()
        guard uniqueCount > 0 else { return [:] }
        
        // Allocate buffers for IDs and scores
        var ids = [UInt64](repeating: 0, count: uniqueCount)
        var scores = [Double](repeating: 0.0, count: uniqueCount)
        
        // Perform fusion
        try performFusion(k: UInt32(k), ids: &ids, scores: &scores)
        
        // Map back to string IDs using our bidirectional mapping
        return mapResults(ids: ids, scores: scores)
    }
    
    /// Clear all rank lists from the capsule and reset mappings.
    public func clear() throws {
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_rank_fusion_capsule_clear(rawHandle, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        stringToIntMap.removeAll()
        intToStringMap.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func addRankList(_ rankList: [String: Int]) throws {
        guard !rankList.isEmpty else { return }
        
        // Convert string IDs to integer IDs, updating mappings
        let (ids, ranks) = try convertRankList(rankList)
        
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_rank_fusion_capsule_add_rank_list(
                rawHandle,
                ids,
                ranks,
                ids.count,
                &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
    }
    
    private func getUniqueCount() throws -> Int {
        var count: size_t = 0
        var error = anigma_capsule_error_t()
        
        try handle?.withHandle { rawHandle in
            let status = anigma_rank_fusion_capsule_get_unique_count(rawHandle, &count, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        return Int(count)
    }
    
    private func performFusion(k: UInt32, ids: inout [UInt64], scores: inout [Double]) throws {
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_rank_fusion_capsule_fuse(
                rawHandle,
                k,
                &scores,
                &ids,
                ids.count,
                &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
    }
    
    private func convertRankList(_ rankList: [String: Int]) throws -> (ids: [UInt64], ranks: [UInt32]) {
        var ids = [UInt64]()
        var ranks = [UInt32]()
        ids.reserveCapacity(rankList.count)
        ranks.reserveCapacity(rankList.count)
        
        for (chunkId, rank) in rankList {
            let intId = try hashStringToUInt64(chunkId)
            ids.append(intId)
            ranks.append(UInt32(rank))
            
            // Update mappings
            stringToIntMap[chunkId] = intId
            intToStringMap[intId] = chunkId
        }
        
        return (ids, ranks)
    }
    
    private func mapResults(ids: [UInt64], scores: [Double]) -> [String: Double] {
        var result: [String: Double] = [:]
        for (index, intId) in ids.enumerated() {
            guard let stringId = intToStringMap[intId] else {
                // This should never happen if mappings are consistent
                continue
            }
            result[stringId] = scores[index]
        }
        return result
    }
    
    private func hashStringToUInt64(_ string: String) -> UInt64 {
        // Compute BLAKE3 hash and take first 8 bytes as UInt64 (little-endian)
        let data = Data(string.utf8)
        let hash = BLAKE3.hash(contentsOf: data)
        let prefix = hash.prefix(8)
        guard prefix.count == 8 else {
            // This should never happen with BLAKE3
            fatalError("BLAKE3 hash produced less than 8 bytes")
        }
        return prefix.withUnsafeBytes { $0.load(as: UInt64.self) }
    }
}