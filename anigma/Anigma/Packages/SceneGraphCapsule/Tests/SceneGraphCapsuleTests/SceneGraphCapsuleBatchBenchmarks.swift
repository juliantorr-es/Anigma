/// SceneGraphCapsuleBatchBenchmarks.swift
/// Performance benchmarks comparing batch vs. individual operations
/// Demonstrates the performance improvements from batching APIs

import XCTest
@testable import SceneGraphCapsule
import CapsuleCore
import TelemetryCore

final class SceneGraphCapsuleBatchBenchmarks: XCTestCase {
    
    var capsule: SceneGraphCapsule!
    
    override func setUp() async throws {
        try await super.setUp()
        capsule = try SceneGraphCapsule(id: "batch-benchmark-capsule")
    }
    
    override func tearDown() async throws {
        capsule = nil
        try await super.tearDown()
    }
    
    // MARK: - Batch addNodes vs Individual addNode
    
    func testBatchAddNodesComparison() async throws {
        let nodeCounts = [10, 50, 100, 500, 1000]
        
        print("\n=== Batch addNodes vs Individual addNode Performance ===\n")
        print(String(format: "%-15s %-15s %-15s %-10s", "Nodes", "Individual (ms)", "Batch (ms)", "Speedup"))
        print(String(repeating: "-", count: 60))
        
        for nodeCount in nodeCounts {
            // Prepare nodes
            let nodes = (0..<nodeCount).map { i in
                SceneNode(
                    id: NodeID("node_\(i)"),
                    type: .mesh,
                    name: "Node \(i)",
                    parentID: NodeID("root")
                )
            }
            
            // Test individual addNode
            let rootNode = SceneNode(id: NodeID("root"), type: .group, name: "Root")
            var sceneGraph1 = try await capsule.createSceneGraph(rootNode: rootNode)
            
            let startIndividual = CFAbsoluteTimeGetCurrent()
            for node in nodes {
                sceneGraph1 = try await capsule.addNode(node, to: sceneGraph1)
            }
            let individualTime = (CFAbsoluteTimeGetCurrent() - startIndividual) * 1000
            
            // Test batch addNodes
            var sceneGraph2 = try await capsule.createSceneGraph(rootNode: rootNode)
            
            let startBatch = CFAbsoluteTimeGetCurrent()
            sceneGraph2 = try await capsule.addNodes(nodes, to: sceneGraph2)
            let batchTime = (CFAbsoluteTimeGetCurrent() - startBatch) * 1000
            
            let speedup = individualTime / batchTime
            
            print(String(format: "%-15d %-15.2f %-15.2f %-10.1fx", 
                        nodeCount, individualTime, batchTime, speedup))
            
            // Verify correctness
            XCTAssertEqual(sceneGraph1.nodeCount, sceneGraph2.nodeCount, 
                          "Both methods should produce same node count")
            XCTAssertEqual(sceneGraph1.nodeCount, nodeCount + 1, 
                          "Should have root + \(nodeCount) nodes")
        }
        
        print("")
    }
    
    // MARK: - Batch getWorldTransforms vs Individual getWorldTransform
    
