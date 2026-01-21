import Foundation
import ContractsCore
import AnigmaPrimitives

// MARK: - Kill Switch Policy

/// Status of the kill switch.
/// Defined in Tier 1 (GovernanceCore) as a pure data structure.
public struct KillSwitchStatus: Sendable, Codable {
    public let isGloballyActive: Bool
    public let activationReason: String?
    public let activatedAt: Date?
    public let activatedBy: String?
    public let projectOverrides: [String: Bool]

    public init(
        isGloballyActive: Bool,
        activationReason: String? = nil,
        activatedAt: Date? = nil,
        activatedBy: String? = nil,
        projectOverrides: [String: Bool] = [:]
    ) {
        self.isGloballyActive = isGloballyActive
        self.activationReason = activationReason
        self.activatedAt = activatedAt
        self.activatedBy = activatedBy
        self.projectOverrides = projectOverrides
    }

    public var isAnyActive: Bool {
        isGloballyActive || projectOverrides.values.contains(true)
    }
}

// MARK: - Write Gate Policy

/// A proposed write operation to be checked.
/// Defined in Tier 1 (GovernanceCore) as a pure data structure.
public struct WriteProposal: Sendable, Codable {
    public let principal: String
    public let module: String
    public let operation: String
    public let entityId: EntityId?
    public let componentType: String?
    public let context: [String: String]

    public init(
        principal: String,
        module: String,
        operation: String,
        entityId: EntityId? = nil,
        componentType: String? = nil,
        context: [String: String] = [:]
    ) {
        self.principal = principal
        self.module = module
        self.operation = operation
        self.entityId = entityId
        self.componentType = componentType
        self.context = context
    }
}

/// A quality check for the write gate.
/// Defined in Tier 1 (GovernanceCore) as a protocol.
public protocol WriteCheck: Sendable {
    var id: String { get }
    var name: String { get }
    var isBlocking: Bool { get }
    func appliesTo(_ proposal: WriteProposal) -> Bool
    func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult
}

/// Result of a write check.
/// Defined in Tier 1 (GovernanceCore) as a pure data structure.
public struct WriteCheckResult: Sendable, Codable {
    public let checkId: String
    public let passed: Bool
    public let message: String
    public let details: [String: String]

    public init(checkId: String, passed: Bool, message: String, details: [String: String] = [:]) {
        self.checkId = checkId
        self.passed = passed
        self.message = message
        self.details = details
    }

    public static func pass(checkId: String, message: String = "Check passed") -> WriteCheckResult {
        WriteCheckResult(checkId: checkId, passed: true, message: message)
    }

    public static func fail(checkId: String, message: String) -> WriteCheckResult {
        WriteCheckResult(checkId: checkId, passed: false, message: message)
    }
}

/// Decision from the write gate.
/// Defined in Tier 1 (GovernanceCore) as a pure data structure.
public struct WriteGateDecision: Sendable, Codable {
    public let allowed: Bool
    public let checkResults: [WriteCheckResult]
    public let evaluatedAt: Date

    public init(allowed: Bool, checkResults: [WriteCheckResult], evaluatedAt: Date) {
        self.allowed = allowed
        self.checkResults = checkResults
        self.evaluatedAt = evaluatedAt
    }

    public var failedChecks: [WriteCheckResult] {
        checkResults.filter { !$0.passed }
    }
}
