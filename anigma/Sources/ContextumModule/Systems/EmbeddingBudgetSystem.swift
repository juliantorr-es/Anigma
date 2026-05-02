import Foundation

public actor EmbeddingBudgetSystem {
    private var inFlightJobs: Set<String> = []
    private let maxInFlightPerRun: Int
    private let maxInFlightGlobal: Int
    private var budgets: [String: RunBudget] = [:]

    public struct RunBudget {
        public let runId: String
        public let maxEmbeddings: Int
        public var consumed: Int

        public var remaining: Int {
            maxEmbeddings - consumed
        }

        public var isExhausted: Bool {
            consumed >= maxEmbeddings
        }

        public init(runId: String, maxEmbeddings: Int) {
            self.runId = runId
            self.maxEmbeddings = maxEmbeddings
            self.consumed = 0
        }
    }

    public init(maxInFlightPerRun: Int = 4, maxInFlightGlobal: Int = 16) {
        self.maxInFlightPerRun = maxInFlightPerRun
        self.maxInFlightGlobal = maxInFlightGlobal
    }

    public func createBudget(runId: String, maxEmbeddings: Int) {
        budgets[runId] = RunBudget(runId: runId, maxEmbeddings: maxEmbeddings)
    }

    public func canStartJob(runId: String, jobId: String) -> Bool {
        guard inFlightJobs.count < maxInFlightGlobal else {
            return false
        }

        let runJobs = inFlightJobs.filter { $0.hasPrefix(runId) }
        guard runJobs.count < maxInFlightPerRun else {
            return false
        }

        if let budget = budgets[runId], budget.isExhausted {
            return false
        }

        return true
    }

    public func startJob(runId: String, jobId: String) throws {
        guard canStartJob(runId: runId, jobId: jobId) else {
            throw EmbeddingBudgetError.budgetExhausted(runId: runId)
        }

        inFlightJobs.insert(jobId)

        if var budget = budgets[runId] {
            budget.consumed += 1
            budgets[runId] = budget
        }
    }

    public func completeJob(jobId: String) {
        inFlightJobs.remove(jobId)
    }

    public func getBudget(runId: String) -> RunBudget? {
        budgets[runId]
    }

    public func getInFlightCount() -> Int {
        inFlightJobs.count
    }

    public func getIndexLagMetrics() -> IndexLagMetrics {
        IndexLagMetrics(
            inFlightGlobal: inFlightJobs.count,
            maxInFlightGlobal: maxInFlightGlobal,
            utilizationPercent: Double(inFlightJobs.count) / Double(maxInFlightGlobal) * 100
        )
    }
}

public struct IndexLagMetrics {
    public let inFlightGlobal: Int
    public let maxInFlightGlobal: Int
    public let utilizationPercent: Double

    public var isUnderPressure: Bool {
        utilizationPercent > 80
    }
}

public enum EmbeddingBudgetError: Error {
    case budgetExhausted(runId: String)
    case globalLimitReached
    case runLimitReached(runId: String)
}
