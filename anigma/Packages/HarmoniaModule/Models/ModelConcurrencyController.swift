//
//  ModelConcurrencyController.swift
//  HarmoniaModule
//
//  Controls per-model concurrency limits using proper async/await primitives.
//  Migrated from: Harmonia/OrchestrumCore/Models/ModelConcurrencyController.swift
//

import Foundation
import AnigmaCore

// MARK: - Model Kind

/// Semantic classification of models for concurrency pooling.
/// Each kind has its own concurrency ceiling.
public enum ModelKind: String, Hashable, Sendable, CaseIterable, Codable {
    /// Fast chat models (deepseek-chat, etc.)
    case chat
    /// Standard reasoning models (deepseek-reasoner)
    case reasoner
    /// Heavy long-context reasoning models (deepseek-reasoner-1)
    case oracle
}

// MARK: - Concurrency Limits

/// Configuration for per-model concurrency limits.
public struct ConcurrencyLimits: Sendable {
    public let chat: Int
    public let reasoner: Int
    public let oracle: Int

    public static let `default` = ConcurrencyLimits(chat: 7, reasoner: 5, oracle: 2)
    public static let conservative = ConcurrencyLimits(chat: 3, reasoner: 2, oracle: 1)
    public static let aggressive = ConcurrencyLimits(chat: 10, reasoner: 8, oracle: 4)

    public init(chat: Int, reasoner: Int, oracle: Int) {
        self.chat = max(1, chat)
        self.reasoner = max(1, reasoner)
        self.oracle = max(1, oracle)
    }

    public func limit(for kind: ModelKind) -> Int {
        switch kind {
        case .chat: return chat
        case .reasoner: return reasoner
        case .oracle: return oracle
        }
    }
}

// MARK: - Concurrency Stats

/// Runtime statistics for the concurrency controller.
public struct ConcurrencyStats: Sendable {
    public let inFlight: [ModelKind: Int]
    public let limits: [ModelKind: Int]
    public let waiting: [ModelKind: Int]
    public let totalCompleted: [ModelKind: Int]
    public let totalRejected: [ModelKind: Int]

