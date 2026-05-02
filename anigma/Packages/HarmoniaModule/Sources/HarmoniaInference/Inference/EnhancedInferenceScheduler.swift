//
//  EnhancedInferenceScheduler.swift
//  HarmoniaModule
//
//  Enhanced scheduler with architecture-aware routing, diffusion support,
//  behavior governance integration, and learning impact tracking.
//
//  This is the "bonkers" tier scheduler that:
//  - Routes based on attention architecture profiles
//  - Integrates diffusion LMs for structured output
//  - Tracks agent behavior for governance
//  - Measures learning impact for training data curation
//

@preconcurrency import Foundation
import Foundation
import HarmoniaCore
import AnigmaPrimitives
import InferenceCore
import AnigmaCore
import HarmoniaInferenceContracts

// MARK: - Enhanced Scheduling Decision

/// Enhanced scheduling decision with architecture awareness.
public struct EnhancedSchedulingDecision: Sendable {
    public let strategy: SchedulingStrategy
    public let primaryModel: ModelDescriptor
    public let fallbackModel: ModelDescriptor?
    public let architectureProfile: ArchitectureProfile?
    public let diffusionConfig: DiffusionInferenceConfig?
    public let behaviorConstraints: AgentBehaviorConstraints
    public let reason: String
    public let architectureReason: String?
    public let estimatedLatency: Duration?
    public let estimatedQuality: Double

    public init(
        strategy: SchedulingStrategy,
        primaryModel: ModelDescriptor,
        fallbackModel: ModelDescriptor? = nil,
        architectureProfile: ArchitectureProfile? = nil,
        diffusionConfig: DiffusionInferenceConfig? = nil,
        behaviorConstraints: AgentBehaviorConstraints = .default,
        reason: String,
        architectureReason: String? = nil,
        estimatedLatency: Duration? = nil,
        estimatedQuality: Double = 0.8
    ) {
        self.strategy = strategy
        self.primaryModel = primaryModel
        self.fallbackModel = fallbackModel
        self.architectureProfile = architectureProfile
        self.diffusionConfig = diffusionConfig
        self.behaviorConstraints = behaviorConstraints
        self.reason = reason
        self.architectureReason = architectureReason
        self.estimatedLatency = estimatedLatency
        self.estimatedQuality = estimatedQuality
    }

    /// Whether this decision routes to a diffusion backend.
    public var usesDiffusion: Bool {
        architectureProfile?.generationMode == .diffusion
    }

    /// Whether this is a resource-constrained decision.
    public var isResourceConstrained: Bool {
        architectureProfile?.isResourceFriendly ?? false
    }
}

// MARK: - Enhanced Inference Scheduler

