import BenchmarkHarness
import Foundation
import PDFCapsule

public final class PDFTextExtractionBenchmark: BenchmarkCase {
    public let name = "pdf_text_extraction"
    public let iterations: Int
    private let sampleData: Data

    public init(iterations: Int = 30) throws {
        self.iterations = iterations
        self.sampleData = try loadSamplePDF()
    }

    public func run() throws {
        let document = try PDFDocument(data: sampleData)
        let page = try document.page(at: 0)
        BenchmarkBlackhole.consume(page.text.count)
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
