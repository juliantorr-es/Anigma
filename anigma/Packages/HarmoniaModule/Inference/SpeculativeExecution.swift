//
//  SpeculativeExecution.swift
//  HarmoniaModule
//
//  Speculative and cascaded execution strategies.
//  Run multiple models in parallel, use fast models as drafts.
//

import AnigmaCore
@preconcurrency import Foundation

// MARK: - Execution Strategy

/// Strategy for executing inference tasks.
public enum ExecutionStrategy: Sendable {
    /// Single model execution.
    case single

    /// Speculative execution: run fast and slow models in parallel.
    case speculative(SpeculativeConfig)

    /// Cascaded execution: use small model for planning, large for execution.
    case cascaded(CascadeConfig)

    /// Ensemble: run multiple models and aggregate results.
    case ensemble(EnsembleConfig)
}

/// Configuration for speculative execution.
public struct SpeculativeConfig: Sendable {
    /// Quality threshold for accepting fast model output.
    public let acceptanceThreshold: Double

    /// Maximum tokens to generate before checking.
    public let checkpointInterval: Int

    /// Whether to use the fast model for draft tokens.
    public let useDraftTokens: Bool

    /// Timeout for the slow model.
    public let slowModelTimeout: Duration

    public init(
        acceptanceThreshold: Double = 0.85,
        checkpointInterval: Int = 32,
        useDraftTokens: Bool = true,
        slowModelTimeout: Duration = .seconds(30)
    ) {
        self.acceptanceThreshold = acceptanceThreshold
        self.checkpointInterval = checkpointInterval
        self.useDraftTokens = useDraftTokens
        self.slowModelTimeout = slowModelTimeout
    }
}

/// Configuration for cascaded execution.
public struct CascadeConfig: Sendable {
    /// Tasks the planning model handles.
    public let plannerTasks: Set<CascadeTask>

    /// Maximum planning tokens.
    public let maxPlanTokens: Int

    /// Whether to parallelize execution steps.
    public let parallelExecution: Bool

    public init(
        plannerTasks: Set<CascadeTask> = [.classify, .chunk, .route],
        maxPlanTokens: Int = 256,
        parallelExecution: Bool = true
    ) {
        self.plannerTasks = plannerTasks
        self.maxPlanTokens = maxPlanTokens
        self.parallelExecution = parallelExecution
    }
}

/// Tasks for cascade planning.
public enum CascadeTask: String, Sendable {
    case classify
    case chunk
    case route
    case summarizeFirst
    case extractEntities
}

/// Configuration for ensemble execution.
public struct EnsembleConfig: Sendable {
    /// How to combine results.
    public let aggregation: EnsembleAggregation

    /// Minimum models that must succeed.
    public let minSuccessful: Int

    /// Timeout for stragglers.
    public let timeout: Duration

    public init(
        aggregation: EnsembleAggregation = .voting,
        minSuccessful: Int = 1,
        timeout: Duration = .seconds(30)
    ) {
        self.aggregation = aggregation
        self.minSuccessful = minSuccessful
        self.timeout = timeout
    }
}

/// How to aggregate ensemble results.
public enum EnsembleAggregation: String, Sendable {
    case voting
    case averaging
    case bestScore
    case consensus
}

// MARK: - Advanced Speculative Executor

