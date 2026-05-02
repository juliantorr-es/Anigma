import Foundation

public struct BenchmarkMetricHints: Sendable {
    public let bytesCopiedPerIteration: Int64?

    public init(bytesCopiedPerIteration: Int64? = nil) {
        self.bytesCopiedPerIteration = bytesCopiedPerIteration
    }
}

/// Async-first benchmark contract.
///
/// Benchmarks should do real work directly with async/await instead of
/// wrapping tasks in semaphores or detached closures.
public protocol BenchmarkCase {
    var name: String { get }
    var iterations: Int { get }
    var metricHints: BenchmarkMetricHints { get }

    mutating func setUp() async throws
    mutating func run() async throws
    mutating func tearDown() async throws
}

public extension BenchmarkCase {
    var metricHints: BenchmarkMetricHints { BenchmarkMetricHints() }
    mutating func setUp() async throws {}
    mutating func tearDown() async throws {}
}
