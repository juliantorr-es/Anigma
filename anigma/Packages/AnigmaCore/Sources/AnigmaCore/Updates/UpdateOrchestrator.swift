//
//  UpdateOrchestrator.swift
//  AnigmaCore
//
//  AnigmaCore - Update Orchestration
//
//  Controls rollout phases, drain modes, and version enforcement.
//  Uses Governance + WriteGate machinery for consistent policy enforcement.
//

import Foundation

// MARK: - Update Phase

/// Current update phase
public enum UpdatePhase: String, Sendable, Codable {
    case stable           // Normal operations, no pending updates
    case announced        // Update available, normal operations continue
    case draining         // Grace period, finishing work, no new heavy operations
    case blocked          // Update required, only sync/checkpoint allowed
    case maintenance      // System in maintenance for migration
    case deploying        // Actively deploying new version
    case verifying        // Post-deployment verification
}

// MARK: - Update Event

/// Events during update lifecycle
public struct UpdateEvent: Sendable, Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: UpdateEventType
    public let fromVersion: SemanticVersion?
    public let toVersion: SemanticVersion?
    public let phase: UpdatePhase
    public let details: String
    public let affectedClients: Int

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: UpdateEventType,
        fromVersion: SemanticVersion? = nil,
        toVersion: SemanticVersion? = nil,
        phase: UpdatePhase,
        details: String = "",
        affectedClients: Int = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.phase = phase
        self.details = details
        self.affectedClients = affectedClients
    }
}

/// Update event types
public enum UpdateEventType: String, Sendable, Codable {
    case releaseAnnounced
    case drainModeStarted
    case drainModeEnded
    case clientBlocked
    case clientUpdated
    case maintenanceStarted
    case maintenanceEnded
    case migrationStarted
    case migrationCompleted
    case migrationFailed
    case rollbackInitiated
    case rollbackCompleted
    case deploymentCompleted
    case verificationPassed
    case verificationFailed
}

// MARK: - Operation Checkpoint Profile

/// Defines what operations are safe during updates
public enum CheckpointProfile: String, Sendable, Codable {
    case hard       // Block immediately during any update phase
    case soft       // Allow during drain, block during maintenance
    case checkpoint // Allow finish, save drafts, but no new work
    case readonly   // Always allowed, read-only operations

    /// Check if operation is allowed in given phase
    public func isAllowed(in phase: UpdatePhase) -> Bool {
        switch self {
        case .readonly:
            return true
        case .checkpoint:
            return phase != .maintenance && phase != .deploying
        case .soft:
            return phase == .stable || phase == .announced || phase == .draining
        case .hard:
            return phase == .stable || phase == .announced
        }
    }
}

// MARK: - Update Decision

/// Decision about whether an operation can proceed
public struct UpdateDecision: Sendable {
    public let allowed: Bool
    public let reason: String
    public let phase: UpdatePhase
    public let clientStatus: ClientUpdateStatus
    public let timeUntilBlocked: TimeInterval?
    public let requiredAction: RequiredAction?

    public init(
        allowed: Bool,
        reason: String,
        phase: UpdatePhase,
        clientStatus: ClientUpdateStatus,
        timeUntilBlocked: TimeInterval? = nil,
        requiredAction: RequiredAction? = nil
    ) {
        self.allowed = allowed
        self.reason = reason
        self.phase = phase
        self.clientStatus = clientStatus
        self.timeUntilBlocked = timeUntilBlocked
        self.requiredAction = requiredAction
    }

    public static func allow(phase: UpdatePhase, status: ClientUpdateStatus) -> UpdateDecision {
        return UpdateDecision(allowed: true, reason: "Operation permitted", phase: phase, clientStatus: status)
    }

    public static func deny(reason: String, phase: UpdatePhase, status: ClientUpdateStatus, requiredAction: RequiredAction? = nil) -> UpdateDecision {
        return UpdateDecision(allowed: false, reason: reason, phase: phase, clientStatus: status, requiredAction: requiredAction)
    }
}

/// Required action when operation is denied
public enum RequiredAction: String, Sendable, Codable {
    case updateClient       // Must update to newer version
    case finishAndSave      // Complete current work and save
    case waitForMaintenance // Wait until maintenance completes
    case contactAdmin       // Contact administrator
}

