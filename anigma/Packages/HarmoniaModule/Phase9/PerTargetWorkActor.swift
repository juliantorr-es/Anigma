//
//  PerTargetWorkActor.swift
//  HarmoniaModule
//
//  Per-target work actor for Phase 9.2 concurrent execution.
//  Provides isolated work context to prevent cross-target state pollution.
//

import Foundation

/// Context for per-target work execution.
public struct TargetWorkContext: Sendable {
    public let targetId: String
    public let workspaceSnapshotHash: String
    public let scoringPolicyHash: String
    public let stopCondition: StopCondition

    public init(
        targetId: String,
        workspaceSnapshotHash: String,
        scoringPolicyHash: String,
        stopCondition: StopCondition
    ) {
        self.targetId = targetId
        self.workspaceSnapshotHash = workspaceSnapshotHash
        self.scoringPolicyHash = scoringPolicyHash
        self.stopCondition = stopCondition
    }
}

/// Per-target work actor for Phase 9.2.
/// Isolates target-specific work to prevent cross-target state pollution.
public actor PerTargetWorkActor {

    private let targetId: String
    private var commitAttempts: Int = 0
    private let singleCommitEnforcer: SingleCommitInvariantEnforcer

    public init(targetId: String) {
        self.targetId = targetId
        self.singleCommitEnforcer = SingleCommitInvariantEnforcer()
    }

    /// Execute work in isolated context for a target.
    /// Prevents cross-target communication and state pollution.
    public func executeForTarget<T: Sendable>(
        targetId: String,
        context: TargetWorkContext,
        work: (TargetWorkContext) async throws -> T
    ) async throws -> T {
        // Verify target matches the actor's target
        guard targetId == self.targetId else {
            throw WorkActorError.targetMismatch(expected: self.targetId, actual: targetId)
        }

        return try await work(context)
    }

    /// Attempt a commit with single-commit invariant enforcement.
    /// Throws if this target has already attempted a commit.
    public func attemptCommit(reason: String) async throws {
        try await singleCommitEnforcer.attemptCommit(reason: "Target \(targetId): \(reason)")
    }

    /// Check if this target already committed.
    public func hasCommitted() async -> Bool {
        return await singleCommitEnforcer.commitCount > 0
    }

    /// Reset commit attempts for new run.
    public func reset() async {
        await singleCommitEnforcer.reset()
    }
}

/// Errors in per-target work execution.
public enum WorkActorError: Error, LocalizedError {
    case targetMismatch(expected: String, actual: String)
    case workExecutionFailed(String)

    public var localizedDescription: String? {
        switch self {
        case .targetMismatch(let expected, let actual):
            return "Target mismatch: expected \(expected), got \(actual)"
        case .workExecutionFailed(let reason):
            return "Work execution failed: \(reason)"
        }
    }
}

/// Factory for creating per-target work actors.
public struct PerTargetWorkActorFactory {

    /// Create actors for a set of targets.
    /// Returns a map of targetId to actor for isolated execution.
    public static func createActors(for targetIds: [String]) -> [String: PerTargetWorkActor] {
        var actors: [String: PerTargetWorkActor] = [:]

        for targetId in targetIds {
            actors[targetId] = PerTargetWorkActor(targetId: targetId)
        }

        return actors
    }

    /// Execute work across multiple targets in parallel with strict isolation.
    /// Each target gets its own isolated actor context.
    public static func executeInParallel<T: Sendable>(
        targetIds: [String],
        contextProvider: @escaping (String) -> TargetWorkContext,
        work: @escaping @Sendable (String, TargetWorkContext, PerTargetWorkActor) async throws -> T
    ) async throws -> [String: T] {

        // Create actors for all targets
        let actors = createActors(for: targetIds)
        var results: [String: T] = [:]

        // Execute in parallel while maintaining isolation
        try await withThrowingTaskGroup(of: (String, T).self) { group in
            for (targetId, actor) in actors {
                let context = contextProvider(targetId)
                group.addTask {
                    let value = try await actor.executeForTarget(
                        targetId: targetId,
                        context: context
                    ) { ctx in
                        try await work(targetId, ctx, actor)
                    }
                    return (targetId, value)
                }
            }

            for try await (targetId, value) in group {
                results[targetId] = value
            }
        }
        return results
    }
}
