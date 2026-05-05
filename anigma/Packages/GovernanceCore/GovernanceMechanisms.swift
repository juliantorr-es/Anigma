import AnigmaPrimitives
import Foundation
import FoundationContracts
import GovernanceContracts

// MARK: - Typealiases for extracted contract types

// These types have been moved to GovernanceContracts (Tier 1)
// KillSwitchStatus and GovernanceDecision moved to WriteGateContracts.swift
public typealias KillSwitchStatus = GovernanceContracts.KillSwitchStatus
public typealias GovernanceDecision = GovernanceContracts.GovernanceDecision

// Write gate types moved to WriteGateContracts.swift
public typealias WriteProposal = GovernanceContracts.WriteProposal
public typealias WriteCheck = GovernanceContracts.WriteCheck
public typealias WriteCheckResult = GovernanceContracts.WriteCheckResult
public typealias WriteGateDecision = GovernanceContracts.WriteGateDecision

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