/// Enhanced scheduler with full architecture awareness.
public actor EnhancedInferenceScheduler {
    /// Architecture registry for model profiles.
    private let architectureRegistry: ArchitectureRegistry

    /// Behavior governor for agent constraints.
    private let behaviorGovernor: AgentBehaviorGovernor

    /// Learning impact measurer for trace collection.
    private let impactMeasurer: LearningImpactMeasurer

    /// Current resource snapshot.
    private var resources: ResourceSnapshot = .mock

    /// Scheduling history.
    private var history: [EnhancedSchedulingRecord] = []

    /// Architecture performance cache.
    private var architecturePerformance: [String: ArchitecturePerformanceMetrics] = [:]

    /// Maximum history size.
    private let maxHistorySize = 2000

    public init(
        architectureRegistry: ArchitectureRegistry = ArchitectureRegistry(),
        behaviorGovernor: AgentBehaviorGovernor = AgentBehaviorGovernor(),
        impactMeasurer: LearningImpactMeasurer = LearningImpactMeasurer()
    ) {
        self.architectureRegistry = architectureRegistry
        self.behaviorGovernor = behaviorGovernor
        self.impactMeasurer = impactMeasurer
    }

    // MARK: - Scheduling

    /// Makes an enhanced scheduling decision.
    public func schedule(
        task: InferenceTask,
        candidates: [ModelDescriptor],
        context: SchedulingContext
    ) async -> EnhancedSchedulingDecision? {
        guard !candidates.isEmpty else { return nil }

        // Derive architecture hints from task
        let hints = ArchitectureSchedulingHints.from(task: task)

        // Score candidates with architecture awareness
        var scoredCandidates: [(ModelDescriptor, Double, ArchitectureProfile?)] = []

        for candidate in candidates {
            let profile = await architectureRegistry.getProfile(for: candidate.family)
            let architectureScore = candidate.architectureScore(for: hints, profile: profile)
            let performanceScore = getPerformanceScore(candidate.family)
            let overallScore = architectureScore * 0.6 + performanceScore * 0.4

            scoredCandidates.append((candidate, overallScore, profile))
        }

        // Sort by score
        scoredCandidates.sort { $0.1 > $1.1 }

        guard let (primary, _, primaryProfile) = scoredCandidates.first else {
            return nil
        }

        // Determine strategy
        let strategy = selectStrategy(
            task: task,
            candidates: scoredCandidates.map { $0.0 },
            primaryProfile: primaryProfile,
            hints: hints
        )

        // Find fallback for speculative
        var fallback: ModelDescriptor?
        if strategy == .speculative && scoredCandidates.count > 1 {
            fallback = scoredCandidates
                .filter { $0.0.capabilities.qualityTier > primary.capabilities.qualityTier }
                .first?.0
        }

        // Determine diffusion config if applicable
        var diffusionConfig: DiffusionInferenceConfig?
        if primaryProfile?.generationMode == .diffusion {
            diffusionConfig = selectDiffusionConfig(for: task)
        }

        // Get behavior constraints for context
        let behaviorConstraints = await getBehaviorConstraints(for: context)

        // Build decision
        let decision = EnhancedSchedulingDecision(
            strategy: strategy,
            primaryModel: primary,
            fallbackModel: fallback,
            architectureProfile: primaryProfile,
            diffusionConfig: diffusionConfig,
            behaviorConstraints: behaviorConstraints,
            reason: buildReason(strategy: strategy, model: primary, hints: hints),
            architectureReason: buildArchitectureReason(profile: primaryProfile, hints: hints),
            estimatedLatency: estimateLatency(model: primary, task: task),
            estimatedQuality: scoredCandidates.first?.1 ?? 0.5
        )

        // Record for analytics
        recordDecision(task: task, decision: decision, context: context)

        return decision
    }

    /// Updates resource snapshot.
    public func updateResources(_ snapshot: ResourceSnapshot) {
        self.resources = snapshot
    }

    /// Records performance metrics for an architecture.
    public func recordPerformance(
        family: String,
        latency: Duration,
        quality: Double,
        success: Bool
    ) {
        var metrics = architecturePerformance[family] ?? ArchitecturePerformanceMetrics()
        metrics.record(latency: latency, quality: quality, success: success)
        architecturePerformance[family] = metrics
    }

    // MARK: - Private Helpers

    private func selectStrategy(
        task: InferenceTask,
        candidates: [ModelDescriptor],
        primaryProfile: ArchitectureProfile?,
        hints: ArchitectureSchedulingHints
    ) -> SchedulingStrategy {
        // Diffusion models work best with single-shot for structured output
        if primaryProfile?.generationMode == .diffusion {
            return .singleShot
        }

        // Use speculative for latency-sensitive chat
        if task.kind == .chat && candidates.count > 1 {
            if let latency = task.constraints.maxLatency,
               latency < .seconds(2) {
                return .speculative
            }
        }

        // Use cascaded for large summarization
        if task.kind == .summarize {
            if case .text(let text) = task.input, text.count > 10000 {
                return .cascaded
            }
        }

        // Use distributed for batches
        if case .batch(let texts) = task.input, texts.count > 10 {
            return .distributed
        }

        return .singleShot
    }

    private func selectDiffusionConfig(for task: InferenceTask) -> DiffusionInferenceConfig {
        switch task.kind {
        case .codeGeneration:
            return .code
        case .extraction:
            return .structured
        default:
            if task.constraints.maxLatency != nil {
                return .fast
            }
            return .quality
        }
    }

    private func getBehaviorConstraints(for context: SchedulingContext) async -> AgentBehaviorConstraints {
        // Strict for DSPS/Transcriptum domains
        if context.domain == "dsps" || context.domain == "transcriptum" {
            return .strict
        }

        // Default for others
        return .default
    }

    private func getPerformanceScore(_ family: String) -> Double {
        guard let metrics = architecturePerformance[family] else {
            return 0.5  // Unknown, neutral score
        }
        return metrics.overallScore
    }

    private func estimateLatency(model: ModelDescriptor, task: InferenceTask) -> Duration? {
        let tokensPerSecond = model.resources.expectedTokensPerSecond
        guard tokensPerSecond > 0 else { return nil }

        let estimatedTokens: Int
        switch task.input {
        case .text(let text):
            estimatedTokens = text.count / 4 + 500  // Input + typical output
        case .messages(let messages):
            let inputTokens = messages.map { $0.content.count }.reduce(0, +) / 4
            estimatedTokens = inputTokens + 500
        default:
            estimatedTokens = 1000
        }

        let seconds = Double(estimatedTokens) / tokensPerSecond
        return .seconds(seconds)
    }

    private func buildReason(
        strategy: SchedulingStrategy,
        model: ModelDescriptor,
        hints: ArchitectureSchedulingHints
    ) -> String {
        switch strategy {
        case .singleShot:
            return "Best match: \(model.displayName)"
        case .speculative:
            return "Fast initial + quality fallback"
        case .cascaded:
            return "Multi-stage for large input"
        case .distributed:
            return "Distributed batch processing"
        }
    }

    private func buildArchitectureReason(
        profile: ArchitectureProfile?,
        hints: ArchitectureSchedulingHints
    ) -> String? {
        guard let profile = profile else { return nil }

        var reasons: [String] = []

        if hints.longContextPreferred && profile.isLongContextFriendly {
            reasons.append("long-context optimized")
        }
        if hints.fastStructuredPreferred && profile.isFastStructuredOutput {
            reasons.append("fast structured output")
        }
        if profile.attentionType == .mla {
            reasons.append("MLA: 16x KV compression")
        }
        if profile.attentionType == .gqa {
            reasons.append("GQA: efficient KV")
        }
        if profile.attentionType == .differential {
            reasons.append("differential: stable quantization")
        }
        if profile.generationMode == .diffusion {
            reasons.append("diffusion: parallel generation")
        }

        return reasons.isEmpty ? nil : reasons.joined(separator: ", ")
    }

    private func recordDecision(
        task: InferenceTask,
        decision: EnhancedSchedulingDecision,
        context: SchedulingContext
    ) {
        let record = EnhancedSchedulingRecord(
            taskId: task.id,
            taskKind: task.kind,
            strategy: decision.strategy,
            modelId: decision.primaryModel.id,
            modelFamily: decision.primaryModel.family,
            attentionType: decision.architectureProfile?.attentionType,
            generationMode: decision.architectureProfile?.generationMode,
            usesDiffusion: decision.usesDiffusion,
            domain: context.domain,
            estimatedQuality: decision.estimatedQuality,
            timestamp: Date()
        )

        history.append(record)

        // Prune if needed
        if history.count > maxHistorySize {
            history.removeFirst(200)
        }
    }

    // MARK: - Analytics

    /// Gets enhanced scheduler statistics.
    public func statistics() -> EnhancedSchedulerStatistics {
        let byArchitecture = Dictionary(
            grouping: history.compactMap { $0.attentionType }
        )            { $0 }.mapValues { $0.count }

        let byGenerationMode = Dictionary(
            grouping: history.compactMap { $0.generationMode }
        )            { $0 }.mapValues { $0.count }

        let diffusionCount = history.filter { $0.usesDiffusion }.count

        return EnhancedSchedulerStatistics(
            totalDecisions: history.count,
            decisionsByArchitecture: byArchitecture,
            decisionsByGenerationMode: byGenerationMode,
            diffusionUsageCount: diffusionCount,
            architecturePerformance: architecturePerformance,
            currentResources: resources
        )
    }
}

