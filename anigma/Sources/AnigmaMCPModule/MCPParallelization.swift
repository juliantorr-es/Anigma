//
//  MCPParallelization.swift
//  AnigmaMCPModule
//
//  Parallelization support for tool execution with structured concurrency patterns.
//

import Foundation

/// Configuration for parallel execution
public struct ParallelExecutionConfig: Sendable {
    /// Maximum concurrent operations
    public let maxConcurrency: Int

    /// Whether to fail fast on first error
    public let failFast: Bool

    /// Timeout for entire batch operation
    public let batchTimeout: TimeInterval

    /// Priority level for work
    public let priority: TaskPriority

    public init(
        maxConcurrency: Int = 4,
        failFast: Bool = false,
        batchTimeout: TimeInterval = 300,
        priority: TaskPriority = .medium
    ) {
        self.maxConcurrency = maxConcurrency
        self.failFast = failFast
        self.batchTimeout = batchTimeout
        self.priority = priority
    }
}

/// Result of a single parallel operation
public struct ParallelOperationResult<T: Sendable>: Sendable {
    public let index: Int
    public let value: T?
    public let error: Error?
    public let durationMs: Int

    public var isSuccess: Bool {
        error == nil && value != nil
    }

    public init(
        index: Int,
        value: T? = nil,
        error: Error? = nil,
        durationMs: Int = 0
    ) {
        self.index = index
        self.value = value
        self.error = error
        self.durationMs = durationMs
    }
}

/// Results from parallel execution
public struct ParallelBatchResults<T: Sendable>: Sendable {
    public let results: [ParallelOperationResult<T>]
    public let totalDurationMs: Int
    public let successCount: Int
    public let errorCount: Int
    public let timedOut: Bool

    public var successRate: Double {
        let total = successCount + errorCount
        return total > 0 ? Double(successCount) / Double(total) : 0
    }

    public init(
        results: [ParallelOperationResult<T>],
        totalDurationMs: Int,
        timedOut: Bool = false
    ) {
        self.results = results
        self.totalDurationMs = totalDurationMs
        self.timedOut = timedOut

        self.successCount = results.filter { $0.isSuccess }.count
        self.errorCount = results.filter { !$0.isSuccess }.count
    }
}

/// Coordinator for parallel tool execution
public actor MCPParallelizationCoordinator {
    private let semaphore: AsyncSemaphore
    private let config: ParallelExecutionConfig

    public init(config: ParallelExecutionConfig = ParallelExecutionConfig()) {
        self.config = config
        self.semaphore = AsyncSemaphore(value: config.maxConcurrency)
    }

    /// Execute multiple operations in parallel with concurrency control
    public func executeConcurrently<T: Sendable>(
        operations: [(index: Int, operation: @Sendable () async throws -> T)],
        name: String = "batch"
    ) async -> ParallelBatchResults<T> {
        let startTime = Date()
        var timedOut = false

        let results = await withTaskGroup(of: ParallelOperationResult<T>.self) { group in
            // Submit tasks up to max concurrency
            for (index, operation) in operations {
                // Check for timeout
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > config.batchTimeout {
                    timedOut = true
                    break
                }

                let semaphore = self.semaphore

                group.addTask(priority: config.priority) {
                    // Acquire semaphore slot
                    await semaphore.wait()
                    defer {
                        Task {
                            await semaphore.signal()
                        }
                    }

                    let opStartTime = Date()

                    do {
                        let result = try await operation()
                        let duration = Int(Date().timeIntervalSince(opStartTime) * 1000)

                        return ParallelOperationResult(
                            index: index,
                            value: result,
                            durationMs: duration
                        )
                    } catch {
                        let duration = Int(Date().timeIntervalSince(opStartTime) * 1000)

                        // Note: failFast optimization removed due to actor isolation constraints
                        // group.cancelAll() cannot be called from escaping closure capturing inout parameter
                        // Future: implement via separate error tracking mechanism

                        return ParallelOperationResult(
                            index: index,
                            error: error,
                            durationMs: duration
                        )
                    }
                }
            }

            // Collect results as they complete
            var collectedResults: [ParallelOperationResult<T>] = []
            for await result in group {
                collectedResults.append(result)
            }

            return collectedResults
        }

        // Sort by original index to maintain order
        var sortedResults = results
        sortedResults.sort { $0.index < $1.index }

        let totalDuration = Int(Date().timeIntervalSince(startTime) * 1000)

        return ParallelBatchResults(
            results: sortedResults,
            totalDurationMs: totalDuration,
            timedOut: timedOut
        )
    }

    /// Execute operations with automatic chunking for very large batches
    public func executeInChunks<T: Sendable>(
        operations: [(index: Int, operation: @Sendable () async throws -> T)],
        chunkSize: Int = 100,
        name: String = "chunked-batch"
    ) async -> ParallelBatchResults<T> {
        let chunks = operations.chunked(into: chunkSize)
        var allResults: [ParallelOperationResult<T>] = []
        let startTime = Date()

        for (chunkIndex, chunk) in chunks.enumerated() {
            fputs("[anigma-mcp] Processing chunk \(chunkIndex + 1)/\(chunks.count) (\(chunk.count) items)...\n", stderr)

            let chunkResults = await executeConcurrently(operations: chunk, name: "\(name)-chunk-\(chunkIndex)")
            allResults.append(contentsOf: chunkResults.results)

            // Break if timeout approaching
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > config.batchTimeout * 0.8 {
                fputs("[anigma-mcp] Approaching timeout, stopping chunk processing\n", stderr)
                break
            }
        }

        let totalDuration = Int(Date().timeIntervalSince(startTime) * 1000)

        return ParallelBatchResults(
            results: allResults,
            totalDurationMs: totalDuration
        )
    }

    /// Execute with automatic retry on transient errors
    public func executeWithRetry<T: Sendable>(
        operations: [(index: Int, operation: @Sendable () async throws -> T)],
        maxRetries: Int = 2,
        backoffMs: Int = 100,
        name: String = "retry-batch"
    ) async -> ParallelBatchResults<T> {
        var finalResults: [ParallelOperationResult<T>] = []
        var remainingOps = operations
        var attemptNumber = 0

        while !remainingOps.isEmpty && attemptNumber <= maxRetries {
            attemptNumber += 1

            if attemptNumber > 1 {
                fputs("[anigma-mcp] Retry attempt \(attemptNumber) for \(remainingOps.count) operations\n", stderr)
                try? await Task.sleep(nanoseconds: UInt64(backoffMs) * 1_000_000)
            }

            let batchResults = await executeConcurrently(operations: remainingOps, name: "\(name)-attempt-\(attemptNumber)")

            // Separate successes from retryable failures
            var retryOps: [(index: Int, operation: @Sendable () async throws -> T)] = []

            for result in batchResults.results {
                if result.isSuccess {
                    finalResults.append(result)
                } else if attemptNumber < maxRetries {
                    // Re-add for retry
                    if let origOp = remainingOps.first(where: { $0.index == result.index }) {
                        retryOps.append(origOp)
                    }
                } else {
                    // Final failure
                    finalResults.append(result)
                }
            }

            remainingOps = retryOps
        }

        // Sort by index
        finalResults.sort { $0.index < $1.index }

        return ParallelBatchResults(
            results: finalResults,
            totalDurationMs: 0  // Rough estimate
        )
    }
}

/// Async semaphore for concurrency control
private actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        while value <= 0 {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
        value -= 1
    }

    func signal() {
        value += 1
        if !waiters.isEmpty {
            let continuation = waiters.removeFirst()
            continuation.resume()
        }
    }
}

/// Extension to array for chunking
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
