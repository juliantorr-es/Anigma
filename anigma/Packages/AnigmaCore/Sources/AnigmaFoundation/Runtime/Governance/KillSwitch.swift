import AnigmaFoundation
import Foundation
import GovernanceContracts
import AnigmaPrimitives

/// The Kill Switch provides emergency halt capability.
/// When activated, all write operations are blocked.
/// This actor lives in Tier 2 (Platform Runtime) as it manages state.
public actor KillSwitch: RuntimeKillSwitchAPI {
    /// Global kill switch state.
    private var isGloballyActive: Bool = false

    /// Per-project kill switch states (projectId -> isActive).
    private var projectOverrides: [String: Bool] = [:]
    
    /// Per-project activation reasons (projectId -> reason).
    private var projectReasons: [String: String] = [:]

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

    /// Engage the kill switch (blocks writes).
    public func setKillSwitch(active: Bool, for projectId: String?, reason: String?, by principal: Principal) async throws {
        if active {
            if let pid = projectId, pid != "global" {
                await activate(reason: reason ?? "Manual activation", forProjectId: pid)
            } else {
                await activate(reason: reason ?? "Manual activation", by: principal.id)
            }
        } else {
            if let pid = projectId, pid != "global" {
                await deactivate(forProjectId: pid)
            } else {
                await deactivate(by: principal.id)
            }
        }
    }

    /// Show the kill switch status.
    public func showKillSwitch(for projectId: String?) async throws -> (active: Bool, reason: String?) {
        if isGloballyActive {
            return (true, activationReason)
        }
        if let projectId = projectId, projectOverrides[projectId] == true {
            return (true, projectReasons[projectId])
        }
        return (false, nil)
    }

    /// Gets the current status of the kill switch.
    public func killSwitchStatus() async -> (isActive: Bool, activationReason: String?) {
        return (isGloballyActive, activationReason)
    }

    /// Activates the kill switch for a project (or global if projectId is "global").
    public func activate(reason: String, forProjectId projectId: String) async {
        if projectId == "global" {
            await activate(reason: reason, by: "GovernanceController")
        } else {
            projectOverrides[projectId] = true
            projectReasons[projectId] = reason
            
            // Log to audit log via self (if needed) or rely on GovernanceController
        }
    }
    
    /// Deactivates the kill switch for a project (or global if projectId is "global").
    public func deactivate(forProjectId projectId: String) async {
        if projectId == "global" {
            await deactivate(by: "GovernanceController")
        } else {
            projectOverrides.removeValue(forKey: projectId)
            projectReasons.removeValue(forKey: projectId)
        }
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
    public func isWriteAllowed(forProject projectId: String? = nil) async -> Bool {
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
            projectOverrides: projectOverrides,
            projectReasons: projectReasons
        )
    }
}
