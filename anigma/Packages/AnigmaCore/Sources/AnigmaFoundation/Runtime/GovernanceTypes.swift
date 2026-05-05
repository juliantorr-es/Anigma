//
//  GovernanceTypes.swift
//  RuntimeCore
//
//  Runtime governance types.
//  Portable contract types have been extracted to GovernanceContracts.
//  This file now contains typealiases pointers to the contract versions
//  and runtime-specific protocols/types that depend on implementation details.
//

import Foundation
import AnigmaPrimitives
import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts
import GovernanceCore
import DatabaseCore

// MARK: - Typealiases for extracted contract types

// Mode types
public typealias ModeSource = GovernanceContracts.ModeSource
public typealias OperatingMode = GovernanceContracts.OperatingMode
public typealias OperatingModeRaw = GovernanceContracts.OperatingModeRaw

// Governance status
public typealias GovernanceStatus = GovernanceContracts.GovernanceStatus

// Access control types
public typealias DataSensitivity = GovernanceContracts.DataSensitivity
public typealias AccessType = GovernanceContracts.AccessType
public typealias AccessPrincipal = GovernanceContracts.AccessPrincipal
public typealias AccessRequest = GovernanceContracts.AccessRequest
public typealias AccessDecision = GovernanceContracts.AccessDecision
public typealias AccessController = GovernanceContracts.AccessController
public typealias AccessPolicy = GovernanceContracts.AccessPolicy

// Write gate types
public typealias WriteCheck = GovernanceContracts.WriteCheck
public typealias WriteProposal = GovernanceContracts.WriteProposal
public typealias WriteCheckResult = GovernanceContracts.WriteCheckResult
public typealias WriteGateDecision = GovernanceContracts.WriteGateDecision

// Kill switch types
public typealias KillSwitchStatus = GovernanceContracts.KillSwitchStatus

// Runtime API protocols (typealiased from contracts)
public typealias RuntimeGovernanceAPI = GovernanceContracts.RuntimeGovernanceAPI
public typealias RuntimeWriteGateAPI = GovernanceContracts.RuntimeWriteGateAPI
public typealias RuntimeKillSwitchAPI = GovernanceContracts.RuntimeKillSwitchAPI

// MARK: - Governance Errors

/// Governance errors with runtime-specific details.
/// Note: GovernanceViolation is defined in GovernanceCore, not contracts.
public enum GovernanceError: Error, LocalizedError, Sendable {
    case writeBlocked(violation: GovernanceCore.GovernanceViolation)
    case modeNotAllowed(required: OperatingMode, current: OperatingMode)
    case killSwitchActive(reason: String)
    case confirmationRequired

    public var errorDescription: String? {
        switch self {
        case .writeBlocked(let violation):
            return "Write blocked: \(violation.summaryMessage)"
        case .modeNotAllowed(let required, let current):
            return "Operation requires \(required.label) mode, but current mode is \(current.label)"
        case .killSwitchActive(let reason):
            return "Kill switch is active: \(reason)"
        case .confirmationRequired:
            return "Human confirmation required for this operation"
        }
    }
}

// MARK: - Governance Controller Protocol

/// Protocol defining the interface for a Governance Controller.
/// This allows PlatformRuntime to refer to it without depending on the concrete implementation.
public protocol GoverningController: RuntimeGovernanceAPI, RuntimeKillSwitchAPI, Sendable {
    /// The Write Gate for pre-mutation checks.
    var writeGate: any RuntimeWriteGateAPI { get }

    /// Initializes basic governance components.
    func initialize() async

    /// Initializes governance with database persistence.
    func initialize(using database: any DatabaseAuthority) async throws

    /// Gets a summary of governance status.
    func status() async -> GovernanceStatus

    /// Gets current operating mode.
    func getMode() async -> OperatingMode

    /// Gets operating mode for a project.
    func getMode(for projectId: String?) async -> OperatingMode

    /// Checks if a write operation is allowed.
    func canWrite(_ proposal: WriteProposal) async -> WriteGateDecision

    /// Registers a new write check.
    func registerWriteCheck(_ check: any WriteCheck) async

    /// Gets the audit log.
    var auditLog: any AuditLogging { get async }

    /// Gets the kill switch management interface.
    var killSwitch: any RuntimeKillSwitchAPI { get async }

    /// Gets the access controller.
    var accessController: any AccessController { get async }

    /// Gets the current mode source for a project.
    func modeSource(for projectId: String?) async -> ModeSource

    // MARK: - PlatformRuntime Extensions

    /// Sets the operating mode for a project with database persistence.
    func setMode(_ mode: OperatingMode, for projectId: String?, by principal: Principal, using database: any DatabaseAuthority) async throws

    /// Sets the kill switch state for a project with database persistence.
    func setKillSwitch(active: Bool, for projectId: String?, reason: String?, by principal: Principal, using database: any DatabaseAuthority) async throws

    /// Clears a project-specific or global mode override with database persistence.
    func clearMode(for projectId: String?, by principalId: String, using database: any DatabaseAuthority) async throws

    /// Clears a project-specific mode override from cache.
    func clearProjectMode(_ projectId: String) async
}
