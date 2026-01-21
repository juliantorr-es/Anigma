//
//  ConexusModuleTests.swift
//  ConexusModuleTests
//
//  Tests for the Conexus CRM module.
//

import Testing
import Foundation
@testable import AnigmaCore
@testable import ConexusModule

@Suite("Conexus Module Tests")
struct ConexusModuleTests {

    // MARK: - Contact Tests

    @Test("Contact component basic properties")
    func contactBasicProperties() {
        let contact = ContactComponent(
            firstName: "Jane",
            lastName: "Doe",
            prefix: "Dr.",
            emails: [EmailAddress(address: "jane@example.com", type: .work, isPrimary: true)],
            phones: [PhoneNumber(number: "555-1234", type: .mobile, isPrimary: true)]
        )

        #expect(contact.fullName == "Dr. Jane Doe")
        #expect(contact.displayName == "Jane")
        #expect(contact.primaryEmail == "jane@example.com")
        #expect(contact.primaryPhone == "555-1234")
    }

    @Test("Contact with organization")
    func contactWithOrganization() {
        let orgId = OrganizationId()
        let contact = ContactComponent(
            contactType: .client,
            firstName: "John",
            lastName: "Smith",
            title: "CEO",
            department: "Executive",
            organizationId: orgId
        )

        #expect(contact.contactType == .client)
        #expect(contact.title == "CEO")
        #expect(contact.organizationId == orgId)
    }

    @Test("Contact with accessibility preferences")
    func contactAccessibilityPreferences() {
        let contact = ContactComponent(
            firstName: "Alex",
            lastName: "Rivera",
            accommodationNeeds: ["Large print", "Extended time"],
            preferredFormats: [.largePrint, .audio, .electronic]
        )

        #expect(contact.accommodationNeeds.count == 2)
        #expect(contact.preferredFormats.contains(.audio))
    }

    // MARK: - Organization Tests

    @Test("Organization component basic properties")
    func organizationBasicProperties() {
        let org = OrganizationComponent(
            organizationType: .educational,
            name: "City College",
            legalName: "City College District",
            industry: "Higher Education",
            employeeCount: 500
        )

        #expect(org.name == "City College")
        #expect(org.organizationType == .educational)
        #expect(org.employeeCount == 500)
    }

    @Test("Organization hierarchy")
    func organizationHierarchy() {
        let parentId = OrganizationId()
        let org = OrganizationComponent(
            name: "DSPS Department",
            parentOrganizationId: parentId
        )

        #expect(org.parentOrganizationId == parentId)
    }

    // MARK: - Deal Tests

    @Test("Deal component basic properties")
    func dealBasicProperties() {
        let pipelineId = PipelineId()
        var deal = DealComponent(
            pipelineId: pipelineId,
            stageId: "new",
            name: "Enterprise License",
            amount: 50000,
            probability: 0.25
        )

        #expect(deal.name == "Enterprise License")
        #expect(deal.amount == 50000)
        #expect(deal.weightedAmount == 12500)
        #expect(!deal.isWon)
        #expect(!deal.isLost)

        deal.markWon()
        #expect(deal.isWon)
        #expect(deal.probability == 1.0)
    }

    @Test("Deal stage movement")
    func dealStageMovement() {
        let pipelineId = PipelineId()
        var deal = DealComponent(
            pipelineId: pipelineId,
            stageId: "new",
            name: "Test Deal"
        )

        deal.moveToStage("qualified", probability: 0.5)
        #expect(deal.stageId == "qualified")
        #expect(deal.probability == 0.5)
    }

    @Test("Deal loss tracking")
    func dealLossTracking() {
        let pipelineId = PipelineId()
        var deal = DealComponent(
            pipelineId: pipelineId,
            stageId: "negotiation",
            name: "Lost Deal"
        )

        deal.markLost(reason: "Budget constraints")
        #expect(deal.isLost)
        #expect(deal.lossReason == "Budget constraints")
        #expect(deal.probability == 0.0)
    }

    // MARK: - Case Tests

