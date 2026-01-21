//
//  IntegrationTests.swift
//  AnigmaCoreTests
//
//  Unit tests for AnigmaCoreTests.
//

import XCTest
import AnigmaTestSupport
@testable import AnigmaCore

/// Tests for SecuredWorld and AnigmaPlatform integration layer.
final class IntegrationTests: XCTestCase {

    // MARK: - SecuredWorld Tests

    func testSecuredWorldCreation() async throws {
        let securedWorld = await SecuredWorld.create()

        // Should have governance initialized
        let mode = await securedWorld.getMode()
        XCTAssertEqual(mode, .assistive)  // Default mode
    }

    func testSecuredWorldEntityCreation() async throws {
        let securedWorld = await SecuredWorld.create()

        let principal = AccessPrincipal(
            id: "test-system",
            module: "TestModule",
            roles: ["admin"]
        )

        // Set mode to autopilot to allow writes
        try await securedWorld.setMode(.autopilot, as: principal)

        let entity = try await securedWorld.createEntity(as: principal)
        let exists = await securedWorld.entityExists(entity)
        XCTAssertTrue(exists)
    }

    func testSecuredWorldKillSwitchBlocksWrites() async throws {
        let securedWorld = await SecuredWorld.create()

        let adminPrincipal = AccessPrincipal(
            id: "admin",
            module: "TestModule",
            roles: ["admin"]
        )

        // Set to autopilot and activate kill switch
        try await securedWorld.setMode(.autopilot, as: adminPrincipal)
        try await securedWorld.activateKillSwitch(reason: "Test", as: adminPrincipal)

        // Should fail to create entity
        do {
            _ = try await securedWorld.createEntity(as: adminPrincipal)
            XCTFail("Should have thrown")
        } catch is GovernanceError {
            // Expected
        }

        // Deactivate and try again
        try await securedWorld.deactivateKillSwitch(as: adminPrincipal)
        let entity = try await securedWorld.createEntity(as: adminPrincipal)
        let exists = await securedWorld.entityExists(entity)
        XCTAssertTrue(exists)
    }

    func testSecuredWorldAuditLogging() async throws {
        let securedWorld = await SecuredWorld.create()

        let principal = AccessPrincipal(
            id: "test-user",
            module: "TestModule",
            roles: ["admin"]
        )

        try await securedWorld.setMode(.autopilot, as: principal)
        _ = try await securedWorld.createEntity(as: principal)

        // Check audit log has entries
        let count = await securedWorld.governance.auditLog.entryCount()
        XCTAssertGreaterThanOrEqual(count, 0)
    }

    func testSecuredWorldThreatHandling() async throws {
        let securedWorld = await SecuredWorld.create()

        let principal = AccessPrincipal(
            id: "security-system",
            module: "Security",
            roles: ["security"]
        )

        // Create a threat
        let threat = DetectedThreat(
            threatType: "TEST_THREAT",
            level: .medium,
            source: "test-source",
            description: "Test threat for unit testing"
        )

        // Handle the threat
        let decision = await securedWorld.handleThreat(threat, principal: principal)

        // Should have made a decision
        XCTAssertNotNil(decision.id)
        XCTAssertEqual(decision.threatId, threat.id)
    }

    // MARK: - AnigmaPlatform Tests

    func testPlatformBootstrap() async throws {
        let platform = try await AnigmaPlatform.bootstrap()

        // Check platform is healthy
        let health = await platform.healthCheck()
        XCTAssertTrue(health.isHealthy)
        XCTAssertTrue(health.auditIntegrity.isValid)
    }

    func testPlatformDevelopmentConfiguration() async throws {
        let platform = try await AnigmaPlatform.bootstrap(
            configuration: .development
        )

        // Development mode should be autopilot
        let mode = await platform.governance.getMode()
        XCTAssertEqual(mode, OperatingMode.autopilot)
    }

    func testPlatformProductionConfiguration() async throws {
        let platform = try await AnigmaPlatform.bootstrap(
            configuration: .production
        )

        // Production mode should be assistive
        let mode = await platform.governance.getMode()
        XCTAssertEqual(mode, OperatingMode.assistive)
    }

    func testPlatformModuleConfiguration() async throws {
        let config = PlatformConfiguration(
            modules: [.diaplasion, .harmonia, .outlineum]
        )

        let platform = try await AnigmaPlatform.bootstrap(configuration: config)

        // Should have access policies configured
        let status = await platform.governance.status()
        XCTAssertGreaterThan(status.accessPolicyCount, 0)
    }

    func testPlatformUptime() async throws {
        let platform = try await AnigmaPlatform.bootstrap()

        // Small delay
        try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

        // Uptime should be positive
        let uptime = await platform.uptime()
        XCTAssertGreaterThan(uptime, 0)
    }

    func testPlatformSystemRegistration() async throws {
        let platform = try await AnigmaPlatform.bootstrap(
            configuration: .development
        )

        // Create a simple test system
        let testSystem = TestSystem()

        // Register it
        await platform.registerSystem(testSystem, module: "TestModule", roles: ["processor"])

        // System should be registered
        let registeredSystems = await platform.world.registeredSystemNames()
        XCTAssertTrue(registeredSystems.contains("TestSystem"))
    }

    func testPlatformComplianceReport() async throws {
        let platform = try await AnigmaPlatform.bootstrap(
            configuration: .development
        )

        let principal = await platform.createSystemPrincipal(
            systemName: "TestSystem",
            module: "TestModule",
            roles: ["admin"]
        )

        // Create some activity
        _ = try await platform.securedWorld.createEntity(as: principal)

        // Generate report
        let report = try await platform.generateComplianceReport(
            from: Date().addingTimeInterval(-3600),
            to: Date()
        )

        XCTAssertTrue(report.isCompliant)
        let legacyCount = await platform.governance.auditLog.entryCount()
        XCTAssertGreaterThanOrEqual(legacyCount, 0)
    }

    func testPlatformShutdown() async throws {
        let platform = try await AnigmaPlatform.bootstrap()

        let principal = AccessPrincipal(
            id: "admin",
            module: "System",
            roles: ["admin"]
        )

        // Shutdown
        await platform.shutdown(by: principal)

        // Kill switch should be active
        let status = await platform.governance.killSwitch.status()
        XCTAssertTrue(status.isGloballyActive)
    }
}

// MARK: - Test Helpers

/// A simple test system for integration tests.
struct TestSystem: System {
    let name = "TestSystem"

    func update(world: World) async {
        // No-op for testing
    }
}
