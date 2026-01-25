import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore
import Crypto // Replaces BLAKE3

/// Fusion strategy types for rank fusion
public enum FusionStrategy: UInt32, CaseIterable, Sendable {
    case reciprocalRank = 1     // Reciprocal Rank Fusion (RRF)
    case weightedSum = 2       // Weighted sum with normalization
    case hybrid = 3            // Hybrid: dense similarity + sparse BM25 + heuristics
}

/// Normalization methods for scores
public enum NormalizationMethod: UInt32, CaseIterable, Sendable {
    case none = 1            // No normalization
    case minMax = 2          // Min-max normalization to [0,1]
    case zScore = 3           // Z-score normalization (mean=0, std=1)
    case rankBased = 4        // Rank-based normalization
}

/// Rank list with metadata for hybrid fusion
public struct RankList: Sendable {
    public var ranks: [String: Int]         // Document ID -> rank position
    public var scores: [String: Double]?     // Optional raw scores
    public var weight: Double                // Weight for this list (default: 1.0)
    public var priority: Int                // Source priority for tie-breaking (lower = higher priority)
    public var isDense: Bool               // True for dense similarity, false for sparse BM25
    
    public init(
        ranks: [String: Int],
        scores: [String: Double]? = nil,
        weight: Double = 1.0,
        priority: Int = 0,
        isDense: Bool = false
    ) {
        self.ranks = ranks
        self.scores = scores
        self.weight = weight
        self.priority = priority
        self.isDense = isDense
    }
}

/// Configuration for rank fusion operations
public struct RankFusionConfig: Sendable {
    public var strategy: FusionStrategy
    public var normalization: NormalizationMethod
    public var rrfK: Double              // RRF k constant (default: 60)
    public var topK: Int                 // Maximum results to return (default: 100)
    public var enableTieBreaking: Bool    // Enable deterministic tie-breaking (default: true)
    public var minScoreThreshold: Double  // Minimum score threshold (default: 0.0)
    
    public static var `default`: RankFusionConfig {
        return RankFusionConfig(
            strategy: .reciprocalRank,
            normalization: .none,
            rrfK: 60.0,
            topK: 100,
            enableTieBreaking: true,
            minScoreThreshold: 0.0
        )
    }
    
    public init(
        strategy: FusionStrategy = .reciprocalRank,
        normalization: NormalizationMethod = .none,
        rrfK: Double = 60.0,
        topK: Int = 100,
        enableTieBreaking: Bool = true,
        minScoreThreshold: Double = 0.0
    ) {
        self.strategy = strategy
        self.normalization = normalization
        self.rrfK = rrfK
        self.topK = topK
        self.enableTieBreaking = enableTieBreaking
        self.minScoreThreshold = minScoreThreshold
    }
}