// MARK: - Update Orchestrator

/// Coordinates update rollout, drain modes, and version enforcement
public actor UpdateOrchestrator {
    // State
    private var currentPhase: UpdatePhase = .stable
    private var platformVersion: PlatformVersion
    private var activePolicy: VersionPolicy?
    private var pendingRelease: ReleaseManifest?
    private var clientStates: [UUID: ClientVersionState] = [:]
    private var updateEvents: [UpdateEvent] = []

    // Configuration
    private let environment: DeploymentEnvironment
    private let autoEnforceDrain: Bool

    public init(
        platformVersion: PlatformVersion,
        environment: DeploymentEnvironment = .development,
        autoEnforceDrain: Bool = true
    ) {
        self.platformVersion = platformVersion
        self.environment = environment
        self.autoEnforceDrain = autoEnforceDrain
    }

    // MARK: - Phase Management

    /// Get current update phase
    public func getPhase() -> UpdatePhase {
        return currentPhase
    }

    /// Get platform version
    public func getPlatformVersion() -> PlatformVersion {
        return platformVersion
    }

    /// Announce a new release
    public func announceRelease(_ manifest: ReleaseManifest) -> UpdateEvent {
        pendingRelease = manifest

        // Determine initial phase based on flags
        if manifest.flags.emergencyHotfix {
            currentPhase = .draining
        } else {
            currentPhase = .announced
        }

        let event = UpdateEvent(
            eventType: .releaseAnnounced,
            fromVersion: platformVersion.current,
            toVersion: manifest.version,
            phase: currentPhase,
            details: "Release \(manifest.version) announced: \(manifest.notes)",
            affectedClients: clientStates.count
        )
        updateEvents.append(event)

        return event
    }

    /// Start drain mode
    public func startDrainMode() -> UpdateEvent {
        currentPhase = .draining

        // Update all client statuses
        for (id, var state) in clientStates {
            if state.updateStatus == .current || state.updateStatus == .updateAvailable {
                state = ClientVersionState(
                    id: state.id,
                    clientVersion: state.clientVersion,
                    serverVersion: state.serverVersion,
                    principalId: state.principalId,
                    deviceId: state.deviceId,
                    sessionStart: state.sessionStart,
                    lastActivity: state.lastActivity,
                    capabilities: state.capabilities,
                    updateStatus: .drainMode
                )
                clientStates[id] = state
            }
        }

        let event = UpdateEvent(
            eventType: .drainModeStarted,
            fromVersion: platformVersion.current,
            toVersion: pendingRelease?.version,
            phase: currentPhase,
            details: "Drain mode started. Clients should finish current work.",
            affectedClients: clientStates.count
        )
        updateEvents.append(event)

        return event
    }

    /// Block all outdated clients
    public func blockOutdatedClients() -> UpdateEvent {
        currentPhase = .blocked

        var blockedCount = 0
        for (id, var state) in clientStates {
            if let pending = pendingRelease,
               state.clientVersion < pending.version {
                state = ClientVersionState(
                    id: state.id,
                    clientVersion: state.clientVersion,
                    serverVersion: state.serverVersion,
                    principalId: state.principalId,
                    deviceId: state.deviceId,
                    sessionStart: state.sessionStart,
                    lastActivity: state.lastActivity,
                    capabilities: state.capabilities,
                    updateStatus: .blocked
                )
                clientStates[id] = state
                blockedCount += 1
            }
        }

        let event = UpdateEvent(
            eventType: .clientBlocked,
            toVersion: pendingRelease?.version,
            phase: currentPhase,
            details: "Blocked \(blockedCount) outdated clients",
            affectedClients: blockedCount
        )
        updateEvents.append(event)

        return event
    }

    /// Enter maintenance mode
    public func enterMaintenance() -> UpdateEvent {
        currentPhase = .maintenance

        let event = UpdateEvent(
            eventType: .maintenanceStarted,
            fromVersion: platformVersion.current,
            toVersion: pendingRelease?.version,
            phase: currentPhase,
            details: "System entering maintenance for update"
        )
        updateEvents.append(event)

        return event
    }

    /// Complete deployment
    public func completeDeployment(newVersion: SemanticVersion) -> UpdateEvent {
        platformVersion = PlatformVersion(
            current: newVersion,
            minimumClient: newVersion,
            pendingRollout: nil,
            lastUpdated: Date(),
            environment: environment
        )
        pendingRelease = nil
        currentPhase = .verifying

        let event = UpdateEvent(
            eventType: .deploymentCompleted,
            toVersion: newVersion,
            phase: currentPhase,
            details: "Deployment to \(newVersion) completed, entering verification"
        )
        updateEvents.append(event)

        return event
    }

    /// Return to stable after successful verification
    public func returnToStable() -> UpdateEvent {
        currentPhase = .stable

        // Reset all client statuses to current
        for (id, var state) in clientStates {
            if state.clientVersion >= platformVersion.current {
                state = ClientVersionState(
                    id: state.id,
                    clientVersion: state.clientVersion,
                    serverVersion: state.serverVersion,
                    principalId: state.principalId,
                    deviceId: state.deviceId,
                    sessionStart: state.sessionStart,
                    lastActivity: state.lastActivity,
                    capabilities: state.capabilities,
                    updateStatus: .current
                )
                clientStates[id] = state
            }
        }

        let event = UpdateEvent(
            eventType: .verificationPassed,
            toVersion: platformVersion.current,
            phase: currentPhase,
            details: "Update verification passed, system stable"
        )
        updateEvents.append(event)

        return event
    }

    // MARK: - Client Management

    /// Register a client session
    public func registerClient(_ state: ClientVersionState) -> ClientUpdateStatus {
        let status = determineClientStatus(state.clientVersion)

        let updatedState = ClientVersionState(
            id: state.id,
            clientVersion: state.clientVersion,
            serverVersion: platformVersion.current,
            principalId: state.principalId,
            deviceId: state.deviceId,
            sessionStart: state.sessionStart,
            lastActivity: Date(),
            capabilities: state.capabilities,
            updateStatus: status
        )
        clientStates[state.id] = updatedState

        return status
    }

    /// Update client activity
    public func updateClientActivity(_ clientId: UUID) {
        guard var state = clientStates[clientId] else { return }
        state = ClientVersionState(
            id: state.id,
            clientVersion: state.clientVersion,
            serverVersion: state.serverVersion,
            principalId: state.principalId,
            deviceId: state.deviceId,
            sessionStart: state.sessionStart,
            lastActivity: Date(),
            capabilities: state.capabilities,
            updateStatus: state.updateStatus
        )
        clientStates[clientId] = state
    }

    /// Mark client as updated
    public func markClientUpdated(_ clientId: UUID, newVersion: SemanticVersion) -> UpdateEvent {
        let state = clientStates[clientId]
        if var s = state {
            s = ClientVersionState(
                id: s.id,
                clientVersion: newVersion,
                serverVersion: platformVersion.current,
                principalId: s.principalId,
                deviceId: s.deviceId,
                sessionStart: Date(),
                lastActivity: Date(),
                capabilities: s.capabilities,
                updateStatus: .current
            )
            clientStates[clientId] = s
        }

        let event = UpdateEvent(
            eventType: .clientUpdated,
            toVersion: newVersion,
            phase: currentPhase,
            details: "Client \(clientId) updated to \(newVersion)"
        )
        updateEvents.append(event)

        return event
    }

    /// Get client state
    public func getClientState(_ clientId: UUID) -> ClientVersionState? {
        return clientStates[clientId]
    }

    /// Get all client states
    public func getAllClientStates() -> [ClientVersionState] {
        return Array(clientStates.values)
    }

    // MARK: - Decision Making

    /// Check if an operation can proceed
    public func canProceed(
        clientId: UUID,
        operationProfile: CheckpointProfile
    ) -> UpdateDecision {
        guard let clientState = clientStates[clientId] else {
            return .deny(
                reason: "Unknown client session",
                phase: currentPhase,
                status: .blocked,
                requiredAction: .contactAdmin
            )
        }

        // Check version requirement
        if !clientState.clientVersion.satisfies(minimum: platformVersion.minimumClient) {
            return .deny(
                reason: "Client version \(clientState.clientVersion) below minimum \(platformVersion.minimumClient)",
                phase: currentPhase,
                status: .blocked,
                requiredAction: .updateClient
            )
        }

        // Check phase compatibility
        if !operationProfile.isAllowed(in: currentPhase) {
            let action: RequiredAction
            switch currentPhase {
            case .maintenance, .deploying:
                action = .waitForMaintenance
            case .blocked:
                action = .updateClient
            case .draining:
                action = .finishAndSave
            default:
                action = .contactAdmin
            }

            return .deny(
                reason: "Operation not allowed during \(currentPhase.rawValue) phase",
                phase: currentPhase,
                status: clientState.updateStatus,
                requiredAction: action
            )
        }

        // Calculate time until blocked if in drain mode
        var timeUntilBlocked: TimeInterval?
        if currentPhase == .draining, let pending = pendingRelease {
            timeUntilBlocked = pending.timeUntilMandatory()
        }

        return UpdateDecision(
            allowed: true,
            reason: "Operation permitted",
            phase: currentPhase,
            clientStatus: clientState.updateStatus,
            timeUntilBlocked: timeUntilBlocked
        )
    }

    // MARK: - Policy Management

    /// Set active version policy
    public func setPolicy(_ policy: VersionPolicy) {
        activePolicy = policy

        // Update minimum version if policy is stricter
        if policy.minimumVersion > platformVersion.minimumClient {
            platformVersion = PlatformVersion(
                current: platformVersion.current,
                minimumClient: policy.minimumVersion,
                pendingRollout: platformVersion.pendingRollout,
                lastUpdated: Date(),
                environment: environment
            )
        }

        // Re-evaluate all client statuses
        for (id, state) in clientStates {
            let newStatus = determineClientStatus(state.clientVersion)
            if newStatus != state.updateStatus {
                let updated = ClientVersionState(
                    id: state.id,
                    clientVersion: state.clientVersion,
                    serverVersion: state.serverVersion,
                    principalId: state.principalId,
                    deviceId: state.deviceId,
                    sessionStart: state.sessionStart,
                    lastActivity: state.lastActivity,
                    capabilities: state.capabilities,
                    updateStatus: newStatus
                )
                clientStates[id] = updated
            }
        }
    }

    /// Get active policy
    public func getActivePolicy() -> VersionPolicy? {
        return activePolicy
    }

    // MARK: - Statistics

    /// Get update statistics
    public func getStatistics() -> UpdateStatistics {
        var stats = UpdateStatistics(
            phase: currentPhase,
            currentVersion: platformVersion.current,
            pendingVersion: pendingRelease?.version,
            totalClients: clientStates.count
        )

        for state in clientStates.values {
            switch state.updateStatus {
            case .current: stats.currentClients += 1
            case .updateAvailable: stats.outdatedClients += 1
            case .drainMode: stats.drainingClients += 1
            case .blocked: stats.blockedClients += 1
            case .updating: stats.updatingClients += 1
            }
        }

        return stats
    }

    /// Get recent events
    public func getRecentEvents(limit: Int = 50) -> [UpdateEvent] {
        return Array(updateEvents.suffix(limit))
    }

    // MARK: - Private Helpers

    private func determineClientStatus(_ clientVersion: SemanticVersion) -> ClientUpdateStatus {
        // Check against minimum
        if clientVersion < platformVersion.minimumClient {
            return .blocked
        }

        // Check phase
        switch currentPhase {
        case .blocked:
            if let pending = pendingRelease, clientVersion < pending.version {
                return .blocked
            }
        case .draining:
            if let pending = pendingRelease, clientVersion < pending.version {
                return .drainMode
            }
        case .announced:
            if let pending = pendingRelease, clientVersion < pending.version {
                return .updateAvailable
            }
        default:
            break
        }

        // Check if update available
        if let pending = pendingRelease, clientVersion < pending.version {
            return .updateAvailable
        }

        return .current
    }
}

// MARK: - Update Statistics

/// Statistics about update state
public struct UpdateStatistics: Sendable {
    public var phase: UpdatePhase
    public var currentVersion: SemanticVersion
    public var pendingVersion: SemanticVersion?
    public var totalClients: Int
    public var currentClients: Int = 0
    public var outdatedClients: Int = 0
    public var drainingClients: Int = 0
    public var blockedClients: Int = 0
    public var updatingClients: Int = 0

    public var updateProgress: Double {
        guard totalClients > 0 else { return 1.0 }
        return Double(currentClients) / Double(totalClients)
    }
}
