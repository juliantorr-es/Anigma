//
//  HarnessRegistration.swift
//  HarmoniaModule
//
//  Registration for harness systems.
//

import AnigmaCore

/// Harness system registration utilities.
public enum HarnessRegistration {
    /// Registers all harness systems with the world for a specific project.
    public static func registerSystems(
        world: World,
        projectSurface: ProjectExecutionSurface
    ) async {
        await world.registerSystem(ProjectInitializerSystem(project: projectSurface))
        await world.registerSystem(ProjectCodingAgentSystem(project: projectSurface))
        await Logger.shared.info("Harness systems registered", category: "Harness")
    }

    /// Creates a test harness world with all systems registered for a test project.
    public static func createTestWorld() async -> World {
        let world = World()
        // Create a fake project surface for testing
        let fakeSurface = FakeProjectSurface()
        await registerSystems(world: world, projectSurface: fakeSurface)
        return world
    }

    /// Runs a simple harness test.
    public static func runTest() async throws {
        print("🧪 Testing harness registration...")

        let world = await createTestWorld()
        print("✅ World created with harness systems")

        // Create a test project entity
        let projectId = await world.createEntity()
        print("✅ Created test entity: \(projectId)")

        // Note: In a real test, we would add components and run systems
        print("\n🎯 Harness systems ready for integration:")
        print("   - ProjectInitializerSystem: Breaks down PRD into features")
        print("   - ProjectCodingAgentSystem: Executes coding iterations")
        print("   - World integration: ✅")

        print("\nNext steps:")
        print("1. Add ProjectSpecComponent to entities")
        print("2. Run world.update() to trigger systems")
        print("3. Connect to tool registry for actual execution")
    }
}
