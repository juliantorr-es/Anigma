//
//  EvidenceSupport.swift
//  ContractsCore
//
//  Contract definition for EvidenceSupport in ContractsCore.
//

import FoundationContracts
import GovernanceContracts
import AnigmaPrimitives
import Foundation

/// Violation detected during evidence chain validation.
public struct ChainViolation: Sendable, Codable, Hashable {
    public let eventId: String
    public let description: String

    public init(eventId: String, description: String) {
        self.eventId = eventId
        self.description = description
    }
}

/// Integrity report produced after verifying an evidence chain.
public struct ChainIntegrityReport: Sendable, Codable {
    public let totalEvents: Int
    public let violations: [ChainViolation]
    public let isIntact: Bool
    public let headHash: String
    public let validationTimestamp: Date

    public init(
        totalEvents: Int,
        violations: [ChainViolation] = [],
        isIntact: Bool,
        headHash: String,
        validationTimestamp: Date = Date()
    ) {
        self.totalEvents = totalEvents
        self.violations = violations
        self.isIntact = isIntact
        self.headHash = headHash
        self.validationTimestamp = validationTimestamp
    }
}

/// Result of verifying an evidence chain against expectations.
public struct EvidenceChainValidation: Sendable, Codable {
    public let isValid: Bool
    public let violations: [EvidenceViolation]
    public let chainLength: Int
    public let lastHash: String?

    public init(isValid: Bool, violations: [EvidenceViolation] = [], chainLength: Int = 0, lastHash: String? = nil) {
        self.isValid = isValid
        self.violations = violations
        self.chainLength = chainLength
        self.lastHash = lastHash
    }
}

/// Canonical evidence record used across coordination systems.
public struct EvidenceRecord: Sendable, Codable, Hashable {
    public let id: String
    public let sessionId: String
    public let agentId: String
    public let toolName: String
    public let requestId: String
    public let parameters: String?
    public let filePath: String?
    public let contentHash: String?
    public let startTime: Date
    public let endTime: Date?
    public let status: String
    public let result: String?
    public let error: String?

    public init(
        id: String,
        sessionId: String,
        agentId: String,
        toolName: String,
        requestId: String,
        parameters: String? = nil,
        filePath: String? = nil,
        contentHash: String? = nil,
        startTime: Date,
        endTime: Date? = nil,
        status: String = "started",
        result: String? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.agentId = agentId
        self.toolName = toolName
        self.requestId = requestId
        self.parameters = parameters
        self.filePath = filePath
        self.contentHash = contentHash
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.result = result
        self.error = error
    }
}
