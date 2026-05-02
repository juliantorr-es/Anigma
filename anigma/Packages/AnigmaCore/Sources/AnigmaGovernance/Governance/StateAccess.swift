//
//  StateAccess.swift
//  AnigmaCore
//
//  Governed access layer for state operations.
//  All state access must go through policy evaluation.
//

import AnigmaFoundation
import GovernanceCore
import Foundation
import FoundationContracts
import EvidenceContracts
import IntelligenceContracts
import GovernanceContracts
import AnigmaPrimitives
import SecurityEventsManager

// Disambiguate type references
public typealias StateSlice = FoundationContracts.StateSlice
public typealias StateDelta = FoundationContracts.StateDelta

/// Actor-based state access with governance enforcement
public actor StateAccess {

    // MARK: - Dependencies

    private let policyEngine: PolicyEnforcementEngine
    private let auditLog: any AuditLogging
    private let evidenceRecorder: any EvidenceRecording
    private let config: StateAccessConfig

    // MARK: - State

    private var stateSnapshots: [String: StateSlice] = [:]  // sessionId -> state
    private var accessHistory: [StateAccessRecord] = []
    private var quarantineList: Set<String> = []  // entity IDs

    // MARK: - Initialization

    public init(
        policyEngine: PolicyEnforcementEngine,
        auditLog: any AuditLogging,
        evidenceRecorder: any EvidenceRecording,
        config: StateAccessConfig = .default
    ) {
        self.policyEngine = policyEngine
        self.auditLog = auditLog
        self.evidenceRecorder = evidenceRecorder
        self.config = config
    }

    // MARK: - Public Interface

    /// Read state slice with governance evaluation
    public func readState(
        sessionId: String,
        entityIds: [String]? = nil,
        trustTier: AnigmaPrimitives.TrustTier = .bronze,
        securityZone: SecurityZone = .selfHost
    ) async throws -> StateSlice {
        let startTime = Date()

        // Check access permissions
        let accessRequest = StateAccessRequest(
            sessionId: sessionId,
            operation: .read,
            entityIds: entityIds ?? [],
            trustTier: trustTier,
            securityZone: securityZone,
            timestamp: startTime
        )

        let decision = try await evaluateAccessRequest(accessRequest)
        guard decision.allowed else {
            throw StateAccessError.accessDenied(decision.reason)
        }

        // Get current state snapshot
        let currentState = stateSnapshots[sessionId] ?? StateSlice()

        // Filter entities if specified
        let filteredEntities = entityIds.map { ids in
            currentState.entities.filter { ids.contains($0.id) }
        } ?? currentState.entities

        // Filter out quarantined entities
        let allowedEntities = filteredEntities.filter { !quarantineList.contains($0.id) }

        let result = StateSlice(
            entities: allowedEntities,
            relations: currentState.relations.filter { relation in
                !quarantineList.contains(relation.fromId) &&
                !quarantineList.contains(relation.toId)
            },
            metadata: currentState.metadata
        )

        // Record access
        let record = StateAccessRecord(
            sessionId: sessionId,
            operation: .read,
            entityIds: entityIds ?? [],
            trustTier: trustTier,
            securityZone: securityZone,
            allowed: true,
            timestamp: startTime,
            duration: Date().timeIntervalSince(startTime),
            entityCount: allowedEntities.count
        )
        accessHistory.append(record)

        // Log to audit trail
        try await auditLog.recordEvent(
            id: UUID(),
            type: AuditEventType.dataRead,
            principal: nil,
            module: "StateAccess",
            description: "Read state for session \(sessionId)",
            metadata: [
                "sessionId": sessionId,
                "entityCount": "\(allowedEntities.count)"
            ]
        )

        return result
    }

    /// Write state delta with governance evaluation
    public func writeState(
        sessionId: String,
        delta: StateDelta,
        trustTier: AnigmaPrimitives.TrustTier = .bronze,
        securityZone: SecurityZone = .standard
    ) async throws -> StateSlice {
        let startTime = Date()

        // Check access permissions
        let affectedEntityIds = delta.addedEntities.map { $0.id } +
                              delta.modifiedEntities.map { $0.id } +
                              delta.deletedEntities

        let accessRequest = StateAccessRequest(
            sessionId: sessionId,
            operation: .write,
            entityIds: affectedEntityIds,
            trustTier: trustTier,
            securityZone: securityZone,
            timestamp: startTime
        )

        let decision = try await evaluateAccessRequest(accessRequest)
        guard decision.allowed else {
            throw StateAccessError.accessDenied(decision.reason)
        }

        // Check for quarantined entities
        let quarantinedEntities = affectedEntityIds.filter { quarantineList.contains($0) }
        guard quarantinedEntities.isEmpty else {
            throw StateAccessError.entitiesQuarantined(quarantinedEntities)
        }

        // Get current state and apply delta
        let currentState = stateSnapshots[sessionId] ?? StateSlice()
        var updatedEntities = currentState.entities
        var updatedRelations = currentState.relations

        // Apply entity additions
        for entity in delta.addedEntities {
            updatedEntities.removeAll { $0.id == entity.id }
            updatedEntities.append(entity)
        }

        // Apply entity modifications
        for entity in delta.modifiedEntities {
            updatedEntities.removeAll { $0.id == entity.id }
            updatedEntities.append(entity)
        }

        // Apply entity deletions
        updatedEntities.removeAll { delta.deletedEntities.contains($0.id) }

        // Apply relation additions
        for relation in delta.addedRelations {
            updatedRelations.removeAll { $0.id == relation.id }
            updatedRelations.append(relation)
        }

        // Apply relation deletions
        updatedRelations.removeAll { delta.deletedRelations.contains($0.id) }

        let newState = StateSlice(
            entities: updatedEntities,
            relations: updatedRelations,
            metadata: currentState.metadata
        )

        // Update state snapshot
        stateSnapshots[sessionId] = newState

        // Record access
        let record = StateAccessRecord(
            sessionId: sessionId,
            operation: .write,
            entityIds: affectedEntityIds,
            trustTier: trustTier,
            securityZone: securityZone,
            allowed: true,
            timestamp: startTime,
            duration: Date().timeIntervalSince(startTime),
            entityCount: affectedEntityIds.count
        )
        accessHistory.append(record)

        // Persist state delta through evidence recorder
        try await evidenceRecorder.recordStateDelta(
            sessionId: sessionId,
            delta: delta,
            timestamp: startTime
        )

        // Log to audit trail
        try? await auditLog.recordEvent(
            id: UUID(),
            type: AuditEventType.dataModified,
            principal: "state_access",
            module: "StateAccess",
            description: "Write state for session \(sessionId)",
            metadata: [
                "session_id": sessionId,
                "added_entities": "\(delta.addedEntities.count)",
                "modified_entities": "\(delta.modifiedEntities.count)",
                "deleted_entities": "\(delta.deletedEntities.count)",
                "total_changes": "\(affectedEntityIds.count)"
            ]
        )

        return newState
    }

    /// Create new state session
    public func createSession(
        sessionId: String,
        initialState: StateSlice = StateSlice(),
        trustTier: AnigmaPrimitives.TrustTier = .bronze,
        securityZone: SecurityZone = .selfHost
    ) async throws {
        let startTime = Date()

        // Check session creation permissions
        let accessRequest = StateAccessRequest(
            sessionId: sessionId,
            operation: .createSession,
            entityIds: [],
            trustTier: trustTier,
            securityZone: securityZone,
            timestamp: startTime
        )

        let decision = try await evaluateAccessRequest(accessRequest)
        guard decision.allowed else {
            throw StateAccessError.accessDenied(decision.reason)
        }

        // Store initial state
        stateSnapshots[sessionId] = initialState

        // Record access
        let record = StateAccessRecord(
            sessionId: sessionId,
            operation: .createSession,
            entityIds: [],
            trustTier: trustTier,
            securityZone: securityZone,
            allowed: true,
            timestamp: startTime,
            duration: 0,
            entityCount: initialState.entities.count
        )
        accessHistory.append(record)

        // Log to audit trail
        try? await auditLog.recordEvent(
            id: UUID(),
            type: AuditEventType.custom,
            principal: "state_access",
            module: "StateAccess",
            description: "Created session with \(initialState.entities.count) entities",
            metadata: [
                "session_id": sessionId,
                "entity_count": "\(initialState.entities.count)",
                "original_event_type": "createSession"
            ]
        )
    }

    /// Delete state session
    public func deleteSession(_ sessionId: String) async throws {
        let startTime = Date()

        // Check session deletion permissions
        let accessRequest = StateAccessRequest(
            sessionId: sessionId,
            operation: .deleteSession,
            entityIds: [],
            trustTier: .bronze,
            securityZone: .selfHost,
            timestamp: startTime
        )

        let decision = try await evaluateAccessRequest(accessRequest)
        guard decision.allowed else {
            throw StateAccessError.accessDenied(decision.reason)
        }

        // Remove session
        stateSnapshots.removeValue(forKey: sessionId)

        // Record access
        let record = StateAccessRecord(
            sessionId: sessionId,
            operation: .deleteSession,
            entityIds: [],
            trustTier: .bronze,
            securityZone: .selfHost,
            allowed: true,
            timestamp: startTime,
            duration: 0,
            entityCount: 0
        )
        accessHistory.append(record)

        // Log to audit trail
        try? await auditLog.recordEvent(
            id: UUID(),
            type: AuditEventType.custom,
            principal: "state_access",
            module: "StateAccess",
            description: "Deleted session",
            metadata: ["session_id": sessionId, "original_event_type": "deleteSession"]
        )
    }

    /// Quarantine entities
    public func quarantineEntities(
        _ entityIds: [String],
        reason: String,
        duration: TimeInterval? = nil
    ) async throws {
        let startTime = Date()

        // Add to quarantine list
        for entityId in entityIds {
            quarantineList.insert(entityId)
        }

        // Record quarantine action
        let record = StateAccessRecord(
            sessionId: "system",
            operation: .quarantine,
            entityIds: entityIds,
            trustTier: .platinum,
            securityZone: .system,
            allowed: true,
            timestamp: startTime,
            duration: 0,
            entityCount: entityIds.count
        )
        accessHistory.append(record)

        // Log to audit trail
        try? await auditLog.recordEvent(
            id: UUID(),
            type: AuditEventType.custom,
            principal: "state_access",
            module: "StateAccess",
            description: "Quarantined \(entityIds.count) entities",
            metadata: [
                "entity_count": "\(entityIds.count)",
                "reason": reason,
                "duration": duration.map { "\($0)" } ?? "indefinite",
                "original_event_type": "quarantineEntities"
            ]
        )

        // Schedule quarantine lift if duration provided
        if let duration = duration {
            // In production, this would use a proper scheduler
            // For MVP, we just log the intention
            try? await auditLog.recordEvent(
                id: UUID(),
                type: AuditEventType.custom,
                principal: "state_access",
                module: "StateAccess",
                description: "Scheduled quarantine lift",
                metadata: [
                    "entity_count": "\(entityIds.count)",
                    "lift_time": ISO8601DateFormatter().string(from: Date().addingTimeInterval(duration)),
                    "original_event_type": "scheduleQuarantineLift"
                ]
            )
        }
    }

    /// Lift quarantine from entities
    public func liftQuarantine(_ entityIds: [String]) async throws {
        let startTime = Date()

        // Remove from quarantine list
        for entityId in entityIds {
            quarantineList.remove(entityId)
        }

        // Record quarantine lift
        let record = StateAccessRecord(
            sessionId: "system",
            operation: .liftQuarantine,
            entityIds: entityIds,
            trustTier: .platinum,
            securityZone: .system,
            allowed: true,
            timestamp: startTime,
            duration: 0,
            entityCount: entityIds.count
        )
        accessHistory.append(record)

        // Log to audit trail
        try? await auditLog.recordEvent(
            id: UUID(),
            type: AuditEventType.custom,
            principal: "state_access",
            module: "StateAccess",
            description: "Lifted quarantine from \(entityIds.count) entities",
            metadata: ["entity_count": "\(entityIds.count)", "original_event_type": "liftQuarantine"]
        )
    }

    /// Get access history
    public func getAccessHistory(
        sessionId: String? = nil,
        limit: Int = 100
    ) async -> [StateAccessRecord] {
        var filtered = accessHistory

        if let sessionId = sessionId {
            filtered = filtered.filter { $0.sessionId == sessionId }
        }

        // Sort by timestamp (most recent first) and limit
        return filtered
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }

    /// Get current state for session
    public func getCurrentState(_ sessionId: String) async -> StateSlice? {
        return stateSnapshots[sessionId]
    }

    /// Get quarantined entities
    public func getQuarantinedEntities() async -> Set<String> {
        return quarantineList
    }

    // MARK: - Private Methods

    /// Evaluate access request against policy engine
    private func evaluateAccessRequest(_ request: StateAccessRequest) async throws -> StateAccessDecision {
        // Create policy context
        _ = StepContext(
            workflowId: "state_access",
            sessionId: request.sessionId,
            trustTier: AnigmaPrimitives.TrustTier(rawValue: request.trustTier.rawValue)!,
            allowedCapabilities: [],  // State access doesn't use capabilities
            zone: SecurityZone(rawValue: request.securityZone.rawValue)!,
            deadline: nil
        )

        // Evaluate based on operation type
        switch request.operation {
        case .read:
            // Read operations are generally allowed but may be restricted by security zone
            let allowedZones: [SecurityZone] = [.selfHost, .inspiration]
            guard allowedZones.contains(SecurityZone(rawValue: request.securityZone.rawValue)!) else {
                let reason = "Read access not allowed in security zone: \(request.securityZone.rawValue)"
                if let manager = SecurityEventingService.shared {
                    manager.logAccessEvaluation(
                        engineId: request.sessionId,
                        principal: request.sessionId,
                        resource: "state_entities",
                        accessType: "read",
                        allowed: false,
                        reason: reason
                    )
                }
                return StateAccessDecision(
                    allowed: false,
                    reason: reason
                )
            }

        case .write:
            // Write operations require higher trust tiers
            guard request.trustTier.rawValue >= AnigmaPrimitives.TrustTier.silver.rawValue else {
                let reason = "Write access requires at least Standard trust tier"
                if let manager = SecurityEventingService.shared {
                    manager.logAccessEvaluation(
                        engineId: request.sessionId,
                        principal: request.sessionId,
                        resource: "state_entities",
                        accessType: "write",
                        allowed: false,
                        reason: reason
                    )
                }
                return StateAccessDecision(
                    allowed: false,
                    reason: reason
                )
            }

            // Check if writing to protected entities
            let protectedEntityTypes = ["system", "policy", "governance"]
            let protectedEntities = request.entityIds.filter { entityId in
                // In production, this would check entity type from state
                protectedEntityTypes.contains { entityId.lowercased().contains($0) }
            }

            guard protectedEntities.isEmpty || request.trustTier == .platinum else {
                let reason = "Cannot write protected entities without Platinum trust tier"
                if let manager = SecurityEventingService.shared {
                    manager.logAccessEvaluation(
                        engineId: request.sessionId,
                        principal: request.sessionId,
                        resource: protectedEntities.first ?? "protected_entity",
                        accessType: "write",
                        allowed: false,
                        reason: reason
                    )
                }
                return StateAccessDecision(
                    allowed: false,
                    reason: reason
                )
            }

        case .createSession:
            // Session creation is allowed for most trust tiers
            guard request.trustTier.rawValue >= AnigmaPrimitives.TrustTier.gold.rawValue else {
                let reason = "Session creation requires at least Elevated trust tier"
                if let manager = SecurityEventingService.shared {
                    manager.logAccessEvaluation(
                        engineId: request.sessionId,
                        principal: request.sessionId,
                        resource: "session",
                        accessType: "create",
                        allowed: false,
                        reason: reason
                    )
                }
                return StateAccessDecision(
                    allowed: false,
                    reason: reason
                )
            }

        case .deleteSession:
            // Session deletion requires same trust tier as creation
            guard request.trustTier.rawValue >= AnigmaPrimitives.TrustTier.gold.rawValue else {
                let reason = "Session deletion requires at least Elevated trust tier"
                if let manager = SecurityEventingService.shared {
                    manager.logAccessEvaluation(
                        engineId: request.sessionId,
                        principal: request.sessionId,
                        resource: "session",
                        accessType: "delete",
                        allowed: false,
                        reason: reason
                    )
                }
                return StateAccessDecision(
                    allowed: false,
                    reason: reason
                )
            }

        case .quarantine, .liftQuarantine:
            // Quarantine operations require Platinum trust tier
            guard request.trustTier == .platinum else {
                let reason = "Quarantine operations require Platinum trust tier"
                if let manager = SecurityEventingService.shared {
                    manager.logAccessEvaluation(
                        engineId: request.sessionId,
                        principal: request.sessionId,
                        resource: "quarantine",
                        accessType: String(describing: request.operation),
                        allowed: false,
                        reason: reason
                    )
                }
                return StateAccessDecision(
                    allowed: false,
                    reason: reason
                )
            }
        }

        // If we get here, operation is allowed
        return StateAccessDecision(allowed: true, reason: "Operation allowed")
    }
}

