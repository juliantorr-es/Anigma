import BenchmarkHarness
import Foundation
import RankFusionCapsule

public final class RankFusionMergeBenchmark: BenchmarkCase {
    public let name = "rank_fusion_merge"
    public let iterations: Int
    private let capsule: RankFusionCapsule
    private let rankLists: [[UInt64]]

    public init(iterations: Int = 200, listCount: Int = 4, listSize: Int = 500) throws {
        self.iterations = iterations
        self.capsule = try RankFusionCapsule()
        self.rankLists = (0..<listCount).map { listIndex in
            (0..<listSize).map { itemIndex in
                UInt64((listIndex * listSize) + itemIndex + 1)
            }
        }
    }

    public func run() throws {
        let fused = try capsule.fuse(rankLists: rankLists, k: 60, topK: 50)
        BenchmarkBlackhole.consume(fused.count)
    }
}
