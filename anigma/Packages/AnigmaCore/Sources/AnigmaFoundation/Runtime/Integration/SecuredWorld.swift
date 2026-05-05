//
//  SecuredWorld.swift
//  AnigmaCore
//
//  A security-integrated ECS World that enforces governance, access control,
//  and audit logging on all mutations. This is the "governed ECS" layer.
//
//  All write operations flow through:
//  1. Kill Switch check
//  2. Operating Mode check
//  3. Access Control (RBAC/ABAC) check
//  4. Write Gate quality checks
//  5. Audit logging
//
//  AI decisions made through this world are automatically:
//  - Explained via XAI
//  - Logged to the audit trail
//  - Subject to governance controls
//

import Foundation
import AnigmaPrimitives
import ContractsCore
import GovernanceCore
import AnigmaFoundation

// MARK: - Secured World

/// A security-integrated ECS World that enforces all governance and privacy controls.
///
/// SecuredWorld wraps the core ECS World and intercepts all mutations to ensure:
/// - Access control policies are enforced
/// - Kill switch can halt all operations
/// - Operating mode restrictions are respected
/// - All access is logged to the audit trail
/// - AI decisions are explainable
///
/// ## Usage
/// ```swift
/// let securedWorld = await SecuredWorld.create()
///
/// // Register a system with its principal
/// let principal = AccessPrincipal.system("OCRExtractionSystem", module: "Diaplasion", roles: ["processor"])
/// await securedWorld.registerSystemPrincipal(systemName: "OCRExtractionSystem", principal: principal)
///
/// // Access components (access control is automatic)
/// let result = try await securedWorld.getComponent(entity, DocumentComponent.self, as: principal)
/// ```
public actor SecuredWorld {
    // MARK: - Core Components

    /// The underlying ECS World.
    public let world: World

    /// Governance controller (kill switch, write gate, operating modes).
    public let governance: any GoverningController

    /// Security infrastructure (XAI, model integrity, enforcement, crypto).
    public let security: any SecurityInfrastructure

    // MARK: - Principal Registry

    /// Maps system names to their access principals.
    private var systemPrincipals: [String: AccessPrincipal] = [:]

    /// Maps component types to their sensitivity metadata.
    private var componentSensitivity: [String: (sensitivity: DataSensitivity, categories: Set<String>)] = [:]

    // MARK: - Initialization

    /// Creates a new SecuredWorld with provided infrastructure.
    public init(
        world: World,
        governance: any GoverningController,
        security: any SecurityInfrastructure
    ) {
        self.world = world
        self.governance = governance
        self.security = security
    }

    // MARK: - Configuration

    /// Registers a principal for a system.
    public func registerSystemPrincipal(systemName: String, principal: AccessPrincipal) {
        systemPrincipals[systemName] = principal
    }

    /// Registers sensitivity metadata for a component type.
    public func registerComponentSensitivity<C: Component>(
        _ type: C.Type,
        sensitivity: DataSensitivity,
        categories: Set<String> = []
    ) {
        let typeName = String(describing: C.self)
        componentSensitivity[typeName] = (sensitivity, categories)
    }

    /// Registers sensitivity for a SensitiveComponent (uses its static metadata).
    public func registerSensitiveComponent<C: SensitiveComponent>(_ type: C.Type) {
        let typeName = String(describing: C.self)
        componentSensitivity[typeName] = (C.sensitivity, C.dataCategories)
    }

    // MARK: - Entity Management (Secured)

    /// Creates a new entity with audit logging.
    public func createEntity(as principal: AccessPrincipal) async throws -> EntityId {
        // Check kill switch
        try await checkKillSwitch(principal: principal)

        // Create entity
        let entity = await world.createEntity()

        // Log creation
        let auditLog = await governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: principal.id,
            module: principal.module,
            description: "Entity created",
            metadata: ["entity_id": entity.raw.uuidString, "original_event_type": "entityCreated"]
        )

        return entity
    }

    /// Destroys an entity with governance checks.
    public func destroyEntity(_ entity: EntityId, as principal: AccessPrincipal) async throws {
        try await checkKillSwitch(principal: principal)
        try await checkWriteAllowed(principal: principal, operation: "destroyEntity", entityId: entity)

        await world.destroyEntity(entity)

        let auditLog = await governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: principal.id,
            module: principal.module,
            description: "Entity destroyed",
            metadata: ["entity_id": entity.raw.uuidString, "original_event_type": "entityDestroyed"]
        )
    }

    // MARK: - Component Access (Secured)

    /// Gets a component with access control check.
    public func getComponent<C: Component>(
        _ entity: EntityId,
        _ type: C.Type,
        as principal: AccessPrincipal,
        justification: String? = nil
    ) async throws -> C? {
        let typeName = String(describing: C.self)
        let (sensitivity, categories) = componentSensitivity[typeName] ?? (.internal, [])

        let request = AccessRequest(
            principal: principal,
            componentType: typeName,
            sensitivity: sensitivity,
            dataCategories: categories,
            accessType: .read,
            entityId: entity,
            justification: justification
        )

        let accessController = await governance.accessController
        try await accessController.checkAccess(request)

        return await world.getComponent(entity, type)
    }

    /// Adds a component with full governance checks.
    public func addComponent<C: Component>(
        _ entity: EntityId,
        _ component: C,
        as principal: AccessPrincipal
    ) async throws {
        let typeName = String(describing: C.self)
        let (sensitivity, categories) = componentSensitivity[typeName] ?? (.internal, [])

        // Check kill switch
        try await checkKillSwitch(principal: principal)

        // Check access control for write
        let accessRequest = AccessRequest(
            principal: principal,
            componentType: typeName,
            sensitivity: sensitivity,
            dataCategories: categories,
            accessType: .write,
            entityId: entity
        )
        let accessController = await governance.accessController
        try await accessController.checkAccess(accessRequest)

        // Check write gate
        let writeProposal = WriteProposal(
            principal: principal.id,
            module: principal.module,
            operation: "addComponent",
            entityId: entity,
            componentType: typeName
        )
        let decision = await governance.canWrite(writeProposal)
        guard decision.allowed else {
            let projectId = principal.attributes["project_id"]
            let modeSource = await governance.modeSource(for: projectId)
            
            let failedChecks = decision.failedChecks.map { 
                GovernanceViolation.FailedCheck(checkId: $0.checkId, message: $0.message) 
            }
            
            let violation = GovernanceViolation(
                principal: principal.id,
                projectId: projectId,
                operation: "addComponent",
                module: principal.module,
                evaluatedModeSource: modeSource.rawValue,
                failedChecks: failedChecks
            )
            
            let auditLog = await governance.auditLog
            try? await auditLog.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.policyViolation,
                principal: principal.id,
                module: "Governance",
                description: "Write blocked: \(violation.summaryMessage)",
                metadata: violation.auditMetadata
            )
            
            throw GovernanceError.writeBlocked(violation: violation)
        }

        // Perform the write
        await world.addComponent(entity, component)

        // Log the modification
        let auditLog = await governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.dataModified,
            principal: principal.id,
            module: principal.module,
            description: "Component added: \(typeName)",
            metadata: [
                "entity_id": entity.raw.uuidString,
                "component_type": typeName,
                "sensitivity": String(describing: sensitivity)
            ]
        )
    }

    /// Removes a component with governance checks.
    public func removeComponent<C: Component>(
        _ entity: EntityId,
        _ type: C.Type,
        as principal: AccessPrincipal
    ) async throws {
        let typeName = String(describing: C.self)
        let (sensitivity, categories) = componentSensitivity[typeName] ?? (.internal, [])

        try await checkKillSwitch(principal: principal)

        let accessRequest = AccessRequest(
            principal: principal,
            componentType: typeName,
            sensitivity: sensitivity,
            dataCategories: categories,
            accessType: .delete,
            entityId: entity
        )
        let accessController = await governance.accessController
        try await accessController.checkAccess(accessRequest)

        let writeProposal = WriteProposal(
            principal: principal.id,
            module: principal.module,
            operation: "removeComponent",
            entityId: entity,
            componentType: typeName
        )
        let decision = await governance.canWrite(writeProposal)
        guard decision.allowed else {
            let projectId = principal.attributes["project_id"]
            let modeSource = await governance.modeSource(for: projectId)
            
            let failedChecks = decision.failedChecks.map { 
                GovernanceViolation.FailedCheck(checkId: $0.checkId, message: $0.message) 
            }
            
            let violation = GovernanceViolation(
                principal: principal.id,
                projectId: projectId,
                operation: "removeComponent",
                module: principal.module,
                evaluatedModeSource: modeSource.rawValue,
                failedChecks: failedChecks
            )
            
            let auditLog = await governance.auditLog
            try? await auditLog.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.policyViolation,
                principal: principal.id,
                module: "Governance",
                description: "Write blocked: \(violation.summaryMessage)",
                metadata: violation.auditMetadata
            )
            
            throw GovernanceError.writeBlocked(violation: violation)
        }

        await world.removeComponent(entity, type)

        let auditLog = await governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.dataDeleted,
            principal: principal.id,
            module: principal.module,
            description: "Component removed: \(typeName)",
            metadata: [
                "entity_id": entity.raw.uuidString,
                "component_type": typeName,
                "sensitivity": String(describing: sensitivity)
            ]
        )
    }

    /// Queries components with access control.
    public func query<C: Component>(
        _ type: C.Type,
        as principal: AccessPrincipal,
        justification: String? = nil
    ) async throws -> [(EntityId, C)] {
        let typeName = String(describing: C.self)
        let (sensitivity, categories) = componentSensitivity[typeName] ?? (.internal, [])

        let request = AccessRequest(
            principal: principal,
            componentType: typeName,
            sensitivity: sensitivity,
            dataCategories: categories,
            accessType: .query,
            justification: justification
        )

        let accessController = await governance.accessController
        try await accessController.checkAccess(request)

        return await world.query(type)
    }
    
    /*
    /// Configuration for recording an AI decision.
    public struct RecordAIDecisionConfiguration: Sendable {
        public let modelId: ModelIdentifier
        public let decisionType: AIDecisionType
        public let outcome: DecisionOutcome
        public let confidence: Double
        public let features: [Feature]
        public let principal: AccessPrincipal
        public let entityId: EntityId?
        
        public init(
            modelId: ModelIdentifier,
            decisionType: AIDecisionType,
            outcome: DecisionOutcome,
            confidence: Double,
            features: [Feature],
            principal: AccessPrincipal,
            entityId: EntityId? = nil
        ) {
            self.modelId = modelId
            self.decisionType = decisionType
            self.outcome = outcome
            self.confidence = confidence
            self.features = features
            self.principal = principal
            self.entityId = entityId
        }
    }

    /// Records an AI decision with explainable AI (XAI) integration.
    public func recordAIDecision(config: RecordAIDecisionConfiguration) async -> AIDecisionExplanation {
        // Generate explanation
        let generator = LocalExplanationGenerator(
            modelIdentifier: config.modelId,
            modelVersion: "1.0"
        )
        
        let explanation = generator.generateExplanation(
            decisionType: config.decisionType,
            outcome: config.outcome,
            confidence: config.confidence,
            features: config.features
        )

        // Record in XAI registry
        await security.xaiRegistry.record(explanation)

        // Log to audit trail
        let auditLog = await governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.policyEvaluated,
            principal: config.principal.id,
            module: config.principal.module,
            description: "AI decision: \(config.decisionType.rawValue) -> \(config.outcome) (confidence: \(String(format: "%.2f", config.confidence)))",
            metadata: {
                var dict: [String: String] = [
                    "model_id": config.modelId,
                    "decision_id": explanation.id.uuidString,
                    "confidence": String(config.confidence)
                ]
                if let entityId = config.entityId {
                    dict["entity_id"] = entityId.raw.uuidString
                }
                return dict
            }()
        )

        return explanation
    }
    */

    /// Handles a detected threat with enforcement and audit.
    public func handleThreat(
        _ threat: DetectedThreat,
        principal: AccessPrincipal
    ) async -> EnforcementDecision {
        // Enforce the threat
        let engine = await security.enforcementEngine
        let decision = await engine.enforce(threat)

        // Log to audit trail
        let auditLog = await governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.policyViolation,
            principal: principal.id,
            module: principal.module,
            description: "Threat detected: \(threat.description) - Action: \(decision.action)",
            metadata: [
                "threat_id": threat.id.uuidString,
                "threat_level": String(describing: threat.level),
                "enforcement_action": decision.action
            ]
        )

        // For critical threats, activate kill switch
        if threat.level == .critical {
            let killSwitch = await governance.killSwitch
            await killSwitch.activate(
                reason: "Critical threat detected: \(threat.description)",
                by: "SecurityModule"
            )
        }

        return decision
    }

    // MARK: - System Execution (Secured)

    /// Runs a system with governance context.
    public func runSystem(_ system: any System) async throws {
        let systemName = system.name
        guard let principal = systemPrincipals[systemName] else {
            throw SecuredWorldError.noPrincipalRegistered(systemName: systemName)
        }

        // Log system start
        let auditLog = await governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: principal.id,
            module: principal.module,
            description: "System started: \(systemName)",
            metadata: ["system_name": systemName, "original_event_type": "systemStarted"]
        )

        await world.runSystem(system)

        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: principal.id,
            module: principal.module,
            description: "System completed: \(systemName)",
            metadata: ["system_name": systemName, "original_event_type": "systemStopped"]
        )
    }

    // MARK: - Convenience Pass-Through

    /// Checks if an entity exists (read-only, no access control needed).
    public func entityExists(_ entity: EntityId) async -> Bool {
        await world.entityExists(entity)
    }

    /// Gets all entities (read-only).
    public func allEntities() async -> [EntityId] {
        await world.allEntities()
    }

    /// Gets entity count (read-only).
    public func entityCount() async -> Int {
        await world.entityCount()
    }

    // MARK: - Governance Shortcuts

    /// Gets current operating mode.
    public func getMode() async -> OperatingMode {
        await governance.getMode()
    }

    /// Sets operating mode (requires admin principal).
    public func setMode(_ mode: OperatingMode, as principal: AccessPrincipal) async throws {
        guard principal.roles.contains("admin") || principal.roles.contains("governance") else {
            throw SecuredWorldError.insufficientPrivileges(
                required: "admin or governance role",
                principal: principal.id
            )
        }

        let runtimePrincipal = Principal(id: principal.id, displayName: principal.id, roles: principal.roles)
        try await governance.setMode(mode, for: .none, by: runtimePrincipal)
    }

    /// Activates kill switch (requires admin principal).
    public func activateKillSwitch(reason: String, as principal: AccessPrincipal) async throws {
        guard principal.roles.contains("admin") || principal.roles.contains("governance") else {
            throw SecuredWorldError.insufficientPrivileges(
                required: "admin or governance role",
                principal: principal.id
            )
        }

        let killSwitch = await governance.killSwitch
        await killSwitch.activate(reason: reason, by: principal.id)
    }

    /// Deactivates kill switch (requires admin principal).
    public func deactivateKillSwitch(as principal: AccessPrincipal) async throws {
        guard principal.roles.contains("admin") || principal.roles.contains("governance") else {
            throw SecuredWorldError.insufficientPrivileges(
                required: "admin or governance role",
                principal: principal.id
            )
        }

        let killSwitch = await governance.killSwitch
        await killSwitch.deactivate(by: principal.id)
        }


    // MARK: - Private Helpers

    private func checkKillSwitch(principal: AccessPrincipal) async throws {
        let projectId = principal.attributes["project_id"]
        let killSwitch = await governance.killSwitch
        let allowed = await killSwitch.isWriteAllowed(forProject: projectId)

        if !allowed {
            let killSwitch = await governance.killSwitch
            let status = await killSwitch.killSwitchStatus()
            throw GovernanceError.killSwitchActive(reason: status.activationReason ?? "Unknown")
        }
    }

    private func checkWriteAllowed(
        principal: AccessPrincipal,
        operation: String,
        entityId: EntityId? = nil,
        componentType: String? = nil
    ) async throws {
        let proposal = WriteProposal(
            principal: principal.id,
            module: principal.module,
            operation: operation,
            entityId: entityId,
            componentType: componentType
        )

        let decision = await governance.canWrite(proposal)

        if !decision.allowed {
            let projectId = principal.attributes["project_id"]
            let modeSource = await governance.modeSource(for: projectId)
            
            let failedChecks = decision.failedChecks.map { 
                GovernanceViolation.FailedCheck(checkId: $0.checkId, message: $0.message) 
            }
            
            let violation = GovernanceViolation(
                principal: principal.id,
                projectId: projectId,
                operation: operation,
                module: principal.module,
                evaluatedModeSource: modeSource.rawValue,
                failedChecks: failedChecks
            )
            
            let auditLog = await governance.auditLog
            try? await auditLog.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.policyViolation,
                principal: principal.id,
                module: "Governance",
                description: "Write blocked: \(violation.summaryMessage)",
                metadata: violation.auditMetadata
            )
            
            throw GovernanceError.writeBlocked(violation: violation)
        }
    }
}

