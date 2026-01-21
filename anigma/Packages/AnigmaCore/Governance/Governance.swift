//
//  Governance.swift
//  AnigmaCore
//
//  Core governance infrastructure for the Anigma platform.
//  Implements Kill Switch, Write Gate, Operating Modes, and Policy Enforcement.
//
//  This provides the "governed AI" capabilities described in the architecture:
//  - Policy-driven behavior via Playbooks
//  - Kill Switch for emergency halts
//  - Write Gate for quality checks before mutations
//  - Operating modes (read_only, assistive, autopilot)
//

import Foundation
import ContractsCore
import GovernanceCore

/// No-op audit logger for testing
public struct NoOpAuditLogger: AuditLogging {
    public init() {}

    public func recordEvent(
        id: UUID,
        type: ContractsCore.AuditEventType,
        principal: String?,
        module: String?,
        description: String,
        metadata: [String: String]
    ) async throws {
        // No-op implementation
    }
}

// MARK: - Operating Modes

/// Operating modes that control what AI agents can do.
public enum OperatingMode: String, Sendable, Codable {
    /// Agents can only read and analyze. No modifications allowed.
    case readOnly = "read_only"

    /// Agents can suggest changes but require human confirmation.
    case assistive = "assistive"

    /// Agents can execute changes autonomously (with governance checks).
    case autopilot = "autopilot"

    public var label: String {
        switch self {
        case .readOnly: return "Read Only"
        case .assistive: return "Assistive"
        case .autopilot: return "Autopilot"
        }
    }

    public var canWrite: Bool {
        self != .readOnly
    }

    public var requiresConfirmation: Bool {
        self == .assistive
    }
}

// MARK: - Built-in Write Checks

/// Check that the operating mode allows writes.
public struct OperatingModeCheck: WriteCheck {
    public let id = "operating-mode"
    public let name = "Operating Mode Check"
    public let isBlocking = true

    private let modeProvider: @Sendable () async -> OperatingMode

    public init(modeProvider: @escaping @Sendable () async -> OperatingMode) {
        self.modeProvider = modeProvider
    }

    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        true // Always applies
    }

    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        let mode = await modeProvider()

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

    private let killSwitch: KillSwitch

    public init(killSwitch: KillSwitch) {
        self.killSwitch = killSwitch
    }

    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        true // Always applies
    }

    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        let projectId = proposal.context["project_id"]
        let allowed = await killSwitch.isWriteAllowed(forProject: projectId)

        if allowed {
            return .pass(checkId: id, message: "Kill switch not active")
        } else {
            let status = await killSwitch.status()
            return .fail(
                checkId: id,
                message: "Kill switch active: \(status.activationReason ?? "unknown reason")"
            )
        }
    }
}

// MARK: - Governance Controller

/// Central governance controller that coordinates all governance mechanisms.
public actor GovernanceController {
    public let killSwitch: KillSwitch
    public let writeGate: WriteGate
    public let accessController: AccessController
    public let lifecycleManager: LifecycleManager
    public let auditLog: AuditLogging

    private var currentMode: OperatingMode = .assistive

    public init(
        auditLog: AuditLogging = NoOpAuditLogger(),
        accessController: AccessController = AccessController(),
        lifecycleManager: LifecycleManager = LifecycleManager()
    ) {
        self.auditLog = auditLog
        self.accessController = accessController
        self.lifecycleManager = lifecycleManager
        self.killSwitch = KillSwitch()
        self.writeGate = WriteGate()
    }

    /// Initializes governance with cross-wiring.
    public func initialize() async {
        // Wire up audit logging to all components
        await killSwitch.setAuditLog(auditLog)
        await writeGate.setAuditLog(auditLog)
        await accessController.setAuditLog(auditLog)
        await lifecycleManager.setAuditLog(auditLog)

        // Register built-in write checks
        await writeGate.registerCheck(KillSwitchCheck(killSwitch: killSwitch))
        await writeGate.registerCheck(OperatingModeCheck { [weak self] in
            await self?.getMode() ?? .readOnly
        })
    }

    /// Gets the current operating mode.
    public func getMode() -> OperatingMode {
        currentMode
    }

    /// Sets the operating mode.
    public func setMode(_ mode: OperatingMode, by principal: String) async {
        let oldMode = currentMode
        currentMode = mode

        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.configChange,
            principal: principal,
            module: "Governance",
            description: "Operating mode changed from \(oldMode.label) to \(mode.label)",
            metadata: ["oldMode": oldMode.label, "newMode": mode.label]
        )
    }

    /// Checks if a write operation is allowed through all governance checks.
    public func canWrite(_ proposal: WriteProposal) async -> WriteGateDecision {
        await writeGate.evaluate(proposal)
    }

    /// Records a human override of an AI decision.
    public func recordHumanOverride(
        principal: String,
        decision: String,
        context: [String: String]
    ) async {
        var metadata = context
        metadata["decision"] = decision

        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "Governance",
            description: "Human override: \(decision)",
            metadata: metadata.merging(["original_event_type": "humanOverride"]) { _, new in new }
        )
    }

    /// Gets a summary of governance status.
    public func status() async -> GovernanceStatus {
        let killSwitchStatus = await killSwitch.status()
        let policyCount = await accessController.listPolicies().count
        let retentionPolicies = await lifecycleManager.listPolicies().count

        return GovernanceStatus(
            operatingMode: currentMode,
            killSwitchActive: killSwitchStatus.isAnyActive,
            killSwitchReason: killSwitchStatus.activationReason,
            accessPolicyCount: policyCount,
            retentionPolicyCount: retentionPolicies
        )
    }
}

/// Summary of governance status.
public struct GovernanceStatus: Sendable {
    public let operatingMode: OperatingMode
    public let killSwitchActive: Bool
    public let killSwitchReason: String?
    public let accessPolicyCount: Int
    public let retentionPolicyCount: Int
}

// MARK: - Governance Errors

public enum GovernanceError: Error, LocalizedError, Sendable {
    case writeBlocked(reason: String)
    case modeNotAllowed(required: OperatingMode, current: OperatingMode)
    case killSwitchActive(reason: String)
    case confirmationRequired

    public var errorDescription: String? {
        switch self {
        case .writeBlocked(let reason):
            return "Write blocked: \(reason)"
        case .modeNotAllowed(let required, let current):
            return "Operation requires \(required.label) mode, but current mode is \(current.label)"
        case .killSwitchActive(let reason):
            return "Kill switch is active: \(reason)"
        case .confirmationRequired:
            return "Human confirmation required for this operation"
        }
    }
}
