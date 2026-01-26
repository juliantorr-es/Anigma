import BenchmarkHarness
import Foundation
import TextChunkingCapsule

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

    public func run() throws {
        try runAsync {
            let chunks = try await chunker.chunk(text)
            BenchmarkBlackhole.consume(chunks.count)
        }
    }
}

private func runAsync(_ operation: @escaping () async throws -> Void) throws {
    let semaphore = DispatchSemaphore(value: 0)
    var storedError: Error?

    Task {
        do {
            try await operation()
        } catch {
            storedError = error
        }
        semaphore.signal()
    }

    semaphore.wait()
    if let storedError {
        throw storedError
    }
}