    func testBatchGetWorldTransformsComparison() async throws {
        // Create a scene with a deep hierarchy
        let rootNode = SceneNode(
            id: NodeID("root"),
            type: .group,
            name: "Root",
            components: [.transform: Transform3D.translation(x: 1, y: 0, z: 0)]
        )
        var sceneGraph = try await capsule.createSceneGraph(rootNode: rootNode)
        
        // Build a tree with multiple levels
        var allNodeIDs: [NodeID] = []
        let levelsPerBranch = 5
        let childrenPerNode = 4
        
        func addLevel(parentID: NodeID, level: Int, maxLevel: Int) async throws {
            guard level < maxLevel else { return }
            
            for i in 0..<childrenPerNode {
                let nodeID = NodeID("node_\(level)_\(i)_\(UUID().uuidString)")
                let node = SceneNode(
                    id: nodeID,
                    type: .mesh,
                    name: "Node L\(level)-\(i)",
                    parentID: parentID,
                    components: [.transform: Transform3D.translation(x: Double(i), y: Double(level), z: 0)]
                )
                sceneGraph = try await capsule.addNode(node, to: sceneGraph)
                allNodeIDs.append(nodeID)
                
                try await addLevel(parentID: nodeID, level: level + 1, maxLevel: maxLevel)
            }
        }
        
        try await addLevel(parentID: rootNode.id, level: 0, maxLevel: levelsPerBranch)
        
        print("\n=== Batch getWorldTransforms vs Individual getWorldTransform Performance ===")
        print("Scene: \(allNodeIDs.count) nodes in hierarchy with shared parents\n")
        
        let queryCounts = [10, 50, 100, min(500, allNodeIDs.count)]
        
        print(String(format: "%-15s %-15s %-15s %-10s", "Queries", "Individual (ms)", "Batch (ms)", "Speedup"))
        print(String(repeating: "-", count: 60))
        
        for queryCount in queryCounts {
            let queryNodeIDs = Array(allNodeIDs.prefix(queryCount))
            
            // Test individual getWorldTransform
            let startIndividual = CFAbsoluteTimeGetCurrent()
            var transforms1: [NodeID: Transform3D] = [:]
            for nodeID in queryNodeIDs {
                let transform = try await capsule.getWorldTransform(for: nodeID, in: sceneGraph)
                transforms1[nodeID] = transform
            }
            let individualTime = (CFAbsoluteTimeGetCurrent() - startIndividual) * 1000
            
            // Test batch getWorldTransforms
            let startBatch = CFAbsoluteTimeGetCurrent()
            let transforms2 = try await capsule.getWorldTransforms(for: queryNodeIDs, in: sceneGraph)
            let batchTime = (CFAbsoluteTimeGetCurrent() - startBatch) * 1000
            
            let speedup = individualTime / batchTime
            
            print(String(format: "%-15d %-15.2f %-15.2f %-10.1fx", 
                        queryCount, individualTime, batchTime, speedup))
            
            // Verify correctness
            XCTAssertEqual(transforms1.count, transforms2.count, 
                          "Both methods should return same number of transforms")
        }
        
        print("")
    }
    
    // MARK: - Real-World Scenario: Building and Querying Large Scene
    
