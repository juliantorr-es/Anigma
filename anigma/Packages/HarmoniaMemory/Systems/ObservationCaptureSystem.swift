//
//  ObservationCaptureSystem.swift
//  HarmoniaMemory
//
//  Captures system events and observations for memory persistence.
//  Listens for tool calls, decisions, errors, and other events.
//

import AnigmaCore
import ContractsCore
import Foundation
import TelemetryCore
import AnigmaPrimitives

/// System that captures observations for memory persistence.
public actor ObservationCaptureSystem: AsyncSystem {
    public nonisolated let name: String = "ObservationCapture"

    public nonisolated let dependencies: [String] = []

    public nonisolated let readComponents: [any Component.Type] = [
        // Components we read from
        MemoryObservation.self,
        ToolCallComponent.self,
        RequestComponent.self,
        SessionComponent.self
    ]

    public nonisolated let writeComponents: [any Component.Type] = [
        // Components we write to
        MemoryObservation.self
    ]

    /// Memory service for storing observations.
    private let memoryService: MemoryService

    /// Telemetry client for logging (canonical per ADR-0009).
    private let telemetryClient: TelemetryClient?

    /// Configuration.
    private let config: ObservationCaptureConfig

    /// Active sessions being tracked.
    private var activeSessions: [String: MemorySessionSummary] = [:]

    public init(
        memoryService: MemoryService,
        telemetryClient: TelemetryClient? = nil,
        config: ObservationCaptureConfig = .default
    ) {
        self.memoryService = memoryService
        self.telemetryClient = telemetryClient
        self.config = config
    }

    public func setup(world: World) async throws {
        print("[ObservationCapture] starting")

        // Load active sessions from memory store
        let active = try? await memoryService.getActiveSessions()
        if let active = active {
            for summary in active {
                activeSessions[summary.sessionId] = summary
            }
        }

        print("[ObservationCapture] loaded \(activeSessions.count) active sessions")
    }

    public func update(world: World) async throws {
        // Capture tool call events
        try await captureToolCalls(world: world)

        // Capture request events
        try await captureRequestEvents(world: world)

        // Capture session events
        try await captureSessionEvents(world: world)

        // Capture custom observation components
        try await captureObservations(world: world)

        // Clean up old in-memory sessions
        cleanupInactiveSessions()
    }

    public func teardown(world: World) async throws {
        // End all active sessions
        for sessionId in activeSessions.keys {
            try? await memoryService.endSession(sessionId: sessionId)
        }
        activeSessions.removeAll()

        print("[ObservationCapture] stopped")
    }

    // MARK: - Capture Methods

    /// Captures tool call events.
    private func captureToolCalls(world: World) async throws {
        // Look for ToolCallComponent entities
        let toolCalls = await world.query(ToolCallComponent.self)

        for (entity, toolCall) in toolCalls {
            // Check if we've already processed this tool call
            if toolCall.observationId != nil { continue }

            // Create observation
            let observation = MemoryObservation.toolCall(
                sessionId: toolCall.sessionId,
                tenantId: toolCall.tenantId,
                source: toolCall.source ?? .daemon,
                toolCall: ToolCall(
                    id: toolCall.id,
                    name: toolCall.toolName,
                    arguments: toolCall.arguments
                ),
                metadata: [
                    "entity_id": entity.raw.uuidString,
                    "tool_call_id": toolCall.id
                ]
            )

            // Store observation
            try await memoryService.storeObservation(observation)

            // Mark tool call as observed
            var updated = toolCall
            updated.observationId = observation.id.uuidString
            await world.addComponent(entity, updated)

            // Update session summary
            await updateSessionSummary(for: observation)

            await logCapture(.toolCall, toolName: toolCall.toolName)
        }
    }

    /// Captures request events.
    private func captureRequestEvents(world: World) async throws {
        let requests = await world.query(RequestComponent.self)

        for (entity, request) in requests {
            // Only capture when request reaches terminal state
            guard request.phase.isTerminal else { continue }

            // Check if we've already captured this request
            if request.observationId != nil { continue }

            let observationType: ObservationType
            let result: ObservationResult?
            let error: ObservationError?

            switch request.phase {
            case .completed:
                observationType = .toolResult
                result = ObservationResult(
                    success: true,
                    output: request.output,
                    durationMs: Int(request.elapsed * 1000),
                    metrics: [
                        "tokens": Double(request.estimatedTokens),
                        "latency": request.elapsed
                    ]
                )
                error = nil

            case .failed:
                observationType = .toolError
                result = nil
                error = ObservationError(
                    domain: "request",
                    code: request.errorCode ?? 0,
                    message: request.errorMessage ?? "Unknown error",
                    isRecoverable: false
                )

            default:
                continue
            }

        let observation = MemoryObservation(
            sessionId: request.sessionId,
            tenantId: request.tenantId,
            observationType: observationType,
            source: request.source ?? .daemon,
            eventData: encodeRequest(request),
            result: result,
            error: error,
            tags: ["request", request.modelKind.rawValue],
            metadata: [
                "entity_id": entity.raw.uuidString,
                "request_id": request.id.uuidString,
                "model_kind": request.modelKind.rawValue
            ]
        )

            try await memoryService.storeObservation(observation)

            // Mark request as observed
            var updated = request
            updated.observationId = observation.id.uuidString
            await world.addComponent(entity, updated)

            // Update session summary
            await updateSessionSummary(for: observation)

            await logCapture(
                .request, details: "\(request.modelKind.rawValue) \(request.phase.rawValue)")
        }
    }

    /// Captures session events.
    private func captureSessionEvents(world: World) async throws {
        let sessions = await world.query(SessionComponent.self)

        for (_, session) in sessions {
            // Check if session needs to be created/updated in memory
            if activeSessions[session.id] == nil {
                // Create new session summary
                let summary = MemorySessionSummary.initial(
                    sessionId: session.id,
                    tenantId: session.tenantId,
                    agentId: session.principalId,
                    mode: session.mode,
                    model: session.model
                )

                activeSessions[session.id] = summary
                try await memoryService.updateSessionSummary(summary)

                await logCapture(.session, details: "Created session \(session.id)")
            }

            // Check if session ended
            if session.endedAt != nil && activeSessions[session.id]?.isActive == true {
                var summary = activeSessions[session.id]
                summary?.endSession()
                if let summary = summary {
                    try await memoryService.updateSessionSummary(summary)
                    activeSessions.removeValue(forKey: session.id)

                    await logCapture(.session, details: "Ended session \(session.id)")
                }
            }
        }
    }

    /// Captures custom observation components.
    private func captureObservations(world: World) async throws {
        let observations = await world.query(MemoryObservation.self)

        for (entity, observation) in observations {
            // Only capture if not already persisted (no persistence flag)
            // We could add a flag to MemoryObservation to mark as persisted
            // For now, we'll assume all MemoryObservation components need to be stored

            try await memoryService.storeObservation(observation)

            // Update session summary
            await updateSessionSummary(for: observation)

            // Remove component after storing (optional)
            if config.removeAfterCapture {
                await world.removeComponent(entity, MemoryObservation.self)
            }

            await logCapture(.observation, details: "\(observation.observationType.rawValue)")
        }
    }

    // MARK: - Helper Methods

    /// Updates session summary with new observation.
    private func updateSessionSummary(for observation: MemoryObservation) async {
        var summary = activeSessions[observation.sessionId]

        if summary == nil {
            summary = MemorySessionSummary.initial(
                sessionId: observation.sessionId,
                tenantId: observation.tenantId
            )
        }

        summary?.update(with: observation)

        if let summary = summary {
            activeSessions[observation.sessionId] = summary

            // Update in memory store (async, fire-and-forget)
            Task {
                try? await memoryService.updateSessionSummary(summary)
            }
        }
    }

    /// Cleans up inactive sessions from memory.
    private func cleanupInactiveSessions() {
        let cutoffDate = Date().addingTimeInterval(-config.sessionCleanupInterval)

        for (sessionId, summary) in activeSessions {
            if summary.updatedAt < cutoffDate && !summary.isActive {
                activeSessions.removeValue(forKey: sessionId)
            }
        }
    }

    /// Logs capture events.
    private func logCapture(_ type: CaptureType, toolName: String? = nil, details: String? = nil)
        async {
        guard let telemetry = telemetryClient else { return }

        var values: [String: TelemetryValue] = [
            "count": .integer(1),
            "type": .hashedToken(TelemetryHash(input: type.rawValue))
        ]

        if let toolName = toolName {
            values["tool"] = .hashedToken(TelemetryHash(input: toolName))
        }

        _ = await telemetry.emit(
            category: .memory,
            name: "observation_captured",
            privacyClassification: .internal,
            values: values
        )
    }

    /// Encodes a request for event data.
    private func encodeRequest(_ request: RequestComponent) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let dict: [String: Any] = [
            "id": request.id.uuidString,
            "model_kind": request.modelKind.rawValue,
            "phase": request.phase.rawValue,
            "estimated_tokens": request.estimatedTokens,
            "elapsed": request.elapsed,
            "error_message": request.errorMessage as Any,
            "error_code": request.errorCode as Any,
            "output": request.output as Any,
            "source": request.source?.rawValue as Any
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: dict) else {
            return "{}"
        }

        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Supporting Types

/// Configuration for observation capture.
public struct ObservationCaptureConfig: Sendable {
    /// Whether to remove MemoryObservation components after capturing.
    public var removeAfterCapture: Bool

    /// Interval for cleaning up inactive sessions (seconds).
    public var sessionCleanupInterval: TimeInterval

    /// Maximum number of observations to process per update.
    public var maxObservationsPerUpdate: Int

    public init(
        removeAfterCapture: Bool = true,
        sessionCleanupInterval: TimeInterval = 3600,  // 1 hour
        maxObservationsPerUpdate: Int = 100
    ) {
        self.removeAfterCapture = removeAfterCapture
        self.sessionCleanupInterval = sessionCleanupInterval
        self.maxObservationsPerUpdate = maxObservationsPerUpdate
    }

    public static let `default` = ObservationCaptureConfig()
}

/// Types of captures.
private enum CaptureType: String {
    case toolCall = "tool_call"
    case request = "request"
    case session = "session"
    case observation = "observation"
}

// MARK: - Component Extensions

/// Component representing a tool call.
public struct ToolCallComponent: Component, Sendable, Codable {
    public let id: String
    public let toolName: String
    public let arguments: [String: String]
    public let sessionId: String
    public let tenantId: String
    public let timestamp: Date
    /// Source of the tool call.
    public var source: ObservationSource?
    public var observationId: String?

    public init(
        id: String = UUID().uuidString,
        toolName: String,
        arguments: [String: String],
        sessionId: String,
        tenantId: String,
        timestamp: Date = Date(),
        source: ObservationSource? = nil
    ) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
        self.sessionId = sessionId
        self.tenantId = tenantId
        self.timestamp = timestamp
        self.source = source
        self.observationId = nil
    }
}

