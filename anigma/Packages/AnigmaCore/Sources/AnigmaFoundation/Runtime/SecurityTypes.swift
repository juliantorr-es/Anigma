//
//  SecurityTypes.swift
//  AnigmaFoundation
//
//  Shared security types to support dependency injection and resolve circular dependencies.
//

import Foundation
import AnigmaPrimitives

/// Level of severity for a security threat.
public enum ThreatLevel: String, Codable, Sendable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"
}

/// A detected security threat.
public struct DetectedThreat: Sendable, Codable, Identifiable {
    public let id: UUID
    public let threatType: String
    public let level: ThreatLevel
    public let source: String
    public let target: String?
    public let description: String
    public let metadata: [String: String]
    
    public init(
        id: UUID = UUID(),
        threatType: String,
        level: ThreatLevel,
        source: String,
        target: String? = nil,
        description: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.threatType = threatType
        self.level = level
        self.source = source
        self.target = target
        self.description = description
        self.metadata = metadata
    }
}

/// Decision made by the enforcement engine.
public struct EnforcementDecision: Sendable, Codable {
    public let threatId: UUID
    public let action: String
    public let reason: String
    public let enforcedAt: Date
    
    public init(threatId: UUID, action: String, reason: String, enforcedAt: Date = Date()) {
        self.threatId = threatId
        self.action = action
        self.reason = reason
        self.enforcedAt = enforcedAt
    }
}

/// Protocol for components with intrinsic sensitivity.
public protocol SensitiveComponent: Component {
    static var sensitivity: DataSensitivity { get }
    static var dataCategories: Set<String> { get }
}

/// A report on compliance status.
public struct ComplianceReport: Codable, Sendable {
    public let id: UUID
    public let generatedAt: Date
    public let status: String
    public let score: Double
    public let findings: [String]
    
    // AnigmaPlatform requirements
    public let startDate: Date?
    public let endDate: Date?
    public let totalEntries: Int
    public let regulationResults: [String: String]
    
    public init(
        id: UUID = UUID(),
        generatedAt: Date = Date(),
        status: String = "complete",
        score: Double = 1.0,
        findings: [String] = [],
        startDate: Date? = nil,
        endDate: Date? = nil,
        totalEntries: Int = 0,
        regulationResults: [String: String] = [:]
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.status = status
        self.score = score
        self.findings = findings
        self.startDate = startDate
        self.endDate = endDate
        self.totalEntries = totalEntries
        self.regulationResults = regulationResults
    }
}
