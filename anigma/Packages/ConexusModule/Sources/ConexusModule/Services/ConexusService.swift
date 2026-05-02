//
//  ConexusService.swift
//  ConexusModule
//
//  Main service for CRM operations, integrating with ECS and governance.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import GovernanceCore

/// Main service for Conexus CRM operations.
public actor ConexusService {
    private let world: World
    private let governance: GovernanceController
    private var pipelines: [PipelineId: PipelineDefinition] = [:]

    public init(world: World, governance: GovernanceController) {
        self.world = world
        self.governance = governance

        // Register default pipelines
        let defaultSales = PipelineDefinition.defaultSales
        pipelines[defaultSales.id] = defaultSales

        let altMedia = PipelineDefinition.altMediaRequest
        pipelines[altMedia.id] = altMedia
    }

    // MARK: - Contact Operations

    /// Creates a new contact.
    public func createContact(
        _ contact: ContactComponent,
        principal: String
    ) async throws -> EntityId {
        let entityId = await world.createEntity()

        let proposal = WriteProposal(
            principal: principal,
            module: "Conexus",
            operation: "create",
            entityId: entityId,
            componentType: "ContactComponent",
            context: ["contact_type": contact.contactType.rawValue]
        )

        let decision = await governance.writeGate.evaluate(proposal)
        guard decision.allowed else {
            let reasons = decision.failedChecks.map(\.message).joined(separator: ", ")
            throw ConexusError.permissionDenied(reason: reasons.isEmpty ? "Write denied" : reasons)
        }

        await world.addComponent(entityId, contact)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "ConexusService",
            description: "Created contact: \(contact.fullName)",
            metadata: [
                "original_event_type": "contact_created",
                "entity_id": entityId.raw.uuidString,
                "component_type": "ContactComponent",
                "contact_name": contact.fullName
            ]
        )

        return entityId
    }

    /// Retrieves a contact by entity ID.
    public func getContact(_ entityId: EntityId) async -> ContactComponent? {
        await world.getComponent(entityId, ContactComponent.self)
    }

    /// Updates a contact.
    public func updateContact(
        _ entityId: EntityId,
        update: (inout ContactComponent) -> Void,
        principal: String
    ) async throws {
        guard var contact = await world.getComponent(entityId, ContactComponent.self) else {
            throw ConexusError.contactNotFound(ContactId())
        }

        update(&contact)
        contact.updatedAt = Date()

        await world.addComponent(entityId, contact)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "ConexusService",
            description: "Updated contact: \(contact.fullName)",
            metadata: [
                "original_event_type": "contact_updated",
                "entity_id": entityId.raw.uuidString,
                "contact_name": contact.fullName
            ]
        )
    }

    /// Finds contacts by query.
    public func findContacts(
        matching predicate: @Sendable (ContactComponent) -> Bool
    ) async -> [(EntityId, ContactComponent)] {
        var results: [(EntityId, ContactComponent)] = []
        let entities = await world.entitiesWith(ContactComponent.self)

        for entityId in entities {
            if let contact = await world.getComponent(entityId, ContactComponent.self),
               predicate(contact) {
                results.append((entityId, contact))
            }
        }

        return results
    }

    // MARK: - Organization Operations

    /// Creates a new organization.
    public func createOrganization(
        _ org: OrganizationComponent,
        principal: String
    ) async throws -> EntityId {
        let entityId = await world.createEntity()

        let proposal = WriteProposal(
            principal: principal,
            module: "Conexus",
            operation: "create",
            entityId: entityId,
            componentType: "OrganizationComponent",
            context: ["org_type": org.organizationType.rawValue]
        )

        let decision = await governance.writeGate.evaluate(proposal)
        guard decision.allowed else {
            let reasons = decision.failedChecks.map(\.message).joined(separator: ", ")
            throw ConexusError.permissionDenied(reason: reasons.isEmpty ? "Write denied" : reasons)
        }

        await world.addComponent(entityId, org)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "ConexusService",
            description: "Created organization: \(org.name)",
            metadata: [
                "original_event_type": "organization_created",
                "entity_id": entityId.raw.uuidString,
                "organization_name": org.name
            ]
        )

        return entityId
    }

    /// Retrieves an organization by entity ID.
    public func getOrganization(_ entityId: EntityId) async -> OrganizationComponent? {
        await world.getComponent(entityId, OrganizationComponent.self)
    }

    // MARK: - Deal Operations

    /// Creates a new deal in a pipeline.
    public func createDeal(
        _ deal: DealComponent,
        principal: String
    ) async throws -> EntityId {
        guard pipelines[deal.pipelineId] != nil else {
            throw ConexusError.pipelineNotFound(deal.pipelineId)
        }

        let entityId = await world.createEntity()

        let proposal = WriteProposal(
            principal: principal,
            module: "Conexus",
            operation: "create",
            entityId: entityId,
            componentType: "DealComponent",
            context: [
                "pipeline_id": deal.pipelineId.raw.uuidString,
                "stage_id": deal.stageId
            ]
        )

        let decision = await governance.writeGate.evaluate(proposal)
        guard decision.allowed else {
            let reasons = decision.failedChecks.map(\.message).joined(separator: ", ")
            throw ConexusError.permissionDenied(reason: reasons.isEmpty ? "Write denied" : reasons)
        }

        await world.addComponent(entityId, deal)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "ConexusService",
            description: "Created deal: \(deal.name)",
            metadata: [
                "original_event_type": "deal_created",
                "entity_id": entityId.raw.uuidString,
                "deal_name": deal.name,
                "pipeline_id": deal.pipelineId.raw.uuidString
            ]
        )

        return entityId
    }

    /// Moves a deal to a new stage.
    public func moveDeal(
        _ entityId: EntityId,
        toStage newStageId: String,
        principal: String
    ) async throws {
        guard var deal = await world.getComponent(entityId, DealComponent.self) else {
            throw ConexusError.dealNotFound(DealId())
        }

        guard let pipeline = pipelines[deal.pipelineId] else {
            throw ConexusError.pipelineNotFound(deal.pipelineId)
        }

        let validNextStages = pipeline.validNextStages(from: deal.stageId)
        guard validNextStages.contains(where: { $0.id == newStageId }) else {
            throw ConexusError.invalidStageTransition(from: deal.stageId, to: newStageId)
        }

        let proposal = WriteProposal(
            principal: principal,
            module: "Conexus",
            operation: "stage_change",
            entityId: entityId,
            context: [
                "from_stage": deal.stageId,
                "to_stage": newStageId
            ]
        )

        let decision = await governance.writeGate.evaluate(proposal)
        guard decision.allowed else {
            let reasons = decision.failedChecks.map(\.message).joined(separator: ", ")
            throw ConexusError.permissionDenied(reason: reasons.isEmpty ? "Write denied" : reasons)
        }

        let newStage = pipeline.stages.first { $0.id == newStageId }
        deal.moveToStage(newStageId, probability: newStage?.probability)

        if newStage?.isWon == true {
            deal.markWon()
        } else if newStage?.isLost == true {
            deal.markLost()
        }

        await world.addComponent(entityId, deal)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "ConexusService",
            description: "Moved deal '\(deal.name)' to stage '\(newStageId)'",
            metadata: [
                "original_event_type": "deal_moved",
                "entity_id": entityId.raw.uuidString,
                "deal_name": deal.name,
                "new_stage_id": newStageId
            ]
        )
    }

    /// Gets pipeline summary with deal counts per stage.
    public func getPipelineSummary(_ pipelineId: PipelineId) async -> PipelineSummary? {
        guard let pipeline = pipelines[pipelineId] else { return nil }

        let dealEntities = await world.entitiesWith(DealComponent.self)
        var stageDeals: [String: [DealComponent]] = [:]

        for entityId in dealEntities {
            if let deal = await world.getComponent(entityId, DealComponent.self),
               deal.pipelineId == pipelineId {
                stageDeals[deal.stageId, default: []].append(deal)
            }
        }

        var stageSummaries: [StageSummary] = []
        for stage in pipeline.stages {
            let deals = stageDeals[stage.id] ?? []
            let totalValue = deals.compactMap(\.amount).reduce(0, +)
            let weightedValue = deals.compactMap(\.weightedAmount).reduce(0, +)

            stageSummaries.append(StageSummary(
                stage: stage,
                dealCount: deals.count,
                totalValue: totalValue,
                weightedValue: weightedValue
            ))
        }

        return PipelineSummary(
            pipeline: pipeline,
            stages: stageSummaries,
            generatedAt: Date()
        )
    }

    // MARK: - Case Operations

    /// Creates a new case.
    public func createCase(
        _ caseRecord: CaseComponent,
        principal: String
    ) async throws -> EntityId {
        let entityId = await world.createEntity()

        let proposal = WriteProposal(
            principal: principal,
            module: "Conexus",
            operation: "create",
            entityId: entityId,
            componentType: "CaseComponent",
            context: [
                "case_type": caseRecord.caseType.rawValue,
                "priority": caseRecord.priority.label
            ]
        )

        let decision = await governance.writeGate.evaluate(proposal)
        guard decision.allowed else {
            let reasons = decision.failedChecks.map(\.message).joined(separator: ", ")
            throw ConexusError.permissionDenied(reason: reasons.isEmpty ? "Write denied" : reasons)
        }

        await world.addComponent(entityId, caseRecord)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "ConexusService",
            description: "Created case: \(caseRecord.caseNumber) - \(caseRecord.subject)",
            metadata: [
                "original_event_type": "case_created",
                "entity_id": entityId.raw.uuidString,
                "case_number": caseRecord.caseNumber
            ]
        )

        return entityId
    }

    /// Updates case status.
    public func updateCaseStatus(
        _ entityId: EntityId,
        newStatus: CaseStatus,
        resolution: String? = nil,
        resolutionType: ResolutionType? = nil,
        principal: String
    ) async throws {
        guard var caseRecord = await world.getComponent(entityId, CaseComponent.self) else {
            throw ConexusError.caseNotFound(CaseId())
        }

        caseRecord.updateStatus(newStatus)
        if let resolution = resolution {
            caseRecord.resolution = resolution
        }
        if let resolutionType = resolutionType {
            caseRecord.resolutionType = resolutionType
        }

        await world.addComponent(entityId, caseRecord)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "ConexusService",
            description: "Updated case \(caseRecord.caseNumber) status to \(newStatus.rawValue)",
            metadata: [
                "original_event_type": "case_status_updated",
                "entity_id": entityId.raw.uuidString,
                "case_number": caseRecord.caseNumber,
                "new_status": newStatus.rawValue
            ]
        )
    }

    // MARK: - Activity Operations

    /// Logs an activity.
    public func logActivity(
        _ activity: ActivityComponent,
        principal: String
    ) async throws -> EntityId {
        let entityId = await world.createEntity()

        await world.addComponent(entityId, activity)

        // Update last contacted date on related contacts
        for contactId in activity.contactIds {
            let contacts = await findContacts { $0.contactId == contactId }
            if let (contactEntityId, _) = contacts.first {
                try? await updateContact(contactEntityId, update: { contact in
                    contact.lastContactedAt = activity.occurredAt
                }, principal: "system")
            }
        }

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "ConexusService",
            description: "Logged \(activity.activityType.rawValue): \(activity.subject)",
            metadata: [
                "original_event_type": "activity_logged",
                "entity_id": entityId.raw.uuidString,
                "activity_type": activity.activityType.rawValue
            ]
        )

        return entityId
    }

    /// Gets activity timeline for a contact.
    public func getActivityTimeline(
        contactId: ContactId,
        limit: Int = 50
    ) async -> [ActivityComponent] {
        let activityEntities = await world.entitiesWith(ActivityComponent.self)
        var activities: [ActivityComponent] = []

        for entityId in activityEntities {
            if let activity = await world.getComponent(entityId, ActivityComponent.self),
               activity.contactIds.contains(contactId) {
                activities.append(activity)
            }
        }

        activities.sort { $0.occurredAt > $1.occurredAt }
        return Array(activities.prefix(limit))
    }

    // MARK: - Pipeline Management

    /// Registers a custom pipeline.
    public func registerPipeline(_ pipeline: PipelineDefinition) {
        pipelines[pipeline.id] = pipeline
    }

    /// Gets a pipeline by ID.
    public func getPipeline(_ pipelineId: PipelineId) -> PipelineDefinition? {
        pipelines[pipelineId]
    }

    /// Lists all registered pipelines.
    public func listPipelines() -> [PipelineDefinition] {
        Array(pipelines.values)
    }
}

// MARK: - Summary Types

/// Summary of a pipeline stage.
public struct StageSummary: Sendable {
    public let stage: PipelineStage
    public let dealCount: Int
    public let totalValue: Decimal
    public let weightedValue: Decimal
}

/// Summary of a pipeline.
public struct PipelineSummary: Sendable {
    public let pipeline: PipelineDefinition
    public let stages: [StageSummary]
    public let generatedAt: Date

    public var totalDeals: Int {
        stages.reduce(0) { $0 + $1.dealCount }
    }

    public var totalValue: Decimal {
        stages.reduce(0) { $0 + $1.totalValue }
    }

    public var weightedPipelineValue: Decimal {
        stages.reduce(0) { $0 + $1.weightedValue }
    }
}
