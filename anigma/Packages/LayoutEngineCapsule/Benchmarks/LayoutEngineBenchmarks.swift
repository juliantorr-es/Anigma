import BenchmarkHarness
import Foundation
import LayoutEngineCapsule

public final class LayoutEngineAnalysisBenchmark: BenchmarkCase {
    public let name = "layout_engine_analysis"
    public let iterations: Int
    private let sampleData: Data
    private let config: LayoutEngineConfig

    public init(iterations: Int = 10) throws {
        self.iterations = iterations
        self.sampleData = try loadSamplePDF()
        self.config = LayoutEngineConfig(determinismTier: 1, flags: LayoutEngineConfig.detectTables)
    }

    public func run() throws {
        let capsule = try LayoutEngineCapsule(config: config)
        let layouts = try capsule.analyzePDF(sampleData)
        BenchmarkBlackhole.consume(layouts.count)
    }
}

private func loadSamplePDF() throws -> Data {
    let fileURL = URL(fileURLWithPath: #filePath)
    let repoRoot = fileURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sampleURL = repoRoot.appendingPathComponent("Tests/LayoutEngineCapsuleTests/TestResources/sample.pdf")
    return try Data(contentsOf: sampleURL)
}
