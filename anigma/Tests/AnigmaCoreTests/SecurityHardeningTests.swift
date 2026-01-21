//
//  SecurityHardeningTests.swift
//  AnigmaCoreTests
//
//  Tests for the security hardening infrastructure.
//

import XCTest
@testable import AnigmaCore

final class SecurityHardeningTests: XCTestCase {

    // MARK: - Bypass Protection Tests

    func testBypassProtectionBlocksUnregisteredPaths() async throws {
        let protection = BypassProtection()

        // Register a legitimate path
        await protection.registerAccessPath("SecuredWorld:createEntity")

        // Registered path should work
        try await protection.validateAccessPath(caller: "SecuredWorld", operation: "createEntity")

        // Unregistered path should throw
        do {
            try await protection.validateAccessPath(caller: "DirectWorld", operation: "createEntity")
            XCTFail("Expected bypass error")
        } catch is BypassError {
            // Expected
        }
    }

    func testBypassProtectionTracksAttempts() async throws {
        let protection = BypassProtection()
        await protection.registerAccessPath("Legitimate:operation")

        // Try multiple bypass attempts
        for _ in 0..<5 {
            try? await protection.validateAccessPath(caller: "Attacker", operation: "steal")
        }

        let stats = await protection.getStatistics()
        XCTAssertEqual(stats.totalAttempts, 5)
        XCTAssertEqual(stats.recentAttempts.count, 5)
    }

    func testBypassProtectionTriggersLockdown() async throws {
        let protection = BypassProtection()
        await protection.registerAccessPath("Legitimate:operation")

        // Try 10 bypass attempts to trigger lockdown
        for _ in 0..<10 {
            try? await protection.validateAccessPath(caller: "Attacker", operation: "steal")
        }

        let stats = await protection.getStatistics()
        XCTAssertTrue(stats.emergencyLockdown)

        // Even legitimate paths should fail during lockdown
        do {
            try await protection.validateAccessPath(caller: "Legitimate", operation: "operation")
            XCTFail("Expected lockdown error")
        } catch BypassError.emergencyLockdown {
            // Expected
        }
    }

    // MARK: - Session Risk Tracking Tests

    func testSessionRiskTrackerInitialAssessment() async {
        let tracker = SessionRiskTracker()

        let clientInfo = SessionClientInfo(ipAddress: "192.168.1.1")

        // Session with MFA should have lower risk
        let mfaSession = await tracker.registerSession(
            UUID(),
            principalId: UUID(),
            clientInfo: clientInfo,
            authMethod: .sso,
            mfaVerified: true
        )
        XCTAssertLessThan(mfaSession.currentRisk, 0.5)
        XCTAssertFalse(mfaSession.requiresStepUp)

        // Session without MFA should have higher risk
        let noMfaSession = await tracker.registerSession(
            UUID(),
            principalId: UUID(),
            clientInfo: clientInfo,
            authMethod: .password,
            mfaVerified: false
        )
        XCTAssertGreaterThan(noMfaSession.currentRisk, mfaSession.currentRisk)
    }

    func testSessionRiskIncreasesWithSuspiciousActivity() async {
        let tracker = SessionRiskTracker()
        let sessionId = UUID()

        _ = await tracker.registerSession(
            sessionId,
            principalId: UUID(),
            clientInfo: SessionClientInfo(),
            authMethod: .password,
            mfaVerified: true
        )

        // Record suspicious activities
        var assessment = await tracker.recordActivity(sessionId: sessionId, activityType: .sensitiveDataAccess)
        XCTAssertNotNil(assessment)
        let risk1 = assessment!.currentRisk

        assessment = await tracker.recordActivity(sessionId: sessionId, activityType: .failedOperation)
        let risk2 = assessment!.currentRisk
        XCTAssertGreaterThan(risk2, risk1)

        assessment = await tracker.recordActivity(sessionId: sessionId, activityType: .rapidRequests)
        let risk3 = assessment!.currentRisk
        XCTAssertGreaterThan(risk3, risk2)
    }

    // MARK: - Tenant Isolation Tests

    func testTenantIsolationBlocksCrossTenantAccess() async throws {
        let enforcer = TenantIsolationEnforcer()

        let tenantA = UUID()
        let tenantB = UUID()
        let operationId = UUID()
        let principalId = UUID()

        await enforcer.registerTenant(tenantA)
        await enforcer.registerTenant(tenantB)

        // Start operation in tenant A
        try await enforcer.beginOperation(
            operationId: operationId,
            tenantId: tenantA,
            principalId: principalId
        )

        // Access to tenant A entities should work
        try await enforcer.validateAccess(
            operationId: operationId,
            entityTenantId: tenantA,
            entityId: UUID()
        )

        // Access to tenant B entities should fail
        do {
            try await enforcer.validateAccess(
                operationId: operationId,
                entityTenantId: tenantB,
                entityId: UUID()
            )
            XCTFail("Expected cross-tenant error")
        } catch TenantIsolationError.crossTenantAccess {
            // Expected
        }
    }

