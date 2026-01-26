import Foundation
import TelemetryCore

/// High-performance rank fusion for combining search results.
public final class RankFusionCapsule {
    private let wrapper: RankFusionCapsuleWrapper
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "rrf-v1"
    
    public init(diagnostics: CapsuleDiagnostics? = nil) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "RankFusionCapsule.init",
            category: "rankfusion.init",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        do {
            self.wrapper = try RankFusionCapsuleWrapper()
            self.diagnostics = resolvedDiagnostics
            span.end(status: .ok)
        } catch {
            resolvedDiagnostics.event(
                level: .error,
                category: "rankfusion.init",
                message: "Failed to create rank fusion capsule: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// Perform Reciprocal Rank Fusion (RRF) on multiple lists of IDs.
    /// - Parameters:
    ///   - rankLists: List of ID lists, where index in inner list implies rank (0 = best)
    ///   - k: RRF constant (default 60)
    ///   - topK: Number of results to return
    public func fuse(rankLists: [[UInt64]], k: UInt32 = 60, topK: Int = 100) throws -> [(id: UInt64, score: Double)] {
        let span = diagnostics.beginSpan(
            name: "RankFusionCapsule.fuseImplicit",
            category: "rankfusion.fuse",
            correlationID: nil,
            tags: [
                "list_count": "\(rankLists.count)",
                "top_k": "\(topK)",
                "k": "\(k)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        do {
            try wrapper.clear()
            for list in rankLists {
                let items = list.enumerated().map { (index, id) in
                    (id: id, rank: UInt32(index))
                }
                try wrapper.addRankList(items)
            }
            let results = try wrapper.fuseTopK(k: k, topK: topK)
            span.end(status: .ok)
            return results
        } catch {
            diagnostics.event(
                level: .error,
                category: "rankfusion.fuse",
                message: "Fusion failed: \(error)",
                correlationID: nil,
                tags: ["list_count": "\(rankLists.count)"]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// Perform RRF with explicit ranks.
    public func fuse(rankLists: [[(id: UInt64, rank: UInt32)]], k: UInt32 = 60, topK: Int = 100) throws -> [(id: UInt64, score: Double)] {
        let span = diagnostics.beginSpan(
            name: "RankFusionCapsule.fuseExplicit",
            category: "rankfusion.fuse",
            correlationID: nil,
            tags: [
                "list_count": "\(rankLists.count)",
                "top_k": "\(topK)",
                "k": "\(k)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        do {
            try wrapper.clear()
            for list in rankLists {
                try wrapper.addRankList(list)
            }
            let results = try wrapper.fuseTopK(k: k, topK: topK)
            span.end(status: .ok)
            return results
        } catch {
            diagnostics.event(
                level: .error,
                category: "rankfusion.fuse",
                message: "Fusion failed: \(error)",
                correlationID: nil,
                tags: ["list_count": "\(rankLists.count)"]
            )
            span.end(status: .error)
            throw error
        }
    }
}
