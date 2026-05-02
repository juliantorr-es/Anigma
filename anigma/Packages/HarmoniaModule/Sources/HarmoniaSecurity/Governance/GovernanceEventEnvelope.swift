//
//  GovernanceEventEnvelope.swift
//  HarmoniaModule
//
//  Envelope and type-erased event representation.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import DoctrineCore
@preconcurrency import Foundation

struct GovernanceEventEnvelope: Codable, Sendable {
    let events: [AnyCodableEvent]
    let envelopeId: String
    let envelopeTimestamp: Date
    let sessionId: String

    init(events: [AnyCodableEvent], sessionId: String) {
        self.events = events
        self.envelopeId = UUID().uuidString
        self.envelopeTimestamp = Date()
        self.sessionId = sessionId
    }
}

struct AnyCodableEvent: Codable, Sendable {
    let type: String
    private let sessionStartedValue: SessionStartedEvent?
    private let sessionEndedValue: SessionEndedEvent?
    private let toolInvokedValue: ToolInvokedEvent?
    private let toolCompletedValue: ToolCompletedEvent?
    private let policyGateEvaluatedValue: PolicyGateEvaluatedEvent?
    private let stateTransitionApprovedValue: StateTransitionApprovedEvent?
    private let jobStartedValue: JobStartedEvent?
    private let jobStepExecutedValue: JobStepExecutedEvent?
    private let jobCompletedValue: JobCompletedEvent

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private init(
        type: String,
        sessionStarted: SessionStartedEvent? = nil,
        sessionEnded: SessionEndedEvent? = nil,
        toolInvoked: ToolInvokedEvent? = nil,
        toolCompleted: ToolCompletedEvent? = nil,
        policyGateEvaluated: PolicyGateEvaluatedEvent? = nil,
        stateTransitionApproved: StateTransitionApprovedEvent? = nil,
        jobStarted: JobStartedEvent? = nil,
        jobStepExecuted: JobStepExecutedEvent? = nil,
        jobCompleted: JobCompletedEvent? = nil
    ) {
        self.type = type
        self.sessionStartedValue = sessionStarted
        self.sessionEndedValue = sessionEnded
        self.toolInvokedValue = toolInvoked
        self.toolCompletedValue = toolCompleted
        self.policyGateEvaluatedValue = policyGateEvaluated
        self.stateTransitionApprovedValue = stateTransitionApproved
        self.jobStartedValue = jobStarted
        self.jobStepExecutedValue = jobStepExecuted
        self.jobCompletedValue = jobCompleted
    }

    static func sessionStarted(_ event: SessionStartedEvent) -> AnyCodableEvent {
        AnyCodableEvent(type: "session.started", sessionStarted: event)
    }

    static func sessionEnded(_ event: SessionEndedEvent) -> AnyCodableEvent {
        AnyCodableEvent(type: "session.ended", sessionEnded: event)
    }

    static func toolInvoked(_ event: ToolInvokedEvent) -> AnyCodableEvent {
        AnyCodableEvent(type: "tool.invoked", toolInvoked: event)
    }

    static func toolCompleted(_ event: ToolCompletedEvent) -> AnyCodableEvent {
        AnyCodableEvent(type: "tool.completed", toolCompleted: event)
    }

    static func policyGateEvaluated(_ event: PolicyGateEvaluatedEvent) -> AnyCodableEvent {
        AnyCodableEvent(type: "policy.evaluated", policyGateEvaluated: event)
    }

    static func stateTransitionApproved(_ event: StateTransitionApprovedEvent) -> AnyCodableEvent {
        AnyCodableEvent(type: "state.transition_approved", stateTransitionApproved: event)
    }

    static func jobStarted(_ event: JobStartedEvent) -> AnyCodableEvent {
        AnyCodableEvent(type: "job.started", jobStarted: event)
    }

    static func jobStepExecuted(_ event: JobStepExecutedEvent) -> AnyCodableEvent {
        AnyCodableEvent(type: "job.step_executed", jobStepExecuted: event)
    }

    static func jobCompleted(_ event: JobCompletedEvent) -> AnyCodableEvent {
        AnyCodableEvent(type: "job.completed", jobCompleted: event)
    }

    var sessionStarted: SessionStartedEvent? { sessionStartedValue }
    var sessionEnded: SessionEndedEvent? { sessionEndedValue }
    var toolInvoked: ToolInvokedEvent? { toolInvokedValue }
    var toolCompleted: ToolCompletedEvent? { toolCompletedValue }
    var policyGateEvaluated: PolicyGateEvaluatedEvent? { policyGateEvaluatedValue }
    var stateTransitionApproved: StateTransitionApprovedEvent? { stateTransitionApprovedValue }
    var jobStarted: JobStartedEvent? { jobStartedValue }
    var jobStepExecuted: JobStepExecutedEvent? { jobStepExecutedValue }
    var jobCompleted: JobCompletedEvent? { jobCompletedValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "session.started":
            self = .sessionStarted(try container.decode(SessionStartedEvent.self, forKey: .value))
        case "session.ended":
            self = .sessionEnded(try container.decode(SessionEndedEvent.self, forKey: .value))
        case "tool.invoked":
            self = .toolInvoked(try container.decode(ToolInvokedEvent.self, forKey: .value))
        case "tool.completed":
            self = .toolCompleted(try container.decode(ToolCompletedEvent.self, forKey: .value))
        case "policy.evaluated":
            self = .policyGateEvaluated(try container.decode(PolicyGateEvaluatedEvent.self, forKey: .value))
        case "state.transition_approved":
            self = .stateTransitionApproved(try container.decode(StateTransitionApprovedEvent.self, forKey: .value))
        case "job.started":
            self = .jobStarted(try container.decode(JobStartedEvent.self, forKey: .value))
        case "job.step_executed":
            self = .jobStepExecuted(try container.decode(JobStepExecutedEvent.self, forKey: .value))
        case "job.completed":
            self = .jobCompleted(try container.decode(JobCompletedEvent.self, forKey: .value))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown governance event type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch type {
        case "session.started":
            try container.encode("session.started", forKey: .type)
            try container.encode(sessionStartedValue, forKey: .value)
        case "session.ended":
            try container.encode("session.ended", forKey: .type)
            try container.encode(sessionEndedValue, forKey: .value)
        case "tool.invoked":
            try container.encode("tool.invoked", forKey: .type)
            try container.encode(toolInvokedValue, forKey: .value)
        case "tool.completed":
            try container.encode("tool.completed", forKey: .type)
            try container.encode(toolCompletedValue, forKey: .value)
        case "policy.evaluated":
            try container.encode("policy.evaluated", forKey: .type)
            try container.encode(policyGateEvaluatedValue, forKey: .value)
        case "state.transition_approved":
            try container.encode("state.transition_approved", forKey: .type)
            try container.encode(stateTransitionApprovedValue, forKey: .value)
        case "job.started":
            try container.encode("job.started", forKey: .type)
            try container.encode(jobStartedValue, forKey: .value)
        case "job.step_executed":
            try container.encode("job.step_executed", forKey: .type)
            try container.encode(jobStepExecutedValue, forKey: .value)
        case "job.completed":
            try container.encode("job.completed", forKey: .type)
            try container.encode(jobCompletedValue, forKey: .value)
        default:
            throw EncodingError.invalidValue(
                type,
                EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unknown governance event type")
            )
        }
    }
}
