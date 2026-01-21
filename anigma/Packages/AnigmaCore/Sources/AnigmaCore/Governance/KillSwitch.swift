import Foundation
import ContractsCore
import AnigmaPrimitives
import GovernanceCore

/// The Kill Switch provides emergency halt capability.
/// When activated, all write operations are blocked.
/// This actor lives in Tier 2 (Platform Runtime) as it manages state.
public actor KillSwitch {
    /// Global kill switch state.
    private var isGloballyActive: Bool = false

    /// Per-project kill switch states.
    private var projectOverrides: [String: Bool] = [:]

    /// Reason for activation (if any).
    private var activationReason: String?

    /// When the kill switch was activated.
    private var activatedAt: Date?

    /// Who activated the kill switch.
    private var activatedBy: String?

    /// Audit log for recording kill switch events.
    private var auditLog: AuditLogging?

    public init() {}

    /// Sets the audit log for kill switch events.
    public func setAuditLog(_ log: AuditLogging) {
        self.auditLog = log
    }

    /// Activates the global kill switch.
    public func activate(reason: String, by principal: String) async {
        isGloballyActive = true
        activationReason = reason
        activatedAt = Date()
        activatedBy = principal

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: .custom,
                principal: principal,
                module: "Governance",
                description: "Kill switch activated: \(reason)",
                metadata: ["original_event_type": "killSwitchActivated"]
            )
        }
    }

    /// Deactivates the global kill switch.
    public func deactivate(by principal: String) async {
        let wasActive = isGloballyActive
        isGloballyActive = false
        activationReason = nil
        activatedAt = nil
        activatedBy = nil

        if wasActive, let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: .custom,
                principal: principal,
                module: "Governance",
                description: "Kill switch deactivated",
                metadata: ["original_event_type": "killSwitchDeactivated"]
            )
        }
    }

    /// Activates kill switch for a specific project.
    public func activateForProject(_ projectId: String, by principal: String) async {
        projectOverrides[projectId] = true

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: .custom,
                principal: principal,
                module: "Governance",
                description: "Kill switch activated for project: \(projectId)",
                metadata: ["projectId": projectId, "original_event_type": "killSwitchActivated"]
            )
        }
    }

    /// Deactivates kill switch for a specific project.
    public func deactivateForProject(_ projectId: String, by principal: String) async {
        projectOverrides.removeValue(forKey: projectId)

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: .custom,
                principal: principal,
                module: "Governance",
                description: "Kill switch deactivated for project: \(projectId)",
                metadata: ["projectId": projectId, "original_event_type": "killSwitchDeactivated"]
            )
        }
    }

    /// Checks if writes are allowed (not blocked by kill switch).
    public func isWriteAllowed(forProject projectId: String? = nil) -> Bool {
        if isGloballyActive {
            return false
        }
        if let projectId = projectId, projectOverrides[projectId] == true {
            return false
        }
        return true
    }

    /// Gets the current status.
    public func status() -> KillSwitchStatus {
        KillSwitchStatus(
            isGloballyActive: isGloballyActive,
            activationReason: activationReason,
            activatedAt: activatedAt,
            activatedBy: activatedBy,
            projectOverrides: projectOverrides
        )
    }
}
