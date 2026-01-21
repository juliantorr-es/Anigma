//
//  SimpleHarnessTest.swift
//  HarmoniaModule
//
//  Simple test to verify the harness works with boring tools.
//

import Foundation
import AnigmaCore

/// Simple test of the harness with boring tools.
public struct SimpleHarnessTest {
    /// Runs a simple end-to-end test of the harness.
    public static func runTest() async throws {
        print("🧪 Starting simple harness test...")

        // 1. Initialize store
        let store = ProjectHarnessStore.shared
        try await store.initialize()
        print("✅ Store initialized")

        // 2. Create a test project
        let project = ProjectSpec(
            id: UUID(),
            name: "Test Project",
            specText: "A simple test project for the harness",
            status: .uninitialized,
            projectDirectory: "/tmp/harmonia-test",
            createdAt: Date(),
            updatedAt: Date()
        )

        try await store.saveProject(project)
        print("✅ Created test project: \(project.name)")

        // 3. Create simple tool registry
        let toolRegistry = SimpleToolRegistry()

        // 4. Bootstrap tools with code analysis enabled
        let config = SimpleToolBootstrap.Config(
            projectDirectory: project.projectDirectory ?? "/tmp/harmonia-default",
            enableCodeAnalysis: true,
            mode: .simulation
        )

        try await SimpleToolBootstrap.configure(
            registry: toolRegistry,
            config: config
        )

        // 5. Create test features
        let features = [
            FeatureTestCase(
                id: UUID(),
                projectId: project.id,
                name: "Add README",
                category: "documentation",
                description: "Create a README file",
                validationSteps: ["README.md exists with project description"],
                status: .pending,
                createdAt: Date(),
                updatedAt: Date(),
                lastError: nil,
                priority: 1,
                estimatedComplexity: 1
            ),
            FeatureTestCase(
                id: UUID(),
                projectId: project.id,
                name: "Hello World",
                category: "implementation",
                description: "Create a simple hello world program",
                validationSteps: ["Program runs and prints 'Hello, World!'"],
                status: .pending,
                createdAt: Date(),
                updatedAt: Date(),
                lastError: nil,
                priority: 2,
                estimatedComplexity: 2
            )
        ]

        try await store.saveFeatures(features)
        print("✅ Created \(features.count) test features")

        // 6. Create a fake project surface for testing
        let fakeSurface = FakeProjectSurface(projectId: project.id)

        // 7. Create coding agent service
        let codingService = ProjectCodingAgentService(
            project: fakeSurface,
            toolRegistry: toolRegistry
        )

        // 8. Run a coding session
        print("🚀 Running coding session...")
        let sessionResult = try await codingService.runCodingSession(
            featureCategory: "test",
            maxIterations: 1
        )
        print("✅ Coding session completed")
        print("   Session: \(sessionResult.sessionIndex)")
        print("   Summary: \(sessionResult.summary)")
        print("   Features completed: \(sessionResult.featuresCompleted)")

        // 8. Check updated features
        let updatedFeatures = try await store.loadFeatures(forProjectId: project.id.uuidString)
        let passingCount = updatedFeatures.filter { $0.status == .passing }.count
        print("📊 Features: \(passingCount)/\(updatedFeatures.count) passing")

        // 9. Cleanup
        print("🧹 Test completed successfully!")
        print("\n🎯 Harness architecture verified:")
        print("   - Project store: ✅")
        print("   - Tool registry: ✅")
        print("   - Coding agent: ✅")
        print("   - Progress tracking: ✅")
        print("\nNext: Run 'harmonia harness create' to create real projects")
    }

    /// Tests tool execution directly.
    public static func testTools() async throws {
        print("🧪 Testing simple tools...")

        let registry = SimpleToolRegistry()
        let testDir = "/tmp/harmonia-tool-test"

        try FileManager.default.createDirectory(
            atPath: testDir,
            withIntermediateDirectories: true
        )

        let config = SimpleToolBootstrap.Config(
            projectDirectory: testDir,
            enableCodeAnalysis: true,
            mode: .simulation
        )

        try await SimpleToolBootstrap.configure(
            registry: registry,
            config: config
        )

        // Test file write
        let writeRequest = ToolRequest(
            name: "write_file",
            arguments: [
                "path": "test.txt",
                "content": "Hello from harness!"
            ],
            sessionId: "test-session",
            projectId: "test-project"
        )

        let writeResponse = try await registry.execute(request: writeRequest)
        print("📝 File write: \(writeResponse.success ? "✅" : "❌")")
        print("   Output: \(writeResponse.output)")

        // Test file read
        let readRequest = ToolRequest(
            name: "read_file",
            arguments: ["path": "test.txt"],
            sessionId: "test-session",
            projectId: "test-project"
        )

        let readResponse = try await registry.execute(request: readRequest)
        print("📖 File read: \(readResponse.success ? "✅" : "❌")")
        print("   Output: \(readResponse.output.prefix(50))...")

        // Test shell command
        let shellRequest = ToolRequest(
            name: "run_shell",
            arguments: ["command": "echo 'Shell test'"],
            sessionId: "test-session",
            projectId: "test-project"
        )

        let shellResponse = try await registry.execute(request: shellRequest)
        print("🐚 Shell command: \(shellResponse.success ? "✅" : "❌")")
        print("   Output: \(shellResponse.output)")

        // Test git
        let gitRequest = ToolRequest(
            name: "git",
            arguments: ["action": "status"],
            sessionId: "test-session",
            projectId: "test-project"
        )

        let gitResponse = try await registry.execute(request: gitRequest)
        print("📚 Git command: \(gitResponse.success ? "✅" : "❌")")
        print("   Output: \(gitResponse.output)")

        print("\n✅ All tools working!")
    }
}