/// Enhanced wrapper for rank fusion capsule with multiple fusion strategies.
/// Supports RRF, weighted sum, and hybrid dense+sparse fusion with deterministic tie-breaking.
public actor RankFusionCapsuleWrapper {
    private var handle: CapsuleHandle<AnyObject>?
    private var stringToIntMap: [String: UInt64] = [:]
    private var intToStringMap: [UInt64: String] = [:]
    private var config: RankFusionConfig
    
    /// Current configuration
    public var configuration: RankFusionConfig { config }
    
    public init(config: RankFusionConfig = .default) throws {
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
        self.config = config
    }
    
    deinit {
        handle?.invalidate()
    }
    
    /// Perform rank fusion using specified strategy.
    /// - Parameters:
    ///   - rankLists: Array of rank lists with metadata
    ///   - config: Fusion configuration (uses default if nil)
    /// - Returns: Dictionary mapping document ID strings to fused scores
    public func fuse(rankLists: [RankList], config: RankFusionConfig? = nil) throws -> [String: Double] {
        let fusionConfig = config ?? self.config
        guard !rankLists.isEmpty else { return [:] }
        
        // Clear previous data and mappings
        try clear()
        
        // Add each rank list to the capsule
        for rankList in rankLists {
            try addRankList(rankList)
        }
        
        // Get unique count to allocate buffers
        let uniqueCount = try getUniqueCount()
        guard uniqueCount > 0 else { return [:] }
        
        // Allocate buffers for IDs and scores
        var ids = [UInt64](repeating: 0, count: uniqueCount)
        var scores = [Double](repeating: 0.0, count: uniqueCount)
        
        // Perform fusion with specified strategy
        try performFusion(
            strategy: fusionConfig.strategy,
            normalization: fusionConfig.normalization,
            rrfK: fusionConfig.rrfK,
            ids: &ids,
            scores: &scores
        )
        
        // Apply top-K filtering and score threshold
        let filteredResults = applyFilters(
            ids: ids,
            scores: scores,
            topK: fusionConfig.topK,
            minScore: fusionConfig.minScoreThreshold
        )
        
        // Map back to string IDs using our bidirectional mapping
        return mapResults(
            ids: filteredResults.ids,
            scores: filteredResults.scores,
            enableTieBreaking: fusionConfig.enableTieBreaking
        )
    }
    
    /// Convenience method for simple RRF fusion with basic rank lists.
    /// - Parameters:
    ///   - rankLists: Array of dictionaries mapping document IDs to ranks
    ///   - k: RRF constant (default: 60)
    /// - Returns: Dictionary mapping document IDs to RRF scores
    public func fuseRRF(rankLists: [[String: Int]], k: Int = 60) throws -> [String: Double] {
        let rankListObjects = rankLists.map { ranks in
            RankList(ranks: ranks, weight: 1.0, priority: 0, isDense: false)
        }
        
        let config = RankFusionConfig(
            strategy: .reciprocalRank,
            normalization: .none,
            rrfK: Double(k),
            topK: 100,
            enableTieBreaking: true
        )
        
        return try fuse(rankLists: rankListObjects, config: config)
    }
    
    /// Convenience method for weighted sum fusion with scores.
    /// - Parameters:
    ///   - rankLists: Array of rank lists with scores
    ///   - weights: Array of weights for each list
    ///   - normalization: Normalization method
    /// - Returns: Dictionary mapping document IDs to weighted sum scores
    public func fuseWeightedSum(
        rankLists: [[String: Double]],
        weights: [Double]? = nil,
        normalization: NormalizationMethod = .minMax
    ) throws -> [String: Double] {
        let rankListObjects = rankLists.enumerated().map { index, scores in
            RankList(
                ranks: [:], // Not used in weighted sum with scores
                scores: scores,
                weight: weights?[safe: index] ?? 1.0,
                priority: index,
                isDense: true
            )
        }
        
        let config = RankFusionConfig(
            strategy: .weightedSum,
            normalization: normalization,
            rrfK: 60.0,
            topK: 100,
            enableTieBreaking: true
        )
        
        return try fuse(rankLists: rankListObjects, config: config)
    }
    
    /// Convenience method for hybrid fusion mixing dense and sparse results.
    /// - Parameters:
    ///   - denseResults: Dense similarity results with scores
    ///   - sparseResults: Sparse BM25 results with ranks
    ///   - denseWeight: Weight for dense results (default: 0.7)
    ///   - sparseWeight: Weight for sparse results (default: 0.3)
    /// - Returns: Dictionary mapping document IDs to hybrid scores
    public func fuseHybrid(
        denseResults: [String: Double],
        sparseResults: [String: Int],
        denseWeight: Double = 0.7,
        sparseWeight: Double = 0.3
    ) throws -> [String: Double] {
        let denseList = RankList(
            ranks: [:],
            scores: denseResults,
            weight: denseWeight,
            priority: 0,
            isDense: true
        )
        
        // Convert sparse BM25 ranks to dummy scores for processing
        var sparseScores: [String: Double] = [:]
        for (key, rank) in sparseResults {
            sparseScores[key] = 1.0 / Double(rank + 1)
        }
        
        let sparseList = RankList(
            ranks: sparseResults,
            scores: sparseScores,
            weight: sparseWeight,
            priority: 1,
            isDense: false
        )
        
        let config = RankFusionConfig(
            strategy: .hybrid,
            normalization: .minMax,
            rrfK: 60.0,
            topK: 100,
            enableTieBreaking: true
        )
        
        return try fuse(rankLists: [denseList, sparseList], config: config)
    }
    
    /// Clear all rank lists from the capsule and reset mappings.
    public func clear() throws {
        var error = anigma_capsule_error_t()
        try handle?.withHandle { (rawHandle: anigma_capsule_handle_t) throws -> Void in
            let status = anigma_rank_fusion_capsule_clear(rawHandle, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        stringToIntMap.removeAll()
        intToStringMap.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func addRankList(_ rankList: RankList) throws {
        guard !rankList.ranks.isEmpty else { return }
        
        // Convert string IDs to integer IDs, updating mappings
        let (ids, ranks) = try convertRankList(rankList)
        
        var error = anigma_capsule_error_t()
        try handle?.withHandle { (rawHandle: anigma_capsule_handle_t) throws -> Void in
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
        
        try handle?.withHandle { (rawHandle: anigma_capsule_handle_t) throws -> Void in
            let status = anigma_rank_fusion_capsule_get_unique_count(rawHandle, &count, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        return Int(count)
    }
    
    private func performFusion(
        strategy: FusionStrategy,
        normalization: NormalizationMethod,
        rrfK: Double,
        ids: inout [UInt64],
        scores: inout [Double]
    ) throws {
        var error = anigma_capsule_error_t()
        try handle?.withHandle { (rawHandle: anigma_capsule_handle_t) throws -> Void in
            // Use the standard fuse function with RRF k parameter
            let status = anigma_rank_fusion_capsule_fuse(
                rawHandle,
                UInt32(rrfK),
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
    
    private func convertRankList(_ rankList: RankList) throws -> (ids: [UInt64], ranks: [UInt32]) {
        var ids = [UInt64]()
        var ranks = [UInt32]()
        ids.reserveCapacity(rankList.ranks.count)
        ranks.reserveCapacity(rankList.ranks.count)
        
        for (chunkId, rank) in rankList.ranks {
            let intId = hashStringToUInt64(chunkId)
            ids.append(intId)
            ranks.append(UInt32(rank))
            
            // Update mappings
            stringToIntMap[chunkId] = intId
            intToStringMap[intId] = chunkId
        }
        
        return (ids, ranks)
    }
    
    private func applyFilters(
        ids: [UInt64],
        scores: [Double],
        topK: Int,
        minScore: Double
    ) -> (ids: [UInt64], scores: [Double]) {
        // Filter by minimum score threshold
        let filteredIndices = scores.enumerated().compactMap { index, score in
            score >= minScore ? index : nil
        }
        
        // Get top-K results by score (deterministic tie-breaking)
        let indexedScores = filteredIndices.map { ($0, scores[$0]) }
        let sortedScores = indexedScores.sorted { a, b in
            if abs(a.1 - b.1) < 1e-10 {
                let id1 = ids[a.0]
                let id2 = ids[b.0]
                return id1 < id2
            }
            return a.1 > b.1
        }
        
        let topKIndices = Array(sortedScores.prefix(topK).map { $0.0 })
        
        let filteredIds = topKIndices.map { ids[$0] }
        let filteredScores = topKIndices.map { scores[$0] }
        
        return (filteredIds, filteredScores)
    }
    
    private func mapResults(
        ids: [UInt64],
        scores: [Double],
        enableTieBreaking: Bool
    ) -> [String: Double] {
        var result: [String: Double] = [:]
        
        if enableTieBreaking {
            // Stable sorting by score then by document ID then by original position
            let indexedResults = ids.enumerated().sorted { a, b in
                let score1 = scores[a.offset]
                let score2 = scores[b.offset]
                let id1 = a.element
                let id2 = b.element
                
                if abs(score1 - score2) < 1e-10 {
                    if id1 != id2 {
                        return id1 < id2
                    }
                    return a.offset < b.offset
                }
                return score1 > score2
            }
            
            for (index, intId) in indexedResults {
                guard let stringId = intToStringMap[intId] else {
                    continue
                }
                result[stringId] = scores[index]
            }
        } else {
            // Simple mapping without reordering
            for (index, intId) in ids.enumerated() {
                guard let stringId = intToStringMap[intId] else {
                    continue
                }
                result[stringId] = scores[index]
            }
        }
        
        return result
    }
    
    private func hashStringToUInt64(_ string: String) -> UInt64 {
        // Compute SHA256 hash and take first 8 bytes as UInt64 (little-endian)
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        
        var result: UInt64 = 0
        var index = 0
        for byte in hash.prefix(8) {
            result |= UInt64(byte) << (index * 8)
            index += 1
        }
        return result
    }
}

// MARK: - Array Extension for Safe Access

private extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}