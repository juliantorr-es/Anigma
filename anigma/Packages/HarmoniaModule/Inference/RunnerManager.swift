//
//  RunnerManager.swift
//  HarmoniaModule
//
//  Manages backend instances (MLX, llama.cpp, Ollama, etc.).
//  Handles starting, stopping, and pooling of inference backends.
//

@preconcurrency import Foundation
import AnigmaCore

// MARK: - Backend Instance

/// Identifier for a running backend instance.
public struct BackendInstanceId: Hashable, Sendable {
    public let value: UUID

    public init() {
        self.value = UUID()
    }

    public init(value: UUID) {
        self.value = value
    }
}

/// A running backend instance.
public struct BackendInstance: Sendable {
    public let id: BackendInstanceId
    public let backend: BackendKind
    public let modelId: String
    public var status: BackendStatus
    public let startedAt: Date
    public var lastUsed: Date
    public var requestCount: Int

    public init(
        id: BackendInstanceId,
        backend: BackendKind,
        modelId: String,
        status: BackendStatus = .starting
    ) {
        self.id = id
        self.backend = backend
        self.modelId = modelId
        self.status = status
        self.startedAt = Date()
        self.lastUsed = Date()
        self.requestCount = 0
    }
}

// MARK: - Runner Manager

/// Manages backend instances for inference.
public actor RunnerManager {
    /// Active backend instances.
    private var instances: [BackendInstanceId: BackendInstance] = [:]

    /// Model -> instance mapping for reuse.
    private var modelInstances: [String: BackendInstanceId] = [:]

    /// Per-backend runners.
    private var runners: [BackendKind: any BackendRunner] = [:]

    /// Resource limits.
    private var maxInstances: Int = 4
    private var maxVRAM: Double = 24.0  // GB
    private var currentVRAM: Double = 0.0

    /// Idle timeout for instances.
    private var idleTimeout: Duration = .seconds(300)

    public init() {
        // Initialize with empty runners
    }

    // MARK: - Runner Registration

    /// Registers a backend runner.
    public func registerRunner(_ runner: any BackendRunner) {
        runners[runner.backend] = runner
    }

    // MARK: - Instance Management

    /// Ensures a runner is available for the given model.
    public func ensureRunner(
        for model: ModelDescriptor,
        context: InferenceContext
    ) async throws -> BackendInstanceId {
        // Check if we already have an instance for this model
        if let existingId = modelInstances[model.id],
           let instance = instances[existingId],
           instance.status == .ready || instance.status == .busy {
            // Update last used time
            var updated = instance
            updated.lastUsed = Date()
            instances[existingId] = updated
            return existingId
        }

        // Need to create a new instance
        guard let runner = runners[model.backend] else {
            throw InferenceError.backendUnavailable(backend: model.backend)
        }

        // Check resource limits
        if currentVRAM + model.resources.vramRequired > maxVRAM {
            // Try to evict idle instances
            await evictIdleInstances()

            if currentVRAM + model.resources.vramRequired > maxVRAM {
                throw InferenceError.executionFailed(
                    reason: "Insufficient VRAM: need \(model.resources.vramRequired)GB, available \(maxVRAM - currentVRAM)GB"
                )
            }
        }

        if instances.count >= maxInstances {
            await evictIdleInstances()

            if instances.count >= maxInstances {
                throw InferenceError.executionFailed(
                    reason: "Maximum number of instances (\(maxInstances)) reached"
                )
            }
        }

        // Create new instance
        let instanceId = BackendInstanceId()
        var instance = BackendInstance(
            id: instanceId,
            backend: model.backend,
            modelId: model.id
        )

        // Start the runner
        try await runner.start(model: model)

        instance.status = .ready
        instances[instanceId] = instance
        modelInstances[model.id] = instanceId
        currentVRAM += model.resources.vramRequired

        return instanceId
    }

    /// Executes a request on a backend instance.
    public func execute(
        on instanceId: BackendInstanceId,
        with model: ModelDescriptor,
        request: BackendRequest
    ) async throws -> BackendResponse {
        guard var instance = instances[instanceId] else {
            throw InferenceError.backendUnavailable(backend: model.backend)
        }

        guard let runner = runners[model.backend] else {
            throw InferenceError.backendUnavailable(backend: model.backend)
        }

        // Update instance state
        instance.status = .busy
        instance.requestCount += 1
        instances[instanceId] = instance

        defer {
            // Reset to ready after execution
            if var inst = instances[instanceId] {
                inst.status = .ready
                inst.lastUsed = Date()
                instances[instanceId] = inst
            }
        }

        return try await runner.execute(request: request)
    }

    /// Streams results from a backend instance.
    public func stream(
        on instanceId: BackendInstanceId,
        with model: ModelDescriptor,
        request: BackendRequest
    ) -> AsyncThrowingStream<InferenceChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let runner = runners[model.backend] else {
                    continuation.finish(throwing: InferenceError.backendUnavailable(backend: model.backend))
                    return
                }

                do {
                    let stream = try await runner.stream(request: request)
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

    /// Stops an instance.
    public func stopInstance(_ instanceId: BackendInstanceId) async {
        guard let instance = instances[instanceId] else { return }

        if let runner = runners[instance.backend] {
            await runner.stop(modelId: instance.modelId)
        }

        instances.removeValue(forKey: instanceId)
        modelInstances.removeValue(forKey: instance.modelId)

        // Would need to track VRAM per instance properly
    }

    /// Gets status of all instances.
    public func status() -> [BackendInstance] {
        Array(instances.values)
    }

    // MARK: - Resource Management

    /// Evicts idle instances to free resources.
    private func evictIdleInstances() async {
        let now = Date()
        let cutoff = now.addingTimeInterval(-idleTimeout.timeInterval)

        let idleInstances = instances.values.filter { instance in
            instance.lastUsed < cutoff && instance.status == .ready
        }

        for instance in idleInstances {
            await stopInstance(instance.id)
        }
    }

    /// Sets resource limits.
    public func setLimits(maxInstances: Int? = nil, maxVRAM: Double? = nil) {
        if let max = maxInstances { self.maxInstances = max }
        if let vram = maxVRAM { self.maxVRAM = vram }
    }
}

// MARK: - Duration Extension

extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = self.components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }

    var milliseconds: Double {
        let (seconds, attoseconds) = self.components
        return Double(seconds) * 1000 + Double(attoseconds) / 1e15
    }
}

