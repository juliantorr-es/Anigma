//
//  InferenceScheduler.swift
//  HarmoniaModule
//
//  Scheduler for inference tasks - handles model selection, speculative execution,
//  and resource allocation across backends.
//

import Foundation
import AnigmaCore

// MARK: - Scheduling Strategy

/// Strategy for scheduling inference tasks.
public enum SchedulingStrategy: String, Sendable, Codable {
    /// Use a single model based on constraints.
    case singleShot

    /// Run fast model first, fall back to slow if needed.
    case speculative

    /// Use small model for planning, large for execution.
    case cascaded

    /// Distribute work across multiple nodes.
    case distributed
}

/// Result of a scheduling decision.
public struct SchedulingDecision: Sendable {
    public let strategy: SchedulingStrategy
    public let primaryModel: ModelDescriptor
    public let fallbackModel: ModelDescriptor?
    public let reason: String

    public init(
        strategy: SchedulingStrategy,
        primaryModel: ModelDescriptor,
        fallbackModel: ModelDescriptor? = nil,
        reason: String
    ) {
        self.strategy = strategy
        self.primaryModel = primaryModel
        self.fallbackModel = fallbackModel
        self.reason = reason
    }
}

// MARK: - Resource Monitor

/// Monitors available compute resources.
public struct ResourceSnapshot: Sendable {
    public let availableVRAM: Double
    public let availableRAM: Double
    public let gpuUtilization: Double
    public let activeInferences: Int
    public let timestamp: Date

    public init(
        availableVRAM: Double,
        availableRAM: Double,
        gpuUtilization: Double,
        activeInferences: Int
    ) {
        self.availableVRAM = availableVRAM
        self.availableRAM = availableRAM
        self.gpuUtilization = gpuUtilization
        self.activeInferences = activeInferences
        self.timestamp = Date()
    }

    public static let mock = ResourceSnapshot(
        availableVRAM: 16.0,
        availableRAM: 32.0,
        gpuUtilization: 0.3,
        activeInferences: 2
    )
}

// MARK: - Inference Scheduler

/// Schedules inference tasks to appropriate backends.
public actor InferenceScheduler {
    /// Current resource snapshot.
    private var resources: ResourceSnapshot = .mock

    /// Pending tasks queue.
    private var pendingTasks: [InferenceTask] = []

    /// Active task count per model.
    private var activeTasksByModel: [String: Int] = [:]

    /// Scheduling history for analytics.
    private var schedulingHistory: [SchedulingRecord] = []

    /// Maximum history entries.
    private let maxHistorySize = 1000

    public init() {}

    // MARK: - Scheduling

    /// Makes a scheduling decision for a task.
    public func schedule(
        task: InferenceTask,
        candidates: [ModelDescriptor]
    ) -> SchedulingDecision? {
        guard let primary = candidates.first else { return nil }

        // Determine strategy based on task and constraints
        let strategy = selectStrategy(task: task, candidates: candidates)

        var fallback: ModelDescriptor?
        if strategy == .speculative && candidates.count > 1 {
            // For speculative, pick a larger fallback model
            fallback = candidates.first { $0.capabilities.qualityTier > primary.capabilities.qualityTier }
        }

        let decision = SchedulingDecision(
            strategy: strategy,
            primaryModel: primary,
            fallbackModel: fallback,
            reason: buildReason(strategy: strategy, task: task, model: primary)
        )

        // Record for analytics
        recordDecision(task: task, decision: decision)

        return decision
    }

    /// Updates resource snapshot.
    public func updateResources(_ snapshot: ResourceSnapshot) {
        self.resources = snapshot
    }

    /// Gets current resource state.
    public func currentResources() -> ResourceSnapshot {
        resources
    }

    // MARK: - Task Tracking

    /// Records that a task started.
    public func taskStarted(taskId: String, modelId: String) {
        activeTasksByModel[modelId, default: 0] += 1
    }

    /// Records that a task completed.
    public func taskCompleted(taskId: String, modelId: String) {
        activeTasksByModel[modelId, default: 1] -= 1
    }

    /// Gets active task count for a model.
    public func activeTaskCount(for modelId: String) -> Int {
        activeTasksByModel[modelId] ?? 0
    }

    // MARK: - Analytics

    /// Gets scheduling statistics.
    public func statistics() -> SchedulerStatistics {
        let strategyDistribution = Dictionary(
            grouping: schedulingHistory
        )            { $0.strategy }.mapValues { $0.count }

        let modelUsage = Dictionary(
            grouping: schedulingHistory
        )            { $0.modelId }.mapValues { $0.count }

        return SchedulerStatistics(
            totalDecisions: schedulingHistory.count,
            strategyDistribution: strategyDistribution,
            modelUsage: modelUsage,
            currentResources: resources
        )
    }

    // MARK: - Private Helpers

    private func selectStrategy(
        task: InferenceTask,
        candidates: [ModelDescriptor]
    ) -> SchedulingStrategy {
        // Use single shot by default
        var strategy: SchedulingStrategy = .singleShot

        // Use speculative for tasks that benefit from fast first response
        if task.kind == .chat && candidates.count > 1 {
            let hasFastOption = candidates.contains { $0.capabilities.qualityTier <= .small }
            let hasQualityOption = candidates.contains { $0.capabilities.qualityTier >= .base }

            if hasFastOption && hasQualityOption && task.constraints.maxLatency != nil {
                strategy = .speculative
            }
        }

        // Use cascaded for summarization of large documents
        if task.kind == .summarize {
            if case .text(let text) = task.input, text.count > 10000 {
                strategy = .cascaded
            }
        }

        // Could use distributed for batch operations
        if case .batch(let texts) = task.input, texts.count > 10 {
            strategy = .distributed
        }

        return strategy
    }

    private func buildReason(
        strategy: SchedulingStrategy,
        task: InferenceTask,
        model: ModelDescriptor
    ) -> String {
        switch strategy {
        case .singleShot:
            return "Best match for constraints: \(model.displayName)"
        case .speculative:
            return "Fast initial response with quality fallback"
        case .cascaded:
            return "Multi-stage processing for large input"
        case .distributed:
            return "Batch distributed across nodes"
        }
    }

    private func recordDecision(task: InferenceTask, decision: SchedulingDecision) {
        let record = SchedulingRecord(
            taskId: task.id,
            taskKind: task.kind,
            strategy: decision.strategy,
            modelId: decision.primaryModel.id,
            timestamp: Date()
        )

        schedulingHistory.append(record)

        // Trim history if needed
        if schedulingHistory.count > maxHistorySize {
            schedulingHistory.removeFirst(100)
        }
    }
}

