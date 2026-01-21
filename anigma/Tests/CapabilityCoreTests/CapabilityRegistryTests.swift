//
//  CapabilityRegistryTests.swift
//  CapabilityCoreTests
//
//  Unit tests for CapabilityCoreTests.
//

import XCTest

@testable import CapabilityCore

protocol MockCapability: Capability {}

final class MockProvider: CapabilityProvider, MockCapability {
    let providerId: String = "test.mock.provider"
    var supportedCapabilities: [String] { ["test.mock"] }
}

actor MockGovernance: CapabilityRegistry.CapabilityGovernance {
    var shouldAllow: Bool = true
    var denialReason: String?

    func setAllowed(_ allowed: Bool, reason: String? = nil) {
        self.shouldAllow = allowed
        self.denialReason = reason
    }

    func canResolve(capabilityId: String, principal: String, context: [String: String]) async -> (
        allowed: Bool, reason: String?
    ) {
        return (shouldAllow, denialReason)
    }
}

actor MockAuditLog: CapabilityRegistry.CapabilityAuditLog {
    var logs:
        [(capabilityId: String, principal: String, success: Bool, metadata: [String: String])] = []

    func logResolution(
        capabilityId: String, principal: String, success: Bool, metadata: [String: String]
    ) async {
        logs.append((capabilityId, principal, success, metadata))
    }

    func getLogs() -> [(
        capabilityId: String, principal: String, success: Bool, metadata: [String: String]
    )] {
        return logs
    }
}

final class CapabilityRegistryTests: XCTestCase {

    // MARK: - ID-Based Registration Tests

    func testIDBasedRegistrationAndResolution() async {
        let registry = CapabilityRegistry.shared
        let provider = MockProvider()

        await registry.register(provider: provider)

        let resolved = await registry.resolve(capabilityId: "test.mock", as: MockCapability.self)
        XCTAssertNotNil(resolved)
        XCTAssertEqual((resolved as? MockProvider)?.providerId, provider.providerId)
    }

    func testResolveAll() async {
        let registry = CapabilityRegistry.shared
        let provider1 = MockProvider()
        let provider2 = MockProvider()

        await registry.register(provider: provider1)
        await registry.register(provider: provider2)

        let resolved = await registry.resolveAll(capabilityId: "test.mock", as: MockCapability.self)
        XCTAssertEqual(resolved.count, 2)
    }

    // MARK: - Type-Based Registration Tests

    func testTypeBasedRegistration() async {
        let registry = CapabilityRegistry.shared
        let provider = MockProvider()

        await registry.register(provider, for: MockProvider.self)

        let resolved = await registry.provider(for: MockProvider.self)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.providerId, provider.providerId)
    }

    // MARK: - Governance Integration Tests

    func testGovernanceAllowed() async {
        let registry = CapabilityRegistry.shared
        let provider = MockProvider()
        let governance = MockGovernance()
        let auditLog = MockAuditLog()

        await registry.register(provider: provider)

        let resolved = await registry.resolveWithGovernance(
            capabilityId: "test.mock",
            as: MockCapability.self,
            principal: "test-user",
            governance: governance,
            auditLog: auditLog
        )

        XCTAssertNotNil(resolved)
        let logs = await auditLog.getLogs()
        XCTAssertEqual(logs.count, 1)
        XCTAssertTrue(logs[0].success)
    }

    func testGovernanceDenied() async {
        let registry = CapabilityRegistry.shared
        let provider = MockProvider()
        let governance = MockGovernance()
        await governance.setAllowed(false, reason: "Test denial")
        let auditLog = MockAuditLog()

        await registry.register(provider: provider)

        let resolved = await registry.resolveWithGovernance(
            capabilityId: "test.mock",
            as: MockCapability.self,
            principal: "test-user",
            governance: governance,
            auditLog: auditLog
        )

        XCTAssertNil(resolved)
        let logs = await auditLog.getLogs()
        XCTAssertEqual(logs.count, 1)
        XCTAssertFalse(logs[0].success)
        XCTAssertEqual(logs[0].metadata["reason"], "Test denial")
    }

    // MARK: - Introspection Tests

    func testRegisteredCapabilityIds() async {
        let registry = CapabilityRegistry.shared
        let provider = MockProvider()

        await registry.register(provider: provider)

        let ids = await registry.registeredCapabilityIds()
        XCTAssertTrue(ids.contains("test.mock"))
    }

    func testProviderCount() async {
        let registry = CapabilityRegistry.shared
        let provider = MockProvider()

        await registry.register(provider: provider)

        let count = await registry.providerCount(for: "test.mock")
        XCTAssertGreaterThan(count, 0)
    }
}