    public var description: String {
        var lines: [String] = []
        for kind in ModelKind.allCases {
            let current = inFlight[kind] ?? 0
            let max = limits[kind] ?? 0
            let queued = waiting[kind] ?? 0
            let done = totalCompleted[kind] ?? 0
            let rejected = totalRejected[kind] ?? 0
            lines.append("\(kind.rawValue): \(current)/\(max) in-flight, \(queued) waiting, \(done) completed, \(rejected) rejected")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Model Concurrency Controller

/// Controls per-model concurrency limits using proper async/await primitives.
///
/// This actor manages concurrency slots per model kind, allowing you to enforce
/// hard limits like "at most 7 chat calls, 5 reasoner calls, 2 oracle calls" in flight
/// at any given time across the entire daemon.
///
/// Instead of busy-waiting with `Task.sleep`, this uses Swift's continuation-based
/// waiting to efficiently queue requests when slots are exhausted.
public actor ModelConcurrencyController {
    // MARK: - State

    private var limits: [ModelKind: Int]
    private var inFlight: [ModelKind: Int] = [: ]
    private var waiters: [ModelKind: [CheckedContinuation<Void, Never>]] = [: ]

    // Counters for stats
    private var totalCompleted: [ModelKind: Int] = [: ]
    private var totalRejected: [ModelKind: Int] = [: ]

    // MARK: - Initialization

    public init(limits: ConcurrencyLimits = .default) {
        self.limits = [
            .chat: limits.chat,
            .reasoner: limits.reasoner,
            .oracle: limits.oracle
        ]

        // Initialize all counters
        for kind in ModelKind.allCases {
            inFlight[kind] = 0
            waiters[kind] = []
            totalCompleted[kind] = 0
            totalRejected[kind] = 0
        }
    }

    // MARK: - Configuration

    /// Update the concurrency limit for a specific model kind.
    public func setLimit(_ limit: Int, for kind: ModelKind) {
        limits[kind] = max(1, limit)
        // Wake up waiters in case we increased the limit
        wakeWaitersIfPossible(for: kind)
    }

    /// Update all limits at once.
    public func setLimits(_ newLimits: ConcurrencyLimits) {
        limits[.chat] = newLimits.chat
        limits[.reasoner] = newLimits.reasoner
        limits[.oracle] = newLimits.oracle

        for kind in ModelKind.allCases {
            wakeWaitersIfPossible(for: kind)
        }
    }

    // MARK: - Main API

    /// Execute an operation with a concurrency slot for the given model kind.
    ///
    /// This method will wait until a slot is available, then execute the operation.
    /// The slot is automatically released when the operation completes (success or failure).
    ///
    /// - Parameters:
    ///   - kind: The model kind to acquire a slot for.
    ///   - operation: The async operation to execute.
    /// - Returns: The result of the operation.
    /// - Throws: Any error thrown by the operation.
    public func withSlot<T: Sendable>(
        for kind: ModelKind,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        // Wait for a slot to become available
        await acquireSlot(for: kind)

        do {
            let result = try await operation()
            releaseSlot(for: kind, completed: true)
            return result
        } catch {
            releaseSlot(for: kind, completed: true)
            throw error
        }
    }

    /// Try to execute an operation immediately if a slot is available.
    ///
    /// - Parameters:
    ///   - kind: The model kind to acquire a slot for.
    ///   - operation: The async operation to execute.
    /// - Returns: The result of the operation, or nil if no slot was available.
    public func tryWithSlot<T: Sendable>(
        for kind: ModelKind,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T? {
        guard tryAcquireSlot(for: kind) else {
            totalRejected[kind, default: 0] += 1
            return nil
        }

        do {
            let result = try await operation()
            releaseSlot(for: kind, completed: true)
            return result
        } catch {
            releaseSlot(for: kind, completed: true)
            throw error
        }
    }

    /// Execute an operation with a timeout for slot acquisition.
    ///
    /// - Parameters:
    ///   - kind: The model kind to acquire a slot for.
    ///   - timeout: Maximum time to wait for a slot.
    ///   - operation: The async operation to execute.
    /// - Returns: The result of the operation.
    /// - Throws: `ConcurrencyError.timeout` if no slot becomes available within the timeout.
    public func withSlot<T: Sendable>(
        for kind: ModelKind,
        timeout: Duration,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        // Try to get a slot with timeout
        let acquired = await withTaskGroup(of: Bool.self) {
            group in
            group.addTask {
                await self.acquireSlot(for: kind)
                return true
            }

            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }

            // Return the first result
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }

        guard acquired else {
            totalRejected[kind, default: 0] += 1
            throw ConcurrencyError.timeout(kind: kind, waited: timeout)
        }

        do {
            let result = try await operation()
            releaseSlot(for: kind, completed: true)
            return result
        } catch {
            releaseSlot(for: kind, completed: true)
            throw error
        }
    }

    // MARK: - Stats

    /// Get current concurrency statistics.
    public func stats() -> ConcurrencyStats {
        ConcurrencyStats(
            inFlight: inFlight,
            limits: limits,
            waiting: waiters.mapValues { $0.count },
            totalCompleted: totalCompleted,
            totalRejected: totalRejected
        )
    }

    /// Check if a slot is immediately available for a model kind.
    public func hasAvailableSlot(for kind: ModelKind) -> Bool {
        let current = inFlight[kind] ?? 0
        let limit = limits[kind] ?? 1
        return current < limit
    }

    /// Get the number of in-flight requests for a model kind.
    public func inFlightCount(for kind: ModelKind) -> Int {
        inFlight[kind] ?? 0
    }

    /// Get the number of waiting requests for a model kind.
    public func waitingCount(for kind: ModelKind) -> Int {
        waiters[kind]?.count ?? 0
    }

    public func modelKinds() -> [ModelKind] {
        return ModelKind.allCases
    }

    // MARK: - Private Slot Management

    private func acquireSlot(for kind: ModelKind) async {
        let current = inFlight[kind] ?? 0
        let limit = limits[kind] ?? 1

        if current < limit {
            // Slot available, take it immediately
            inFlight[kind] = current + 1
            return
        }

        // No slot available, wait using continuation
        await withCheckedContinuation {
            (continuation: CheckedContinuation<Void, Never>) in
            waiters[kind, default: []].append(continuation)
        }

        // When we resume, we already have the slot (granted by releaseSlot)
    }

    private func tryAcquireSlot(for kind: ModelKind) -> Bool {
        let current = inFlight[kind] ?? 0
        let limit = limits[kind] ?? 1

        if current < limit {
            inFlight[kind] = current + 1
            return true
        }

        return false
    }

    private func releaseSlot(for kind: ModelKind, completed: Bool) {
        if completed {
            totalCompleted[kind, default: 0] += 1
        }

        // Check if there are waiters
        if var kindWaiters = waiters[kind], !kindWaiters.isEmpty {
            // Give the slot to the first waiter (FIFO)
            let waiter = kindWaiters.removeFirst()
            waiters[kind] = kindWaiters
            // Don't decrement inFlight - we're transferring the slot
            waiter.resume()
        } else {
            // No waiters, release the slot
            let current = inFlight[kind] ?? 1
            inFlight[kind] = max(0, current - 1)
        }
    }

    private func wakeWaitersIfPossible(for kind: ModelKind) {
        let current = inFlight[kind] ?? 0
        let limit = limits[kind] ?? 1
        var available = limit - current

        while available > 0, var kindWaiters = waiters[kind], !kindWaiters.isEmpty {
            let waiter = kindWaiters.removeFirst()
            waiters[kind] = kindWaiters
            inFlight[kind, default: 0] += 1
            available -= 1
            waiter.resume()
        }
    }
}

// MARK: - Errors

/// Errors that can occur during concurrency control.
public enum ConcurrencyError: Error, LocalizedError {
    case timeout(kind: ModelKind, waited: Duration)
    case rejected(kind: ModelKind, reason: String)

    public var errorDescription: String? {
        switch self {
        case .timeout(let kind, let waited):
            return "Timed out waiting for \(kind.rawValue) slot after \(waited)"
        case .rejected(let kind, let reason):
            return "Request for \(kind.rawValue) slot rejected: \(reason)"
        }
    }
}
