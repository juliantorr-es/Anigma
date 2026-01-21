//
//  InferencePlaneInfrastructure.swift
//  HarmoniaModule
//
//  Unified infrastructure that combines all bonkers-tier inference components:
//  - Architecture-aware scheduling (GQA, MLA, Differential, Diffusion)
//  - Agent behavior governance (overthinking, rogue actions)
//  - Learning impact measurement (curated training, UPFT)
//  - Governed telemetry integration
//  - Reasoning kernel integration for adversarial analysis
//
//  This is the "one ring" that rules them all.
//

import AnigmaCore
import Foundation

// MARK: - Infrastructure Configuration

/// Configuration for the unified inference infrastructure.
public struct InferenceInfrastructureConfig: Sendable {
    /// Whether to enable advanced architecture routing.
    public var enableArchitectureRouting: Bool

    /// Whether to enable diffusion backend.
    public var enableDiffusion: Bool

    /// Whether to enable agent behavior governance.
    public var enableBehaviorGovernance: Bool

    /// Whether to collect learning traces.
    public var enableLearningTraces: Bool

    /// Whether to run UPFT prefix extraction.
    public var enableUPFT: Bool

    /// Default behavior constraints.
    public var defaultBehaviorConstraints: AgentBehaviorConstraints

    /// Telemetry mode.
    public var telemetryMode: TelemetryMode

    public init(
        enableArchitectureRouting: Bool = true,
        enableDiffusion: Bool = true,
        enableBehaviorGovernance: Bool = true,
        enableLearningTraces: Bool = true,
        enableUPFT: Bool = true,
        defaultBehaviorConstraints: AgentBehaviorConstraints = .default,
        telemetryMode: TelemetryMode = .balanced
    ) {
        self.enableArchitectureRouting = enableArchitectureRouting
        self.enableDiffusion = enableDiffusion
        self.enableBehaviorGovernance = enableBehaviorGovernance
        self.enableLearningTraces = enableLearningTraces
        self.enableUPFT = enableUPFT
        self.defaultBehaviorConstraints = defaultBehaviorConstraints
        self.telemetryMode = telemetryMode
    }

    // MARK: - Presets

    /// Production CCSF configuration.
    public static let ccsfProduction = InferenceInfrastructureConfig(
        enableArchitectureRouting: true,
        enableDiffusion: true,
        enableBehaviorGovernance: true,
        enableLearningTraces: true,
        enableUPFT: false,  // Only in staging
        defaultBehaviorConstraints: .strict,
        telemetryMode: .balanced
    )

    /// Staging configuration.
    public static let staging = InferenceInfrastructureConfig(
        enableArchitectureRouting: true,
        enableDiffusion: true,
        enableBehaviorGovernance: true,
        enableLearningTraces: true,
        enableUPFT: true,
        defaultBehaviorConstraints: .default,
        telemetryMode: .research
    )

    /// Development/lab configuration.
    public static let development = InferenceInfrastructureConfig(
        enableArchitectureRouting: true,
        enableDiffusion: true,
        enableBehaviorGovernance: false,
        enableLearningTraces: true,
        enableUPFT: true,
        defaultBehaviorConstraints: .relaxed,
        telemetryMode: .research
    )
}

// MARK: - Unified Infrastructure

