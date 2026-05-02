//
//  GovernanceEventSchemas.swift
//  HarmoniaModule
//
//  Governance event schemas for Phase 8.5: Versioned, append-friendly events
//  for session state, governance decisions, tool invocations, and workflow progress.
//  All events are stored through DatabaseCore and surfaced through Harmonia.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import DoctrineCore
import AnigmaPrimitives
import ContractsCore
@preconcurrency import Foundation

// MARK: - Governance Event Protocol

/// Base protocol for all governance events.
/// Events are immutable, versioned, and append-only.
public protocol GovernanceEvent: Codable, Sendable {
    var eventId: String { get }
    var eventType: String { get }
    var version: Int { get }
    var timestamp: Date { get }
    var sessionId: String { get }
}

// MARK: - Session Lifecycle Events

/// Session started event.
public struct SessionStartedEvent: GovernanceEvent {
    public let eventId: String
    public let eventType: String
    public let version: Int
    public let timestamp: Date
    public let sessionId: String
    public let agentId: String
    public let permissions: Set<Permission>
    public let allowGovernedBuild: Bool
    public let workingDirectory: String

    public init(
        sessionId: String,
        agentId: String,
        permissions: Set<Permission>,
        allowGovernedBuild: Bool,
        workingDirectory: String
    ) {
        self.eventId = "session-\(sessionId.hashValue)"  // Deterministic from sessionId
        self.eventType = "session.started"
        self.version = 1
        self.timestamp = Date()
        self.sessionId = sessionId
        self.agentId = agentId
        self.permissions = permissions
        self.allowGovernedBuild = allowGovernedBuild
        self.workingDirectory = workingDirectory
    }
}

/// Session ended event.
public struct SessionEndedEvent: GovernanceEvent {
    public let eventId: String
    public let eventType: String
    public let version: Int
    public let timestamp: Date
    public let sessionId: String
    public let reason: String
    public let finalStatus: String

    public init(sessionId: String, reason: String, finalStatus: String = "ended") {
        self.eventId = "session-\(sessionId.hashValue)-ended"  // Deterministic
        self.eventType = "session.ended"
        self.version = 1
        self.timestamp = Date()
        self.sessionId = sessionId
        self.reason = reason
        self.finalStatus = finalStatus
    }
}

// MARK: - Tool Invocation Events

/// Tool invocation requested event.
public struct ToolInvokedEvent: GovernanceEvent {
    public let eventId: String
    public let eventType: String
    public let version: Int
    public let timestamp: Date
    public let sessionId: String
    public let toolName: String
    public let parameters: [String: String]
    public let inputHash: String?

    public init(
        sessionId: String,
        toolName: String,
        parameters: [String: String],
        inputHash: String? = nil
    ) {
        let paramsHash = parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
            .joined().hashValue
        self.eventId = "tool-\(sessionId)-\(toolName)-\(Swift.abs(paramsHash))"  // Deterministic
        self.eventType = "tool.invoked"
        self.version = 1
        self.timestamp = Date()
        self.sessionId = sessionId
        self.toolName = toolName
        self.parameters = parameters
        self.inputHash = inputHash
    }
}

/// Tool invocation completed event.
public struct ToolCompletedEvent: GovernanceEvent {
    public let eventId: String
    public let eventType: String
    public let version: Int
    public let timestamp: Date
    public let sessionId: String
    public let toolName: String
    public let invokedEventId: String
    public let status: String  // "success", "failed", "blocked"
    public let outputHash: String?
    public let durationMs: Int
    public let errorMessage: String?

    public init(
        sessionId: String,
        toolName: String,
        invokedEventId: String,
        status: String,
        outputHash: String? = nil,
        durationMs: Int = 0,
        errorMessage: String? = nil
    ) {
        self.eventId =
            "tool-\(sessionId)-\(toolName)-\(invokedEventId.hashValue)-\(status.hashValue)"  // Deterministic
        self.eventType = "tool.completed"
        self.version = 1
        self.timestamp = Date()
        self.sessionId = sessionId
        self.toolName = toolName
        self.invokedEventId = invokedEventId
        self.status = status
        self.outputHash = outputHash
        self.durationMs = durationMs
        self.errorMessage = errorMessage
    }
}

