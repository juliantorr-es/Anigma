//
//  BuildExecutorTests.swift
//  HarmoniaModuleTests
//
//  Unit tests for BuildExecutor component
//

import XCTest
import AnigmaPrimitives
import DatabaseCore
@testable import HarmoniaModule

final class BuildExecutorTests: XCTestCase {
    var executor: BuildExecutor!
    var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary directory for tests
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Initialize executor with temp directory
        executor = BuildExecutor(workingDirectory: tempDir)
    }

    override func tearDown() async throws {
        try await super.tearDown()

        // Cleanup temp directory
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testBuildExecutorInitialization() {
        XCTAssertNotNil(executor)
    }

    func testBuildRequestStructure() {
        let request = BuildRequest(
            target: "TestTarget",
            configuration: .debug,
            additionalFlags: ["-Xswiftc", "-strict-concurrency=complete"],
            environment: ["TEST": "value"]
        )

        XCTAssertEqual(request.target, "TestTarget")
        XCTAssertEqual(request.configuration, .debug)
        XCTAssertEqual(request.additionalFlags.count, 2)
        XCTAssertEqual(request.environment?["TEST"], "value")
    }

    func testBuildConfigurationValues() {
        XCTAssertEqual(BuildConfiguration.debug.rawValue, "debug")
        XCTAssertEqual(BuildConfiguration.release.rawValue, "release")

        XCTAssertEqual(BuildConfiguration(rawValue: "debug"), .debug)
        XCTAssertEqual(BuildConfiguration(rawValue: "release"), .release)
    }

    func testBuildResultStructure() {
        let startTime = Date()
        let endTime = Date(timeIntervalSinceNow: 5)
        let duration = endTime.timeIntervalSince(startTime)

        let result = BuildResult(
            stdout: "Build output",
            stderr: "",
            exitCode: 0,
            duration: duration,
            startTimestamp: startTime,
            endTimestamp: endTime
        )

        XCTAssertEqual(result.stdout, "Build output")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertGreaterThan(result.duration, 0)
        XCTAssertEqual(result.startTimestamp, startTime)
        XCTAssertEqual(result.endTimestamp, endTime)
    }

    func testBuildExecutorErrorTypes() {
        let timeoutError = BuildExecutorError.timeout(1800)
        XCTAssertEqual(timeoutError.errorDescription, "Build timed out after 1800 seconds")

        let invalidPathError = BuildExecutorError.invalidSwiftPath("/invalid/path")
        XCTAssertTrue(invalidPathError.errorDescription?.contains("Invalid Swift executable path") ?? false)
    }

    func testBuildConfigurationRawValues() {
        let debugConfig = BuildConfiguration.debug
        let releaseConfig = BuildConfiguration.release

        XCTAssertEqual(debugConfig.rawValue, "debug")
        XCTAssertEqual(releaseConfig.rawValue, "release")
    }
}
