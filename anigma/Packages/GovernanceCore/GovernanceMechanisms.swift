import AnigmaPrimitives
import Foundation
import FoundationContracts
import GovernanceContracts

// MARK: - Kill Switch Policy

/// Status of the kill switch.
/// Defined in Tier 1 (GovernanceCore) as a pure data structure.
public struct KillSwitchStatus: Sendable, Codable {
  public let isGloballyActive: Bool
  public let activationReason: String?
  public let activatedAt: Date?
  public let activatedBy: String?
  public let projectOverrides: [String: Bool]
  public let projectReasons: [String: String]

  public init(
    isGloballyActive: Bool,
    activationReason: String? = nil,
    activatedAt: Date? = nil,
    activatedBy: String? = nil,
    projectOverrides: [String: Bool] = [:],
    projectReasons: [String: String] = [:]
  ) {
    self.isGloballyActive = isGloballyActive
    self.activationReason = activationReason
    self.activatedAt = activatedAt
    self.activatedBy = activatedBy
    self.projectOverrides = projectOverrides
    self.projectReasons = projectReasons
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

// MARK: - Energy Efficiency Check

/// Tier 1 energy efficiency check enforces hardware efficiency constraints.
/// Evaluates operations against signed mission energy budgets and power limits.
public struct EnergyEfficiencyCheck: WriteCheck, Sendable {
  public let id: String
  public let name: String
  public let isBlocking: Bool
  private let energyBudgetJoules: UInt64
  private let maxPowerWatts: Float
  private let thermalLimitCelsius: Float?
  private let predictiveWindowSeconds: Float

  public init(
    id: String = "energy_efficiency",
    name: String = "Energy Efficiency Check",
    isBlocking: Bool = true,
    energyBudgetJoules: UInt64,
    maxPowerWatts: Float,
    thermalLimitCelsius: Float? = nil,
    predictiveWindowSeconds: Float = 30.0
  ) {
    self.id = id
    self.name = name
    self.isBlocking = isBlocking
    self.energyBudgetJoules = energyBudgetJoules
    self.maxPowerWatts = maxPowerWatts
    self.thermalLimitCelsius = thermalLimitCelsius
    self.predictiveWindowSeconds = max(0, predictiveWindowSeconds)
  }

  public func appliesTo(_ proposal: WriteProposal) -> Bool {
    proposal.context["energy_bounded"] == "true"
  }

  public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
    guard let powerWattsStr = proposal.context["power_watts"],
      let powerWatts = Float(powerWattsStr)
    else {
      return .pass(checkId: id, message: "No power metrics available, skipping check")
    }

    if let thermalEvaluation = ThermalForecastEvaluation(
      proposalContext: proposal.context,
      configuredThermalLimitCelsius: thermalLimitCelsius,
      predictiveWindowSeconds: predictiveWindowSeconds
    ), thermalEvaluation.projectedTemperatureCelsius > thermalEvaluation.thermalLimitCelsius {
      return .fail(
        checkId: id,
        message: """
          Projected thermal load \(thermalEvaluation.projectedTemperatureCelsius)C exceeds limit \
          \(thermalEvaluation.thermalLimitCelsius)C within \(thermalEvaluation.predictiveWindowSeconds)s
          """
      )
    }

    if powerWatts > maxPowerWatts {
      return .fail(
        checkId: id,
        message: "Power usage \(powerWatts)W exceeds limit \(maxPowerWatts)W"
      )
    }

    return .pass(
      checkId: id,
      message: "Power usage \(powerWatts)W within budget"
    )
  }
}

private struct ThermalForecastEvaluation: Sendable {
  let currentTemperatureCelsius: Float
  let thermalLimitCelsius: Float
  let thermalRiseRateCelsiusPerSecond: Float
  let predictiveWindowSeconds: Float

  var projectedTemperatureCelsius: Float {
    currentTemperatureCelsius + thermalRiseRateCelsiusPerSecond * predictiveWindowSeconds
  }

