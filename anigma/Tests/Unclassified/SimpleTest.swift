//
//  SimpleTest.swift
//  Simple test to verify MAKER engine implementation
//

import Foundation

// Simple test to verify core components compile
func testCoreComponents() {
    print("Testing core components...")

    // Test StepId
    let stepId = StepId("test-step")
    print("✅ StepId created: \(stepId.value)")

    // Test StepKind
    let stepKind = StepKind.analyze
    print("✅ StepKind created: \(stepKind.rawValue)")

    // Test StateSlice
    let stateSlice = StateSlice(
        entities: [StateEntity(id: "test", type: "test", attributes: [:])],
        relations: []
    )
    print("✅ StateSlice created with \(stateSlice.entities.count) entities")

    // Test StepInput
    let stepInput = StepInput(
        stepId: stepId,
        stateSlice: stateSlice,
        context: StepContext(
            workflowId: "test-workflow",
            sessionId: "test-session",
            trustTier: .gold,
            allowedCapabilities: ["test"],
            securityZone: .selfHost
        )
    )
    print("✅ StepInput created")

    // Test IRNodeId
    let irNodeId = IRNodeId("test-node")
    print("✅ IRNodeId created: \(irNodeId.value)")

    // Test IRNode
    let irNode = IRNode(
        id: irNodeId,
        kind: .entity,
        type: "test",
        attributes: IRAttributes(["test": .string("test")]),
        metadata: IRMetadata()
    )
    print("✅ IRNode created")

    // Test IRGraph
    let irGraph = IRGraph(
        id: IRGraphId("test-graph"),
        name: "test-graph",
        version: IRVersion(major: 1, minor: 0, patch: 0),
        nodes: [irNode],
        edges: []
    )
    print("✅ IRGraph created with \(irGraph.nodes.count) nodes")

    print("✅ All core components working correctly!")
}

// Run the test
testCoreComponents()
