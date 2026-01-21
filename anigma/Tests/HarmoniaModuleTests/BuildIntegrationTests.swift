//
//  BuildIntegrationTests.swift
//  HarmoniaModuleTests
//
//  Integration tests for the complete build system
//

import XCTest
import AnigmaPrimitives
import DatabaseCore
@testable import HarmoniaModule

final class BuildIntegrationTests: XCTestCase {
    var tempDir: URL!
    var dbPath: String!

    override func setUp() async throws {
        try await super.setUp()

        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        dbPath = tempDir.appendingPathComponent("integration.sqlite").path
    }

    override func tearDown() async throws {
        try await super.tearDown()
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testBuildSessionLifecycle() async throws {
        let db = DatabaseActor(dbPath: dbPath)
        try await db.open()

        let manager = BuildSessionManager(dbActor: db)

        // Start session
        let session = try await manager.startSession(
            target: "TestTarget",
            configuration: "debug",
            commandLine: "swift build --target TestTarget --configuration debug"
        )

        XCTAssertEqual(session.target, "TestTarget")
        XCTAssertEqual(session.configuration, "debug")
        XCTAssertEqual(session.status, .running)

        // Create mock build result
        let result = BuildResult(
            stdout: "Building...",
            stderr: "",
            exitCode: 0,
            duration: 5.0,
            startTimestamp: Date(),
            endTimestamp: Date(timeIntervalSinceNow: 5)
        )

        // Create mock diagnostics
        let diagnostics: [ParsedDiagnostic] = [
            ParsedDiagnostic(
                filePath: "Sources/main.swift",
                lineNumber: 10,
                columnNumber: 5,
                severity: "warning",
                category: "compiler",
                tool: "swiftc",
                message: "Unused variable"
            )
        ]

        // Complete session
        try await manager.completeSession(
            sessionId: session.id,
            result: result,
            diagnostics: diagnostics
        )

        // Verify session was updated
        let retrievedSession = await manager.getSession(session.id)
        XCTAssertNotNil(retrievedSession)
        XCTAssertEqual(retrievedSession?.status, .completed)
        XCTAssertEqual(retrievedSession?.exitCode, 0)
        XCTAssertEqual(retrievedSession?.warningCount, 1)
    }

    func testDiagnosticAnalysisWorkflow() async throws {
        let db = DatabaseActor(dbPath: dbPath)
        try await db.open()

        let sessionManager = BuildSessionManager(dbActor: db)
        let diagnosticAnalyzer = DiagnosticAnalyzer(dbActor: db)

        // Create a session with diagnostics
        let session = try await sessionManager.startSession(
            target: "TestTarget",
            configuration: "debug",
            commandLine: "swift build"
        )

        // Complete with diagnostics
        let buildResult = BuildResult(
            stdout: "",
            stderr: "test.swift:5:3: error: test error\ntest.swift:10:1: warning: test warning",
            exitCode: 1,
            duration: 2.0,
            startTimestamp: Date(),
            endTimestamp: Date(timeIntervalSinceNow: 2)
        )

        let diagnostics = [
            ParsedDiagnostic(
                filePath: "test.swift",
                lineNumber: 5,
                columnNumber: 3,
                severity: "error",
                tool: "swiftc",
                message: "test error"
            ),
            ParsedDiagnostic(
                filePath: "test.swift",
                lineNumber: 10,
                columnNumber: 1,
                severity: "warning",
                tool: "swiftc",
                message: "test warning"
            )
        ]

        try await sessionManager.completeSession(
            sessionId: session.id,
            result: buildResult,
            diagnostics: diagnostics
        )

        // Analyze diagnostics
        let stats = try await diagnosticAnalyzer.getStatistics(sessionId: session.id)

        XCTAssertEqual(stats.totalErrors, 1)
        XCTAssertEqual(stats.totalWarnings, 1)
        XCTAssertEqual(stats.affectedFiles.count, 1)
        XCTAssertTrue(stats.affectedFiles.contains("test.swift"))
    }

    func testBuildTimingMetrics() async throws {
        let db = DatabaseActor(dbPath: dbPath)
        try await db.open()

        let sessionManager = BuildSessionManager(dbActor: db)
        let timingAnalyzer = BuildTimingAnalyzer(dbActor: db)

        // Create a session
        let session = try await sessionManager.startSession(
            target: "TestTarget",
            configuration: "debug",
            commandLine: "swift build"
        )

        // Record timing metrics
        try await timingAnalyzer.recordTiming(
            sessionId: session.id,
            phase: .total,
            duration: 10.5,
            filesProcessed: 50,
            cacheHitRate: 0.8
        )

        try await timingAnalyzer.recordTiming(
            sessionId: session.id,
            phase: .compilation,
            duration: 8.0,
            filesProcessed: 40
        )

        try await timingAnalyzer.recordTiming(
            sessionId: session.id,
            phase: .linking,
            duration: 2.5,
            filesProcessed: 1
        )

        // Verify metrics were recorded
        let breakdown = try await timingAnalyzer.getPhaseBreakdown(sessionId: session.id)

        XCTAssertEqual(breakdown.keys.count, 3)
        XCTAssertNotNil(breakdown[.total])
        XCTAssertNotNil(breakdown[.compilation])
        XCTAssertNotNil(breakdown[.linking])
    }

    func testCacheStructures() async throws {
        let db = DatabaseActor(dbPath: dbPath)
        try await db.open()

        let cache = SwiftBuildCache(dbActor: db)

        // Test cache miss
        let query = CacheQuery(
            filePath: "Sources/main.swift",
            target: "AnigmaCore",
            configuration: "debug",
            currentHash: "abc123",
            gitStateId: "git123",
            compilerVersion: "swift-5.10"
        )

        let missResult = try await cache.lookup(query)
        XCTAssertFalse(missResult.hit)
        XCTAssertEqual(missResult.reason, "cache_miss_no_entry")
    }

    func testDependencyGraphAnalysis() async throws {
        let analyzer = SwiftDependencyAnalyzer()

        // Create test source files
        let file1URL = tempDir.appendingPathComponent("A.swift")
        let file2URL = tempDir.appendingPathComponent("B.swift")
        let file3URL = tempDir.appendingPathComponent("C.swift")

        try "import Foundation\nimport B".write(to: file1URL, atomically: true, encoding: .utf8)
        try "import Foundation\nimport C".write(to: file2URL, atomically: true, encoding: .utf8)
        try "import Foundation".write(to: file3URL, atomically: true, encoding: .utf8)

        // Build dependency graph
        let sourceFiles = [file1URL, file2URL, file3URL]
        let graph = try await analyzer.buildDependencyGraph(for: "TestTarget", sourceFiles: sourceFiles)

        XCTAssertEqual(graph.nodes.count, 3)
        XCTAssertGreaterThan(graph.edges.count, 0)
        XCTAssertFalse(graph.hasCycle())
    }
}