    func testTenantIsolationAllowsPlatformWideEntities() async throws {
        let enforcer = TenantIsolationEnforcer()

        let tenantA = UUID()
        let operationId = UUID()

        await enforcer.registerTenant(tenantA)

        try await enforcer.beginOperation(
            operationId: operationId,
            tenantId: tenantA,
            principalId: UUID()
        )

        // Platform-wide entities (nil tenant) should be accessible
        try await enforcer.validateAccess(
            operationId: operationId,
            entityTenantId: nil,
            entityId: UUID()
        )
    }

    // MARK: - Security Operation Registry Tests

    func testSecurityOperationRegistryReturnsDefaultForUnknown() async {
        let registry = SecurityOperationRegistry()

        // Register some profiles
        await registry.register(StandardOperationProfiles.viewEntity)

        // Known operation should return its profile
        let known = await registry.getProfile("entity.view")
        XCTAssertEqual(known.operationId, "entity.view")
        XCTAssertEqual(known.checkpointProfile, .readOnly)

        // Unknown operation should return restrictive default
        let unknown = await registry.getProfile("unknown.operation")
        XCTAssertEqual(unknown.checkpointProfile, .hard)
        XCTAssertEqual(unknown.riskLevel, .high)
    }

    func testSecurityOperationRegistryEnforcesMode() async {
        let registry = SecurityOperationRegistry()
        await registry.registerAll(StandardOperationProfiles.all)

        // Read operations allowed in all modes
        var result = await registry.isAllowed(operationId: "entity.view", mode: .readOnly)
        XCTAssertTrue(result.allowed)

        result = await registry.isAllowed(operationId: "entity.view", mode: .autopilot)
        XCTAssertTrue(result.allowed)

        // Grade recording should not be allowed in autopilot
        result = await registry.isAllowed(operationId: "transcriptum.grade.record", mode: .autopilot)
        XCTAssertFalse(result.allowed)

        result = await registry.isAllowed(operationId: "transcriptum.grade.record", mode: .assistive)
        XCTAssertTrue(result.allowed)
    }

    // MARK: - Automation Containment Tests

    func testAutomationContainmentEnforcesDomainBoundaries() async throws {
        let containment = AutomationContainment()
        let executionId = UUID()
        let agentId = UUID()

        _ = try await containment.createSandbox(
            executionId: executionId,
            agentId: agentId,
            operatingMode: .assistive,
            allowedDomains: ["dsps", "diaplasion"],
            maxSensitivity: .confidential,
            allowedCapabilities: ["ocr"]
        )

        // Allowed domain should work
        try await containment.validateOperation(
            executionId: executionId,
            operation: SandboxedOperation(operationType: "read", domain: "dsps")
        )

        // Disallowed domain should fail
        do {
            try await containment.validateOperation(
                executionId: executionId,
                operation: SandboxedOperation(operationType: "read", domain: "transcriptum")
            )
            XCTFail("Expected domain error")
        } catch ContainmentError.domainNotAllowed {
            // Expected
        }
    }

    func testAutomationContainmentEnforcesSensitivity() async throws {
        let containment = AutomationContainment()
        let executionId = UUID()

        _ = try await containment.createSandbox(
            executionId: executionId,
            agentId: UUID(),
            operatingMode: .assistive,
            allowedDomains: ["dsps"],
            maxSensitivity: .confidential,
            allowedCapabilities: []
        )

        // Confidential should work
        try await containment.validateOperation(
            executionId: executionId,
            operation: SandboxedOperation(
                operationType: "read",
                domain: "dsps",
                sensitivity: .confidential
            )
        )

        // Restricted should fail
        do {
            try await containment.validateOperation(
                executionId: executionId,
                operation: SandboxedOperation(
                    operationType: "read",
                    domain: "dsps",
                    sensitivity: .restricted
                )
            )
            XCTFail("Expected sensitivity error")
        } catch ContainmentError.sensitivityExceeded {
            // Expected
        }
    }

