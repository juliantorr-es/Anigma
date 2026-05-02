import Foundation

public struct BenchmarkResult: Codable {
    public let name: String
    public let wallTimeSeconds: Double
    public let durationSeconds: Double
    public let operations: Int
    public let opsPerSecond: Double
    public let memoryBytes: Int64?
    public let rssBytes: Int64?
    public let allocationCount: Int64?
    public let crossLanguageCallCount: Int64?
    public let crossLanguageCallsByBoundary: [String: Int64]?
    public let bytesCopied: Int64?

    public init(
        name: String,
        wallTimeSeconds: Double,
        durationSeconds: Double,
        operations: Int,
        opsPerSecond: Double,
        memoryBytes: Int64?,
        rssBytes: Int64? = nil,
        allocationCount: Int64? = nil,
        crossLanguageCallCount: Int64? = nil,
        crossLanguageCallsByBoundary: [String: Int64]? = nil,
        bytesCopied: Int64? = nil
    ) {
        self.name = name
        self.wallTimeSeconds = wallTimeSeconds
        self.durationSeconds = durationSeconds
        self.operations = operations
        self.opsPerSecond = opsPerSecond
        self.memoryBytes = memoryBytes
        self.rssBytes = rssBytes
        self.allocationCount = allocationCount
        self.crossLanguageCallCount = crossLanguageCallCount
        self.crossLanguageCallsByBoundary = crossLanguageCallsByBoundary
        self.bytesCopied = bytesCopied
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
