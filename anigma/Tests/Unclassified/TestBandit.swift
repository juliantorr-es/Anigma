import Foundation
import HarmoniaModule

// Simple test of bandit functionality
func testBandit() async throws {
    print("🧪 Testing Bandit Config Selector...")

    // Initialize store
    let store = ProjectHarnessStore.shared
    try store.initialize(databasePath: ":memory:")  // Use in-memory database for testing

    // Create a test project
    let projectId = UUID()
    let projectSpec = ProjectSpec(
        id: projectId,
        name: "Test Project",
        description: "Test project for bandit",
        createdAt: Date(),
        updatedAt: Date(),
        status: .active,
        metadata: [:]
    )
    try store.createProjectSpec(projectSpec)

    // Test bandit config selector
    let selector = BanditConfigSelector()

    // Test 1: Select config for a feature category (should use default initially)
    print("\nTest 1: Selecting config for UI feature...")
    let uiConfig = try await selector.selectConfig(
        projectId: projectId,
        featureCategory: "ui"
    )
    print("Selected config: \(uiConfig.name) (\(uiConfig.id))")
    print("Parameters: \(uiConfig.parameters)")

    // Test 2: Select config for backend feature
    print("\nTest 2: Selecting config for backend feature...")
    let backendConfig = try await selector.selectConfig(
        projectId: projectId,
        featureCategory: "backend"
    )
    print("Selected config: \(backendConfig.name) (\(backendConfig.id))")

    // Test 3: Update bandit stats with a reward
    print("\nTest 3: Updating bandit stats with reward...")
    try await store.updateBanditStats(
        projectId: projectId,
        featureCategory: "ui",
        configId: uiConfig.id,
        reward: 0.8  // Good reward
    )
    print("Bandit stats updated with reward 0.8")

    // Test 4: Select config again (should potentially choose same config due to good reward)
    print("\nTest 4: Selecting config for UI feature again...")
    let uiConfig2 = try await selector.selectConfig(
        projectId: projectId,
        featureCategory: "ui"
    )
    print("Selected config: \(uiConfig2.name) (\(uiConfig2.id))")

    // Test 5: Get bandit report
    print("\nTest 5: Getting bandit report...")
    let report = try await selector.getBanditReport(projectId: projectId)
    print("Bandit report generated (\(report.count) characters)")

    // Test 6: Get deprecation recommendations
    print("\nTest 6: Getting deprecation recommendations...")
    let recommendations = try await selector.getDeprecationRecommendations(projectId: projectId)
    print("Deprecation recommendations: \(recommendations)")

    print("\n✅ All tests passed!")
}

// Run the test
Task {
    do {
        try await testBandit()
        exit(0)
    } catch {
        print("❌ Test failed with error: \(error)")
        exit(1)
    }
}

// Keep the program running
RunLoop.main.run()
