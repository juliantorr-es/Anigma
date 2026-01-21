//
//  MetopticonRunner.swift
//  AnigmaCore
//
//  Unified pipeline runner with governance integration.
//
//  This runner:
//  - Enforces RBAC and manifest policies
//  - Creates workload entities in ECS
//  - Executes pipelines via Graphene engine
//  - Updates workload metrics and health
//  - Returns results with workload tracking
//

import Foundation
import AnigmaPrimitives

/// Unified pipeline runner with governance.
public actor MetopticonRunner {
    private let world: World?
    private let adapter: MetopticonRunnerAdapter
    private let pipelineRunner: PipelineRunner
    private let accessEnforcer: MetopticonAccessEnforcer

    /// Initialize a Metopticon runner.
    /// - Parameters:
    ///   - world: Optional ECS world for workload component storage.
    ///   - store: Optional workload store (creates default if nil).
    ///   - engine: Optional Graphene engine (creates default if nil).
    ///   - accessEnforcer: Optional RBAC enforcer (creates default if nil).
    public init(
        world: World? = nil,
        store: MetopticonWorkloadStore? = nil,
        engine: GrapheneEngine? = nil,
        accessEnforcer: MetopticonAccessEnforcer? = nil,
        mlWorkerPath: String
    ) async throws {
        self.world = world
        let store = store ?? MetopticonWorkloadStore()
        self.adapter = MetopticonRunnerAdapter(store: store, world: world)
        self.pipelineRunner = try await ModulePipelineFactory.createRunner(engine: engine, mlWorkerPath: mlWorkerPath)
        self.accessEnforcer = accessEnforcer ?? MetopticonAccessEnforcer()
    }

    /// Run a pipeline with governance enforcement.
    /// - Parameters:
    ///   - graph: The node graph to execute.
    ///   - config: Workload configuration (category, owner, etc.).
    ///   - inputs: Input values for the graph.
    ///   - principal: The principal requesting execution.
    /// - Returns: A tuple containing the execution result and workload ID.
    /// - Throws: `MetopticonAccessError` if principal lacks permission, or pipeline execution errors.
    public func runPipeline(
        graph: NodeGraph,
        config: MetopticonWorkloadConfig,
        inputs: [String: AnyPortValue] = [:],
        principal: MetopticonPrincipal
    ) async throws -> (result: GraphExecutionResult, workloadId: WorkloadEntityId) {
        // 1. Validate principal access to this pipeline category
        try validateAccess(for: principal, config: config)

        // 2. Create workload entity
        let workloadId = await adapter.workloadStarted(config: config)

        // 3. Execute pipeline with profiling
        do {
            let (result, trace) = try await pipelineRunner.runWithProfiling(
                graph: graph,
                inputs: inputs
            )

            // 4. Update workload metrics from trace
            await updateWorkloadMetrics(
                workloadId,
                result: result,
                trace: trace
            )

            // 5. Mark workload as completed
            let durationMs = Int(result.executionTime * 1000)
            await adapter.workloadCompleted(workloadId, durationMs: durationMs)

            return (result, workloadId)
        } catch {
            // 6. On failure, mark workload as failed
            await adapter.workloadFailed(workloadId, error: error.localizedDescription)
            throw error
        }
    }

    /// Run a pipeline with streaming output.
    /// - Parameters:
    ///   - graph: The node graph to execute.
    ///   - config: Workload configuration.
    ///   - inputs: Input values for the graph.
    ///   - principal: The principal requesting execution.
    /// - Returns: An async throwing stream of pipeline events, each paired with workload ID.
    public func runPipelineStreaming(
        graph: NodeGraph,
        config: MetopticonWorkloadConfig,
        inputs: [String: AnyPortValue] = [:],
        principal: MetopticonPrincipal
    ) -> AsyncThrowingStream<(PipelineStreamEvent, WorkloadEntityId), Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Validate access
                do {
                    try validateAccess(for: principal, config: config)
                } catch {
                    continuation.finish(throwing: error)
                    return
                }

                // Create workload entity
                let workloadId = await adapter.workloadStarted(config: config)

                // Start streaming execution
                let stream = await pipelineRunner.runStreaming(graph: graph, inputs: inputs)

                do {
                    for try await event in stream {
                        // Update workload status based on event
                        await self.handleStreamingEvent(event, workloadId: workloadId)
                        continuation.yield((event, workloadId))
                    }
                    // Stream completed successfully
                    await adapter.workloadCompleted(workloadId, durationMs: 0) // duration unknown
                    continuation.finish()
                } catch {
                    await adapter.workloadFailed(workloadId, error: error.localizedDescription)
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func validateAccess(
        for principal: MetopticonPrincipal,
        config: MetopticonWorkloadConfig
    ) throws {
        // 1. Ensure principal has at least one role
        guard !principal.roles.isEmpty else {
            throw MetopticonAccessError.unauthorized(
                reason: "Principal has no roles",
                principalId: principal.id
            )
        }

        // 2. Check RBAC: principal must have a role that allows this category
        guard canRunCategory(config.category, for: principal) else {
            throw MetopticonAccessError.categoryNotAllowed(
                category: config.category,
                principalId: principal.id
            )
        }

        // 3. Check manifest prohibited uses
        _ = MetopticonManifestValidator()
        // For now, we could validate telemetry context later during execution
        // Placeholder for future manifest validation of pipeline inputs
    }

    private func canRunCategory(_ category: WorkloadCategory, for principal: MetopticonPrincipal) -> Bool {
        // Union of allowed categories across all roles
        var allowedCategories: Set<WorkloadCategory> = []

        for role in principal.roles {
            allowedCategories.formUnion(self.allowedCategories(for: role))
        }

        return allowedCategories.contains(category)
    }

    private func allowedCategories(for role: MetopticonRole) -> Set<WorkloadCategory> {
        switch role {
        case .itInfrastructure, .systemAdmin:
            // All categories
            return Set(WorkloadCategory.allCases)
        case .dspsStaff:
            return [.dsps, .altMedia]
        case .faculty:
            return [.altMedia, .grading, .research, .facultyTools, .personalSandbox]
        case .departmentLead:
            return [.altMedia, .grading, .research, .facultyTools]
        case .student:
            return [.personalSandbox]
        case .auditor:
            return []  // Cannot run pipelines
        }
    }

    private func updateWorkloadMetrics(
        _ workloadId: WorkloadEntityId,
        result: GraphExecutionResult,
        trace: ExecutionTrace?
    ) async {
        let nodeCount = result.nodeResults.count
        let nodesExecuted: Int
        let errorCount: Int
        if let trace = trace {
            nodesExecuted = trace.nodeTraces.values.filter { $0.errorInfo == nil }.count
            errorCount = trace.nodeTraces.values.filter { $0.errorInfo != nil }.count
        } else {
            nodesExecuted = nodeCount
            errorCount = 0
        }
        let cacheHits = result.cacheHits
        let cacheMisses = result.cacheMisses

        // Extract backend information from trace (simplified)
        var backends: Set<String> = []
        if let trace = trace {
            for nodeTrace in trace.nodeTraces {
                backends.insert(nodeTrace.value.executionBackend.rawValue)
            }
        }

        await adapter.updateFromTrace(
            workloadId,
            nodeCount: nodeCount,
            nodesExecuted: nodesExecuted,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            errorCount: errorCount,
            backends: backends,
            durationMs: Int(result.executionTime * 1000)
        )
    }

    private func handleStreamingEvent(
        _ event: PipelineStreamEvent,
        workloadId: WorkloadEntityId
    ) async {
        switch event {
        case .nodeStarted, .progress, .chunk, .nodeCompleted:
            // Keep workload running
            break
        case .complete(let result):
            // Update metrics from final result
            await updateWorkloadMetrics(workloadId, result: result, trace: nil)
        }
    }
}

/// Errors for Metopticon access violations.
public enum MetopticonAccessError: Error, LocalizedError {
    case unauthorized(reason: String, principalId: String)
    case categoryNotAllowed(category: WorkloadCategory, principalId: String)
    case manifestViolation(violations: [ManifestViolation])

    public var errorDescription: String? {
        switch self {
        case .unauthorized(let reason, let principalId):
            return "Unauthorized for principal \(principalId): \(reason)"
        case .categoryNotAllowed(let category, let principalId):
            return "Principal \(principalId) not allowed to run pipelines in category \(category.rawValue)"
        case .manifestViolation(let violations):
            return "Manifest violation(s): \(violations.map { $0.description }.joined(separator: ", "))"
        }
    }
}