/// The unified inference infrastructure with all components.
public actor InferencePlaneInfrastructure {
    // MARK: - Components

    /// Configuration.
    private let config: InferenceInfrastructureConfig

    /// Model registry.
    public let modelRegistry: ModelRegistry

    /// Architecture registry.
    public let architectureRegistry: ArchitectureRegistry

    /// Enhanced scheduler.
    public let scheduler: EnhancedInferenceScheduler

    /// Diffusion adapter.
    public let diffusionAdapter: DiffusionInferenceAdapter

    /// Behavior governor.
    public let behaviorGovernor: AgentBehaviorGovernor

    /// Learning impact measurer.
    public let impactMeasurer: LearningImpactMeasurer

    /// UPFT extractor.
    public let upftExtractor: UPFTExtractor

    /// Integrated executor.
    public let executor: IntegratedInferenceExecutor

    /// Telemetry service (use existing TelemetryService).
    // Note: Uses existing AnigmaCore TelemetryService

    /// Telemetry gate.
    public let telemetryGate: TelemetryGate

    // MARK: - State

    /// Infrastructure health status.
    private var healthStatus: InfrastructureHealthStatus = .initializing

    /// Active sessions.
    private var activeSessions: [String: InferenceSession] = [:]

    /// Performance history.
    private var performanceHistory: [PerformanceSnapshot] = []

    // MARK: - Initialization

    public init(config: InferenceInfrastructureConfig = InferenceInfrastructureConfig()) {
        self.config = config

        // Initialize components
        self.modelRegistry = ModelRegistry()
        self.architectureRegistry = ArchitectureRegistry()
        self.behaviorGovernor = AgentBehaviorGovernor()
        self.impactMeasurer = LearningImpactMeasurer()
        self.upftExtractor = UPFTExtractor()
        self.telemetryGate = TelemetryGate()

        // Initialize scheduler with dependencies
        self.scheduler = EnhancedInferenceScheduler(
            architectureRegistry: architectureRegistry,
            behaviorGovernor: behaviorGovernor,
            impactMeasurer: impactMeasurer
        )

        // Initialize diffusion adapter
        self.diffusionAdapter = DiffusionInferenceAdapter(
            architectureRegistry: architectureRegistry
        )

        // Initialize integrated executor
        self.executor = IntegratedInferenceExecutor(
            scheduler: scheduler,
            diffusionAdapter: diffusionAdapter,
            behaviorGovernor: behaviorGovernor,
            impactMeasurer: impactMeasurer,
            upftExtractor: upftExtractor
        )

        self.healthStatus = .healthy
    }

    // MARK: - Session Management

    /// Starts an inference session.
    public func startSession(
        tenantId: String,
        environmentId: String,
        domain: String
    ) -> InferenceSession {
        let session = InferenceSession(
            id: UUID().uuidString,
            tenantId: tenantId,
            environmentId: environmentId,
            domain: domain,
            startedAt: Date()
        )

        activeSessions[session.id] = session
        return session
    }

    /// Ends a session and returns summary.
    public func endSession(_ sessionId: String) -> InferenceSessionSummary? {
        guard let session = activeSessions.removeValue(forKey: sessionId) else {
            return nil
        }

        return InferenceSessionSummary(
            sessionId: session.id,
            tenantId: session.tenantId,
            domain: session.domain,
            duration: Date().timeIntervalSince(session.startedAt),
            tasksExecuted: session.tasksExecuted,
            totalTokens: session.totalTokens,
            violationCount: session.violations.count
        )
    }

    // MARK: - Inference Execution

    /// Executes an inference task within a session.
    public func execute(
        task: InferenceTask,
        sessionId: String
    ) async throws -> IntegratedInferenceResult {
        guard var session = activeSessions[sessionId] else {
            throw InferenceError.executionFailed(reason: "Session not found: \(sessionId)")
        }

        // Get candidates from registry
        let candidates = await modelRegistry.findCandidates(
            for: task,
            tenantId: session.tenantId
        )

        // Create scheduling context
        let context = SchedulingContext(
            tenantId: session.tenantId,
            environmentId: session.environmentId,
            domain: session.domain,
            agentTurnId: session.currentTurnId
        )

        // Execute
        let result = try await executor.execute(
            task: task,
            candidates: candidates,
            context: context
        )

        // Update session
        session.tasksExecuted += 1
        session.totalTokens += result.result.tokensIn + result.result.tokensOut
        if result.hadViolations {
            session.violations.append(contentsOf: result.turnSummary?.violations ?? [])
        }
        activeSessions[sessionId] = session

        // Emit telemetry using helper
        let telemetryEvent = InferenceTelemetryHelper.createInferenceEvent(
            tenantId: session.tenantId,
            environmentId: session.environmentId,
            modelId: result.result.modelUsed,
            taskKind: task.kind.rawValue,
            tokensIn: result.result.tokensIn,
            tokensOut: result.result.tokensOut,
            latencyMs: result.totalLatency * 1000,
            success: true,
            architectureType: result.architectureUsed?.rawValue
        )
        // Telemetry event would be emitted via TelemetryService
        _ = telemetryEvent

        return result
    }

    // MARK: - Health & Status

    /// Gets current health status.
    public func getHealthStatus() -> InfrastructureHealthStatus {
        healthStatus
    }

    /// Runs health check.
    public func runHealthCheck() async -> InfrastructureHealthReport {
        var checks: [HealthCheckResult] = []

        // Check model registry
        let registryStats = await modelRegistry.statistics()
        checks.append(
            HealthCheckResult(
                component: "ModelRegistry",
                status: registryStats.enabledModels > 0 ? .healthy : .degraded,
                message: "\(registryStats.enabledModels) models enabled"
            ))

        // Check scheduler
        let schedulerStats = await scheduler.statistics()
        checks.append(
            HealthCheckResult(
                component: "Scheduler",
                status: .healthy,
                message: "\(schedulerStats.totalDecisions) decisions made"
            ))

        // Check behavior governor
        let behaviorStats = await behaviorGovernor.statistics()
        let behaviorStatus: ComponentHealthStatus =
            behaviorStats.totalViolations > 100 ? .degraded : .healthy
        checks.append(
            HealthCheckResult(
                component: "BehaviorGovernor",
                status: behaviorStatus,
                message: "\(behaviorStats.totalViolations) total violations"
            ))

        // Check telemetry
        checks.append(
            HealthCheckResult(
                component: "Telemetry",
                status: .healthy,
                message: "Gate active"
            ))

        // Compute overall status
        let overallStatus: InfrastructureHealthStatus
        if checks.allSatisfy({ $0.status == .healthy }) {
            overallStatus = .healthy
        } else if checks.contains(where: { $0.status == .failed }) {
            overallStatus = .failed
        } else {
            overallStatus = .degraded
        }

        healthStatus = overallStatus

        return InfrastructureHealthReport(
            status: overallStatus,
            checks: checks,
            timestamp: Date()
        )
    }

    // MARK: - Statistics

    /// Gets comprehensive infrastructure statistics.
    public func getStatistics() async -> InfrastructureStatistics {
        let schedulerStats = await scheduler.statistics()
        let behaviorStats = await behaviorGovernor.statistics()
        let registryStats = await modelRegistry.statistics()

        return InfrastructureStatistics(
            activeSessions: activeSessions.count,
            totalModels: registryStats.totalModels,
            enabledModels: registryStats.enabledModels,
            schedulingDecisions: schedulerStats.totalDecisions,
            diffusionUsage: schedulerStats.diffusionUsagePercentage,
            behaviorViolations: behaviorStats.totalViolations,
            architectureDistribution: schedulerStats.decisionsByArchitecture,
            timestamp: Date()
        )
    }

    // MARK: - Configuration Updates

    /// Sets behavior constraints for a domain.
    public func setBehaviorConstraints(
        _ constraints: AgentBehaviorConstraints,
        forDomain domain: String
    ) async {
        await behaviorGovernor.setConstraints(constraints, for: domain)
    }

    /// Sets telemetry policy for a tenant.
    public func setTelemetryPolicy(_ policy: TelemetryPolicy) async {
        await telemetryGate.setPolicy(policy)
    }
}

