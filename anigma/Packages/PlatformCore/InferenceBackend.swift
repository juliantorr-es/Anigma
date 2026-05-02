//
//  InferenceBackend.swift
//  PlatformCore
//
//  Inference backend abstraction for Phase 8.3
//

import Foundation

// MARK: - Inference Request/Response Models

/// Represents a request to an inference backend
public struct InferenceRequest: Codable, Sendable {
    public let id: String
    public let model: String
    public let prompt: String
    public let parameters: InferenceParameters
    public let metadata: [String: String]

    public init(id: String = UUID().uuidString, model: String, prompt: String, parameters: InferenceParameters = InferenceParameters(), metadata: [String: String] = [:]) {
        self.id = id
        self.model = model
        self.prompt = prompt
        self.parameters = parameters
        self.metadata = metadata
    }
}

/// Configuration parameters for inference
public struct InferenceParameters: Codable, Sendable {
    public let temperature: Double
    public let maxTokens: Int
    public let topP: Double
    public let topK: Int?
    public let stopSequences: [String]

    public init(temperature: Double = 0.7, maxTokens: Int = 1024, topP: Double = 0.9, topK: Int? = nil, stopSequences: [String] = []) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
    }
}

/// Represents a response from an inference backend
public struct InferenceResponse: Codable, Sendable {
    public let requestId: String
    public let model: String
    public let output: String
    public let tokensUsed: TokenUsage
    public let metadata: [String: String]
    public let timestamp: Date

    public init(requestId: String, model: String, output: String, tokensUsed: TokenUsage, metadata: [String: String] = [:], timestamp: Date = Date()) {
        self.requestId = requestId
        self.model = model
        self.output = output
        self.tokensUsed = tokensUsed
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

/// Encapsulates token usage for inference responses.
public struct TokenUsage: Codable, Sendable {
    public let input: Int
    public let output: Int

    public init(input: Int, output: Int) {
        self.input = input
        self.output = output
    }
}

// MARK: - Inference Backend Protocol

/// Protocol for implementing inference backends
public protocol InferenceBackend: Actor {
    /// Name of the backend
    var name: String { get }

    /// List of supported models
    var supportedModels: [String] { get }

    /// Check if the backend is available
    var isAvailable: Bool { get }

    /// Initialize/configure the backend
    func initialize() async throws

    /// Execute inference on a request
    func infer(request: InferenceRequest) async throws -> InferenceResponse

    /// Batch inference for multiple requests
    func batchInfer(requests: [InferenceRequest]) async throws -> [InferenceResponse]

    /// Get backend status
    func status() async -> BackendStatus
}

/// Status information for a backend
public struct BackendStatus: Codable, Sendable {
    public let name: String
    public let available: Bool
    public let version: String
    public let latency: TimeInterval?
    public let loadedModels: [String]
    public let error: String?

    public init(name: String, available: Bool, version: String, latency: TimeInterval? = nil, loadedModels: [String] = [], error: String? = nil) {
        self.name = name
        self.available = available
        self.version = version
        self.latency = latency
        self.loadedModels = loadedModels
        self.error = error
    }
}

// MARK: - Inference Backend Errors

public enum InferenceError: Error, LocalizedError {
    case backendNotAvailable(String)
    case modelNotSupported(String)
    case inferenceFailure(String)
    case invalidRequest(String)
    case timeout
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .backendNotAvailable(let name):
            return "Backend '\(name)' is not available"
        case .modelNotSupported(let model):
            return "Model '\(model)' is not supported"
        case .inferenceFailure(let message):
            return "Inference failed: \(message)"
        case .invalidRequest(let message):
            return "Invalid inference request: \(message)"
        case .timeout:
            return "Inference request timed out"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Inference Backend Registry

/// Registry for managing multiple inference backends
public actor InferenceBackendRegistry {
    private var backends: [String: any InferenceBackend] = [:]
    private var defaultBackendName: String?

    public init() {}

    /// Register a new inference backend
    public func register(_ backend: any InferenceBackend, as name: String, default isDefault: Bool = false) throws {
        backends[name] = backend

        if isDefault {
            defaultBackendName = name
        } else if defaultBackendName == nil {
            defaultBackendName = name
        }
    }

    /// Get a backend by name
    public func backend(named name: String) throws -> (any InferenceBackend) {
        guard let backend = backends[name] else {
            throw InferenceError.backendNotAvailable(name)
        }
        return backend
    }

    /// Get the default backend
    public func defaultBackend() throws -> (any InferenceBackend) {
        guard let defaultName = defaultBackendName else {
            throw InferenceError.backendNotAvailable("No default backend configured")
        }
        return try backend(named: defaultName)
    }

    /// Get all registered backends
    public var registeredBackends: [String] {
        Array(backends.keys)
    }

    /// Execute inference using a specific backend
    public func infer(request: InferenceRequest, using backendName: String? = nil) async throws -> InferenceResponse {
        let resolvedBackend: any InferenceBackend
        if let backendName {
            resolvedBackend = try backend(named: backendName)
        } else {
            resolvedBackend = try defaultBackend()
        }
        return try await resolvedBackend.infer(request: request)
    }

    /// Get status of all backends
    public func statusAll() async -> [String: BackendStatus] {
        var statuses: [String: BackendStatus] = [:]

        for (name, backend) in backends {
            statuses[name] = await backend.status()
        }

        return statuses
    }
}

// MARK: - Mock Inference Backend for Testing

/// A mock inference backend for testing and demonstration
public actor MockInferenceBackend: InferenceBackend {
    public let name: String
    public let supportedModels: [String]
    public private(set) var isAvailable: Bool

    public init(name: String = "MockBackend", models: [String] = ["mock-model-1", "mock-model-2"]) {
        self.name = name
        self.supportedModels = models
        self.isAvailable = true
    }

    public func initialize() async throws {
        isAvailable = true
    }

    public func infer(request: InferenceRequest) async throws -> InferenceResponse {
        guard isAvailable else {
            throw InferenceError.backendNotAvailable(name)
        }

        guard supportedModels.contains(request.model) else {
            throw InferenceError.modelNotSupported(request.model)
        }

        // Simulate some processing delay
        try await Task.sleep(nanoseconds: UInt64(100_000_000)) // 0.1 seconds

        // Generate mock output based on prompt
        let mockOutput = "Mock response to: \(request.prompt.prefix(50))..."

        return InferenceResponse(
            requestId: request.id,
            model: request.model,
            output: mockOutput,
            tokensUsed: TokenUsage(input: request.prompt.count / 4, output: mockOutput.count / 4),
            metadata: ["backend": name]
        )
    }

    public func batchInfer(requests: [InferenceRequest]) async throws -> [InferenceResponse] {
        var responses: [InferenceResponse] = []

        for request in requests {
            let response = try await infer(request: request)
            responses.append(response)
        }

        return responses
    }

    public func status() async -> BackendStatus {
        return BackendStatus(
            name: name,
            available: isAvailable,
            version: "1.0.0",
            loadedModels: supportedModels
        )
    }
}
