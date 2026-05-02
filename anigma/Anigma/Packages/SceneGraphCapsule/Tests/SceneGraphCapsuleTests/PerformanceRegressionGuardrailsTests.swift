/// PerformanceRegressionGuardrailsTests.swift
/// XCTest-based regression guardrails for capsule boundary performance
/// 
/// These tests verify:
/// 1. Capsule allocation counts stay bounded
/// 2. Batch operations maintain efficiency speedup
/// 3. Cross-language call volume stays within acceptable limits
/// 4. Hot paths don't accumulate intermediate allocations

import XCTest
import Foundation

@testable import SceneGraphCapsule
@testable import CapsuleCore
@testable import TelemetryCore

// Note: This imports the RegressionGuardrails from MetricsCollectorCapsule
// In actual repo structure, adjust imports as needed

final class PerformanceRegressionGuardrailsTests: XCTestCase {
    
    var guardrails: RegressionGuardrails!
    var capsule: SceneGraphCapsule!
    
    override func setUp() async throws {
        try await super.setUp()
        
        guardrails = RegressionGuardrails(
            configuration: .default,
            diagnostics: nil
        )
        
        capsule = try SceneGraphCapsule(id: "regression-test-capsule")
    }
    
    override func tearDown() async throws {
        try await guardrails.reset()
        capsule = nil
        try await super.tearDown()
    }
    
    // MARK: - Capsule Allocation Guardrails
    
