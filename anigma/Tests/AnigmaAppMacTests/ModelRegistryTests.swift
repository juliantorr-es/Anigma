//
//  ModelRegistryTests.swift
//  AnigmaAppMac
//
//  Tests for governed model registry with ModelSpec contracts.
//

import XCTest
@testable import AnigmaAppMac

@MainActor
final class ModelRegistryTests: XCTestCase {
    var tempDir: URL!
    var registry: ModelRegistry!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let registryPath = tempDir.appendingPathComponent("model_registry.json")
        registry = try ModelRegistry(registryPath: registryPath)
    }

    override func tearDown() async throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
    }

    func testRegisterAndFind() async throws {
        let spec = ModelSpec(
            modelId: "test-model-1",
            modelHash: "abc123",
            taskKind: .inference,
            backendFormat: "mlx",
            dimension: 512,
            tokenizerHash: "tok123",
            license: "MIT",
            trustTier: .firstClass,
            source: ModelSource(type: .local, location: "/tmp/model", revision: "v1.0")
        )

        try await registry.register(spec)

        let found = try await registry.find(id: "test-model-1")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.modelId, "test-model-1")
        XCTAssertEqual(found?.taskKind, .inference)
        XCTAssertEqual(found?.trustTier, .firstClass)
    }

    func testQueryByTaskKind() async throws {
        let spec1 = ModelSpec(
            modelId: "llm-1",
            modelHash: "hash1",
            taskKind: .inference,
            backendFormat: "mlx",
            trustTier: .firstClass,
            source: ModelSource(type: .bundled, location: "/models/llm1")
        )

        let spec2 = ModelSpec(
            modelId: "embed-1",
            modelHash: "hash2",
            taskKind: .embedding,
            backendFormat: "mlx",
            dimension: 384,
            trustTier: .compatible,
            source: ModelSource(type: .bundled, location: "/models/embed1")
        )

        try await registry.register(spec1)
        try await registry.register(spec2)

        let llms = try await registry.query(taskKind: .inference)
        XCTAssertEqual(llms.count, 1)
        XCTAssertEqual(llms.first?.modelId, "llm-1")

        let embeddings = try await registry.query(taskKind: .embedding)
        XCTAssertEqual(embeddings.count, 1)
        XCTAssertEqual(embeddings.first?.modelId, "embed-1")
    }

    func testQueryByTrustTier() async throws {
        let spec1 = ModelSpec(
            modelId: "trusted-1",
            modelHash: "hash1",
            taskKind: .inference,
            backendFormat: "mlx",
            trustTier: .firstClass,
            source: ModelSource(type: .bundled, location: "/models/trusted")
        )

        let spec2 = ModelSpec(
            modelId: "experimental-1",
            modelHash: "hash2",
            taskKind: .inference,
            backendFormat: "gguf",
            trustTier: .experimental,
            source: ModelSource(type: .local, location: "/tmp/experimental")
        )

        try await registry.register(spec1)
        try await registry.register(spec2)

        let firstClass = try await registry.query(trustTier: .firstClass)
        XCTAssertEqual(firstClass.count, 1)
        XCTAssertEqual(firstClass.first?.modelId, "trusted-1")

        let experimental = try await registry.query(trustTier: .experimental)
        XCTAssertEqual(experimental.count, 1)
        XCTAssertEqual(experimental.first?.modelId, "experimental-1")
    }

    func testUpdateTrustTier() async throws {
        let spec = ModelSpec(
            modelId: "upgrade-me",
            modelHash: "hash1",
            taskKind: .inference,
            backendFormat: "mlx",
            trustTier: .experimental,
            source: ModelSource(type: .local, location: "/tmp/model")
        )

        try await registry.register(spec)

        try await registry.updateTrustTier("upgrade-me", tier: .compatible)

        let updated = try await registry.find(id: "upgrade-me")
        XCTAssertEqual(updated?.trustTier, .compatible)
    }

    func testCanonicalHash() throws {
        let spec = ModelSpec(
            modelId: "test",
            modelHash: "abc",
            taskKind: .inference,
            backendFormat: "mlx",
            trustTier: .firstClass,
            source: ModelSource(type: .bundled, location: "/path")
        )

        let hash1 = try spec.canonicalHash()
        let hash2 = try spec.canonicalHash()

        // Same spec should produce same hash (determinism)
        XCTAssertEqual(hash1, hash2)
        XCTAssertFalse(hash1.isEmpty)
    }

    func testDelete() async throws {
        let spec = ModelSpec(
            modelId: "delete-me",
            modelHash: "hash",
            taskKind: .inference,
            backendFormat: "mlx",
            trustTier: .experimental,
            source: ModelSource(type: .local, location: "/tmp/delete")
        )

        try await registry.register(spec)
        XCTAssertNotNil(try await registry.find(id: "delete-me"))

        try await registry.delete("delete-me")
        XCTAssertNil(try await registry.find(id: "delete-me"))
    }

    func testListAll() async throws {
        let spec1 = ModelSpec(
            modelId: "model-1",
            modelHash: "hash1",
            taskKind: .inference,
            backendFormat: "mlx",
            trustTier: .firstClass,
            source: ModelSource(type: .bundled, location: "/m1")
        )

        let spec2 = ModelSpec(
            modelId: "model-2",
            modelHash: "hash2",
            taskKind: .embedding,
            backendFormat: "mlx",
            trustTier: .compatible,
            source: ModelSource(type: .bundled, location: "/m2")
        )

        try await registry.register(spec1)
        try await registry.register(spec2)

        let all = try await registry.listAll()
        XCTAssertEqual(all.count, 2)
    }
}