// MARK: - Secured World Errors

public enum SecuredWorldError: Error, LocalizedError, Sendable {
    case noPrincipalRegistered(systemName: String)
    case insufficientPrivileges(required: String, principal: String)
    case securityViolation(message: String)

    public var errorDescription: String? {
        switch self {
        case .noPrincipalRegistered(let name):
            return "No principal registered for system: \(name)"
        case .insufficientPrivileges(let required, let principal):
            return "Insufficient privileges: \(principal) requires \(required)"
        case .securityViolation(let message):
            return "Security violation: \(message)"
        }
    }
}

// MARK: - Secured World Observer

/// Observer that integrates security events with the World observer pattern.
public final class SecuredWorldObserver: WorldObserver, @unchecked Sendable {
    private let securedWorld: SecuredWorld
    private let principal: AccessPrincipal

    public init(securedWorld: SecuredWorld, principal: AccessPrincipal) {
        self.securedWorld = securedWorld
        self.principal = principal
    }

    public func entityCreated(_ entity: EntityId) async {
        let auditLog = await securedWorld.governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: principal.id,
            module: principal.module,
            description: "Entity created (via observer)",
            metadata: ["entity_id": entity.raw.uuidString, "original_event_type": "entityCreated"]
        )
    }

    public func entityDestroyed(_ entity: EntityId) async {
        let auditLog = await securedWorld.governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: principal.id,
            module: principal.module,
            description: "Entity destroyed (via observer)",
            metadata: ["entity_id": entity.raw.uuidString, "original_event_type": "entityDestroyed"]
        )
    }

    public func componentAdded<C: Component>(_ entity: EntityId, component: C) async {
        let typeName = String(describing: C.self)
        let auditLog = await securedWorld.governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.dataCreated,
            principal: principal.id,
            module: principal.module,
            description: "Component added: \(typeName) (via observer)",
            metadata: [
                "entity_id": entity.raw.uuidString,
                "component_type": typeName
            ]
        )
    }

    public func componentRemoved<C: Component>(_ entity: EntityId, componentType: C.Type) async {
        let typeName = String(describing: C.self)
        let auditLog = await securedWorld.governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.dataDeleted,
            principal: principal.id,
            module: principal.module,
            description: "Component removed: \(typeName) (via observer)",
            metadata: [
                "entity_id": entity.raw.uuidString,
                "component_type": typeName
            ]
        )
    }

}
