import Foundation

public struct AgentStatsComponent: Codable, Hashable, Sendable {
    public let agentId: String
    public let taskTaxonomy: String
    public let totalExecutions: Int
    public let successCount: Int
    public let failureCount: Int
    public let avgDurationMs: Double
    public let p50DurationMs: Double
    public let p95DurationMs: Double
    public let lastExecuted: Date
    public let failureCodes: [String: Int]

    public init(
        agentId: String,
        taskTaxonomy: String,
        totalExecutions: Int = 0,
        successCount: Int = 0,
        failureCount: Int = 0,
        avgDurationMs: Double = 0,
        p50DurationMs: Double = 0,
        p95DurationMs: Double = 0,
        lastExecuted: Date = Date(),
        failureCodes: [String: Int] = [:]
    ) {
        self.agentId = agentId
        self.taskTaxonomy = taskTaxonomy
        self.totalExecutions = totalExecutions
        self.successCount = successCount
        self.failureCount = failureCount
        self.avgDurationMs = avgDurationMs
        self.p50DurationMs = p50DurationMs
        self.p95DurationMs = p95DurationMs
        self.lastExecuted = lastExecuted
        self.failureCodes = failureCodes
    }

    public var successRate: Double {
        guard totalExecutions > 0 else { return 0 }
        return Double(successCount) / Double(totalExecutions)
    }
}
