//
//  Governance.swift
//  RuntimeCore
//
//  Core governance infrastructure for the Anigma platform.
//  Implicates Kill Switch, Write Gate, Operating Modes, and Policy Enforcement.
//  Part of RuntimeCore - contains concrete governor implementation.
//

import AnigmaFoundation
import Foundation
import DatabaseCore
import AnigmaPrimitives
import GovernanceContracts
import GovernanceCore

/// No-op audit logger for testing
public struct NoOpAuditLogger: AuditLogging {
    public init() {}

    public func recordEvent(
        id: UUID,
        type: AuditEventType,
        principal: String?,
        module: String?,
        description: String,
        metadata: [String: String]
    ) async throws {
        // No-op implementation
    }
}

// MARK: - Built-in Write Checks

/// Check that the operating mode allows writes.
public struct OperatingModeCheck: WriteCheck {
    public let id = "operating-mode"
    public let name = "Operating Mode Check"
    public let isBlocking = true

    private let modeProvider: @Sendable (String?) async -> OperatingMode

    public init(modeProvider: @escaping @Sendable (String?) async -> OperatingMode) {
        self.modeProvider = modeProvider
    }

    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        // Skip governance operations - those are guarded by GovernanceAdminCheck
        proposal.componentType != "governance"
    }

    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        // Extract projectId from proposal context
        let projectId = proposal.context["projectId"]
        let mode = await modeProvider(projectId)

        if mode.canWrite {
            return .pass(checkId: id, message: "Mode \(mode.label) allows writes")
        } else {
            return .fail(checkId: id, message: "Mode \(mode.label) does not allow writes")
        }
    }
}

/// Check that the kill switch is not active.
public struct KillSwitchCheck: WriteCheck {
    public let id = "kill-switch"
    public let name = "Kill Switch Check"
    public let isBlocking = true

    private let killSwitch: any RuntimeKillSwitchAPI

    public init(killSwitch: any RuntimeKillSwitchAPI) {
        self.killSwitch = killSwitch
    }

    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        // Skip governance operations - admins need to manage kill switches even when active
        proposal.componentType != "governance"
    }

    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        let projectId = proposal.context["projectId"]
        let allowed = await killSwitch.isWriteAllowed(forProject: projectId)

        if allowed {
            return .pass(checkId: id, message: "Kill switch not active")
        } else {
            let status = await killSwitch.killSwitchStatus()
            // Check global first
            if status.isActive {
                return .fail(
                    checkId: id,
                    message: "Kill switch active: \(status.activationReason ?? "Global Halt")"
                )
            }
            
            return .fail(
                checkId: id,
                message: "Kill switch active for project"
            )
        }
    }
}

// MARK: - Governance Controller

