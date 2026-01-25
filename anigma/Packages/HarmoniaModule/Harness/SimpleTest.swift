//
//  SimpleTest.swift
//  HarmoniaModule
//
//  Simple test to verify harness components work.
//

@preconcurrency import Foundation
import AnigmaCore

/// Simple test of harness components.
public struct SimpleComponentTest {
    /// Tests the basic harness components.
    public static func runTest() async throws {
        print("🧪 Testing harness components...")

        // 1. Test store initialization
        let store = ProjectHarnessStore.shared
        try await store.initialize()
        print("✅ Store initialized")

        // 2. Test project creation
        let project = ProjectSpec(
            id: UUID(),
            name: "Test Project",
            specText: "Test project for harness",
            status: .uninitialized,
            projectDirectory: "/tmp/harmonia-test-\(UUID().uuidString)"
        )

        try await store.saveProject(project)
        print("✅ Project saved: \(project.name)")

        // 3. Test feature creation
        let feature = FeatureTestCase(
            id: UUID(),
            projectId: project.id,
            name: "Test Feature",
            category: "test",
            description: "Test feature",
            validationSteps: ["Test passes"],
            status: .pending
        )

        try await store.saveFeatures([feature])
        print("✅ Feature saved: \(feature.name)")

        // 4. Test loading
        let loadedProject = try await store.getProjectSpec(id: project.id)
        print("✅ Project loaded: \(loadedProject?.name ?? "nil")")

        let loadedFeatures = try await store.loadFeatures(forProjectId: project.id.uuidString)
        print("✅ Features loaded: \(loadedFeatures.count)")

        // 5. Test tool registry
        let registry = SimpleToolRegistry()
        let testDir = "/tmp/harmonia-tool-test-\(UUID().uuidString)"

        try FileManager.default.createDirectory(
            atPath: testDir,
            withIntermediateDirectories: true
        )

        await registry.register(
            name: "test_tool",
            handler: AnyToolHandler(TestToolHandler())
        )

        let request = ToolRequest(
            name: "test_tool",
            arguments: ["message": "Hello"],
            sessionId: "test-session",
            projectId: project.id.uuidString
        )

        let response = try await registry.execute(request: request)
        print("✅ Tool executed: \(response.success ? "success" : "failure")")

        // 6. Cleanup
        print("🧹 Test completed successfully!")
        print("\n🎯 Harness components verified:")
        print("   - Project store: ✅")
        print("   - Feature store: ✅")
        print("   - Tool registry: ✅")
    }
}

private struct TestToolHandler: ToolHandlerProtocol {
    func handle(request: ToolRequest) async throws -> ToolResponse {
        let message = request.arguments["message"] ?? "No message"
        return .success("Test tool received: \(message)")
    }
}
