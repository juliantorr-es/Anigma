import BenchmarkHarness
import Foundation
import TextChunkingCapsule
import TextPipelineCapsule

public final class TextChunkingLargeInputBenchmark: BenchmarkCase {
    public let name = "text_chunking_large_input"
    public let iterations: Int
    private let chunker: TextChunkingCapsule
    private let text: String

    public init(iterations: Int = 20, repeatCount: Int = 4000) throws {
        self.iterations = iterations
        let config = TextChunkingConfig(targetChunkSize: 1024, minChunkSize: 512, maxChunkSize: 4096)
        self.chunker = try TextChunkingCapsule(config: config)
        self.text = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: repeatCount)
    }

    public func run() async throws {
        let chunks = try await chunker.chunk(text)
        BenchmarkBlackhole.consume(chunks.count)
    }

    public var metricHints: BenchmarkMetricHints {
        BenchmarkMetricHints(bytesCopiedPerIteration: Int64(text.utf8.count))
    }
}

public final class TextIngestNormalizeChunkHotPathBenchmark: BenchmarkCase {
    public let name = "text_chunking_ingest_normalize_hotpath"
    public let iterations: Int
    private let pipeline: TextPipelineCapsuleWrapper
    private let chunker: TextChunkingCapsule
    private let documents: [String]
    private let inputBytesPerIteration: Int64

    public init(iterations: Int = 12, documentCount: Int = 48, repeatCount: Int = 20) throws {
        self.iterations = iterations
        self.pipeline = try TextPipelineCapsuleWrapper(config: TextPipelineConfig())
        self.chunker = try TextChunkingCapsule(
            config: TextChunkingConfig(targetChunkSize: 768, minChunkSize: 384, maxChunkSize: 2048)
        )
        self.documents = (0..<documentCount).map { index in
            let header = "doc-\(index):"
            let body = String(
                repeating: " café naïve résumé UTF8 normalization + chunking workload. ",
                count: repeatCount
            )
            return header + body
        }
        self.inputBytesPerIteration = Int64(documents.reduce(0) { $0 + $1.utf8.count })
    }

    public func run() async throws {
        let normalized = try await pipeline.normalizeBatch(documents, form: .nfkc)
        var totalChunks = 0
        for document in normalized {
            totalChunks += try await chunker.chunk(document).count
        }
        BenchmarkBlackhole.consume(totalChunks)
    }

    public var metricHints: BenchmarkMetricHints {
        // Normalize + chunk touch the payload at least twice at the Swift/native boundary.
        BenchmarkMetricHints(bytesCopiedPerIteration: inputBytesPerIteration * 2)
    }
}