    func testAutomationContainmentBlocksWriteInReadOnlyMode() async throws {
        let containment = AutomationContainment()
        let executionId = UUID()

        _ = try await containment.createSandbox(
            executionId: executionId,
            agentId: UUID(),
            operatingMode: .readOnly,
            allowedDomains: ["dsps"],
            maxSensitivity: .confidential,
            allowedCapabilities: []
        )

        // Read should work
        try await containment.validateOperation(
            executionId: executionId,
            operation: SandboxedOperation(operationType: "read", domain: "dsps", isWrite: false)
        )

        // Write should fail
        do {
            try await containment.validateOperation(
                executionId: executionId,
                operation: SandboxedOperation(operationType: "update", domain: "dsps", isWrite: true)
            )
            XCTFail("Expected write error")
        } catch ContainmentError.writeNotAllowed {
            // Expected
        }
    }

    func testAutomationContainmentKillsAgentOnExcessiveAccess() async throws {
        let containment = AutomationContainment()
        let executionId = UUID()
        let agentId = UUID()

        _ = try await containment.createSandbox(
            executionId: executionId,
            agentId: agentId,
            operatingMode: .assistive,
            allowedDomains: ["dsps"],
            maxSensitivity: .confidential,
            allowedCapabilities: []
        )

        // Perform many operations
        for i in 0..<1001 {
            do {
                try await containment.validateOperation(
                    executionId: executionId,
                    operation: SandboxedOperation(operationType: "read_\(i)", domain: "dsps")
                )
            } catch ContainmentError.excessiveAccess {
                // Expected after 1000 operations
                break
            }
        }

        // Agent should be killed
        let isKilled = await containment.isAgentKilled(agentId)
        XCTAssertTrue(isKilled)

        // New sandbox creation should fail for killed agent
        do {
            _ = try await containment.createSandbox(
                executionId: UUID(),
                agentId: agentId,
                operatingMode: .assistive,
                allowedDomains: ["dsps"],
                maxSensitivity: .confidential,
                allowedCapabilities: []
            )
            XCTFail("Expected agent killed error")
        } catch ContainmentError.agentKilled {
            // Expected
        }
    }

    // MARK: - Immediate Deprovisioning Tests

    func testImmediateDeprovisioningBlocksAccess() async {
        let deprovisioner = ImmediateDeprovisioner()
        let principalId = UUID()
        let adminId = UUID()

        // Initially not deprovisioned
        var isDeprovisioned = await deprovisioner.isDeprovisioned(principalId)
        XCTAssertFalse(isDeprovisioned)

        // Deprovision
        await deprovisioner.deprovision(
            principalId: principalId,
            reason: "Employee termination",
            initiatedBy: adminId
        )

        // Now should be deprovisioned
        isDeprovisioned = await deprovisioner.isDeprovisioned(principalId)
        XCTAssertTrue(isDeprovisioned)

        // Reprovision
        await deprovisioner.reprovision(
            principalId: principalId,
            reason: "Error corrected",
            authorizedBy: adminId
        )

        // Should no longer be deprovisioned
        isDeprovisioned = await deprovisioner.isDeprovisioned(principalId)
        XCTAssertFalse(isDeprovisioned)
    }

    // MARK: - Hardened Infrastructure Tests

    func testHardenedInfrastructureHealthCheck() async {
        let auditLog = AuditLog()
        let infrastructure = await HardenedSecurityInfrastructure(auditLog: auditLog)

        let report = await infrastructure.healthCheck()

        // Initial state should be healthy
        XCTAssertEqual(report.overallHealth, .healthy)
        XCTAssertEqual(report.bypassAttempts, 0)
        XCTAssertFalse(report.emergencyLockdown)
        XCTAssertEqual(report.sandboxViolations, 0)
        XCTAssertEqual(report.crossTenantAttempts, 0)
    }

    // MARK: - Audit Integrity Tests

    func testAuditIntegrityCreatesAnchors() async {
        let auditLog = AuditLog()
        let manager = AuditIntegrityManager(auditLog: auditLog, anchorInterval: 5)

        // Record entries
        for i in 0..<10 {
            await manager.record(
                eventType: .dataAccessed,
                principal: "test",
                description: "Entry \(i)"
            )
        }

        // Should have created anchors
        let anchors = await manager.getAnchors()
        XCTAssertGreaterThanOrEqual(anchors.count, 1)
    }

    func testAuditIntegrityVerification() async {
        let auditLog = AuditLog()
        let manager = AuditIntegrityManager(auditLog: auditLog, anchorInterval: 5)

        // Record some entries
        for i in 0..<10 {
            await manager.record(
                eventType: .dataAccessed,
                principal: "test",
                description: "Entry \(i)"
            )
        }

        // Force anchor creation
        await manager.createAnchor()

        // Verify integrity
        let result = await manager.verifyIntegrity()
        XCTAssertTrue(result.verified)
        XCTAssertTrue(result.issues.isEmpty)
    }
}