// MARK: - Supporting Types

/// An inference session.
public struct InferenceSession: Sendable {
    public let id: String
    public let tenantId: String
    public let environmentId: String
    public let domain: String
    public let startedAt: Date
    public var currentTurnId: String?
    public var tasksExecuted: Int = 0
    public var totalTokens: Int = 0
    public var violations: [BehaviorViolation] = []
}

/// Summary of a completed session.
public struct InferenceSessionSummary: Sendable {
    public let sessionId: String
    public let tenantId: String
    public let domain: String
    public let duration: TimeInterval
    public let tasksExecuted: Int
    public let totalTokens: Int
    public let violationCount: Int
}

/// Infrastructure health status.
public enum InfrastructureHealthStatus: String, Sendable, Codable {
    case initializing
    case healthy
    case degraded
    case failed
}

/// Component health status.
public enum ComponentHealthStatus: String, Sendable, Codable {
    case healthy
    case degraded
    case failed
}

/// Result of a health check.
public struct HealthCheckResult: Sendable {
    public let component: String
    public let status: ComponentHealthStatus
    public let message: String
}

/// Full health report.
public struct InfrastructureHealthReport: Sendable {
    public let status: InfrastructureHealthStatus
    public let checks: [HealthCheckResult]
    public let timestamp: Date
}