// MARK: - Supporting Types

/// Context for scheduling decisions.
public struct SchedulingContext: Sendable {
    public let tenantId: String
    public let environmentId: String
    public let domain: String
    public let agentTurnId: String?

    public init(
        tenantId: String,
        environmentId: String,
        domain: String,
        agentTurnId: String? = nil
    ) {
        self.tenantId = tenantId
        self.environmentId = environmentId
        self.domain = domain
        self.agentTurnId = agentTurnId
    }
}

/// Enhanced scheduling record.
struct EnhancedSchedulingRecord: Sendable {
    let taskId: String
    let taskKind: InferenceTaskKind
    let strategy: SchedulingStrategy
    let modelId: String
    let modelFamily: String
    let attentionType: AttentionArchitecture?
    let generationMode: GenerationMode?
    let usesDiffusion: Bool
    let domain: String
    public let estimatedQuality: Double
    public let timestamp: Date
}

/// Performance metrics for an architecture.
public struct ArchitecturePerformanceMetrics: Sendable {
    public var totalInferences: Int = 0
    public var successfulInferences: Int = 0
    public var totalLatency: TimeInterval = 0
    public var totalQuality: Double = 0

    public var successRate: Double {
        guard totalInferences > 0 else { return 0 }
        return Double(successfulInferences) / Double(totalInferences)
    }

