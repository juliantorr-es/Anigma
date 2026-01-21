//
//  AnigmaCoreTests.swift
//  AnigmaCoreTests
//
//  Tests for the AnigmaCore ECS and job system.
//

import XCTest
@testable import AnigmaCore

final class AnigmaCoreTests: XCTestCase {

    // MARK: - EntityId Tests

    func testEntityIdCreation() {
        let entity1 = EntityId()
        let entity2 = EntityId()

        XCTAssertNotEqual(entity1, entity2)
        XCTAssertEqual(entity1, entity1)
    }

    func testEntityIdFromUUID() {
        let uuid = UUID()
        let entity = EntityId(raw: uuid)

        XCTAssertEqual(entity.raw, uuid)
    }

    func testEntityIdFromString() {
        let uuidString = "550E8400-E29B-41D4-A716-446655440000"
        let entity = EntityId(uuidString: uuidString)

        XCTAssertNotNil(entity)
        XCTAssertEqual(entity?.raw.uuidString.uppercased(), uuidString)
    }

    // MARK: - World Tests

    func testWorldEntityCreation() async {
        let world = World()

        let entity = await world.createEntity()

        let exists = await world.entityExists(entity)
        XCTAssertTrue(exists)

        let count = await world.entityCount()
        XCTAssertEqual(count, 1)
    }

    func testWorldEntityDestruction() async {
        let world = World()

        let entity = await world.createEntity()
        await world.destroyEntity(entity)

        let exists = await world.entityExists(entity)
        XCTAssertFalse(exists)
    }