/// Advanced speculative executor with fast/slow model pairing.
public actor AdvancedSpeculativeExecutor {
    private let runnerManager: RunnerManager
    private let registry: ModelRegistry

    public init(runnerManager: RunnerManager, registry: ModelRegistry) {
        self.runnerManager = runnerManager
        self.registry = registry
    }

    /// Runs speculative execution.
    public func execute(
        task: InferenceTask,
        fastModel: ModelDescriptor,
        slowModel: ModelDescriptor,
        config: SpeculativeConfig
    ) async throws -> SpeculativeResult {
        let startTime = ContinuousClock.now

        // Start both models in parallel
        async let fastResult = runFastModel(task: task, model: fastModel)
        async let slowResult = runSlowModel(
            task: task, model: slowModel, timeout: config.slowModelTimeout)

        // Get fast result first
        let fast = try await fastResult

        // Check if fast result is acceptable
        let quality = assessQuality(result: fast, task: task)

        if quality >= config.acceptanceThreshold {
            // Fast model is good enough, cancel slow
            return SpeculativeResult(
                output: fast.output,
                usedModel: fastModel.id,
                wasSpeculative: true,
                acceptedFast: true,
                qualityScore: quality,
                latency: ContinuousClock.now - startTime
            )
        }

        // Wait for slow model
        do {
            let slow = try await slowResult
            return SpeculativeResult(
                output: slow.output,
                usedModel: slowModel.id,
                wasSpeculative: true,
                acceptedFast: false,
                qualityScore: nil,
                latency: ContinuousClock.now - startTime
            )
        } catch {
            // Slow model failed, fall back to fast
            return SpeculativeResult(
                output: fast.output,
                usedModel: fastModel.id,
                wasSpeculative: true,
                acceptedFast: true,
                qualityScore: quality,
                latency: ContinuousClock.now - startTime
            )
        }
    }

    private func runFastModel(task: InferenceTask, model: ModelDescriptor) async throws
        -> InferenceResult {
        let instanceId = try await runnerManager.ensureRunner(for: model, context: task.context)
        let request = BackendRequest(
            taskId: task.id,
            kind: task.kind,
            input: task.input,
            model: model,
            parameters: BackendParameters()
        )
        let response = try await runnerManager.execute(
            on: instanceId, with: model, request: request)

        return InferenceResult(
            taskId: task.id,
            output: response.output,
            modelUsed: model.id,
            backendUsed: model.backend,
            tokensIn: response.tokensIn,
            tokensOut: response.tokensOut,
            latency: .zero
        )
    }

    private func runSlowModel(
        task: InferenceTask,
        model: ModelDescriptor,
        timeout: Duration
    ) async throws -> InferenceResult {
        try await withThrowingTaskGroup(of: InferenceResult.self) { group in
            group.addTask {
                let instanceId = try await self.runnerManager.ensureRunner(
                    for: model, context: task.context)
                let request = BackendRequest(
                    taskId: task.id,
                    kind: task.kind,
                    input: task.input,
                    model: model,
                    parameters: BackendParameters()
                )
                let response = try await self.runnerManager.execute(
                    on: instanceId, with: model, request: request)

                return InferenceResult(
                    taskId: task.id,
                    output: response.output,
                    modelUsed: model.id,
                    backendUsed: model.backend,
                    tokensIn: response.tokensIn,
                    tokensOut: response.tokensOut,
                    latency: .zero
                )
            }

            group.addTask {
                try await Task.sleep(for: timeout)
                throw InferenceError.timeout(duration: timeout)
            }

            guard let result = try await group.next() else {
                fatalError("Failed to unwrap result")
            }
            group.cancelAll()
            return result
        }
    }

    private func assessQuality(result: InferenceResult, task: InferenceTask) -> Double {
        // Simple heuristic quality assessment
        // Real implementation would use more sophisticated checks

        switch result.output {
        case .text(let text):
            // Check for basic quality signals
            var score = 0.5

            // Has reasonable length
            if text.count > 10 && text.count < 10000 {
                score += 0.2
            }

            // Doesn't contain obvious errors
            let errorPatterns = ["I cannot", "I'm sorry", "error", "undefined"]
            let hasErrors = errorPatterns.contains { text.lowercased().contains($0) }
            if !hasErrors {
                score += 0.2
            }

            // Ends with proper punctuation
            if text.last?.isPunctuation == true {
                score += 0.1
            }

            return min(1.0, score)

        case .embedding, .embeddings:
            // Embeddings are usually valid if generated
            return 0.95

        case .classification(_, let confidence):
            return confidence

        case .toolCalls(let calls):
            return calls.isEmpty ? 0.3 : 0.9

        case .rankings(let items):
            return items.isEmpty ? 0.3 : 0.9
        }
    }
}

/// Result of speculative execution.
public struct SpeculativeResult: Sendable {
    public let output: InferenceOutput
    public let usedModel: String
    public let wasSpeculative: Bool
    public let acceptedFast: Bool
    public let qualityScore: Double?
    public let latency: Duration
}

// MARK: - Cascade Executor