    public var averageLatency: TimeInterval {
        guard totalInferences > 0 else { return 0 }
        return totalLatency / Double(totalInferences)
    }

    public var averageQuality: Double {
        guard totalInferences > 0 else { return 0 }
        return totalQuality / Double(totalInferences)
    }

    public var overallScore: Double {
        // Weighted combination
        successRate * 0.4 + averageQuality * 0.4 + (1.0 / max(averageLatency, 0.1)) * 0.2
    }

    public mutating func record(latency: Duration, quality: Double, success: Bool) {
        totalInferences += 1
        if success { successfulInferences += 1 }
        totalLatency += Double(latency.components.seconds)
        totalQuality += quality
    }
}

/// Enhanced scheduler statistics.
public struct EnhancedSchedulerStatistics: Sendable {
    public let totalDecisions: Int
    public let decisionsByArchitecture: [AttentionArchitecture: Int]
    public let decisionsByGenerationMode: [GenerationMode: Int]
    public let diffusionUsageCount: Int
    public let architecturePerformance: [String: ArchitecturePerformanceMetrics]
    public let currentResources: ResourceSnapshot

    public var diffusionUsagePercentage: Double {
        guard totalDecisions > 0 else { return 0 }
        return Double(diffusionUsageCount) / Double(totalDecisions) * 100
    }
}

// MARK: - Integrated Inference Execution