    func testWorldComponentAddGet() async {
        let world = World()
        let entity = await world.createEntity()

        let nameComp = NameComponent(name: "test", displayName: "Test Entity")
        await world.addComponent(entity, nameComp)

        let retrieved = await world.getComponent(entity, NameComponent.self)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "test")
        XCTAssertEqual(retrieved?.displayName, "Test Entity")
    }

    func testWorldComponentRemove() async {
        let world = World()
        let entity = await world.createEntity()

        await world.addComponent(entity, NameComponent(name: "test"))
        await world.removeComponent(entity, NameComponent.self)

        let retrieved = await world.getComponent(entity, NameComponent.self)
        XCTAssertNil(retrieved)
    }

    func testWorldQuery() async {
        let world = World()

        let e1 = await world.createEntity()
        let e2 = await world.createEntity()
        let e3 = await world.createEntity()

        await world.addComponent(e1, NameComponent(name: "first"))
        await world.addComponent(e2, NameComponent(name: "second"))
        // e3 has no NameComponent

        let results = await world.query(NameComponent.self)
        XCTAssertEqual(results.count, 2)

        let names = Set(results.map { $0.1.name })
        XCTAssertTrue(names.contains("first"))
        XCTAssertTrue(names.contains("second"))
    }

    func testWorldMultiComponentQuery() async {
        let world = World()

        let e1 = await world.createEntity()
        let e2 = await world.createEntity()

        await world.addComponent(e1, NameComponent(name: "entity1"))
        await world.addComponent(e1, TagComponent("important"))

        await world.addComponent(e2, NameComponent(name: "entity2"))
        // e2 has no TagComponent

        let results = await world.query(NameComponent.self, TagComponent.self)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].1.name, "entity1")
    }

    // MARK: - System Tests

    func testSystemRegistrationAndUpdate() async {
        let world = World()

        let entity = await world.createEntity()
        await world.addComponent(entity, StatusComponent(status: "initial"))

        // Register a simple system
        await world.registerSystem(StatusUpdateSystem())

        // Run update
        await world.update()

        let status = await world.getComponent(entity, StatusComponent.self)
        XCTAssertEqual(status?.status, "updated")
    }

    // MARK: - Job Tests

    func testJobCreation() {
        let job = Job(
            typeId: "test",
            priority: .high,
            inputRefs: [EntityId()],
            metadata: ["key": "value"],
            label: "Test Job"
        )

        XCTAssertEqual(job.typeId, "test")
        XCTAssertEqual(job.priority, .high)
        XCTAssertEqual(job.inputRefs.count, 1)
        XCTAssertEqual(job.metadata["key"], "value")
        XCTAssertEqual(job.label, "Test Job")
        XCTAssertTrue(job.isReady)
        XCTAssertFalse(job.isExpired)
    }

    func testSchedulerEnqueueDequeue() async {
        let scheduler = Scheduler()

        let job = Job(typeId: "test", priority: .normal)
        _ = try! await scheduler.enqueue(job)

        let stats = await scheduler.stats()
        XCTAssertEqual(stats.pending, 1)

        let dequeued = await scheduler.dequeue()
        XCTAssertNotNil(dequeued)
        XCTAssertEqual(dequeued?.job.id, job.id)
        XCTAssertEqual(dequeued?.status, .running)
    }

    func testSchedulerPriorityOrdering() async {
        let scheduler = Scheduler()

        let lowJob = Job(typeId: "test", priority: .low)
        let highJob = Job(typeId: "test", priority: .high)
        let normalJob = Job(typeId: "test", priority: .normal)

        _ = try! await scheduler.enqueue(lowJob)
        _ = try! await scheduler.enqueue(highJob)
        _ = try! await scheduler.enqueue(normalJob)

        // Should dequeue in priority order: high, normal, low
        let first = await scheduler.dequeue()
        XCTAssertEqual(first?.job.priority, .high)

        let second = await scheduler.dequeue()
        XCTAssertEqual(second?.job.priority, .normal)

        let third = await scheduler.dequeue()
        XCTAssertEqual(third?.job.priority, .low)
    }

    func testSchedulerCompletion() async {
        let scheduler = Scheduler()

        let job = Job(typeId: "test")
        _ = try! await scheduler.enqueue(job)
        _ = await scheduler.dequeue()

        let result = JobResult(outcome: .success, summary: "Done", actionsApplied: 1, durationMs: 100)
        await scheduler.complete(job.id, result: result)

        let record = await scheduler.get(job.id)
        XCTAssertEqual(record?.status, .completed)
        XCTAssertEqual(record?.result?.outcome, .success)
    }

    // MARK: - Shared Component Tests

    func testFileComponent() {
        let file = FileComponent(path: "/path/to/file.pdf")

        XCTAssertEqual(file.path, "/path/to/file.pdf")
        XCTAssertEqual(file.displayName, "file.pdf")
        XCTAssertEqual(file.fileExtension, "pdf")
    }

    func testMetadataComponent() {
        var meta = MetadataComponent()
        meta.values["count"] = "42"
        meta.values["enabled"] = "true"
        meta.tags = ["test", "important"]

        XCTAssertEqual(meta.getInt("count"), 42)
        XCTAssertEqual(meta.getBool("enabled"), true)
        XCTAssertTrue(meta.hasTag("test"))
    }

    func testQAComponent() {
        var qa = QAComponent()
        qa.overallScore = 0.85
        qa.scores["accuracy"] = 0.9
        qa.flags["needs_review"] = false

        XCTAssertTrue(qa.passes(threshold: 0.8))
        XCTAssertFalse(qa.passes(threshold: 0.9))
        XCTAssertFalse(qa.needsReview)
    }

    // MARK: - Scheduler Persistence Tests

    func testSchedulerSaveLoad() async throws {
        let scheduler = Scheduler()

        // Enqueue some jobs
        let job1 = Job(typeId: "test", priority: .high, label: "High priority")
        let job2 = Job(typeId: "test", priority: .normal, label: "Normal priority")
        _ = try await scheduler.enqueue(job1)
        _ = try await scheduler.enqueue(job2)

        // Save to temp file
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("scheduler_test_\(UUID().uuidString).json")

        try await scheduler.save(to: tempFile)

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempFile.path))

        // Create new scheduler and load
        let newScheduler = Scheduler()
        let restored = try await newScheduler.load(from: tempFile)

        XCTAssertEqual(restored, 2)

        // Verify jobs restored correctly
        let stats = await newScheduler.stats()
        XCTAssertEqual(stats.pending, 2)

        // Verify priority order preserved
        let first = await newScheduler.dequeue()
        XCTAssertEqual(first?.job.priority, .high)

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    func testSchedulerSaveExcludesCompleted() async throws {
        let scheduler = Scheduler()

        // Enqueue and complete one job
        let completedJob = Job(typeId: "test", label: "Completed")
        let pendingJob = Job(typeId: "test", label: "Pending")

        _ = try await scheduler.enqueue(completedJob)
        _ = try await scheduler.enqueue(pendingJob)

        // Complete one
        _ = await scheduler.dequeue()  // Gets completedJob (first in)
        await scheduler.complete(completedJob.id, result: JobResult(outcome: .success))

        // Save without completed
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("scheduler_test_\(UUID().uuidString).json")

        try await scheduler.save(to: tempFile, includeCompleted: false)

        // Load into new scheduler
        let newScheduler = Scheduler()
        let restored = try await newScheduler.load(from: tempFile)

        // Only pending job should be restored
        XCTAssertEqual(restored, 1)

        let stats = await newScheduler.stats()
        XCTAssertEqual(stats.pending, 1)

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    func testSchedulerSnapshotFormat() async throws {
        let scheduler = Scheduler()

        let job = Job(typeId: "snapshot_test", metadata: ["key": "value"])
        _ = try await scheduler.enqueue(job)

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("scheduler_snapshot_\(UUID().uuidString).json")

        try await scheduler.save(to: tempFile)

        // Read and verify it's valid JSON
        let data = try Data(contentsOf: tempFile)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["version"] as? Int, 1)
        XCTAssertNotNil(json?["savedAt"])
        XCTAssertNotNil(json?["jobs"])

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }
}

// MARK: - Test Helpers

/// Simple test system that updates StatusComponent.
struct StatusUpdateSystem: System {
    var name: String { "StatusUpdate" }

    func update(world: World) async {
        let entities = await world.query(StatusComponent.self)
        for (entity, var status) in entities {
            status.transition(to: "updated")
            await world.addComponent(entity, status)
        }
    }
}