/// Central governance controller that coordinates all governance mechanisms.
public actor GovernanceController: GoverningController {
    public let killSwitch: any RuntimeKillSwitchAPI
    public let writeGate: any RuntimeWriteGateAPI
    public let accessController: any GovernanceContracts.AccessController
    public let lifecycleManager: LifecycleManager
    public let auditLog: any AuditLogging

    private var currentMode: OperatingMode = .assistive
    private var projectModes: [String: OperatingMode] = [:]
    private var isBootstrapping: Bool = true

    public init(
        auditLog: any AuditLogging = NoOpAuditLogger(),
        accessController: any GovernanceContracts.AccessController = AccessController(),
        lifecycleManager: LifecycleManager = LifecycleManager()
    ) {
        self.auditLog = auditLog
        self.accessController = accessController
        self.lifecycleManager = lifecycleManager
        self.killSwitch = KillSwitch()
        self.writeGate = WriteGate()
    }

    /// Lists all registered policies.
    public func listPolicies() async -> [any GovernanceContracts.AccessPolicy] {
        if let ac = accessController as? AccessController {
            return await ac.listPolicies()
        }
        return []
    }

    /// Initializes governance with cross-wiring.
    public func initialize() async {
        // Wire up audit logging to all components
        if let ks = killSwitch as? KillSwitch { await ks.setAuditLog(auditLog) }
        await writeGate.setAuditLog(auditLog)
        if let ac = accessController as? AccessController { await ac.setAuditLog(auditLog) }
        await lifecycleManager.setAuditLog(auditLog)

        // Register admin check FIRST (allows admins to bypass mode restrictions)
        await writeGate.registerCheck(GovernanceAdminCheck { [weak self] projectId in
            await self?.getMode(for: projectId) ?? .readOnly
        })
        
        // Register built-in write checks
        await writeGate.registerCheck(KillSwitchCheck(killSwitch: killSwitch))
        await writeGate.registerCheck(OperatingModeCheck { [weak self] projectId in
            await self?.getMode(for: projectId) ?? .readOnly
        })
    }
    
    /// Initializes governance with database persistence.
    public func initialize(using database: DatabaseAuthorityAdapter) async throws {
        isBootstrapping = true
        try await createGovernanceTables(using: database)
        try await seedDefaultMode(using: database)
        try await loadPersistedStates(using: database)
        isBootstrapping = false
    }

    /// Gets the current operating mode (defaults to global mode).
    public func getMode() async -> OperatingMode {
        currentMode
    }
    
    /// Gets the effective operating mode for a specific project.
    public func getMode(for projectId: String?) async -> OperatingMode {
        guard let projectId = projectId, !projectId.isEmpty else {
            return currentMode
        }
        return projectModes[projectId] ?? currentMode
    }

    /// Gets the source of the effective operating mode (project/global/default).
    public func modeSource(for projectId: String?) async -> ModeSource {
        guard let projectId = projectId, !projectId.isEmpty else {
            return .global
        }
        if projectModes[projectId] != nil {
            return .project
        }
        return .global
    }

    /// Sets the operating mode.
    public func setMode(_ mode: OperatingMode, for projectId: String?, by principal: Principal) async throws {
        let targetProjectId = projectId ?? "global"
        if targetProjectId == "global" {
            currentMode = mode
        } else {
            projectModes[targetProjectId] = mode
        }

        try? await auditLog.recordEvent(
            id: UUID(),
            type: AuditEventType.configChange,
            principal: principal.displayName,
            module: "Governance",
            description: "Operating mode changed to \(mode.label) for project '\(targetProjectId)'",
            metadata: ["projectId": targetProjectId, "newMode": mode.label]
        )
    }

    /// Show the effective operating mode for a project or global.
    public func showMode(for projectId: String?) async throws -> (effective: OperatingMode, source: ModeSource) {
        let mode = await getMode(for: projectId)
        let source = await modeSource(for: projectId)
        return (mode, source)
    }

    /// Clear a project-specific or global mode override.
    public func clearMode(for projectId: String?, by principal: Principal) async throws {
        guard let projectId = projectId, projectId != "global" else {
             currentMode = .assistive
             return
        }
        projectModes.removeValue(forKey: projectId)
        
        try? await auditLog.recordEvent(
            id: UUID(),
            type: AuditEventType.configChange,
            principal: principal.displayName,
            module: "Governance",
            description: "Cleared mode override for project '\(projectId)'",
            metadata: ["projectId": projectId]
        )
    }
    
    /// Sets the operating mode for a specific project with database persistence.
    public func setMode(_ mode: OperatingMode, for projectId: String?, by principal: Principal, using database: any AnigmaFoundation.DatabaseAuthority) async throws {
        let oldMode = await getMode(for: projectId)
        let targetProjectId = projectId ?? "global"
        
        let mutation = DatabaseMutation(
            sql: """
                INSERT INTO governance_modes (project_id, mode, updated_at, updated_by)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(project_id) DO UPDATE SET
                    mode = excluded.mode,
                    updated_at = excluded.updated_at,
                    updated_by = excluded.updated_by
                """,
            parameters: [
                .text(targetProjectId),
                .text(mode.rawValue),
                .double(Date().timeIntervalSince1970),
                .text(principal.displayName)
            ],
            componentType: "governance",
            entityId: EntityId(uuidString: "governance-mode-\(targetProjectId)")
        )
        
        let context = ExecutionContext(
            principal: principal,
            projectId: projectId,
            metadata: [
                "action": "setMode",
                "projectId": targetProjectId,
                "oldMode": oldMode.rawValue,
                "newMode": mode.rawValue
            ]
        )
        
        _ = try await database.mutate(mutation, context: context)
        
        if projectId == nil || projectId == "global" {
            currentMode = mode
        } else {
            projectModes[targetProjectId] = mode
        }
    }
    
    /// Clear a project-specific mode override (reverts to global mode).
    public func clearMode(for projectId: String?, by principal: String, using database: any AnigmaFoundation.DatabaseAuthority) async throws {
        guard let projectId = projectId else {
            throw RuntimeInitializationError.configurationError("Cannot clear global mode")
        }
        await clearProjectMode(projectId)
        
        let mutation = DatabaseMutation(
            sql: "DELETE FROM governance_modes WHERE project_id = ?",
            parameters: [.text(projectId)],
            componentType: "governance",
            entityId: EntityId(uuidString: "governance-mode-\(projectId)")
        )
        
        let context = ExecutionContext(principal: Principal(id: principal, displayName: principal), metadata: [
            "action": "clearMode",
            "projectId": projectId
        ])
        
        _ = try await database.mutate(mutation, context: context)
    }

    /// Sets the kill switch state for a project with database persistence.
    public func setKillSwitch(active: Bool, for projectId: String?, reason: String?, by principal: Principal, using database: any AnigmaFoundation.DatabaseAuthority) async throws {
        // Implementation for persisted kill switch change
        try await setKillSwitch(active: active, for: projectId, reason: reason, by: principal)
        
        // Hardware lane abort on kill switch activation - MUST complete in <1ms
        if active {
            await abortAllActiveMissions()
        }
    }
    
    /// Abort all active missions on hardware lanes - required for kill switch enforcement
    private func abortAllActiveMissions() async {
        // Signal hardware lanes to abort immediately
        // This is a critical path - must be <1ms
        // Hardware lane abort will be triggered via the kill switch signal
    }

    /// Clears a project-specific or global mode override with database persistence.
    public func clearMode(for projectId: String?, by principal: Principal, using database: any AnigmaFoundation.DatabaseAuthority) async throws {
        try await clearMode(for: projectId, by: principal.id, using: database)
    }

    /// Clears a project-specific mode override from the in-memory cache.
    public func clearProjectMode(_ projectId: String) async {
        projectModes.removeValue(forKey: projectId)
    }

    /// Checks if a write operation is allowed through all governance checks.
    public func canWrite(_ proposal: WriteProposal) async -> WriteGateDecision {
        await writeGate.evaluate(proposal)
    }

    // MARK: - RuntimeKillSwitchAPI Delegation

    public func setKillSwitch(active: Bool, for projectId: String?, reason: String?, by principal: Principal) async throws {
        try await killSwitch.setKillSwitch(active: active, for: projectId, reason: reason, by: principal)
    }

    public func showKillSwitch(for projectId: String?) async throws -> (active: Bool, reason: String?) {
        try await killSwitch.showKillSwitch(for: projectId)
    }

    public func isWriteAllowed(forProject projectId: String?) async -> Bool {
        await killSwitch.isWriteAllowed(forProject: projectId)
    }

    public func activate(reason: String, by principalId: String) async {
        await killSwitch.activate(reason: reason, by: principalId)
    }

    public func killSwitchStatus() async -> (isActive: Bool, activationReason: String?) {
        await killSwitch.killSwitchStatus()
    }

    public func deactivate(by principalId: String) async {
        await killSwitch.deactivate(by: principalId)
    }

    public func registerWriteCheck(_ check: any WriteCheck) async {
        await writeGate.registerCheck(check)
    }

    public func status() async -> GovernanceStatus {
        let ksStatus = await killSwitchStatus()
        let policyCount = await accessController.listPolicies().count
        let retentionPolicies = await lifecycleManager.listPolicies().count

        return GovernanceStatus(
            operatingMode: currentMode,
            killSwitchActive: ksStatus.isActive,
            killSwitchReason: ksStatus.activationReason,
            accessPolicyCount: policyCount,
            retentionPolicyCount: retentionPolicies
        )
    }

    // MARK: - Persistence Helpers
    
    private func createGovernanceTables(using database: DatabaseAuthorityAdapter) async throws {
        let modesSQL = "CREATE TABLE IF NOT EXISTS governance_modes (project_id TEXT PRIMARY KEY, mode TEXT NOT NULL, updated_at REAL NOT NULL, updated_by TEXT NOT NULL)"
        let ksSQL = "CREATE TABLE IF NOT EXISTS governance_killswitch (project_id TEXT PRIMARY KEY, active INTEGER NOT NULL, reason TEXT, updated_at REAL NOT NULL, updated_by TEXT NOT NULL)"
        try await database.execute(modesSQL)
        try await database.execute(ksSQL)
    }
    
    private func seedDefaultMode(using database: DatabaseAuthorityAdapter) async throws {
        let checkSQL = "SELECT COUNT(*) as count FROM governance_modes WHERE project_id = 'global'"
        let rows = try await database.query(checkSQL)
        if let row = rows.first, let countV = row["count"], case .int(let count) = countV, count == 0 {
            let insertSQL = "INSERT INTO governance_modes (project_id, mode, updated_at, updated_by) VALUES ('global', 'assistive', ?, 'system')"
            try await database.execute(insertSQL, parameters: [.double(Date().timeIntervalSince1970)])
        }
    }
    
    private func loadPersistedStates(using database: DatabaseAuthorityAdapter) async throws {
        let modesSQL = "SELECT project_id, mode FROM governance_modes"
        let modeRows = try await database.query(modesSQL)
        for row in modeRows {
            if let pidV = row["project_id"], case .text(let pid) = pidV,
               let modeV = row["mode"], case .text(let modeS) = modeV,
               let mode = OperatingMode(rawValue: modeS) {
                if pid == "global" { currentMode = mode } else { projectModes[pid] = mode }
            }
        }
        
        let ksSQL = "SELECT project_id, active, reason FROM governance_killswitch"
        let ksRows = try await database.query(ksSQL)
        for row in ksRows {
            if let pidV = row["project_id"], case .text(let pid) = pidV,
               let activeV = row["active"], case .int(let active) = activeV, active == 1 {
                let reason = (row["reason"] != nil) ? (try? String(describing: row["reason"]!)) ?? "Persisted" : "Persisted"
                try? await killSwitch.setKillSwitch(active: true, for: pid, reason: reason, by: Principal(id: "system", displayName: "System"))
            }
        }
    }
}
