import AnigmaPrimitives

import AnigmaPrimitives

//
//  IntelligenceComponents.swift
//  ContractsCore
//
//  Shared ECS components for intelligence and Harmonia pipelines.
//

import Foundation
import AnigmaPrimitives

// MARK: - Model and Request Types

/// Types of models that can be served by the Harmonia pipeline.
public enum ModelKind: String, Sendable, CaseIterable, Codable {
    // Basic types
    case chat
    case reasoner
    case oracle
    
    // Capability types
    case embedder
    case generator
    case summarizer
    case classifier
    case vision
    case audio
    case translation
    
    public var displayName: String {
        self.rawValue.capitalized
    }
}

/// ECS component for Harmonia pipeline requests.
public struct RequestComponent: Component, Sendable, Codable {
    public let id: UUID
    public let requestId: String // For legacy compatibility
    public let modelKind: String // Raw value of ModelKind
    public let sessionId: String // For legacy compatibility
    public let prompt: String
    public var phase: RequestPhase
    public var estimatedTokens: Int
    public let userId: String?
    public let createdAt: Date
    
    public enum RequestPhase: String, Codable, Sendable {
        case queued
        case active
        case completed
        case failed
    }
    
    public var elapsed: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }
    
    public init(
        id: UUID = UUID(),
        requestId: String = UUID().uuidString,
        modelKind: String,
        sessionId: String = "",
        prompt: String = "",
        phase: RequestPhase = .queued,
        estimatedTokens: Int = 0,
        userId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.requestId = requestId
        self.modelKind = modelKind
        self.sessionId = sessionId
        self.prompt = prompt
        self.phase = phase
        self.estimatedTokens = estimatedTokens
        self.userId = userId
        self.createdAt = createdAt
    }
}

// MARK: - Concurrency and Metrics

/// ECS component for Harmonia concurrency slots.
public struct SlotComponent: Component, Sendable, Codable {
    public enum Status: String, Codable, Sendable {
        case idle
        case occupied
        case releasing
    }
    
    public let modelKind: String
    public var status: Status
    public var acquiredAt: Date?
    
    public init(modelKind: String, status: Status = .idle, acquiredAt: Date? = nil) {
        self.modelKind = modelKind
        self.status = status
        self.acquiredAt = acquiredAt
    }
}

/// ECS component for Harmonia metrics.
public struct MetricsComponent: Component, Sendable, Codable {
    public let modelKind: String
    public var completedCount: Int
    public var failedCount: Int
    public var averageLatencyMs: Int64
    public var totalLatencyMs: Int64
    public var tokensProcessed: Int
    public var lastUpdated: Date
    
    public init(
        modelKind: String,
        completedCount: Int = 0,
        failedCount: Int = 0,
        averageLatencyMs: Int64 = 0,
        totalLatencyMs: Int64 = 0,
        tokensProcessed: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.modelKind = modelKind
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.averageLatencyMs = averageLatencyMs
        self.totalLatencyMs = totalLatencyMs
        self.tokensProcessed = tokensProcessed
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Worker Integration

/// ECS component for ML Worker tasks.
public struct MLTaskComponent: Component, Sendable, Codable {
    public let taskId: UUID
    public let runId: String
    public let stepId: String
    public let modelKind: String
    public let inputs: [MLArtifactRef]
    public let engine: MLWorkerEngine
    public let task: MLWorkerTask
    
    public init(
        taskId: UUID = UUID(),
        runId: String,
        stepId: String,
        modelKind: String,
        inputs: [MLArtifactRef],
        engine: MLWorkerEngine = .mlx,
        task: MLWorkerTask = .chat
    ) {
        self.taskId = taskId
        self.runId = runId
        self.stepId = stepId
        self.modelKind = modelKind
        self.inputs = inputs
        self.engine = engine
        self.task = task
    }
}

/// ECS component for ML Worker results.
public struct MLResultComponent: Component, Sendable, Codable {
    public let runId: String
    public let stepId: String
    public let taskId: UUID
    public let status: MLWorkerStatus
    public let outputs: [MLArtifactRef]
    public let metrics: MLWorkerMetrics
    public let engineMeta: MLWorkerEngineMetadata?
    public let errorMessage: String?
    
    public init(
        runId: String,
        stepId: String,
        taskId: UUID,
        status: MLWorkerStatus,
        outputs: [MLArtifactRef],
        metrics: MLWorkerMetrics,
        engineMeta: MLWorkerEngineMetadata? = nil,
        errorMessage: String? = nil
    ) {
        self.runId = runId
        self.stepId = stepId
        self.taskId = taskId
        self.status = status
        self.outputs = outputs
        self.metrics = metrics
        self.engineMeta = engineMeta
        self.errorMessage = errorMessage
    }
}

/// ECS component for Harmonia session state.
public struct SessionComponent: Component, Sendable, Codable {
    public let sessionId: String
    public let userId: String?
    public var idleTime: TimeInterval
    
    public init(sessionId: String, userId: String? = nil, idleTime: TimeInterval = 0) {
        self.sessionId = sessionId
        self.userId = userId
        self.idleTime = idleTime
    }
}

/// ECS component for Harmonia concurrency state.
public struct ConcurrencyStateComponent: Component, Sendable, Codable {
    public enum Pressure: String, Codable, Sendable {
        case low
        case medium
        case critical
    }
    
    public let modelKind: String
    public var pressure: Pressure
    public var utilization: Double
    
    public init(modelKind: String, pressure: Pressure = .low, utilization: Double = 0) {
        self.modelKind = modelKind
        self.pressure = pressure
        self.utilization = utilization
    }
}