// MARK: - Backend Runner Protocol

/// Protocol for backend-specific runners.
public protocol BackendRunner: Sendable {
    var backend: BackendKind { get }

    func start(model: ModelDescriptor) async throws
    func stop(modelId: String) async
    func execute(request: BackendRequest) async throws -> BackendResponse
    func stream(request: BackendRequest) async throws -> AsyncThrowingStream<InferenceChunk, Error>
    func isAvailable() async -> Bool
}

// MARK: - Mock Backend Runner

/// Mock implementation for testing.
public actor MockBackendRunner: BackendRunner {
    public let backend: BackendKind
    private var loadedModels: Set<String> = []

    public init(backend: BackendKind) {
        self.backend = backend
    }

    public func start(model: ModelDescriptor) async throws {
        // Simulate loading time
        try await Task.sleep(for: .milliseconds(100))
        loadedModels.insert(model.id)
    }

    public func stop(modelId: String) async {
        loadedModels.remove(modelId)
    }

    public func execute(request: BackendRequest) async throws -> BackendResponse {
        // Simulate inference time
        try await Task.sleep(for: .milliseconds(50))

        let output: InferenceOutput

        switch request.kind {
        case .chat, .summarize, .codeGeneration, .codeExplanation, .extraction, .translation:
            output = .text("Mock response for \(request.kind)")
        case .embed:
            output = .embedding(Array(repeating: 0.0, count: 384))
        case .classify:
            output = .classification(label: "mock_category", confidence: 0.95)
        case .rerank:
            output = .rankings([(0, 0.9), (1, 0.7), (2, 0.3)])
        case .toolCall:
            output = .toolCalls([InferenceToolCall(id: "1", name: "mock_tool", arguments: [:])])
        }

        return BackendResponse(
            output: output,
            tokensIn: 100,
            tokensOut: 50
        )
    }

    public func stream(request: BackendRequest) async throws -> AsyncThrowingStream<InferenceChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let words = ["Mock", " streaming", " response", " for", " \(request.kind)"]
                var tokenCount = 0

                for (index, word) in words.enumerated() {
                    try await Task.sleep(for: .milliseconds(20))
                    tokenCount += 1
                    continuation.yield(InferenceChunk(
                        taskId: request.taskId,
                        delta: word,
                        isComplete: index == words.count - 1,
                        tokensGenerated: tokenCount
                    ))
                }

                continuation.finish()
            }
        }
    }

    public func isAvailable() async -> Bool {
        true
    }
}