    @Test("Case component basic properties")
    func caseBasicProperties() {
        let caseRecord = CaseComponent(
            caseType: .altMediaRequest,
            priority: .high,
            subject: "Need EPUB version of textbook",
            requestedFormats: [.electronic, .audio]
        )

        #expect(caseRecord.caseType == .altMediaRequest)
        #expect(caseRecord.priority == .high)
        #expect(caseRecord.isOpen)
        #expect(caseRecord.requestedFormats.contains(.audio))
        #expect(caseRecord.caseNumber.hasPrefix("CASE-"))
    }

    @Test("Case status updates")
    func caseStatusUpdates() {
        var caseRecord = CaseComponent(
            subject: "Test case"
        )

        #expect(caseRecord.status == .new)

        caseRecord.updateStatus(.inProgress)
        #expect(caseRecord.status == .inProgress)
        #expect(caseRecord.isOpen)

        caseRecord.updateStatus(.resolved)
        #expect(caseRecord.status == .resolved)
        #expect(!caseRecord.isOpen)
        #expect(caseRecord.resolvedAt != nil)
    }

    @Test("Case escalation")
    func caseEscalation() {
        var caseRecord = CaseComponent(
            priority: .medium,
            subject: "Urgent issue"
        )

        caseRecord.escalate(to: "supervisor@example.com")
        #expect(caseRecord.escalatedTo == "supervisor@example.com")
        #expect(caseRecord.priority == .high)
    }

    // MARK: - Activity Tests

    @Test("Activity builders")
    func activityBuilders() {
        let callActivity = ActivityComponent.call(
            subject: "Follow-up call",
            direction: .outbound,
            duration: 900,
            notes: "Discussed requirements",
            createdBy: "user1"
        )

        #expect(callActivity.activityType == .call)
        #expect(callActivity.direction == .outbound)
        #expect(callActivity.formattedDuration == "15m")

        let noteActivity = ActivityComponent.note(
            content: "Important meeting notes",
            createdBy: "user2"
        )

        #expect(noteActivity.activityType == .note)
        #expect(noteActivity.body == "Important meeting notes")
    }

    @Test("Task activity completion")
    func taskActivityCompletion() {
        var task = ActivityComponent.task(
            subject: "Follow up with client",
            dueDate: Date().addingTimeInterval(86400),
            priority: .high,
            createdBy: "user1"
        )

        #expect(!task.isCompleted)

        task.complete()
        #expect(task.isCompleted)
        #expect(task.completedAt != nil)
    }

    // MARK: - Relationship Tests

    @Test("Relationship builders")
    func relationshipBuilders() {
        let contactId = ContactId()
        let orgId = OrganizationId()

        let employment = RelationshipComponent.employedBy(
            contact: contactId,
            organization: orgId,
            role: "Software Engineer"
        )

        #expect(employment.relationshipType == .employedBy)
        #expect(employment.fromType == .contact)
        #expect(employment.toType == .organization)
        #expect(employment.role == "Software Engineer")
        #expect(employment.isActive)
    }

    // MARK: - Pipeline Tests

    @Test("Pipeline definition")
    func pipelineDefinition() {
        let pipeline = PipelineDefinition.defaultSales

        #expect(pipeline.stages.count == 6)
        #expect(pipeline.defaultStageId == "new")

        let validNext = pipeline.validNextStages(from: "new")
        #expect(validNext.contains { $0.id == "qualified" })
        #expect(validNext.contains { $0.id == "closed_won" })
    }

    @Test("Alt-media pipeline")
    func altMediaPipeline() {
        let pipeline = PipelineDefinition.altMediaRequest

        #expect(pipeline.type == .altMedia)
        #expect(pipeline.stages.count == 5)
        #expect(pipeline.stages.first?.id == "submitted")
    }

    // MARK: - Service Integration Tests

    @Test("ConexusService creates contact")
    func serviceCreatesContact() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = ConexusService(world: world, governance: governance)

        let contact = ContactComponent(
            firstName: "Test",
            lastName: "User"
        )

        let entityId = try await service.createContact(contact, principal: "tester")

