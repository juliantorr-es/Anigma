//
//  GovernancePolicyEvents.swift
//  HarmoniaModule
//
//  Policy and state transition governance events.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import DoctrineCore
@preconcurrency import Foundation

struct PolicyGateEvaluatedEvent: Codable {
    let eventId: String
    let eventType: String
    let version: Int
    let timestamp: Date
    let sessionId: String
    let toolName: String
    let decision: String
    let reason: String
    let authority: String

    init(
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

struct StateTransitionApprovedEvent: Codable {
    let eventId: String
    let eventType: String
    let version: Int
    let timestamp: Date
    let sessionId: String
    let transitionId: String
    let fromState: String
    let toState: String
    let approverAuth: String
    let evidenceId: String?

    init(
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