/// Request component (placeholder - should match actual RequestComponent in AnigmaCore).
public struct RequestComponent: Component, Sendable, Codable {
    public let id: UUID
    public let modelKind: ModelKind
    public let sessionId: String
    public let tenantId: String
    public var phase: RequestPhase
    public var estimatedTokens: Int
    public var elapsed: TimeInterval
    public var errorMessage: String?
    /// Optional error code when the request fails.
    public var errorCode: Int?
    /// Optional output payload, if the request succeeded.
    public var output: String?
    /// Source of the request.
    public var source: ObservationSource?
    public var observationId: String?

    public init(
        id: UUID = UUID(),
        modelKind: ModelKind,
        sessionId: String,
        tenantId: String,
        phase: RequestPhase = .queued,
        estimatedTokens: Int = 0
    ) {
        self.id = id
        self.modelKind = modelKind
        self.sessionId = sessionId
        self.tenantId = tenantId
        self.phase = phase
        self.estimatedTokens = estimatedTokens
        self.elapsed = 0
        self.errorMessage = nil
        self.errorCode = nil
        self.output = nil
        self.source = nil
        self.observationId = nil
    }
}

/// Session component (placeholder - should match actual SessionComponent in AnigmaCore).
public struct SessionComponent: Component, Sendable, Codable {
    public let id: String
    public let tenantId: String
    public let principalId: String
    public let startedAt: Date
    public var endedAt: Date?
    public var lastActivityAt: Date
    /// Optional session mode identifier.
    public var mode: String?
    /// Optional model identifier for the session.
    public var model: String?

    public init(
        id: String = UUID().uuidString,
        tenantId: String,
        principalId: String,
        startedAt: Date = Date(),
        mode: String? = nil,
        model: String? = nil
    ) {
        self.id = id
        self.tenantId = tenantId
        self.principalId = principalId
        self.startedAt = startedAt
        self.endedAt = nil
        self.lastActivityAt = startedAt
        self.mode = mode
        self.model = model
    }
}

/// Request phases.
public enum RequestPhase: String, Codable, Sendable {
    case queued
    case processing
    case completed
    case failed
    case cancelled

    public var isActive: Bool {
        self == .processing
    }

    public var isTerminal: Bool {
        self == .completed || self == .failed || self == .cancelled
    }
}

/// Model kinds.
public enum ModelKind: String, Codable, Sendable {
    case unknown
    case gpt4
    case claude
    case llama
    case local

    public var displayName: String {
        rawValue.capitalized
    }
}