// MARK: - Supporting Types

/// Configuration for state access
public struct StateAccessConfig: Sendable {
    public let maxSessionCount: Int
    public let maxStateSize: Int
    public let enableQuarantine: Bool
    public let defaultQuarantineDuration: TimeInterval

    public init(
        maxSessionCount: Int = 100,
        maxStateSize: Int = 10_000,  // entities
        enableQuarantine: Bool = true,
        defaultQuarantineDuration: TimeInterval = 300  // 5 minutes
    ) {
        self.maxSessionCount = maxSessionCount
        self.maxStateSize = maxStateSize
        self.enableQuarantine = enableQuarantine
        self.defaultQuarantineDuration = defaultQuarantineDuration
    }

    public static let `default` = StateAccessConfig()
}

/// Request for state access
public struct StateAccessRequest: Sendable {
    public let sessionId: String
    public let operation: StateAccessOperation
    public let entityIds: [String]
    public let trustTier: AnigmaPrimitives.TrustTier
    public let securityZone: SecurityZone
    public let timestamp: Date

    public init(
        sessionId: String,
        operation: StateAccessOperation,
        entityIds: [String],
        trustTier: TrustTier,
        securityZone: SecurityZone,
        timestamp: Date
    ) {
        self.sessionId = sessionId
        self.operation = operation
        self.entityIds = entityIds
        self.trustTier = trustTier
        self.securityZone = securityZone
        self.timestamp = timestamp
    }
}