/// Performance snapshot.
public struct PerformanceSnapshot: Sendable {
    public let timestamp: Date
    public let activeSessions: Int
    public let totalDecisions: Int
    public let averageLatency: TimeInterval
}

/// Infrastructure statistics.
public struct InfrastructureStatistics: Sendable {
    public let activeSessions: Int
    public let totalModels: Int
    public let enabledModels: Int
    public let schedulingDecisions: Int
    public let diffusionUsage: Double
    public let behaviorViolations: Int
    public let architectureDistribution: [AttentionArchitecture: Int]
    public let timestamp: Date
}

// MARK: - Reasoning Integration

/// Puzzle builder for inference plane analysis.
public struct InferencePlanePuzzleBuilder {
    /// Builds a puzzle to check routing policy compliance.
    public static func buildRoutingPolicyPuzzle(
        task: InferenceTask,
        availableModels: [ModelDescriptor],
        tenantPolicy: TelemetryPolicy?
    ) -> InferenceRoutingPuzzle {
        // Abstract the task and models into a puzzle
        let abstractTask = AbstractInferenceTask(
            kind: task.kind.rawValue,
            privacyLevel: task.constraints.privacyLevel.rawValue,
            localOnly: task.constraints.localOnly,
            estimatedTokens: estimateTokens(task)
        )

        let abstractModels = availableModels.map { model in
            AbstractModel(
                id: model.id,
                backend: model.backend.rawValue,
                privacyTier: model.privacyTier.rawValue,
                isLocal: model.backend != .remoteAPI
            )
        }

        return InferenceRoutingPuzzle(
            task: abstractTask,
            models: abstractModels,
            constraints: [
                "restricted_data_local_only",
                "no_cross_tenant_routing",
                "diffusion_for_structured_only"
            ]
        )
    }

    private static func estimateTokens(_ task: InferenceTask) -> Int {
        switch task.input {
        case .text(let text):
            return text.count / 4
        case .messages(let messages):
            return messages.map { $0.content.count }.reduce(0, +) / 4
        case .batch(let texts):
            return texts.map { $0.count }.reduce(0, +) / 4
        case .structured:
            return 500
        }
    }
}

/// Abstract inference task for puzzles.
public struct AbstractInferenceTask: Sendable {
    public let kind: String
    public let privacyLevel: String
    public let localOnly: Bool
    public let estimatedTokens: Int
}

/// Abstract model for puzzles.
public struct AbstractModel: Sendable {
    public let id: String
    public let backend: String
    public let privacyTier: String
    public let isLocal: Bool
}

/// A puzzle for analyzing inference routing.
public struct InferenceRoutingPuzzle: Sendable {
    public let task: AbstractInferenceTask
    public let models: [AbstractModel]
    public let constraints: [String]
}

// MARK: - Convenience Extensions

extension InferencePlaneInfrastructure {
    /// Quick inference without session management.
    public func quickInference(
        task: InferenceTask,
        tenantId: String,
        environmentId: String,
        domain: String = "general"
    ) async throws -> IntegratedInferenceResult {
        let session = startSession(
            tenantId: tenantId,
            environmentId: environmentId,
            domain: domain
        )

        defer {
            Task {
                _ = self.endSession(session.id)
            }
        }

        return try await execute(task: task, sessionId: session.id)
    }
}
