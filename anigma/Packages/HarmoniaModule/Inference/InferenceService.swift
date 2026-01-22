//
//  InferenceService.swift
//  HarmoniaModule
//
//  Unified Inference Service - the main entry point for all inference operations.
//  Abstracts away backend differences and provides constraint-based model selection.
//

import Foundation
import AnigmaCore

// MARK: - Inference Service

/// The main entry point for inference operations.
/// Abstracts away backend differences and provides unified API.
public actor InferenceService {
    private let registry: ModelRegistry
    private let runnerManager: RunnerManager
    private let scheduler: InferenceScheduler
    private var telemetryHandler: ((InferenceTelemetryEvent) async -> Void)?

    public init(
        registry: ModelRegistry = ModelRegistry(),
        runnerManager: RunnerManager = RunnerManager(),
        scheduler: InferenceScheduler = InferenceScheduler()
    ) {
        self.registry = registry
        self.runnerManager = runnerManager
        self.scheduler = scheduler
        
        // Register available backends
        Task {
            await registerBackends()
        }
    }

    /// Sets a telemetry handler for inference events.
    public func setTelemetryHandler(_ handler: @escaping (InferenceTelemetryEvent) async -> Void) {
        self.telemetryHandler = handler
    }

    // MARK: - Main API

    /// Runs an inference task and returns the result.
    public func run(_ task: InferenceTask) async throws -> InferenceResult {
        let startTime = ContinuousClock.now

        // Emit start telemetry
        await emitTelemetry(.taskStarted(task))

        do {
            // Select the best model
            guard let model = await registry.selectBest(for: task, tenantId: task.context.tenantId) else {
                throw InferenceError.noSuitableModel(constraints: describeConstraints(task.constraints))
            }

            // Ensure backend is running
            let instanceId = try await runnerManager.ensureRunner(for: model, context: task.context)

            // Execute inference
            let request = buildBackendRequest(task: task, model: model)
            let response = try await runnerManager.execute(
                on: instanceId,
                with: model,
                request: request
            )

            let latency = ContinuousClock.now - startTime

            // Build result
            let result = InferenceResult(
                taskId: task.id,
                output: response.output,
                modelUsed: model.id,
                backendUsed: model.backend,
                tokensIn: response.tokensIn,
                tokensOut: response.tokensOut,
                latency: latency
            )

            // Emit completion telemetry
            await emitTelemetry(.taskCompleted(result))

            return result

        } catch {
            let latency = ContinuousClock.now - startTime
            await emitTelemetry(.taskFailed(taskId: task.id, error: error, latency: latency))
            throw error
        }
    }

    /// Streams inference results as they're generated.
    public func stream(_ task: InferenceTask) -> AsyncThrowingStream<InferenceChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Select the best model
                    guard let model = await registry.selectBest(for: task, tenantId: task.context.tenantId) else {
                        throw InferenceError.noSuitableModel(constraints: describeConstraints(task.constraints))
                    }

                    // Ensure backend is running
                    let instanceId = try await runnerManager.ensureRunner(for: model, context: task.context)

                    // Stream from backend
                    let request = buildBackendRequest(task: task, model: model)
                    let stream = await runnerManager.stream(
                        on: instanceId,
                        with: model,
                        request: request
                    )

                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Convenience Methods

    /// Simple text completion.
    public func complete(
        prompt: String,
        context: InferenceContext,
        constraints: InferenceConstraints = .internalDefault
    ) async throws -> String {
        let task = InferenceTask(
            kind: .chat,
            input: .text(prompt),
            context: context,
            constraints: constraints
        )

        let result = try await run(task)

        switch result.output {
        case .text(let text):
            return text
        default:
            throw InferenceError.executionFailed(reason: "Unexpected output type")
        }
    }

    /// Chat completion with messages.
    public func chat(
        messages: [ChatMessage],
        context: InferenceContext,
        constraints: InferenceConstraints = .internalDefault
    ) async throws -> String {
        let task = InferenceTask(
            kind: .chat,
            input: .messages(messages),
            context: context,
            constraints: constraints
        )

        let result = try await run(task)

        switch result.output {
        case .text(let text):
            return text
        default:
            throw InferenceError.executionFailed(reason: "Unexpected output type")
        }
    }

    /// Generate embeddings for text.
    public func embed(
        text: String,
        context: InferenceContext,
        constraints: InferenceConstraints = .internalDefault
    ) async throws -> [Float] {
        var embedConstraints = constraints
        embedConstraints.requiredCapabilities = (embedConstraints.requiredCapabilities ?? [])

        let task = InferenceTask(
            kind: .embed,
            input: .text(text),
            context: context,
            constraints: embedConstraints
        )

        let result = try await run(task)

        switch result.output {
        case .embedding(let vec):
            return vec
        default:
            throw InferenceError.executionFailed(reason: "Unexpected output type")
        }
    }

    /// Generate embeddings for a batch of texts.
    public func embedBatch(
        texts: [String],
        context: InferenceContext,
        constraints: InferenceConstraints = .internalDefault
    ) async throws -> [[Float]] {
        let task = InferenceTask(
            kind: .embed,
            input: .batch(texts),
            context: context,
            constraints: constraints
        )

        let result = try await run(task)

        switch result.output {
        case .embeddings(let vecs):
            return vecs
        default:
            throw InferenceError.executionFailed(reason: "Unexpected output type")
        }
    }

    /// Summarize text.
    public func summarize(
        text: String,
        context: InferenceContext,
        constraints: InferenceConstraints = .internalDefault
    ) async throws -> String {
        let task = InferenceTask(
            kind: .summarize,
            input: .text(text),
            context: context,
            constraints: constraints
        )

        let result = try await run(task)

        switch result.output {
        case .text(let text):
            return text
        default:
            throw InferenceError.executionFailed(reason: "Unexpected output type")
        }
    }

    /// Classify text into categories.
    public func classify(
        text: String,
        categories: [String],
        context: InferenceContext,
        constraints: InferenceConstraints = .internalDefault
    ) async throws -> (label: String, confidence: Double) {
        let task = InferenceTask(
            kind: .classify,
            input: .structured(StructuredInput(
                type: "classification",
                data: [
                    "text": text,
                    "categories": categories.joined(separator: ",")
                ]
            )),
            context: context,
            constraints: constraints
        )

        let result = try await run(task)

        switch result.output {
        case .classification(let label, let confidence):
            return (label, confidence)
        default:
            throw InferenceError.executionFailed(reason: "Unexpected output type")
        }
    }

    // MARK: - Registry Access

    /// Lists available models for a tenant.
    public func listModels(forTenant tenantId: String) async -> [ModelDescriptor] {
        await registry.listAll().filter { model in
            model.isEnabled
        }
    }

    /// Gets registry statistics.
    public func registryStats() async -> RegistryStatistics {
        await registry.statistics()
    }

    // MARK: - Private Helpers

    private func buildBackendRequest(task: InferenceTask, model: ModelDescriptor) -> BackendRequest {
        BackendRequest(
            taskId: task.id,
            kind: task.kind,
            input: task.input,
            model: model,
            parameters: BackendParameters()
        )
    }

    private func describeConstraints(_ constraints: InferenceConstraints) -> String {
        var parts: [String] = []
        if constraints.localOnly { parts.append("local-only") }
        if let tier = constraints.minQualityTier { parts.append("min-quality:\(tier)") }
        if let cost = constraints.maxCostTier { parts.append("max-cost:\(cost)") }
        parts.append("privacy:\(constraints.privacyLevel)")
        return parts.joined(separator: ", ")
    }

    private func emitTelemetry(_ event: InferenceTelemetryEvent) async {
        await telemetryHandler?(event)
    }
    
    /// Register available backends
    private func registerBackends() async {
        // Register MLX backend for Apple Silicon
        let mlxRunner = MLXBackendRunner()
        await runnerManager.registerRunner(mlxRunner)
        
        // Register mock backend as fallback
        let mockRunner = MockBackendRunner(backend: .mock)
        await runnerManager.registerRunner(mockRunner)
        
        print("Registered MLX and Mock backends")
    }
}

