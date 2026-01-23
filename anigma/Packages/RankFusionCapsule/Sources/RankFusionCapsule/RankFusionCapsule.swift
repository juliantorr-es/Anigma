import Foundation
import AnigmaPrimitives

/// High-performance rank fusion for combining search results.
public final class RankFusionCapsule {
    private let wrapper: RankFusionCapsuleWrapper
    
    public init() throws {
        self.wrapper = try RankFusionCapsuleWrapper()
    }
    
    /// Perform Reciprocal Rank Fusion (RRF) on multiple lists of IDs.
    /// - Parameters:
    ///   - rankLists: List of ID lists, where index in inner list implies rank (0 = best)
    ///   - k: RRF constant (default 60)
    ///   - topK: Number of results to return
    public func fuse(rankLists: [[UInt64]], k: UInt32 = 60, topK: Int = 100) throws -> [(id: UInt64, score: Double)] {
        try wrapper.clear()
        
        for list in rankLists {
            // Convert list index to rank (0-based)
            let items = list.enumerated().map { (index, id) in
                (id: id, rank: UInt32(index))
            }
            try wrapper.addRankList(items)
        }
        
        return try wrapper.fuseTopK(k: k, topK: topK)
    }
    
    /// Perform RRF with explicit ranks.
    public func fuse(rankLists: [[(id: UInt64, rank: UInt32)]], k: UInt32 = 60, topK: Int = 100) throws -> [(id: UInt64, score: Double)] {
        try wrapper.clear()
        
        for list in rankLists {
            try wrapper.addRankList(list)
        }
        
        return try wrapper.fuseTopK(k: k, topK: topK)
    }
}