/// Executes inference with full integration of all bonkers-tier features.
public actor IntegratedInferenceExecutor {
    private let scheduler: EnhancedInferenceScheduler
    private let diffusionAdapter: DiffusionInferenceAdapter
    private let behaviorGovernor: AgentBehaviorGovernor
    private let impactMeasurer: LearningImpactMeasurer
    private let upftExtractor: UPFTExtractor

    public init(
        scheduler: EnhancedInferenceScheduler = EnhancedInferenceScheduler(),
        diffusionAdapter: DiffusionInferenceAdapter = DiffusionInferenceAdapter(),
        behaviorGovernor: AgentBehaviorGovernor = AgentBehaviorGovernor(),
        impactMeasurer: LearningImpactMeasurer = LearningImpactMeasurer(),
        upftExtractor: UPFTExtractor = UPFTExtractor()
    ) {
        self.scheduler = scheduler
        self.diffusionAdapter = diffusionAdapter
        self.behaviorGovernor = behaviorGovernor
        self.impactMeasurer = impactMeasurer
        self.upftExtractor = upftExtractor
    }

    /// Executes an inference task with full governance and tracking.
    public func execute(
        task: InferenceTask,
        candidates: [ModelDescriptor],
        context: SchedulingContext
    ) async throws -> IntegratedInferenceResult {
        let startTime = Date()

        // Start behavior tracking if this is part of an agent turn
        let turnId: String?
        if let agentTurn = context.agentTurnId {
            turnId = agentTurn
        } else {
            turnId = await behaviorGovernor.startTurn()
        }

        // Get scheduling decision
        guard let decision = await scheduler.schedule(
            task: task,
            candidates: candidates,
            context: context
        ) else {
            throw InferenceError.noSuitableModel(constraints: "No candidates match constraints")
        }

        // Execute based on decision
        let result: InferenceResult

        if decision.usesDiffusion {
            // Route to diffusion backend
            result = try await diffusionAdapter.runInference(
                task: task,
                model: decision.primaryModel
            )
        } else {
            // Placeholder for normal inference path
            result = InferenceResult(
                taskId: task.id,
                output: .text("Inference result placeholder"),
                modelUsed: decision.primaryModel.id,
                backendUsed: decision.primaryModel.backend,
                tokensIn: 100,
                tokensOut: 200,
                latency: .seconds(1)
            )
        }

        // Record behavior
        if let turnId = turnId {
            _ = await behaviorGovernor.recordToolCall(
                turnId: turnId,
                toolName: "inference",
                context: context.domain,
                waitedForResult: true
            )
        }

        // Record performance for architecture
        await scheduler.recordPerformance(
            family: decision.primaryModel.family,
            latency: result.latency,
            quality: decision.estimatedQuality,
            success: true
        )

        // Collect reasoning trace if applicable
        if case .text(let output) = result.output {
            let trace = ReasoningTrace(
                domain: mapDomainToTraining(context.domain),
                taskType: task.kind.rawValue,
                input: extractInput(task),
                reasoning: output,
                output: output,
                metadata: TraceMetadata(
                    modelId: decision.primaryModel.id,
                    modelVersion: decision.primaryModel.version,
                    tokensIn: result.tokensIn,
                    tokensOut: result.tokensOut,
                    latency: Double(result.latency.components.seconds)
                ),
                quality: TraceQuality(
                    overallScore: decision.estimatedQuality,
                    structureScore: 0.8,
                    clarityScore: 0.8,
                    followsDomainPatterns: true
                )
            )

            await impactMeasurer.record(trace)

            // Extract prefix for UPFT if quality is good
            if trace.quality.meetsQualityBar {
                _ = await upftExtractor.extractPrefix(from: trace)
            }
        }

        // End turn if we started it
        let turnSummary: AgentTurnSummary?
        if context.agentTurnId == nil, let turnId = turnId {
            turnSummary = await behaviorGovernor.endTurn(turnId)
        } else {
            turnSummary = nil
        }

        return IntegratedInferenceResult(
            result: result,
            decision: decision,
            turnSummary: turnSummary,
            totalLatency: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Private Helpers

    private func mapDomainToTraining(_ domain: String) -> TrainingDomain {
        switch domain.lowercased() {
        case "dsps": return .dsps
        case "transcriptum", "academic": return .transcriptum
        case "compliance", "governance": return .compliance
        case "code", "coding": return .coding
        default: return .general
        }
    }

    private func extractInput(_ task: InferenceTask) -> String {
        switch task.input {
        case .text(let text):
            return text
        case .messages(let messages):
            return messages.map { $0.content }.joined(separator: "\n")
        case .batch(let texts):
            return texts.joined(separator: "\n---\n")
        case .structured(let input):
            return input.data.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        }
    }
}

/// Result of integrated inference execution.
public struct IntegratedInferenceResult: Sendable {
    public let result: InferenceResult
    public let decision: EnhancedSchedulingDecision
    public let turnSummary: AgentTurnSummary?
    public let totalLatency: TimeInterval

    /// Whether this execution had behavior violations.
    public var hadViolations: Bool {
        turnSummary?.violations.isEmpty == false
    }

    /// The architecture used.
    public var architectureUsed: AttentionArchitecture? {
        decision.architectureProfile?.attentionType
    }

    /// Whether diffusion was used.
    public var usedDiffusion: Bool {
        decision.usesDiffusion
    }
}
