import BenchmarkHarness
import Foundation
import VectorIndexCapsule

public final class VectorIndexBuildBenchmark: BenchmarkCase {
    public let name = "vector_index_build"
    public let iterations: Int
    private let config: VectorIndexConfig
    private let vectors: [[Float]]
    private let ids: [UInt64]

    public init(iterations: Int = 12, vectorCount: Int = 512, dimension: Int = 128) {
        self.iterations = iterations
        self.config = VectorIndexConfig(
            dimension: dimension,
            maxElements: vectorCount,
            M: 16,
            efConstruction: 200,
            efSearch: 64
        )
        self.vectors = (0..<vectorCount).map { makeVector(seed: $0, dimension: dimension) }
        self.ids = (0..<vectorCount).map { UInt64($0 + 1) }
    }

    public func run() throws {
        try runAsync {
            let index = try VectorIndexCapsule(config: config)
            for (id, vector) in zip(ids, vectors) {
                try await index.add(id: id, vector: vector)
            }
            let count = try await index.count
            BenchmarkBlackhole.consume(count)
        }
    }
}

public final class VectorIndexQueryBenchmark: BenchmarkCase {
    public let name = "vector_index_query"
    public let iterations: Int
    private let index: VectorIndexCapsule
    private let query: [Float]
    private let topK: Int

    public init(
        iterations: Int = 50,
        vectorCount: Int = 1024,
        dimension: Int = 128,
        topK: Int = 20
    ) throws {
        self.iterations = iterations
        self.query = makeVector(seed: 42, dimension: dimension)
        self.topK = topK
        let config = VectorIndexConfig(
            dimension: dimension,
            maxElements: vectorCount,
            M: 16,
            efConstruction: 200,
            efSearch: 64
        )
        self.index = try VectorIndexCapsule(config: config)
        let vectors = (0..<vectorCount).map { makeVector(seed: $0, dimension: dimension) }
        let ids = (0..<vectorCount).map { UInt64($0 + 1) }
        try runAsync {
            for (id, vector) in zip(ids, vectors) {
                try await index.add(id: id, vector: vector)
            }
        }
    }

    public func run() throws {
        try runAsync {
            let results = try await index.search(query: query, k: topK)
            BenchmarkBlackhole.consume(results.count)
        }
    }
}

private func makeVector(seed: Int, dimension: Int) -> [Float] {
    var vector: [Float] = []
    vector.reserveCapacity(dimension)
    for i in 0..<dimension {
        let value = Float((seed + i) % 10) / 10.0
        vector.append(value)
    }
    return vector
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
