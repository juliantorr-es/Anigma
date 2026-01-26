import Foundation

public struct BenchmarkResult: Codable {
    public let name: String
    public let durationSeconds: Double
    public let operations: Int
    public let opsPerSecond: Double
    public let memoryBytes: Int64?

    public init(
        name: String,
        durationSeconds: Double,
        operations: Int,
        opsPerSecond: Double,
        memoryBytes: Int64?
    ) {
        self.name = name
        self.durationSeconds = durationSeconds
        self.operations = operations
        self.opsPerSecond = opsPerSecond
        self.memoryBytes = memoryBytes
    }
}

public struct BenchmarkReport: Codable {
    public let generatedAt: Date
    public let results: [BenchmarkResult]

    public init(generatedAt: Date, results: [BenchmarkResult]) {
        self.generatedAt = generatedAt
        self.results = results
    }
}
