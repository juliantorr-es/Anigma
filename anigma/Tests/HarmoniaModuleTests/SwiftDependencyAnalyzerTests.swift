//
//  SwiftDependencyAnalyzerTests.swift
//  HarmoniaModuleTests
//
//  Unit tests for SwiftDependencyAnalyzer component
//

import XCTest
@testable import HarmoniaModule

final class SwiftDependencyAnalyzerTests: XCTestCase {
    var analyzer: SwiftDependencyAnalyzer!
    var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()

        analyzer = SwiftDependencyAnalyzer()

        // Create temporary directory for test files
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testDependencyNodeStructure() {
        let node = DependencyNode(
            filePath: "Sources/main.swift",
            imports: ["Foundation", "AnigmaCore"]
        )

        XCTAssertEqual(node.filePath, "Sources/main.swift")
        XCTAssertEqual(node.imports.count, 2)
        XCTAssert(node.imports.contains("Foundation"))
    }

    func testDependencyEdgeStructure() {
        let edge = DependencyEdge(
            from: "Sources/main.swift",
            to: "Sources/helper.swift",
            isLocal: true
        )

        XCTAssertEqual(edge.from, "Sources/main.swift")
        XCTAssertEqual(edge.to, "Sources/helper.swift")
        XCTAssertTrue(edge.isLocal)
    }

    func testDependencyEdgeEquality() {
        let edge1 = DependencyEdge(from: "A.swift", to: "B.swift", isLocal: true)
        let edge2 = DependencyEdge(from: "A.swift", to: "B.swift", isLocal: true)
        let edge3 = DependencyEdge(from: "A.swift", to: "B.swift", isLocal: false)

        XCTAssertEqual(edge1, edge2)
        XCTAssertNotEqual(edge1, edge3)
    }

    func testDependencyGraphStructure() {
        let nodes: [String: DependencyNode] = [
            "main.swift": DependencyNode(filePath: "main.swift", imports: ["Foundation"]),
            "helper.swift": DependencyNode(filePath: "helper.swift", imports: [])
        ]

        let edges = [
            DependencyEdge(from: "main.swift", to: "helper.swift", isLocal: true)
        ]

        let graph = DependencyGraph(
            nodes: nodes,
            edges: edges
        )

        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.edges.count, 1)
    }

    func testTransitiveDependencies() {
        let nodes: [String: DependencyNode] = [
            "A.swift": DependencyNode(filePath: "A.swift", imports: ["B"]),
            "B.swift": DependencyNode(filePath: "B.swift", imports: ["C"]),
            "C.swift": DependencyNode(filePath: "C.swift", imports: [])
        ]

        let edges = [
            DependencyEdge(from: "A.swift", to: "B.swift", isLocal: true),
            DependencyEdge(from: "B.swift", to: "C.swift", isLocal: true)
        ]

        let graph = DependencyGraph(nodes: nodes, edges: edges)
        let transitiveDeps = graph.transitiveDependencies(of: "A.swift")

        XCTAssertTrue(transitiveDeps.contains("B.swift"))
        XCTAssertTrue(transitiveDeps.contains("C.swift"))
        XCTAssertEqual(transitiveDeps.count, 2)
    }

    func testInferModuleName() {
        let name1 = SwiftDependencyAnalyzer.inferModuleName(from: "Sources/AnigmaCore/main.swift")
        XCTAssertEqual(name1, "AnigmaCore")

        let name2 = SwiftDependencyAnalyzer.inferModuleName(from: "test.swift")
        XCTAssertEqual(name2, "test")
    }

    func testCycleDetectionNoCycle() {
        let nodes: [String: DependencyNode] = [
            "A.swift": DependencyNode(filePath: "A.swift", imports: ["B"]),
            "B.swift": DependencyNode(filePath: "B.swift", imports: [])
        ]

        let edges = [
            DependencyEdge(from: "A.swift", to: "B.swift", isLocal: true)
        ]

        let graph = DependencyGraph(nodes: nodes, edges: edges)
        XCTAssertFalse(graph.hasCycle())
    }

    func testCycleDetectionWithCycle() {
        let nodes: [String: DependencyNode] = [
            "A.swift": DependencyNode(filePath: "A.swift", imports: ["B"]),
            "B.swift": DependencyNode(filePath: "B.swift", imports: ["A"])
        ]

        let edges = [
            DependencyEdge(from: "A.swift", to: "B.swift", isLocal: true),
            DependencyEdge(from: "B.swift", to: "A.swift", isLocal: true)
        ]

        let graph = DependencyGraph(nodes: nodes, edges: edges)
        XCTAssertTrue(graph.hasCycle())
    }

    func testDependencyGraphTestHelper() {
        let testGraph = SwiftDependencyAnalyzer.createTestGraph()

        XCTAssertEqual(testGraph.nodes.count, 3)
        XCTAssertEqual(testGraph.edges.count, 3)
        XCTAssertFalse(testGraph.hasCycle())
    }
}
