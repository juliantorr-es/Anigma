import AnigmaPrimitives
import Foundation
import FoundationContracts

// MARK: - Core Domain Types

/// Security zones for execution isolation
public enum SecurityZone: String, Sendable, Codable, CaseIterable {
  case sandbox = "sandbox"
  case restricted = "restricted"
  case standard = "standard"
  case privileged = "privileged"
  case system = "system"
  case selfHost = "self_host"
  case inspiration = "inspiration"
  case externalServices = "external_services"
  case untrusted = "untrusted"
}

// MARK: - Protocol Ports

/// Types of audit events
public enum AuditEventType: String, Sendable, Codable, CaseIterable {
  case custom = "custom"  // For events not fitting specific categories

  // Access control
  case accessGranted = "access_granted"
  case accessDenied = "access_denied"

  // Policy & Governance
  case policyViolation = "policy_violation"
  case policyEvaluated = "policy_evaluated"
  case configChange = "config_change"
  case trustChange = "trust_change"

  // Automation & Reasoning
  case automationTriggered = "automation_triggered"
  case automationExecuted = "automation_executed"
  case automationFailed = "automation_failed"

  // Data Lifecycle
  case dataAccessed = "data_accessed"
  case dataCreated = "data_created"
  case dataRead = "data_read"
  case dataModified = "data_modified"
  case dataDeleted = "data_deleted"
  case dataExported = "data_exported"
  case dataImported = "data_imported"

  // Security
  case threatDetected = "threat_detected"
  case enforcementAction = "enforcement_action"
  case vulnerabilityReported = "vulnerability_reported"
  case userDeprovisioned = "user_deprovisioned"
  case securityHardening = "security_hardening"

  // Updates
  case updateAnnounced = "update_announced"
  case updateDrainStarted = "update_drain_started"
  case updateBlocked = "update_blocked"
  case updateCompleted = "update_completed"
  case updateRolledBack = "update_rolled_back"
  case migrationExecuted = "migration_executed"
  case migrationFailed = "migration_failed"
  case clientVersionBlocked = "client_version_blocked"
  case cohortRolloutChanged = "cohort_rollout_changed"
}

/// Protocol for audit logging - minimal boundary interface
public protocol AuditLogging: Sendable {
  func recordEvent(
    id: UUID,
    type: AuditEventType,
    principal: String?,
    module: String?,
    description: String,
    metadata: [String: String]
  ) async throws
}

extension AuditLogging {
  public func record(
    eventType: AuditEventType,
    principal: String?,
    module: String?,
    description: String,
    metadata: [String: String]
  ) async throws {
    // Map to recordEvent
    try await recordEvent(
      id: UUID(),  // Generate a new ID for each record call
      type: eventType,  // Use rawValue of AuditEventType as the string type
      principal: principal,
      module: module,
      description: description,
      metadata: metadata
    )
  }

  public func getChainHead() async -> String? {
    return nil
  }

  public func entryCount() async -> Int {
    return 0
  }

  public func verifyChain() async -> Bool {
    return true
  }
}

/// Content value kinds for trace redaction
public enum TraceValueKind: String, Sendable, Codable {
    case hash = "hash"           // Content hash only
    case pointer = "pointer"     // Reference to stored content
    case preview = "preview"     // Redacted preview
    case literal = "literal"     // Full content (policy-gated)
}

/// Protocol for trace content policy
public protocol TraceContentPolicy: Sendable {
  func allowedValueKind(for zone: SecurityZone, tier: TrustTier) -> TraceValueKind
  func shouldRedact(content: String, in zone: SecurityZone) -> Bool
}
