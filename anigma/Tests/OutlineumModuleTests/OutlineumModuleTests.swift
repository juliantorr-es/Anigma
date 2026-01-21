//
//  OutlineumModuleTests.swift
//  OutlineumModuleTests
//
//  Tests for the Outlineum outline generation pipeline.
//

import XCTest
@testable import AnigmaCore
@testable import OutlineumModule

final class OutlineumModuleTests: XCTestCase {

    // MARK: - Component Tests

    func testImageComponentCreation() {
        let image = ImageComponent(originalPath: "/path/to/image.png")

        XCTAssertEqual(image.originalPath, "/path/to/image.png")
        XCTAssertNil(image.normalizedPath)
        XCTAssertEqual(image.width, 0)
        XCTAssertEqual(image.height, 0)
    }

    func testOutlineComponentFlags() {
        var outline = OutlineComponent()

        XCTAssertFalse(outline.hasKidsOutline)
        XCTAssertFalse(outline.hasAdultOutline)
        XCTAssertFalse(outline.hasAnyOutline)

        outline.kidsOutlineVector = "/path/to/kids.svg"
        XCTAssertTrue(outline.hasKidsOutline)
        XCTAssertTrue(outline.hasAnyOutline)

        outline.adultOutlineVector = "/path/to/adult.svg"
        XCTAssertTrue(outline.hasAdultOutline)
    }

    func testOutlineQAComponentDecisions() {
        var qa = OutlineQAComponent()

        qa.decisionFlags["approved_for_kids"] = true
        qa.decisionFlags["approved_for_adults"] = false
        qa.decisionFlags["needs_manual_review"] = true

        XCTAssertTrue(qa.approvedForKids)
        XCTAssertFalse(qa.approvedForAdults)
        XCTAssertTrue(qa.needsManualReview)
    }

    func testOutlineQAAverageScore() {
        var qa = OutlineQAComponent()
        qa.outlineScores["clarity"] = 0.8
        qa.outlineScores["noise"] = 0.2
        qa.outlineScores["coverage"] = 0.6

        guard let average = qa.averageOutlineScore else {
            fatalError("Failed to unwrap average")
        }
        XCTAssertEqual(average, (0.8 + 0.2 + 0.6) / 3, accuracy: 0.001)
    }

    func testZineComponentPageCount() {
        var zine = ZineComponent(title: "Test Zine")
        XCTAssertEqual(zine.pageCount, 0)

        zine.pageEntityIds = [EntityId(), EntityId(), EntityId()]
        XCTAssertEqual(zine.pageCount, 3)
    }

    // MARK: - System Registration Tests

    func testModuleRegistration() async {
        let world = World()
        let registry = WorkflowRegistry()

        try? await OutlineumModule.register(world: world, registry: registry)

        // Verify systems are registered
        let systemNames = await world.registeredSystemNames()
        XCTAssertTrue(systemNames.contains("Ingest"))
        XCTAssertTrue(systemNames.contains("Outline"))
        XCTAssertTrue(systemNames.contains("OutlineQA"))

        // Verify workflows are registered
        let workflowIds = await registry.allJobTypeIds()
        XCTAssertTrue(workflowIds.contains(OutlineJobType.identifier))
        XCTAssertTrue(workflowIds.contains(ZineJobType.identifier))
    }

    // MARK: - Pipeline Tests