/// Executes cascaded inference with planning and execution phases.
public actor CascadeExecutor {
    private let runnerManager: RunnerManager
    private let registry: ModelRegistry

    public init(runnerManager: RunnerManager, registry: ModelRegistry) {
        self.runnerManager = runnerManager
        self.registry = registry
    }

    /// Runs cascaded execution.
    public func execute(
        task: InferenceTask,
        plannerModel: ModelDescriptor,
        executorModel: ModelDescriptor,
        config: CascadeConfig
    ) async throws -> CascadeResult {
        let startTime = ContinuousClock.now

        // Phase 1: Planning with small model
        let plan = try await runPlanner(
            task: task,
            model: plannerModel,
            config: config
        )

        // Phase 2: Execute plan with large model
        let results = try await executePlan(
            plan: plan,
            originalTask: task,
            model: executorModel,
            parallel: config.parallelExecution
        )

        // Phase 3: Aggregate results
        let aggregated = aggregateResults(results: results, task: task)

        return CascadeResult(
            output: aggregated,
            plan: plan,
            stepResults: results,
            plannerModel: plannerModel.id,
            executorModel: executorModel.id,
            latency: ContinuousClock.now - startTime
        )
    }

    private func runPlanner(
        task: InferenceTask,
        model: ModelDescriptor,
        config: CascadeConfig
    ) async throws -> ExecutionPlan {
        // Use small model to create a plan
        let instanceId = try await runnerManager.ensureRunner(for: model, context: task.context)

        let planPrompt = buildPlanPrompt(task: task, tasks: config.plannerTasks)
        let request = BackendRequest(
            taskId: "\(task.id)-plan",
            kind: .chat,
            input: .text(planPrompt),
            model: model,
            parameters: BackendParameters(maxTokens: config.maxPlanTokens)
        )

        let response = try await runnerManager.execute(
            on: instanceId, with: model, request: request)

        return parsePlan(response: response, originalTask: task)
    }

    private func buildPlanPrompt(task: InferenceTask, tasks: Set<CascadeTask>) -> String {
        var prompt = "Analyze the following task and create an execution plan.\n\n"
        prompt += "Task type: \(task.kind)\n"

        switch task.input {
        case .text(let text):
            prompt += "Input: \(text.prefix(500))\n"
        case .messages(let msgs):
            prompt += "Messages: \(msgs.count) messages\n"
        case .batch(let texts):
            prompt += "Batch of \(texts.count) items\n"
        case .structured(let input):
            prompt += "Structured input type: \(input.type)\n"
        }

        prompt += "\nAvailable planning tasks: \(tasks.map(\.rawValue).joined(separator: ", "))\n"
        prompt += "Output a JSON plan with steps."

        return prompt
    }

    private func parsePlan(response: BackendResponse, originalTask: InferenceTask) -> ExecutionPlan {
        // Simple plan: just execute the original task
        // Real implementation would parse structured output
        return ExecutionPlan(
            steps: [
                ExecutionStep(
                    id: "main",
                    type: .execute,
                    input: originalTask.input,
                    dependencies: []
                )
            ],
            metadata: [:]
        )
    }

    private func executePlan(
        plan: ExecutionPlan,
        originalTask: InferenceTask,
        model: ModelDescriptor,
        parallel: Bool
    ) async throws -> [StepResult] {
        var results: [StepResult] = []

        if parallel {
            try await withThrowingTaskGroup(of: StepResult.self) { group in
                for step in plan.steps where step.dependencies.isEmpty {
                    group.addTask {
                        try await self.executeStep(
                            step: step,
                            context: originalTask.context,
                            model: model
                        )
                    }
                }

                for try await result in group {
                    results.append(result)
                }
            }
        } else {
            for step in plan.steps {
                let result = try await executeStep(
                    step: step,
                    context: originalTask.context,
                    model: model
                )
                results.append(result)
            }
        }

        return results
    }

    private func executeStep(
        step: ExecutionStep,
        context: InferenceContext,
        model: ModelDescriptor
    ) async throws -> StepResult {
        let instanceId = try await runnerManager.ensureRunner(for: model, context: context)

        let request = BackendRequest(
            taskId: step.id,
            kind: .chat,
            input: step.input,
            model: model,
            parameters: BackendParameters()
        )

        let response = try await runnerManager.execute(
            on: instanceId, with: model, request: request)

        return StepResult(
            stepId: step.id,
            output: response.output,
            tokensUsed: response.tokensIn + response.tokensOut
        )
    }

    private func aggregateResults(results: [StepResult], task: InferenceTask) -> InferenceOutput {
        // Simple aggregation: return first result
        // Real implementation would combine based on task type
        return results.first?.output ?? .text("")
    }
}

/// Execution plan from planner model.
public struct ExecutionPlan: Sendable {
    public let steps: [ExecutionStep]
    public let metadata: [String: String]
}

/// A step in the execution plan.
public struct ExecutionStep: Sendable {
    public let id: String
    public let type: StepType
    public let input: InferenceInput
    public let dependencies: [String]
}