// MARK: - Backend Request/Response

/// Request to a backend.
public struct BackendRequest: Sendable {
    public let taskId: String
    public let kind: InferenceTaskKind
    public let input: InferenceInput
    public let model: ModelDescriptor
    public let parameters: BackendParameters

    public init(
        taskId: String,
        kind: InferenceTaskKind,
        input: InferenceInput,
        model: ModelDescriptor,
        parameters: BackendParameters
    ) {
        self.taskId = taskId
        self.kind = kind
        self.input = input
        self.model = model
        self.parameters = parameters
    }
}

/// Parameters for backend execution.
public struct BackendParameters: Sendable {
    public var temperature: Double
    public var maxTokens: Int?
    public var topP: Double?
    public var topK: Int?
    public var stopSequences: [String]?

    public init(
        temperature: Double = 0.7,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stopSequences: [String]? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
    }
}

/// Response from a backend.
public struct BackendResponse: Sendable {
    public let output: InferenceOutput
    public let tokensIn: Int
    public let tokensOut: Int

    public init(output: InferenceOutput, tokensIn: Int, tokensOut: Int) {
        self.output = output
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
    }
}

// MARK: - Telemetry Events

/// Telemetry events for inference operations.
public enum InferenceTelemetryEvent: Sendable {
    case taskStarted(InferenceTask)
    case taskCompleted(InferenceResult)
    case taskFailed(taskId: String, error: Error, latency: Duration)
    case modelLoaded(modelId: String, backend: BackendKind, loadTime: Duration)
    case modelUnloaded(modelId: String, reason: String)
    case backendStarted(backend: BackendKind, instanceId: String)
    case backendStopped(backend: BackendKind, instanceId: String, reason: String)
}
