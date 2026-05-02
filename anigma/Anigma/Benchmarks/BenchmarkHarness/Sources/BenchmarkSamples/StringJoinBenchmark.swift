import BenchmarkHarness
import Foundation

public struct StringJoinBenchmark: BenchmarkCase {
    public let name = "string_join"
    public let iterations: Int
    private let payload: [String]

    public init(iterations: Int = 2_000, payloadSize: Int = 64) {
        self.iterations = iterations
        self.payload = (0..<payloadSize).map { "token\($0)" }
    }

    public mutating func run() async throws {
        let joined = payload.joined(separator: ",")
        BenchmarkBlackhole.consume(joined)
    }
}