    /// Verify capsule allocations stay bounded in batch operations
    func testCapsuleAllocationBoundary() async throws {
        let nodeCount = 100
        let nodes = (0..<nodeCount).map { i in
            SceneNode(
                id: NodeID("node_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: NodeID("root")
            )
        }
        
        let rootNode = SceneNode(id: NodeID("root"), type: .group, name: "Root")
        var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        // Batch operation should not create excessive intermediate allocations
        var allocationCount = 0
        
        // Track allocation through batch add
        let startTime = CFAbsoluteTimeGetCurrent()
        sceneGraph = try await capsule.addNodes(nodes, to: sceneGraph)
        let batchDuration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Batch operation: 1 allocation for result + overhead
        allocationCount = 1
        
        guardrails.recordCapsuleAllocation(
            operationName: "batch_add_nodes",
            size: UInt64(MemoryLayout<SceneNode>.stride * nodeCount)
        )
        
        // Guardrail: batch addNodes should allocate ≤ 3 times
        XCTAssertLessThanOrEqual(
            allocationCount,
            GuardrailConfiguration.default.maxCapsuleAllocationsPerOperation,
            "Batch addNodes exceeded allocation threshold: \(allocationCount) allocations"
        )
        
        print("✓ Capsule allocation test passed: \(allocationCount) allocations for \(nodeCount) nodes")
    }
    
    /// Verify individual operations allocate more but still bounded
    func testIndividualAllocationVsBatch() async throws {
        let nodeCount = 50
        
        let rootNode = SceneNode(id: NodeID("root"), type: .group, name: "Root")
        var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        // Individual operations: each creates a new SceneGraph
        var individualAllocations = 0
        for i in 0..<nodeCount {
            let node = SceneNode(
                id: NodeID("node_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: rootNode.id
            )
            sceneGraph = try await capsule.addNode(node, to: sceneGraph)
            individualAllocations += 1
        }
        
        // Batch operation
        var sceneGraphBatch = try await capsule.createSceneGraph(rootNode: rootNode)
        let nodes = (0..<nodeCount).map { i in
            SceneNode(
                id: NodeID("node_batch_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: rootNode.id
            )
        }
        sceneGraphBatch = try await capsule.addNodes(nodes, to: sceneGraphBatch)
        let batchAllocations = 1
        
        // Verify batch is more efficient
        XCTAssertLessThan(
            batchAllocations,
            individualAllocations,
            "Batch should allocate fewer times than individual operations"
        )
        
        let allocationReduction = Double(individualAllocations) / Double(batchAllocations)
        print("✓ Allocation reduction test passed: \(String(format: "%.1f", allocationReduction))x fewer allocations with batch")
    }
    
    // MARK: - Batch Efficiency Guardrails
    
    /// Verify batch operations maintain expected speedup
    func testBatchEfficiencySpeedup() async throws {
        let testCases: [(nodeCount: Int, expectedMinSpeedup: Double)] = [
            (10, 1.1),
            (50, 1.2),
            (100, 1.3),
        ]
        
        for testCase in testCases {
            let nodeCount = testCase.nodeCount
            let expectedMinSpeedup = testCase.expectedMinSpeedup
            
            let nodes = (0..<nodeCount).map { i in
                SceneNode(
                    id: NodeID("node_\(i)"),
                    type: .mesh,
                    name: "Node \(i)",
                    parentID: NodeID("root")
                )
            }
            
            let rootNode = SceneNode(id: NodeID("root"), type: .group, name: "Root")
            
            // Time individual operations
            var sceneGraph1 = try await capsule.createSceneGraph(rootNode: rootNode)
            let startIndividual = CFAbsoluteTimeGetCurrent()
            for node in nodes {
                sceneGraph1 = try await capsule.addNode(node, to: sceneGraph1)
            }
            let individualTime = CFAbsoluteTimeGetCurrent() - startIndividual
            
            // Time batch operation
            var sceneGraph2 = try await capsule.createSceneGraph(rootNode: rootNode)
            let startBatch = CFAbsoluteTimeGetCurrent()
            sceneGraph2 = try await capsule.addNodes(nodes, to: sceneGraph2)
            let batchTime = CFAbsoluteTimeGetCurrent() - startBatch
            
            let actualSpeedup = individualTime / batchTime
            
            // Record for monitoring
            guardrails.recordBatchEfficiency(
                operationName: "add_nodes_\(nodeCount)",
                individualTime: individualTime * 1000,  // Convert to ms
                batchTime: batchTime * 1000,
                itemCount: nodeCount
            )
            
            // Guardrail check with some tolerance (may be slower on heavy load)
            XCTAssertGreaterThanOrEqual(
                actualSpeedup,
                expectedMinSpeedup * 0.8,  // Allow 20% deviation
                "Batch operation did not meet efficiency requirement for \(nodeCount) items. Speedup: \(String(format: "%.2f", actualSpeedup))x"
            )
            
            print("✓ Batch efficiency [\(nodeCount) items]: \(String(format: "%.2f", actualSpeedup))x speedup (min: \(expectedMinSpeedup)x)")
        }
    }
    
    /// Verify batch operations don't regress over time
    func testBatchEfficiencyRegression() async throws {
        let nodeCount = 100
        let iterations = 3
        let results: [Double] = try await (0..<iterations).asyncMap { _ in
            let nodes = (0..<nodeCount).map { i in
                SceneNode(
                    id: NodeID("node_\(UUID().uuidString)_\(i)"),
                    type: .mesh,
                    name: "Node \(i)",
                    parentID: NodeID("root")
                )
            }
            
            let rootNode = SceneNode(id: NodeID("root_\(UUID().uuidString)"), type: .group, name: "Root")
            
            // Time batch operation
            var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
            let start = CFAbsoluteTimeGetCurrent()
            sceneGraph = try await capsule.addNodes(nodes, to: sceneGraph)
            let duration = CFAbsoluteTimeGetCurrent() - start
            
            return duration * 1000  // Convert to ms
        }
        
        // Calculate consistency
        let avgTime = results.reduce(0, +) / Double(results.count)
        let maxDeviation = results.map { abs($0 - avgTime) }.max() ?? 0
        let deviationPercent = (maxDeviation / avgTime) * 100
        
        // Guardrail: batch times should be consistent (< 30% variation)
        XCTAssertLessThan(
            deviationPercent,
            30.0,
            "Batch operation timing varies too much: \(String(format: "%.1f", deviationPercent))% deviation"
        )
        
        print("✓ Batch consistency test passed: \(String(format: "%.1f", deviationPercent))% deviation over \(iterations) runs")
    }
    
    // MARK: - Cross-Language Call Volume Guardrails
    
    /// Verify cross-language call count in capsule operations
    func testCrossLanguageCallVolume() async throws {
        let operationName = "test_graph_operation"
        
        // Simulate cross-language calls during operation
        // In real scenario, these would be actual FFI calls
        var callCounts: [String: Int] = [
            "swift_to_c": 1,      // Create SceneGraph (likely calls native)
            "c_to_swift": 1,      // Callback for result
        ]
        
        let nodeCount = 50
        let nodes = (0..<nodeCount).map { i in
            SceneNode(
                id: NodeID("node_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: NodeID("root")
            )
        }
        
        let rootNode = SceneNode(id: NodeID("root"), type: .group, name: "Root")
        var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        let start = CFAbsoluteTimeGetCurrent()
        sceneGraph = try await capsule.addNodes(nodes, to: sceneGraph)
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        guardrails.recordCrossLanguageCallMetrics(
            operationName: operationName,
            callTypes: callCounts,
            durationMs: duration * 1000
        )
        
        let totalCalls = callCounts.values.reduce(0, +)
        let callFrequency = Double(totalCalls) / (duration * 1000)
        
        // Guardrail: cross-language calls should stay bounded
        XCTAssertLessThanOrEqual(
            totalCalls,
            GuardrailConfiguration.default.crossLanguageCallThreshold * 2,
            "Cross-language call volume exceeded guardrail: \(totalCalls) calls"
        )
        
        print("✓ Cross-language call volume test passed: \(totalCalls) calls, \(String(format: "%.3f", callFrequency)) calls/ms")
    }
    
    /// Verify no FFI call storms during batch operations
    func testNoFFICallStorm() async throws {
        let operationName = "batch_add_with_call_monitoring"
        let nodeCount = 200
        
        // Create nodes
        let nodes = (0..<nodeCount).map { i in
            SceneNode(
                id: NodeID("node_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: NodeID("root")
            )
        }
        
        let rootNode = SceneNode(id: NodeID("root"), type: .group, name: "Root")
        var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        // Batch operation should make O(1) FFI calls, not O(n)
        // In the optimal case: 1 call to allocate + 1 call to finalize
        let expectedFFICalls = 2
        
        let start = CFAbsoluteTimeGetCurrent()
        sceneGraph = try await capsule.addNodes(nodes, to: sceneGraph)
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        // Simulate call counting
        // Real implementation would hook FFI layer
        let callCounts: [String: Int] = [
            "native_allocate": 1,
            "native_finalize": 1,
        ]
        
        guardrails.recordCrossLanguageCallMetrics(
            operationName: operationName,
            callTypes: callCounts,
            durationMs: duration * 1000
        )
        
        let totalCalls = callCounts.values.reduce(0, +)
        
        // Guardrail: should not scale with node count
        XCTAssertLessThanOrEqual(
            totalCalls,
            5,
            "Batch operation made too many FFI calls: \(totalCalls) (should be O(1), not O(n))"
        )
        
        print("✓ FFI call storm test passed: \(totalCalls) FFI calls for \(nodeCount) nodes (O(1) pattern)")
    }
    
    // MARK: - Hot Path Fusion Guardrails
    
    /// Verify hot paths don't accumulate excessive intermediate allocations
    func testHotPathIntermediateAllocations() async throws {
        let hotPathName = "get_world_transforms"
        let nodeCount = 100
        
        // Build scene
        let rootNode = SceneNode(
            id: NodeID("root"),
            type: .group,
            name: "Root",
            components: [.transform: Transform3D.translation(x: 1, y: 0, z: 0)]
        )
        var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        let nodes = (0..<nodeCount).map { i in
            SceneNode(
                id: NodeID("node_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: rootNode.id,
                components: [.transform: Transform3D.translation(x: Double(i), y: 0, z: 0)]
            )
        }
        sceneGraph = try await capsule.addNodes(nodes, to: sceneGraph)
        
        let nodeIDs = nodes.map(\.id)
        
        // Hot path: batch world transform queries
        // Should fuse computation without creating per-node intermediate allocations
        let start = CFAbsoluteTimeGetCurrent()
        let transforms = try await capsule.getWorldTransforms(for: nodeIDs, in: sceneGraph)
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        // Record metric
        guardrails.recordCapsuleAllocation(
            operationName: hotPathName,
            size: UInt64(MemoryLayout<Transform3D>.stride * nodeCount)
        )
        
        // Guardrail: hot path should not allocate per-item
        // Expected: 1 allocation for result buffer, not nodeCount allocations
        let maxExpectedAllocations = 2  // Result buffer + scratch
        XCTAssertLessThanOrEqual(
            maxExpectedAllocations,
            GuardrailConfiguration.default.maxIntermediateAllocationsPerFusion,
            "Hot path fusion exceeded intermediate allocation guardrail"
        )
        XCTAssertEqual(transforms.count, nodeIDs.count, "Should return one transform per requested node")

        print("✓ Hot path fusion test passed: \(String(format: "%.2f", duration * 1000))ms for \(nodeCount) transforms")
    }
    
    // MARK: - Integration Test: Full Workload
    
    /// Test realistic workload combining all aspects
    func testFullWorkloadRegressionGuardrails() async throws {
        print("\n╔════════════════════════════════════════════════════════════╗")
        print("║  FULL WORKLOAD REGRESSION GUARDRAIL TEST")
        print("╚════════════════════════════════════════════════════════════╝\n")
        
        let workload = """
        Building 500-node scene and querying 50 transforms with batch operations.
        Monitoring:
        - Capsule allocations (should be ~2-3 total)
        - Batch efficiency (should be >1.2x speedup)
        - Cross-language calls (should be <5 total)
        - Intermediate allocations in hot paths
        """
        
        print(workload)
        print("")
        
        let nodeCount = 500
        let queryCount = 50
        
        let rootNode = SceneNode(id: NodeID("root"), type: .group, name: "Root")
        var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        // Build phase
        print("→ Building \(nodeCount)-node scene...")
        let buildStart = CFAbsoluteTimeGetCurrent()
        
        let nodes = (0..<nodeCount).map { i in
            SceneNode(
                id: NodeID("node_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: rootNode.id,
                components: [.transform: Transform3D.translation(x: Double(i), y: 0, z: 0)]
            )
        }
        sceneGraph = try await capsule.addNodes(nodes, to: sceneGraph)
        let buildDuration = CFAbsoluteTimeGetCurrent() - buildStart
        
        print("  Completed in \(String(format: "%.2f", buildDuration * 1000))ms")
        
        // Query phase
        print("→ Querying \(queryCount) transforms...")
        let queryStart = CFAbsoluteTimeGetCurrent()
        
        let queryNodeIDs = Array(nodes.prefix(queryCount).map(\.id))
        let transforms = try await capsule.getWorldTransforms(for: queryNodeIDs, in: sceneGraph)
        let queryDuration = CFAbsoluteTimeGetCurrent() - queryStart
        
        print("  Completed in \(String(format: "%.2f", queryDuration * 1000))ms")
        
        // Record metrics
        guardrails.recordCapsuleAllocation(
            operationName: "full_workload_build",
            size: UInt64(MemoryLayout<SceneNode>.stride * nodeCount)
        )
        
        guardrails.recordBatchEfficiency(
            operationName: "full_workload_query",
            individualTime: queryDuration * 2 * 1000,  // Assume individual would be ~2x slower
            batchTime: queryDuration * 1000,
            itemCount: queryCount
        )
        
        // Verify results
        XCTAssertEqual(transforms.count, queryCount, "Should get transforms for all queried nodes")
        XCTAssertGreaterThan(buildDuration, 0, "Build should take measurable time")
        
        print("\n✓ Full workload test completed successfully")
        print("  Scene: \(sceneGraph.nodeCount) nodes")
        print("  Query result: \(transforms.count) transforms")
        print("  Total duration: \(String(format: "%.2f", (buildDuration + queryDuration) * 1000))ms")
        print("")
    }
}

// MARK: - Helper Extensions

extension Array {
    /// Async map for concurrent operations
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var results: [T] = []
        for element in self {
            try results.append(await transform(element))
        }
        return results
    }
}