    func testCreateOutlineJob() async {
        let world = World()

        let (job, entityId) = await OutlineumModule.createOutlineJob(
            imagePath: "/path/to/test.png",
            world: world
        )

        XCTAssertEqual(job.typeId, OutlineJobType.identifier)
        XCTAssertEqual(job.inputRefs.count, 1)
        XCTAssertEqual(job.inputRefs.first, entityId)

        // Verify entity has ImageComponent
        let image = await world.getComponent(entityId, ImageComponent.self)
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.originalPath, "/path/to/test.png")
    }

    func testIngestSystemSkipsNormalized() async {
        let world = World()
        let entityId = await world.createEntity()

        // Add already-normalized ImageComponent
        let image = ImageComponent(
            originalPath: "/path/to/original.png",
            normalizedPath: "/path/to/normalized.png",
            width: 100,
            height: 100
        )
        await world.addComponent(entityId, image)

        // Run ingest system
        let ingestSystem = IngestSystem()
        await ingestSystem.update(world: world)

        // Should not have changed
        let updated = await world.getComponent(entityId, ImageComponent.self)
        XCTAssertEqual(updated?.normalizedPath, "/path/to/normalized.png")
    }

    func testOutlineSystemSkipsExisting() async {
        let world = World()
        let entityId = await world.createEntity()

        // Add normalized image + existing outline
        await world.addComponent(entityId, ImageComponent(
            originalPath: "/path/to/original.png",
            normalizedPath: "/path/to/normalized.png"
        ))
        await world.addComponent(entityId, OutlineComponent(
            kidsOutlineVector: "/path/to/existing.svg"
        ))

        // Run outline system
        let outlineSystem = OutlineSystem()
        await outlineSystem.update(world: world)

        // Should not have added second outline component
        let outline = await world.getComponent(entityId, OutlineComponent.self)
        XCTAssertEqual(outline?.kidsOutlineVector, "/path/to/existing.svg")
    }

    func testOutlineQASystemSkipsExisting() async {
        let world = World()
        let entityId = await world.createEntity()

        // Add outline + existing QA
        await world.addComponent(entityId, OutlineComponent(
            kidsOutlineVector: "/path/to/outline.svg"
        ))
        await world.addComponent(entityId, OutlineQAComponent(
            overallPass: true
        ))

        // Run QA system
        let qaSystem = OutlineQASystem()
        await qaSystem.update(world: world)

        // Should not have changed
        let qa = await world.getComponent(entityId, OutlineQAComponent.self)
        XCTAssertTrue(qa?.overallPass ?? false)
    }

    // MARK: - Workflow Tests

    func testOutlineWorkflowValidation() async {
        let world = World()
        let workflow = OutlineWorkflow()

        // Create job with non-existent entity
        let badJob = Job(
            typeId: OutlineJobType.identifier,
            inputRefs: [EntityId()]  // Non-existent
        )

        do {
            try await workflow.prepare(job: badJob, world: world)
            XCTFail("Should have thrown for non-existent entity")
        } catch {
            // Expected
        }
    }

    func testOutlineWorkflowWithValidEntity() async {
        let world = World()
        let workflow = OutlineWorkflow()

        // Create valid entity with ImageComponent
        let entityId = await world.createEntity()
        await world.addComponent(entityId, ImageComponent(originalPath: "/path/to/image.png"))

        let job = Job(
            typeId: OutlineJobType.identifier,
            inputRefs: [entityId]
        )

        // Should not throw
        do {
            try await workflow.prepare(job: job, world: world)
        } catch {
            XCTFail("Should not throw for valid entity: \(error)")
        }
    }
}

// MARK: - Zine System Tests

final class ZineSystemTests: XCTestCase {

    func testZineLayoutSystemCreation() {
        let system = ZineLayoutSystem()
        XCTAssertEqual(system.name, "ZineLayout")
    }

    func testZineLayoutSystemWithCustomConfig() {
        var config = ZineLayoutConfig()
        config.pageWidth = 595  // A4
        config.pageHeight = 842

        let system = ZineLayoutSystem(config: config)
        XCTAssertEqual(system.name, "ZineLayout")
    }

    func testZineExportSystemCreation() {
        let system = ZineExportSystem()
        XCTAssertEqual(system.name, "ZineExport")
    }

    func testZineExportSystemWithOptions() {
        let system = ZineExportSystem(generateBooklet: false)
        XCTAssertEqual(system.name, "ZineExport")
    }

    func testZineWorkflowSystems() {
        let workflow = ZineWorkflow()
        XCTAssertEqual(workflow.name, "Zine Creation")
        XCTAssertEqual(workflow.jobTypeId, ZineJobType.identifier)
        XCTAssertTrue(workflow.systemNames.contains("ZineLayout"))
        XCTAssertTrue(workflow.systemNames.contains("ZineExport"))
    }

    func testZineLayoutSkipsDraft() async {
        let world = World()
        let system = ZineLayoutSystem()

        // Create zine already in generating status (not draft)
        let entityId = await world.createEntity()
        var zine = ZineComponent(title: "Test Zine")
        zine.status = .generating  // Not draft, should be skipped
        await world.addComponent(entityId, zine)

        await system.update(world: world)

        // Status should remain generating (not modified)
        let updated = await world.getComponent(entityId, ZineComponent.self)
        XCTAssertEqual(updated?.status, .generating)
    }

    func testZineExportSkipsUnready() async {
        let world = World()
        let system = ZineExportSystem()

        // Create zine in draft status (not ready for export)
        let entityId = await world.createEntity()
        let zine = ZineComponent(title: "Test Zine", status: .draft)
        await world.addComponent(entityId, zine)

        await system.update(world: world)

        // Should not have export paths
        let updated = await world.getComponent(entityId, ZineComponent.self)
        XCTAssertNil(updated?.linearPdfPath)
        XCTAssertNil(updated?.bookletPdfPath)
    }
}