// MARK: - Governance Decision Events

/// Policy gate evaluation event.
public struct PolicyGateEvaluatedEvent: GovernanceEvent {
    public let eventId: String
    public let eventType: String
    public let version: Int
    public let timestamp: Date
    public let sessionId: String
    public let toolName: String
    public let decision: String  // "allowed", "denied", "blocked"
    public let reason: String
    public let authority: String

    public init(
        sessionId: String,
        toolName: String,
        decision: String,
        reason: String,
        authority: String = "PolicyGate"
    ) {
        self.eventId = UUID().uuidString
        self.eventType = "policy.evaluated"
        self.version = 1
        self.timestamp = Date()
        self.sessionId = sessionId
        self.toolName = toolName
        self.decision = decision
        self.reason = reason
        self.authority = authority
    }
}

/// State transition approved event.
public struct StateTransitionApprovedEvent: GovernanceEvent {
    public let eventId: String
    public let eventType: String
    public let version: Int
    public let timestamp: Date
    public let sessionId: String
    public let transitionId: String
    public let fromState: String
    public let toState: String
    public let approverAuth: String
    public let evidenceId: String?

    public init(
        sessionId: String,
        transitionId: String,
        fromState: String,
        toState: String,
        approverAuth: String,
        evidenceId: String? = nil
    ) {
        self.eventId = UUID().uuidString
        self.eventType = "state.transition_approved"
        self.version = 1
        self.timestamp = Date()
        self.sessionId = sessionId
        self.transitionId = transitionId
        self.fromState = fromState
        self.toState = toState
        self.approverAuth = approverAuth
        self.evidenceId = evidenceId
    }
}

// MARK: - Workflow/Job Progress Events

/// Job started event.
public struct JobStartedEvent: GovernanceEvent {
    public let eventId: String
    public let eventType: String
    public let version: Int
    public let timestamp: Date
    public let sessionId: String
    public let jobId: String
    public let jobName: String
    public let workflowId: String?

    public init(
        sessionId: String,
        jobId: String,
        jobName: String,
        workflowId: String? = nil
    ) {
        self.eventId = UUID().uuidString
        self.eventType = "job.started"
        self.version = 1
        self.timestamp = Date()
        self.sessionId = sessionId
        self.jobId = jobId
        self.jobName = jobName
        self.workflowId = workflowId
    }
}

/// Job step executed event.
public struct JobStepExecutedEvent: GovernanceEvent {
    public let eventId: String
    public let eventType: String
    public let version: Int
    public let timestamp: Date
    public let sessionId: String
    public let jobId: String
    public let stepIndex: Int
    public let stepName: String
    public let status: String  // "success", "failed", "skipped"
    public let durationMs: Int

    public init(
        sessionId: String,
        jobId: String,
        stepIndex: Int,
        stepName: String,
        status: String,
        durationMs: Int = 0
    ) {
        self.eventId = UUID().uuidString
        self.eventType = "job.step_executed"
        self.version = 1
        self.timestamp = Date()
        self.sessionId = sessionId
        self.jobId = jobId
        self.stepIndex = stepIndex
        self.stepName = stepName
        self.status = status
        self.durationMs = durationMs
    }
}

/// Job completed event.
public struct JobCompletedEvent: GovernanceEvent {
    public let eventId: String
    public let eventType: String
    public let version: Int
    public let timestamp: Date
    public let sessionId: String
    public let jobId: String
    public let status: String  // "success", "failed", "cancelled"
    public let totalDurationMs: Int
    public let stepsCompleted: Int
    public let stepsFailed: Int

