//
//  CLIOrchestratorIntegration.swift
//  AnigmaCLIOrchestrator
//
//  Integration layer connecting orchestrator with database tracking.
//  Wraps orchestrator calls with run/step tracking and receipts.
//

import AnigmaCLICore
import AnigmaCLIDatabase
import AnigmaCLIEventing
import AnigmaCLIGovernance
import AnigmaCLIProviders
import AnigmaCLIRouter
import Foundation

/// Orchestrator with integrated database tracking and receipts.
public actor CLIIntegratedOrchestrator {
    private let orchestrator: AnigmaCLIOrchestrator
    private let db: CLIDatabaseActor
    private let runManager: CLIRunManager
    private let receiptManager: CLIReceiptManager
    private let eventStream: CLIEventStream
    private let loopBreakerConfig: LoopBreakerConfig

    public init(
        orchestrator: AnigmaCLIOrchestrator,
        database: CLIDatabaseActor,
        eventStream: CLIEventStream,
        loopBreakerConfig: LoopBreakerConfig = .default
    ) {
        self.orchestrator = orchestrator
        self.db = database
        self.eventStream = eventStream
        self.loopBreakerConfig = loopBreakerConfig
        self.receiptManager = CLIReceiptManager(database: database)
        self.runManager = CLIRunManager(database: database, receiptManager: receiptManager)
    }

    /// Plan a task with tracking.
    public func plan(
        task: TaskIntent,
        context: TaskContext
    ) async throws -> TrackedPlanOutcome {
        // Create run record
        let run = try await runManager.createRun(
            taskSummary: task.summary,
            taskDetails: task.details,
            mode: .plan,
            dryRun: true,
            worktreePath: context.worktreeRoot.path
        )

        await emitEvent(.info, "Created run: \(run.runID.prefix(8))")

        // Update status
        try await runManager.updateRunStatus(runID: run.runID, status: .running)

        do {
            // Execute plan
            let outcome = try await orchestrator.plan(
                task: task,
                context: context
            )

            // Record completion
            try await runManager.updateRunStatus(
                runID: run.runID,
                status: .completed,
                message: "Plan created successfully"
            )

            return TrackedPlanOutcome(
                runID: run.runID,
                outcome: outcome
            )
        } catch {
            // Record failure
            try await runManager.updateRunStatus(
                runID: run.runID,
                status: .failed,
                message: error.localizedDescription
            )
            throw error
        }
    }

    /// Run a task with full tracking and receipts.
    public func run(
        task: TaskIntent,
        context: TaskContext,
        dryRun: Bool = true
    ) async throws -> TrackedRunOutcome {
        // Create run record
        let run = try await runManager.createRun(
            taskSummary: task.summary,
            taskDetails: task.details,
            mode: .run,
            dryRun: dryRun,
            worktreePath: context.worktreeRoot.path
        )

        await emitEvent(.info, "Created run: \(run.runID.prefix(8))")

        // Create loop breaker
        let loopBreaker = CLILoopBreaker(runID: run.runID, config: loopBreakerConfig)

        // Update status
        try await runManager.updateRunStatus(runID: run.runID, status: .running)

        do {
            // Step 1: Planning
            let planStep = try await runManager.recordStep(
                runID: run.runID,
                stepNumber: 1,
                actionType: "planning",
                actionData: task.summary
            )

            await loopBreaker.recordStep()

            // Check loop breaker before execution
            if let stopResult = await loopBreaker.shouldStop() {
                await emitEvent(.warning, "Loop breaker triggered: \(stopResult.reason.rawValue)")

                // Generate stop receipt
                _ = try await receiptManager.recordLoopBreaker(
                    runID: run.runID,
                    result: stopResult
                )

                try await runManager.updateStepStatus(
                    stepID: planStep.stepID,
                    status: .failed,
                    errorMessage: stopResult.message
                )

                try await runManager.updateRunStatus(
                    runID: run.runID,
                    status: .cancelled,
                    message: "Loop breaker: \(stopResult.message)"
                )

                return TrackedRunOutcome(
                    runID: run.runID,
                    outcome: RunOutcome(
                        plan: PlanOutcome(
                            contract: TaskContract(
                                taskId: task.id,
                                objective: task.summary,
                                requirements: [],
                                acceptanceCriteria: [],
                                builder: "stopped"
                            ),
                            route: RouteDecision(
                                taskId: task.id,
                                requiredCapabilities: [],
                                selected: nil,
                                candidates: [],
                                policy: RoutingPolicy(localFirst: true, allowExternalCLI: true, allowCloudFallback: true),
                                reason: "Loop breaker triggered"
                            )
                        ),
                        governance: GovernanceDecision(
                            allowed: false,
                            issues: [GovernanceIssue(severity: .error, message: stopResult.message)]
                        ),
                        dryRun: dryRun,
                        status: .failed,
                        message: stopResult.message
                    )
                )
            }

            let outcome = try await orchestrator.run(
                task: task,
                context: context,
                dryRun: dryRun
            )

            try await runManager.updateStepStatus(
                stepID: planStep.stepID,
                status: .completed
            )

            // Determine final status
            let finalStatus: RunStatus
            let finalMessage: String

            if !outcome.governance.allowed {
                finalStatus = .failed
                finalMessage = "Governance denied"
            } else if outcome.status == .failed {
                finalStatus = .failed
                finalMessage = outcome.message
            } else {
                finalStatus = .completed
                finalMessage = outcome.message
            }

            // Record completion
            try await runManager.updateRunStatus(
                runID: run.runID,
                status: finalStatus,
                message: finalMessage
            )

            // Log final counters
            let counters = await loopBreaker.getCurrentCounters()
            await emitEvent(.info, "Run completed - Steps: \(counters.steps), Tool Calls: \(counters.toolCalls), Time: \(String(format: "%.1f", counters.wallTimeSeconds))s")

            return TrackedRunOutcome(
                runID: run.runID,
                outcome: outcome
            )
        } catch {
            // Record failure
            try await runManager.updateRunStatus(
                runID: run.runID,
                status: .failed,
                message: error.localizedDescription
            )
            throw error
        }
    }

    /// Get run details.
    public func getRunDetails(runID: String) async throws -> RunDetails? {
        return try await runManager.getRunDetails(runID: runID)
    }

    /// List recent runs.
    public func listRuns(limit: Int = 20) async throws -> [Run] {
        return try await runManager.listRuns(limit: limit)
    }

    private func emitEvent(_ kind: CLIEventKind, _ message: String, _ metadata: [String: String] = [:]) async {
        await eventStream.emit(
            CLIEvent(kind: kind, message: message, metadata: metadata)
        )
    }
}

// MARK: - Tracked Outcomes

public struct TrackedPlanOutcome: Sendable {
    public let runID: String
    public let outcome: PlanOutcome

    public init(runID: String, outcome: PlanOutcome) {
        self.runID = runID
        self.outcome = outcome
    }
}

public struct TrackedRunOutcome: Sendable {
    public let runID: String
    public let outcome: RunOutcome

    public init(runID: String, outcome: RunOutcome) {
        self.runID = runID
        self.outcome = outcome
    }
}
