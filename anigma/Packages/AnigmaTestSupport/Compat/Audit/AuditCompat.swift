//
//  AuditCompat.swift
//  AnigmaTestSupport
//
//  [Brief description of file purpose]
//

import Foundation
import ContractsCore
import AnigmaCore

// MARK: - Legacy Event Types (Test-Only)

public enum LegacyAuditEventType: String, Sendable, CaseIterable {
  case accessGranted
  case accessDenied
  case dataCreated
  case dataRead
  case dataModified
  case policyViolation
  case automationExecuted

  public func toRuntime() -> AuditEventType {
    switch self {
    case .accessGranted:
      return .accessGranted
    case .accessDenied:
      return .accessDenied
    case .dataCreated:
      return .dataCreated
    case .dataRead:
      return .dataRead
    case .dataModified:
      return .dataModified
    case .policyViolation:
      return .policyViolation
    case .automationExecuted:
      return .automationExecuted
    }
  }

  public var label: String { rawValue }
}

// MARK: - Legacy Audit Entry View

public struct AuditEntryView: Sendable {
  public let timestamp: Date
  public let eventTypeString: String
  public let principalString: String
  public let moduleString: String
  public let metadata: [String: String]

  init(_ entry: AuditEntry) {
    self.timestamp = entry.timestamp
    self.eventTypeString = entry.metadata?["legacy_event_type"]
      ?? entry.operation
    self.principalString = entry.command ?? ""
    self.moduleString = entry.engineId
    self.metadata = entry.metadata ?? [:]
  }
}

public struct LegacyAuditingResult: Sendable {
  public let totalEntries: Int
  public let verifiedEntries: Int
  public let issues: [String]
  public let isValid: Bool
}

public struct LegacyComplianceReport: Sendable {
  public let totalEvents: Int
  public let accessGranted: Int
  public let accessDenied: Int
  public let sensitiveDataAccess: Int
  public let policyViolations: Int
struct RecordLegacyConfiguration: Sendable {
    let eventType: String
    let principal: String
    let module: String
    let entityId: EntityId?
    let componentType: String?
    let sensitivity: LifecycleSensitivity?
    let description: String
    let metadata: [String: String]
    
    init(
        eventType: String,
        principal: String,
        module: String,
        entityId: EntityId? = nil,
        componentType: String? = nil,
        sensitivity: LifecycleSensitivity? = nil,
        description: String,
        metadata: [String: String] = [:]
    ) {
        self.eventType = eventType
        self.principal = principal
        self.module = module
        self.entityId = entityId
        self.componentType = componentType
        self.sensitivity = sensitivity
        self.description = description
        self.metadata = metadata
    }
}

// Updated function signature:
func recordLegacy(config: RecordLegacyConfiguration) async throws {
    var envelope = config.metadata
    if let entityId = config.entityId {
        envelope["entity_id"] = entityId.raw.uuidString
    }
    if let componentType = config.componentType {
        // ... rest of the function implementation
    }
    // ... rest of the function
}
      envelope["component_type"] = componentType
    }
    if let sensitivity {
      envelope["sensitivity"] = sensitivity.rawValue
    }
    envelope["legacy_event_type"] = eventType.label

    try await recordEvent(
      id: UUID(),
      type: eventType.toRuntime(),
      principal: principal,
      module: module,
      description: description,
      metadata: envelope
    )
  }

  func legacyCount() async throws -> Int {
    return await entryCount()
  }

  func legacyVerifyIntegrity() async throws -> LegacyAuditingResult {
    let isValid = await verifyChain()
    let entries = try await recent(count: 100)
    return LegacyAuditingResult(
      totalEntries: entries.count,
      verifiedEntries: entries.count,
      issues: isValid ? [] : ["chain integrity failed"],
      isValid: isValid
    )
  }

  func legacyEntries(count: Int = 10) async throws -> [AuditEntryView] {
    let entries = try await recent(count: count)
    return entries.map(AuditEntryView.init)
  }

  func legacyComplianceReport() async throws -> LegacyComplianceReport {
    let entries = try await recent(count: 100)
    var accessGranted = 0
    var accessDenied = 0
    var sensitiveCount = 0
    var policyViolations = 0
    var dataModifications = 0

    for entry in entries {
      let legacyType = entry.metadata?["legacy_event_type"] ?? entry.operation
      switch legacyType {
      case LegacyAuditEventType.accessGranted.rawValue:
        accessGranted += 1
      case LegacyAuditEventType.accessDenied.rawValue:
        accessDenied += 1
      case LegacyAuditEventType.policyViolation.rawValue:
        policyViolations += 1
      case LegacyAuditEventType.dataModified.rawValue:
        dataModifications += 1
      case LegacyAuditEventType.dataCreated.rawValue, LegacyAuditEventType.dataRead.rawValue:
        break
      default:
        break
      }

      if entry.metadata?["sensitivity"] == LifecycleSensitivity.sensitive.rawValue {
        sensitiveCount += 1
      }
    }

    return LegacyComplianceReport(
      totalEvents: entries.count,
      accessGranted: accessGranted,
      accessDenied: accessDenied,
      sensitiveDataAccess: sensitiveCount,
      policyViolations: policyViolations,
      dataModifications: dataModifications
    )
  }
}