    public init(
        sessionId: String,
        jobId: String,
        status: String,
        totalDurationMs: Int = 0,
        stepsCompleted: Int = 0,
        stepsFailed: Int = 0
    ) {
        self.eventId = UUID().uuidString
        self.eventType = "job.completed"
        self.version = 1
        self.timestamp = Date()
        self.sessionId = sessionId
        self.jobId = jobId
        self.status = status
        self.totalDurationMs = totalDurationMs
        self.stepsCompleted = stepsCompleted
        self.stepsFailed = stepsFailed
    }
}

// MARK: - Event Envelope

/// Envelope for transmitting events through the system.
public struct GovernanceEventEnvelope: Codable, Sendable {
    public let events: [AnyCodableEvent]
    public let envelopeId: String
    public let envelopeTimestamp: Date
    public let sessionId: String

    public init(events: [AnyCodableEvent], sessionId: String) {
        self.events = events
        self.envelopeId = UUID().uuidString
        self.envelopeTimestamp = Date()
        self.sessionId = sessionId
    }
}

/// Type-erased event wrapper for heterogeneous collections.
public enum AnyCodableEvent: Codable, Sendable {
    case sessionStarted(SessionStartedEvent)
    case sessionEnded(SessionEndedEvent)
    case toolInvoked(ToolInvokedEvent)
    case toolCompleted(ToolCompletedEvent)
    case policyGateEvaluated(PolicyGateEvaluatedEvent)
    case stateTransitionApproved(StateTransitionApprovedEvent)
    case jobStarted(JobStartedEvent)
    case jobStepExecuted(JobStepExecutedEvent)
    case jobCompleted(JobCompletedEvent)

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "session.started":
            let value = try container.decode(SessionStartedEvent.self, forKey: .value)
            self = .sessionStarted(value)
        case "session.ended":
            let value = try container.decode(SessionEndedEvent.self, forKey: .value)
            self = .sessionEnded(value)
        case "tool.invoked":
            let value = try container.decode(ToolInvokedEvent.self, forKey: .value)
            self = .toolInvoked(value)
        case "tool.completed":
            let value = try container.decode(ToolCompletedEvent.self, forKey: .value)
            self = .toolCompleted(value)
        case "policy.evaluated":
            let value = try container.decode(PolicyGateEvaluatedEvent.self, forKey: .value)
            self = .policyGateEvaluated(value)
        case "state.transition_approved":
            let value = try container.decode(StateTransitionApprovedEvent.self, forKey: .value)
            self = .stateTransitionApproved(value)
        case "job.started":
            let value = try container.decode(JobStartedEvent.self, forKey: .value)
            self = .jobStarted(value)
        case "job.step_executed":
            let value = try container.decode(JobStepExecutedEvent.self, forKey: .value)
            self = .jobStepExecuted(value)
        case "job.completed":
            let value = try container.decode(JobCompletedEvent.self, forKey: .value)
            self = .jobCompleted(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown event type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .sessionStarted(let event):
            try container.encode("session.started", forKey: .type)
            try container.encode(event, forKey: .value)
        case .sessionEnded(let event):
            try container.encode("session.ended", forKey: .type)
            try container.encode(event, forKey: .value)
        case .toolInvoked(let event):
            try container.encode("tool.invoked", forKey: .type)
            try container.encode(event, forKey: .value)
        case .toolCompleted(let event):
            try container.encode("tool.completed", forKey: .type)
            try container.encode(event, forKey: .value)
        case .policyGateEvaluated(let event):
            try container.encode("policy.evaluated", forKey: .type)
            try container.encode(event, forKey: .value)
        case .stateTransitionApproved(let event):
            try container.encode("state.transition_approved", forKey: .type)
            try container.encode(event, forKey: .value)
        case .jobStarted(let event):
            try container.encode("job.started", forKey: .type)
            try container.encode(event, forKey: .value)
        case .jobStepExecuted(let event):
            try container.encode("job.step_executed", forKey: .type)
            try container.encode(event, forKey: .value)
        case .jobCompleted(let event):
            try container.encode("job.completed", forKey: .type)
            try container.encode(event, forKey: .value)
        }
    }
}