  init?(
    proposalContext: [String: String],
    configuredThermalLimitCelsius: Float?,
    predictiveWindowSeconds: Float
  ) {
    guard let currentTemperatureCelsius = Float(proposalContext["temperature_celsius"] ?? "") else {
      return nil
    }

    let contextThermalLimit = Float(proposalContext["thermal_limit_celsius"] ?? "")
    guard let thermalLimitCelsius = configuredThermalLimitCelsius ?? contextThermalLimit else {
      return nil
    }

    let thermalRiseRateCelsiusPerSecond =
      Float(proposalContext["thermal_rise_rate_celsius_per_second"] ?? "") ?? 0

    self.currentTemperatureCelsius = currentTemperatureCelsius
    self.thermalLimitCelsius = thermalLimitCelsius
    self.thermalRiseRateCelsiusPerSecond = thermalRiseRateCelsiusPerSecond
    self.predictiveWindowSeconds = predictiveWindowSeconds
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

  public func asGovernanceDecision() -> GovernanceDecision {
    let results = Dictionary(uniqueKeysWithValues: checkResults.map { ($0.checkId, $0.passed) })
    return GovernanceDecision(
      allowed: allowed,
      reason: failedChecks.first?.message,
      checkResults: results,
      evaluatedAt: evaluatedAt
    )
  }
}

/// Structured receipt for a denied operation.
/// Provides full provenance for why an operation was blocked.
public struct GovernanceDenialReceipt: Sendable, Codable {
  public let id: UUID
  public let principal: String
  public let operation: String
  public let projectId: String?
  public let reason: String
  public let failingCheckId: String?
  public let timestamp: Date

  public init(
    id: UUID = UUID(),
    principal: String,
    operation: String,
    projectId: String?,
    reason: String,
    failingCheckId: String?,
    timestamp: Date = Date()
  ) {
    self.id = id
    self.principal = principal
    self.operation = operation
    self.projectId = projectId
    self.reason = reason
    self.failingCheckId = failingCheckId
    self.timestamp = timestamp
  }
}

/// Detailed structured payload for governance violations.
/// Carries complete context for audit logging, policy enforcement, and operator visibility.
public struct GovernanceViolation: Sendable, Codable {
  public let id: UUID
  public let principal: String
  public let projectId: String?
  public let operation: String
  public let module: String?
  public let evaluatedModeSource: String?  // "project" | "global" | "default"
  public let failedChecks: [FailedCheck]
  public let timestamp: Date

  public struct FailedCheck: Sendable, Codable {
    public let checkId: String
    public let message: String

    public init(checkId: String, message: String) {
      self.checkId = checkId
      self.message = message
    }
  }

  public init(
    id: UUID = UUID(),
    principal: String,
    projectId: String?,
    operation: String,
    module: String?,
    evaluatedModeSource: String?,
    failedChecks: [FailedCheck],
    timestamp: Date = Date()
  ) {
    self.id = id
    self.principal = principal
    self.projectId = projectId
    self.operation = operation
    self.module = module
    self.evaluatedModeSource = evaluatedModeSource
    self.failedChecks = failedChecks
    self.timestamp = timestamp
  }

  /// Summary message for display
  public var summaryMessage: String {
    if failedChecks.isEmpty {
      return "Governance violation"
    }
    let checkIds = failedChecks.map { $0.checkId }.joined(separator: ", ")
    return "Governance violation: \(checkIds)"
  }

  /// Human-readable message for error display
  public var humanReadableMessage: String {
    return summaryMessage
  }

  /// Metadata dictionary for audit logging (canonical format)
  public var auditMetadata: [String: String] {
    var metadata: [String: String] = [
      "violation_id": id.uuidString,
      "operation": operation,
      "failed_checks": failedChecks.map { $0.checkId }.joined(separator: ", "),
    ]

    if let projectId = projectId {
      metadata["project_id"] = projectId
    }

    if let module = module {
      metadata["module"] = module
    }

    if let modeSource = evaluatedModeSource {
      metadata["mode_source"] = modeSource
    }

    return metadata
  }
}

// MARK: - Evidence-Level Governance Decision

/// Governance decision record for evidence recording and audit trails.
/// Captures governance checks at evidence recording time (Tier 1 in runtime).
public struct GovernanceDecision: Sendable, Codable {
  public let allowed: Bool
  public let reason: String?
  public let checkResults: [String: Bool]  // checkId -> passed
  public let evaluatedAt: Date

  public init(
    allowed: Bool,
    reason: String? = nil,
    checkResults: [String: Bool] = [:],
    evaluatedAt: Date = Date()
  ) {
    self.allowed = allowed
    self.reason = reason
    self.checkResults = checkResults
    self.evaluatedAt = evaluatedAt
  }
}
