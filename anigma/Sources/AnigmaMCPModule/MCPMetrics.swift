import Foundation

/// Per-tool metrics aggregation
public struct ToolMetrics: Sendable, Codable {
    public let toolName: String
    public let callCount: Int
    public let errorCount: Int
    public let cacheHitCount: Int
    public let cacheMissCount: Int

    // Latency percentiles (in milliseconds)
    public let latencyP50: Int
    public let latencyP95: Int
    public let latencyP99: Int

    // Overall statistics
    public let minLatencyMs: Int
    public let maxLatencyMs: Int
    public let avgLatencyMs: Int

    var cacheHitRate: Double {
        let total = cacheHitCount + cacheMissCount
        return total > 0 ? Double(cacheHitCount) / Double(total) : 0
    }

    init(
        toolName: String,
        callCount: Int,
        errorCount: Int,
        cacheHitCount: Int,
        cacheMissCount: Int,
        latencies: [Int]
    ) {
        self.toolName = toolName
        self.callCount = callCount
        self.errorCount = errorCount
        self.cacheHitCount = cacheHitCount
        self.cacheMissCount = cacheMissCount

        // Calculate percentiles from sorted latencies
        let sorted = latencies.sorted()
        self.latencyP50 = Self.percentile(sorted, 50)
        self.latencyP95 = Self.percentile(sorted, 95)
        self.latencyP99 = Self.percentile(sorted, 99)

        self.minLatencyMs = sorted.first ?? 0
        self.maxLatencyMs = sorted.last ?? 0
        self.avgLatencyMs = sorted.isEmpty ? 0 : sorted.reduce(0, +) / sorted.count
    }

    private static func percentile(_ sorted: [Int], _ p: Int) -> Int {
        guard !sorted.isEmpty else { return 0 }
        let index = Int(Double(sorted.count) * Double(p) / 100.0)
        return sorted[min(index, sorted.count - 1)]
    }
}

/// Per-tool latency samples (keeps last N samples for percentile calculation)
private struct LatencySamples {
    private var samples: [Int] = []
    private let maxSamples = 1000

    mutating func record(_ latencyMs: Int) {
        samples.append(latencyMs)
        if samples.count > maxSamples {
            samples.removeFirst()
        }
    }

    func getSamples() -> [Int] {
        samples
    }
}

/// Thread-safe metrics collection for the MCP server
public actor MCPMetrics {
    private var toolMetricsData: [String: (callCount: Int, errorCount: Int, cacheHit: Int, cacheMiss: Int, latencies: LatencySamples)] = [:]
    private let createdAt = Date()
    private var totalRequests = 0
    private var totalErrors = 0

    public nonisolated let id = UUID()

    public init() {}

    /// Records a tool execution
    public func recordToolExecution(
        toolName: String,
        success: Bool,
        durationMs: Int,
        cacheHit: Bool = false
    ) {
        var metrics = toolMetricsData[toolName, default: (0, 0, 0, 0, LatencySamples())]

        metrics.callCount += 1
        if !success {
            metrics.errorCount += 1
            totalErrors += 1
        }

        if cacheHit {
            metrics.cacheHit += 1
        } else {
            metrics.cacheMiss += 1
        }

        metrics.latencies.record(durationMs)
        toolMetricsData[toolName] = metrics
        totalRequests += 1
    }

    /// Gets metrics for a specific tool
    public func getToolMetrics(_ toolName: String) -> ToolMetrics? {
        guard let data = toolMetricsData[toolName] else { return nil }
        return ToolMetrics(
            toolName: toolName,
            callCount: data.callCount,
            errorCount: data.errorCount,
            cacheHitCount: data.cacheHit,
            cacheMissCount: data.cacheMiss,
            latencies: data.latencies.getSamples()
        )
    }

    /// Gets metrics for all tools
    public func getAllToolMetrics() -> [ToolMetrics] {
        toolMetricsData.map { toolName, data in
            ToolMetrics(
                toolName: toolName,
                callCount: data.callCount,
                errorCount: data.errorCount,
                cacheHitCount: data.cacheHit,
                cacheMissCount: data.cacheMiss,
                latencies: data.latencies.getSamples()
            )
        }.sorted { $0.toolName < $1.toolName }
    }

    /// Gets overall metrics
    public func getOverallMetrics() -> (totalRequests: Int, totalErrors: Int, errorRate: Double) {
        let errorRate = totalRequests > 0 ? Double(totalErrors) / Double(totalRequests) : 0
        return (totalRequests, totalErrors, errorRate)
    }

    /// Gets server uptime
    public func getUptime() -> TimeInterval {
        Date().timeIntervalSince(createdAt)
    }

    /// Resets all metrics
    public func reset() {
        toolMetricsData.removeAll()
        totalRequests = 0
        totalErrors = 0
    }
}