/// Type of execution step.
public enum StepType: String, Sendable {
    case classify
    case chunk
    case execute
    case aggregate
    case filter
}

/// Result of a single step.
public struct StepResult: Sendable {
    public let stepId: String
    public let output: InferenceOutput
    public let tokensUsed: Int
}

/// Result of cascaded execution.
public struct CascadeResult: Sendable {
    public let output: InferenceOutput
    public let plan: ExecutionPlan
    public let stepResults: [StepResult]
    public let plannerModel: String
    public let executorModel: String
    public let latency: Duration
}

// MARK: - Ensemble Executor

/// Executes ensemble inference across multiple models.
public actor EnsembleExecutor {
    private let runnerManager: RunnerManager
    private let registry: ModelRegistry

    public init(runnerManager: RunnerManager, registry: ModelRegistry) {
        self.runnerManager = runnerManager
        self.registry = registry
    }

    /// Runs ensemble execution.
    public func execute(
        task: InferenceTask,
        models: [ModelDescriptor],
        config: EnsembleConfig
    ) async throws -> EnsembleResult {
        let startTime = ContinuousClock.now
        var results: [ModelResult] = []
        let errors: [String: Error] = [:]

        try await withThrowingTaskGroup(of: ModelResult?.self) { group in
            for model in models {
                group.addTask {
                    do {
                        let instanceId = try await self.runnerManager.ensureRunner(
                            for: model, context: task.context)
                        let request = BackendRequest(
                            taskId: task.id,
                            kind: task.kind,
                            input: task.input,
                            model: model,
                            parameters: BackendParameters()
                        )
                        let response = try await self.runnerManager.execute(
                            on: instanceId, with: model, request: request)

                        return ModelResult(
                            modelId: model.id,
                            output: response.output,
                            tokensUsed: response.tokensIn + response.tokensOut
                        )
                    } catch {
                        return nil
                    }
                }
            }

            // Timeout task
            group.addTask {
                try await Task.sleep(for: config.timeout)
                return nil
            }

            for try await result in group {
                if let r = result {
                    results.append(r)
                    if results.count >= config.minSuccessful {
                        group.cancelAll()
                        break
                    }
                }
            }
        }

        guard results.count >= config.minSuccessful else {
            throw InferenceError.executionFailed(reason: "Not enough models succeeded")
        }

        let aggregated = aggregate(results: results, method: config.aggregation)

        return EnsembleResult(
            output: aggregated,
            modelResults: results,
            aggregationMethod: config.aggregation,
            modelsSucceeded: results.count,
            modelsFailed: errors.count,
            latency: ContinuousClock.now - startTime
        )
    }

    private func aggregate(results: [ModelResult], method: EnsembleAggregation) -> InferenceOutput {
        guard let first = results.first else {
            return .text("")
        }

        switch method {
        case .voting:
            // For classification, vote; otherwise return first
            return first.output

        case .averaging:
            // For embeddings, average; otherwise return first
            if case .embedding = first.output {
                let allVecs = results.compactMap { r -> [Float]? in
                    if case .embedding(let v) = r.output { return v }
                    return nil
                }
                let averaged = averageVectors(allVecs)
                return .embedding(averaged)
            }
            return first.output

        case .bestScore:
            // Return highest confidence result
            if case .classification = first.output {
                let best = results.max { a, b in
                    guard case .classification(_, let confA) = a.output,
                        case .classification(_, let confB) = b.output
                    else {
                        return false
                    }
                    return confA < confB
                }
                return best?.output ?? first.output
            }
            return first.output

        case .consensus:
            // Return if all agree, otherwise first
            return first.output
        }
    }

    private func averageVectors(_ vecs: [[Float]]) -> [Float] {
        guard let first = vecs.first else { return [] }
        let count = Float(vecs.count)

        var result = [Float](repeating: 0, count: first.count)
        for vec in vecs {
            for (i, v) in vec.enumerated() where i < result.count {
                result[i] += v / count
            }
        }
        return result
    }
}

/// Result from a single model in ensemble.
public struct ModelResult: Sendable {
    public let modelId: String
    public let output: InferenceOutput
    public let tokensUsed: Int
}

/// Result of ensemble execution.
public struct EnsembleResult: Sendable {
    public let output: InferenceOutput
    public let modelResults: [ModelResult]
    public let aggregationMethod: EnsembleAggregation
    public let modelsSucceeded: Int
    public let modelsFailed: Int
    public let latency: Duration
}