        let retrieved = await service.getContact(entityId)
        #expect(retrieved != nil)
        #expect(retrieved?.fullName == "Test User")
    }

    @Test("ConexusService finds contacts")
    func serviceFindsContacts() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = ConexusService(world: world, governance: governance)

        // Create contacts
        _ = try await service.createContact(
            ContactComponent(contactType: .student, firstName: "Alice", lastName: "Student"),
            principal: "tester"
        )
        _ = try await service.createContact(
            ContactComponent(contactType: .client, firstName: "Bob", lastName: "Client"),
            principal: "tester"
        )
        _ = try await service.createContact(
            ContactComponent(contactType: .student, firstName: "Carol", lastName: "Student"),
            principal: "tester"
        )

        let students = await service.findContacts { $0.contactType == .student }
        #expect(students.count == 2)
    }

    @Test("ConexusService creates deal in pipeline")
    func serviceCreatesDeal() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = ConexusService(world: world, governance: governance)

        let pipelines = await service.listPipelines()
        guard let salesPipeline = pipelines.first { $0.type == .sales } else {
            fatalError("Failed to unwrap salesPipeline")
        }

        let deal = DealComponent(
            pipelineId: salesPipeline.id,
            stageId: "new",
            name: "Test Deal",
            amount: 10000
        )

        let entityId = try await service.createDeal(deal, principal: "tester")

        let summary = await service.getPipelineSummary(salesPipeline.id)
        #expect(summary != nil)
        #expect(summary?.totalDeals == 1)
        #expect(summary?.totalValue == 10000)
    }

    @Test("ConexusService moves deal through stages")
    func serviceMovesDeal() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = ConexusService(world: world, governance: governance)

        let pipelines = await service.listPipelines()
        guard let salesPipeline = pipelines.first { $0.type == .sales } else {
            fatalError("Failed to unwrap salesPipeline")
        }

        let deal = DealComponent(
            pipelineId: salesPipeline.id,
            stageId: "new",
            name: "Moving Deal",
            amount: 5000
        )

        let entityId = try await service.createDeal(deal, principal: "tester")

        // Move to qualified
        try await service.moveDeal(entityId, toStage: "qualified", principal: "tester")

        // Move to closed won
        try await service.moveDeal(entityId, toStage: "closed_won", principal: "tester")

        // Verify final state through pipeline summary
        let summary = await service.getPipelineSummary(salesPipeline.id)
        let wonStage = summary?.stages.first { $0.stage.isWon }
        #expect(wonStage?.dealCount == 1)
    }

    @Test("ConexusService creates and updates case")
    func serviceManagesCase() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = ConexusService(world: world, governance: governance)

        let caseRecord = CaseComponent(
            caseType: .altMediaRequest,
            subject: "Need audio version",
            requestedFormats: [.audio]
        )

        let entityId = try await service.createCase(caseRecord, principal: "tester")

        try await service.updateCaseStatus(
            entityId,
            newStatus: .resolved,
            resolution: "Converted to audio format",
            resolutionType: .solved,
            principal: "tester"
        )
    }

    @Test("ConexusService logs activities")
    func serviceLogsActivities() async throws {
        let world = World()
        let governance = GovernanceController()
        let service = ConexusService(world: world, governance: governance)

        let contact = ContactComponent(firstName: "Timeline", lastName: "Test")
        let contactEntityId = try await service.createContact(contact, principal: "tester")
        guard let contactComp = await service.getContact(contactEntityId) else {
            fatalError("Failed to unwrap contactComp")
        }

        // Log activities
        _ = try await service.logActivity(
            ActivityComponent.call(
                subject: "Intro call",
                direction: .outbound,
                contactIds: [contactComp.contactId],
                createdBy: "tester"
            ),
            principal: "tester"
        )

        _ = try await service.logActivity(
            ActivityComponent.email(
                subject: "Follow-up email",
                body: "Thanks for the call",
                direction: .outbound,
                contactIds: [contactComp.contactId],
                createdBy: "tester"
            ),
            principal: "tester"
        )

        let timeline = await service.getActivityTimeline(contactId: contactComp.contactId)
        #expect(timeline.count == 2)
    }
}