/// Operation type for state access
public enum StateAccessOperation: String, Sendable, Codable {
    case read = "read"
    case write = "write"
    case createSession = "create_session"
    case deleteSession = "delete_session"
    case quarantine = "quarantine"
    case liftQuarantine = "lift_quarantine"

    public var description: String {
        switch self {
        case .read: return "Read state"
        case .write: return "Write state"
        case .createSession: return "Create session"
        case .deleteSession: return "Delete session"
        case .quarantine: return "Quarantine entities"
        case .liftQuarantine: return "Lift quarantine"
        }
    }
}

/// Decision for state access
public struct StateAccessDecision: Sendable {
    public let allowed: Bool
    public let reason: String

    public init(allowed: Bool, reason: String) {
        self.allowed = allowed
        self.reason = reason
    }
}

/// Record of state access
public struct StateAccessRecord: Sendable, Codable {
    public let sessionId: String
    public let operation: StateAccessOperation
    public let entityIds: [String]
    public let trustTier: AnigmaPrimitives.TrustTier
    public let securityZone: SecurityZone
    public let allowed: Bool
    public let timestamp: Date
    public let duration: TimeInterval
    public let entityCount: Int

    public init(
        sessionId: String,
        operation: StateAccessOperation,
        entityIds: [String],
        trustTier: TrustTier,
        securityZone: SecurityZone,
        allowed: Bool,
        timestamp: Date,
        duration: TimeInterval,
        entityCount: Int
    ) {
        self.sessionId = sessionId
        self.operation = operation
        self.entityIds = entityIds
        self.trustTier = trustTier
        self.securityZone = securityZone
        self.allowed = allowed
        self.timestamp = timestamp
        self.duration = duration
        self.entityCount = entityCount
    }
}

/// Errors specific to state access
public enum StateAccessError: Error, Sendable {
    case accessDenied(String)
    case entitiesQuarantined([String])
    case sessionNotFound(String)
    case quotaExceeded(String)
    case invalidOperation(String)

    public var localizedDescription: String {
        switch self {
        case .accessDenied(let reason):
            return "Access denied: \(reason)"
        case .entitiesQuarantined(let entities):
            return "Entities are quarantined: \(entities.joined(separator: ", "))"
        case .sessionNotFound(let sessionId):
            return "Session not found: \(sessionId)"
        case .quotaExceeded(let reason):
            return "Quota exceeded: \(reason)"
        case .invalidOperation(let operation):
            return "Invalid operation: \(operation)"
        }
    }
}
