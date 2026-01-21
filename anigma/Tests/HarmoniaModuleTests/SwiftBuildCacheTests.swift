//
//  SwiftBuildCacheTests.swift
//  HarmoniaModuleTests
//
//  Unit tests for SwiftBuildCache component with file-level caching
//

import XCTest
import AnigmaPrimitives
import DatabaseCore
@testable import HarmoniaModule

final class SwiftBuildCacheTests: XCTestCase {
    var tempDir: URL!
    var dbActor: DatabaseActor!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary directory and database
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let dbPath = tempDir.appendingPathComponent("test.sqlite").path
        dbActor = DatabaseActor(dbPath: dbPath)
        try await dbActor.open()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testCacheQueryStructure() {
        let query = CacheQuery(
            filePath: "Sources/AnigmaCore/main.swift",
            target: "AnigmaCore",
            configuration: "debug",
            currentHash: "abc123",
            gitStateId: "git123",
            compilerVersion: "swift-5.10",
            compilerFlags: ["-Xswiftc", "-strict-concurrency=complete"]
        )

        XCTAssertEqual(query.filePath, "Sources/AnigmaCore/main.swift")
        XCTAssertEqual(query.target, "AnigmaCore")
        XCTAssertEqual(query.configuration, "debug")
        XCTAssertEqual(query.currentHash, "abc123")
        XCTAssertEqual(query.compilerVersion, "swift-5.10")
        XCTAssertEqual(query.compilerFlags.count, 2)
    }

    func testCacheEntryStructure() {
        guard let objectData = "compiled binary data".data(using: .utf8) else {
            fatalError("Failed to unwrap objectData")
        }

        let entry = CacheEntry(
            filePath: "Sources/AnigmaCore/main.swift",
            fileHash: "file_hash_123",
            target: "AnigmaCore",
            configuration: "debug",
            objectFile: objectData,
            objectHash: "object_hash_456",
            imports: ["Foundation", "AnigmaPrimitives"],
            compilerVersion: "swift-5.10",
            compilerFlags: [],
            gitStateId: "git_state_123"
        )

        XCTAssertEqual(entry.filePath, "Sources/AnigmaCore/main.swift")
        XCTAssertEqual(entry.imports.count, 2)
        XCTAssertEqual(entry.objectFile, objectData)
    }

    func testCacheLookupResultStructure() {
        let result = CacheLookupResult(
            hit: true,
            cachedArtifactId: "artifact_123",
            reason: "cache_hit"
        )

        XCTAssertTrue(result.hit)
        XCTAssertEqual(result.cachedArtifactId, "artifact_123")
        XCTAssertEqual(result.reason, "cache_hit")
    }

    func testCacheMissReason() {
        let missResult = CacheLookupResult(
            hit: false,
            reason: "cache_miss_hash_mismatch"
        )

        XCTAssertFalse(missResult.hit)
        XCTAssertEqual(missResult.reason, "cache_miss_hash_mismatch")
    }
}