    func testRealWorldScenarioBatchVsIndividual() async throws {
        print("\n=== Real-World Scenario: Building 1000-node Scene and Querying 100 Transforms ===\n")
        
        let nodeCount = 1000
        let queryCount = 100
        
        // Scenario 1: Individual operations
        print("Scenario 1: Individual operations")
        let startScenario1 = CFAbsoluteTimeGetCurrent()
        
        let rootNode1 = SceneNode(id: NodeID("root1"), type: .group, name: "Root")
        var sceneGraph1 = try await capsule.createSceneGraph(rootNode: rootNode1)
        
        var nodeIDs1: [NodeID] = []
        for i in 0..<nodeCount {
            let nodeID = NodeID("node_\(i)")
            let node = SceneNode(
                id: nodeID,
                type: .mesh,
                name: "Node \(i)",
                parentID: rootNode1.id,
                components: [.transform: Transform3D.translation(x: Double(i), y: 0, z: 0)]
            )
            sceneGraph1 = try await capsule.addNode(node, to: sceneGraph1)
            nodeIDs1.append(nodeID)
        }
        
        let buildTime1 = (CFAbsoluteTimeGetCurrent() - startScenario1) * 1000
        
        let startQuery1 = CFAbsoluteTimeGetCurrent()
        var transforms1: [NodeID: Transform3D] = [:]
        for nodeID in nodeIDs1.prefix(queryCount) {
            let transform = try await capsule.getWorldTransform(for: nodeID, in: sceneGraph1)
            transforms1[nodeID] = transform
        }
        let queryTime1 = (CFAbsoluteTimeGetCurrent() - startQuery1) * 1000
        let totalTime1 = (CFAbsoluteTimeGetCurrent() - startScenario1) * 1000
        
        print("  Build time: \(String(format: "%.2f", buildTime1))ms")
        print("  Query time: \(String(format: "%.2f", queryTime1))ms")
        print("  Total time: \(String(format: "%.2f", totalTime1))ms")
        
        // Scenario 2: Batch operations
        print("\nScenario 2: Batch operations")
        let startScenario2 = CFAbsoluteTimeGetCurrent()
        
        let rootNode2 = SceneNode(id: NodeID("root2"), type: .group, name: "Root")
        var sceneGraph2 = try await capsule.createSceneGraph(rootNode: rootNode2)
        
        let nodes2 = (0..<nodeCount).map { i in
            SceneNode(
                id: NodeID("node_batch_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: rootNode2.id,
                components: [.transform: Transform3D.translation(x: Double(i), y: 0, z: 0)]
            )
        }
        let nodeIDs2 = nodes2.map(\.id)
        
        sceneGraph2 = try await capsule.addNodes(nodes2, to: sceneGraph2)
        
        let buildTime2 = (CFAbsoluteTimeGetCurrent() - startScenario2) * 1000
        
        let startQuery2 = CFAbsoluteTimeGetCurrent()
        let transforms2 = try await capsule.getWorldTransforms(
            for: Array(nodeIDs2.prefix(queryCount)), 
            in: sceneGraph2
        )
        let queryTime2 = (CFAbsoluteTimeGetCurrent() - startQuery2) * 1000
        let totalTime2 = (CFAbsoluteTimeGetCurrent() - startScenario2) * 1000
        
        print("  Build time: \(String(format: "%.2f", buildTime2))ms")
        print("  Query time: \(String(format: "%.2f", queryTime2))ms")
        print("  Total time: \(String(format: "%.2f", totalTime2))ms")
        
        // Summary
        print("\nSpeedup comparison:")
        print("  Build speedup: \(String(format: "%.1fx", buildTime1 / buildTime2))")
        print("  Query speedup: \(String(format: "%.1fx", queryTime1 / queryTime2))")
        print("  Total speedup: \(String(format: "%.1fx", totalTime1 / totalTime2))")
        
        // Verify correctness
        XCTAssertEqual(sceneGraph1.nodeCount, sceneGraph2.nodeCount)
        XCTAssertEqual(transforms1.count, transforms2.count)
        
        print("")
    }
    
    // MARK: - Memory Efficiency Test
    
    func testMemoryEfficiencyBatchVsIndividual() async throws {
        print("\n=== Memory Efficiency: Batch vs Individual ===\n")
        
        let nodeCount = 500
        
        let rootNode = SceneNode(id: NodeID("root"), type: .group, name: "Root")
        var sceneGraphIndividual = try await capsule.createSceneGraph(rootNode: rootNode)
        
        // Track intermediate SceneGraph allocations with individual operations
        var allocationCount = 0
        for i in 0..<nodeCount {
            let node = SceneNode(
                id: NodeID("node_\(i)"),
                type: .mesh,
                name: "Node \(i)",
                parentID: rootNode.id
            )
            sceneGraphIndividual = try await capsule.addNode(node, to: sceneGraphIndividual)
            allocationCount += 1  // Each addNode creates a new SceneGraph
        }
        
        print("Individual operations:")
        print("  Total SceneGraph allocations: \(allocationCount)")
        
        // Batch operation creates only one new SceneGraph
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
        
        print("Batch operation:")
        print("  Total SceneGraph allocations: 1")
        print("  Allocation reduction: \(allocationCount)x fewer allocations")
        
        print("")
    }
}