// MARK: - Supporting Types

/// Record of a scheduling decision.
public struct SchedulingRecord: Sendable {
    public let taskId: String
    public let taskKind: InferenceTaskKind
    public let strategy: SchedulingStrategy
    public let modelId: String
    public let timestamp: Date
}

/// Statistics about scheduler behavior.
public struct SchedulerStatistics: Sendable {
    public let totalDecisions: Int
    public let strategyDistribution: [SchedulingStrategy: Int]
    public let modelUsage: [String: Int]
    public let currentResources: ResourceSnapshot
}

// MARK: - Speculative Execution

/// Manages speculative execution of inference tasks.
public actor SpeculativeExecutor {
    /// Runs primary and fallback models, returning the better result.
    public func execute(
        primary: () async throws -> InferenceResult,
        fallback: (() async throws -> InferenceResult)?,
        qualityThreshold: Double = 0.8
    ) async throws -> InferenceResult {
        // Start primary
        let primaryResult = try await primary()

        // If no fallback, return primary
        guard let fallbackTask = fallback else {
            return primaryResult
        }

        // For now, just return primary
        // In a real implementation, we'd evaluate quality and potentially use fallback
        _ = fallbackTask

        return primaryResult
    }
}

// MARK: - Load Balancer

/// Balances load across multiple inference instances.
public actor LoadBalancer {
    /// Nodes and their current load.
    private var nodeLoad: [String: Double] = [:]

    /// Selects the best node for a task.
    public func selectNode(
        for model: ModelDescriptor,
        availableNodes: [String]
    ) -> String? {
        guard !availableNodes.isEmpty else { return nil }

        // Select node with lowest load
        let sortedNodes = availableNodes.sorted { lhs, rhs in
            (nodeLoad[lhs] ?? 0) < (nodeLoad[rhs] ?? 0)
        }

        return sortedNodes.first
    }

    /// Updates node load.
    public func updateLoad(node: String, load: Double) {
        nodeLoad[node] = load
    }

    /// Records task started on a node.
    public func taskStarted(on node: String) {
        nodeLoad[node, default: 0] += 0.1
    }

    /// Records task completed on a node.
    public func taskCompleted(on node: String) {
        nodeLoad[node, default: 0.1] -= 0.1
    }
}
