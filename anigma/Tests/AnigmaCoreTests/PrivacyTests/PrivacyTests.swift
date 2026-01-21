//
//  PrivacyTests.swift
//  AnigmaCoreTests
//
//  Tests for the privacy and governance infrastructure.
//

import XCTest
import AnigmaTestSupport
import ContractsCore
@testable import AnigmaCore

final class AccessControlTests: XCTestCase {

    // MARK: - Data Sensitivity Tests

    func testDataSensitivityComparison() {
        XCTAssertTrue(DataSensitivity.public < DataSensitivity.internal)
        XCTAssertTrue(DataSensitivity.internal < DataSensitivity.confidential)
        XCTAssertTrue(DataSensitivity.confidential < DataSensitivity.sensitive)
        XCTAssertTrue(DataSensitivity.sensitive < DataSensitivity.restricted)
    }

    // MARK: - Access Principal Tests

    func testAccessPrincipalCreation() {
        let principal = AccessPrincipal.system(
            "OCRExtractionSystem",
            module: "DiaplasionModule",
            roles: ["reader", "processor"]
        )

        XCTAssertEqual(principal.id, "OCRExtractionSystem")
        XCTAssertEqual(principal.module, "DiaplasionModule")
        XCTAssertTrue(principal.roles.contains("reader"))
        XCTAssertTrue(principal.roles.contains("processor"))
    }

    // MARK: - Role-Based Policy Tests

    func testRoleBasedPolicyAllowsMatchingRole() async {
        let policy = RoleBasedPolicy(
            id: "reader-policy",
            allowedRoles: ["reader"],
            maxSensitivity: .confidential,
            accessTypes: [.read, .query]
        )

        let request = AccessRequest(
            principal: AccessPrincipal.system("TestSystem", module: "Test", roles: ["reader"]),
            componentType: "DocumentComponent",
            sensitivity: .confidential,
            accessType: .read
        )

        let decision = policy.evaluate(request)
        XCTAssertNotNil(decision)
        XCTAssertTrue(decision!.allowed)
    }

    func testRoleBasedPolicyDeniesExcessiveSensitivity() async {
        let policy = RoleBasedPolicy(
            id: "reader-policy",
            allowedRoles: ["reader"],
            maxSensitivity: .confidential,
            accessTypes: [.read]
        )

        let request = AccessRequest(
            principal: AccessPrincipal.system("TestSystem", module: "Test", roles: ["reader"]),
            componentType: "MedicalRecordComponent",
            sensitivity: .sensitive,  // Above policy max
            accessType: .read
        )

        let decision = policy.evaluate(request)
        XCTAssertNotNil(decision)
        XCTAssertFalse(decision!.allowed)
    }

    func testRoleBasedPolicySkipsNonMatchingRole() async {
        let policy = RoleBasedPolicy(
            id: "admin-policy",
            allowedRoles: ["admin"],
            accessTypes: [.read, .write, .delete]
        )

        let request = AccessRequest(
            principal: AccessPrincipal.system("TestSystem", module: "Test", roles: ["reader"]),
            componentType: "ConfigComponent",
            sensitivity: .internal,
            accessType: .read
        )

        // Should return nil (doesn't apply), not deny
        let decision = policy.evaluate(request)
        XCTAssertNil(decision)
    }

    // MARK: - Restricted Data Policy Tests

    func testRestrictedDataRequiresJustification() async {
        let policy = RestrictedDataPolicy()

        // Request without justification
        let requestNoJustification = AccessRequest(
            principal: AccessPrincipal.system("TestSystem", module: "Test", roles: ["admin"]),
            componentType: "PIIComponent",
            sensitivity: .restricted,
            accessType: .read,
            justification: nil
        )

        let denied = policy.evaluate(requestNoJustification)
        XCTAssertNotNil(denied)
        XCTAssertFalse(denied!.allowed)

        // Request with justification
        let requestWithJustification = AccessRequest(
            principal: AccessPrincipal.system("TestSystem", module: "Test", roles: ["admin"]),
            componentType: "PIIComponent",
            sensitivity: .restricted,
            accessType: .read,
            justification: "Student requested disability accommodation"
        )

        let allowed = policy.evaluate(requestWithJustification)
        XCTAssertNotNil(allowed)
        XCTAssertTrue(allowed!.allowed)
        XCTAssertTrue(allowed!.conditions.contains("AUDIT_REQUIRED"))
    }

    // MARK: - Access Controller Tests

    func testAccessControllerDefaultDeny() async {
        let controller = AccessController()

        let request = AccessRequest(
            principal: AccessPrincipal.system("TestSystem", module: "Test", roles: []),
            componentType: "SomeComponent",
            sensitivity: .internal,
            accessType: .read
        )

        let decision = await controller.evaluate(request)
        XCTAssertFalse(decision.allowed)
        XCTAssertEqual(decision.policyId, "default-deny")
    }

    func testAccessControllerWithPolicies() async {
        let controller = AccessController()

        // Add a reader policy
        await controller.addPolicy(RoleBasedPolicy(
            id: "reader-access",
            priority: 100,
            allowedRoles: ["reader"],
            maxSensitivity: .confidential,
            accessTypes: [.read, .query]
        ))

        // Request from reader role
        let request = AccessRequest(
            principal: AccessPrincipal.system("ReaderSystem", module: "Test", roles: ["reader"]),
            componentType: "DocumentComponent",
            sensitivity: .confidential,
            accessType: .read
        )

        let decision = await controller.evaluate(request)
        XCTAssertTrue(decision.allowed)
        XCTAssertEqual(decision.policyId, "reader-access")
    }
}

final class AuditLogTests: XCTestCase {

    func testAuditLogRecordsEvents() async throws {
        let storage = InMemoryAuditStorage()
        let log = AuditLog(storage: storage)

        try await log.recordLegacy(
            eventType: .dataCreated,
            principal: "TestSystem",
            module: "TestModule",
            entityId: EntityId(),
            componentType: "TestComponent",
            sensitivity: .internal,
            description: "Test entity created"
        )

        let count = try await log.legacyCount()
        XCTAssertEqual(count, 1)

        let entries = try await log.legacyEntries(count: 10)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].eventTypeString, LegacyAuditEventType.dataCreated.rawValue)
        XCTAssertEqual(entries[0].principalString, "TestSystem")
    }

    func testAuditLogChainIntegrity() async throws {
        let storage = InMemoryAuditStorage()
        let log = AuditLog(storage: storage)

        // Record multiple events
        for i in 1...10 {
            try await log.recordLegacy(
                eventType: .dataRead,
                description: "Event \(i)"
            )
        }

        let report = try await log.legacyVerifyIntegrity()
        XCTAssertTrue(report.isValid)
        XCTAssertEqual(report.totalEntries, 10)
        XCTAssertEqual(report.verifiedEntries, 10)
    }

    func testAuditLogChainVerification() async throws {
        let storage = TestAuditStorage()
        let log = AuditLog(storage: storage)

        try await log.recordEvent(
            id: UUID(),
            type: .dataCreated,
            principal: "TestSystem",
            module: "TestModule",
            description: "Created",
            metadata: [:]
        )
        try await log.recordEvent(
            id: UUID(),
            type: .dataModified,
            principal: "TestSystem",
            module: "TestModule",
            description: "Modified",
            metadata: [:]
        )

        let entries = try await storage.query(filter: AuditFilter())
        XCTAssertEqual(entries.count, 2)
        XCTAssertNotNil(entries[0].metadata?["chain_hash"])
        XCTAssertNotNil(entries[1].metadata?["chain_prev_hash"])

        let valid = await log.verifyChain()
        XCTAssertTrue(valid)
    }

    func testAuditLogChainTamperDetection() async throws {
        let storage = TestAuditStorage()
        let log = AuditLog(storage: storage)

        try await log.recordEvent(
            id: UUID(),
            type: .dataCreated,
            principal: "TestSystem",
            module: "TestModule",
            description: "Created",
            metadata: [:]
        )
        try await log.recordEvent(
            id: UUID(),
            type: .dataModified,
            principal: "TestSystem",
            module: "TestModule",
            description: "Modified",
            metadata: [:]
        )

        await storage.tamper(at: 1) { entry in
            var metadata = entry.metadata ?? [:]
            metadata["chain_prev_hash"] = "tampered"
            entry = AuditEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                engineId: entry.engineId,
                operation: entry.operation,
                command: entry.command,
                arguments: entry.arguments,
                error: entry.error,
                metadata: metadata
            )
        }

        let valid = await log.verifyChain()
        XCTAssertFalse(valid)
    }

    func testAuditLogFiltering() async throws {
        let storage = InMemoryAuditStorage()
        let log = AuditLog(storage: storage)

        // Record different event types
        try await log.recordLegacy(eventType: .accessGranted, description: "Access 1")
        try await log.recordLegacy(eventType: .accessDenied, description: "Denied 1")
        try await log.recordLegacy(eventType: .accessGranted, description: "Access 2")
        try await log.recordLegacy(eventType: .dataModified, description: "Modified 1")

        // Filter by event type
        let filter = AuditFilter(eventTypes: [.accessGranted])
        let entries = try await log.query(filter: filter)

        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.allSatisfy { $0.operation == AuditEventType.accessGranted.rawValue })
    }

    func testComplianceReportGeneration() async throws {
        let storage = InMemoryAuditStorage()
        let log = AuditLog(storage: storage)

        // Record various events
        try await log.recordLegacy(
            eventType: .accessGranted,
            sensitivity: .internal,
            description: "Internal access"
        )
        try await log.recordLegacy(
            eventType: .accessGranted,
            sensitivity: .sensitive,
            description: "Sensitive access"
        )
        try await log.recordLegacy(
            eventType: .accessDenied,
            description: "Denied access"
        )
        try await log.recordLegacy(
            eventType: .dataModified,
            description: "Data modified"
        )
        try await log.recordLegacy(
            eventType: .policyViolation,
            description: "Policy violation!"
        )

        let report = try await log.legacyComplianceReport()

        XCTAssertEqual(report.totalEvents, 5)
        XCTAssertEqual(report.accessGranted, 2)
        XCTAssertEqual(report.accessDenied, 1)
        XCTAssertEqual(report.sensitiveDataAccess, 1)
        XCTAssertEqual(report.policyViolations, 1)
        XCTAssertEqual(report.dataModifications, 1)
    }
}

private actor TestAuditStorage: AuditLogStorage {
    private var entries: [AuditEntry] = []

    func append(_ entry: AuditEntry) async throws {
        entries.append(entry)
    }

    func query(filter: AuditFilter) async throws -> [AuditEntry] {
        var filteredEntries = entries.filter { filter.matches($0) }
        if let limit = filter.limit {
            filteredEntries = Array(filteredEntries.suffix(limit))
        }
        return filteredEntries
    }

    func queryLatestEntry() async throws -> AuditEntry? {
        entries.last
    }

    func count() async throws -> Int {
        entries.count
    }

    func tamper(at index: Int, mutate: (inout AuditEntry) -> Void) async {
        guard entries.indices.contains(index) else { return }
        var entry = entries[index]
        mutate(&entry)
        entries[index] = entry
    }
}

final class DataLifecycleTests: XCTestCase {

    func testRetentionPolicyMatching() {
        let policy = RetentionPolicy.default

        XCTAssertEqual(policy.metadata.version, "1.0")
        XCTAssertEqual(policy.sessionDb.ttlDays, 7)
        XCTAssertFalse(policy.canDeleteNow)
    }

    func testLifecycleManagerFindPolicy() async {
        let manager = LifecycleManager()

        // Should find a policy for sensitive data
        let sensitivePolicy = await manager.findApplicablePolicy(
            componentType: "MedicalRecord",
            sensitivity: .sensitive
        )
        XCTAssertNotNil(sensitivePolicy)
        XCTAssertEqual(sensitivePolicy?.id, "sensitive-90d")

        // Should find a policy for restricted data
        let restrictedPolicy = await manager.findApplicablePolicy(
            componentType: "SSN",
            sensitivity: .restricted
        )
        XCTAssertNotNil(restrictedPolicy)
        XCTAssertEqual(restrictedPolicy?.id, "restricted-30d")
    }

    func testLifecycleMetadataExpiration() {
        var metadata = LifecycleMetadataComponent(
            expiresAt: Date().addingTimeInterval(-100)  // Already expired
        )

        XCTAssertTrue(metadata.isExpired)

        metadata.expiresAt = Date().addingTimeInterval(100)  // Not expired
        XCTAssertFalse(metadata.isExpired)
    }

    func testLifecycleApplyToEntity() async {
        let world = World()
        let manager = LifecycleManager()

        let entity = await world.createEntity()

        let metadata = await manager.applyLifecycle(
            to: entity,
            componentType: "SensitiveDocument",
            sensitivity: .sensitive,
            in: world
        )

        XCTAssertEqual(metadata.state, .active)
        XCTAssertNotNil(metadata.expiresAt)
        XCTAssertEqual(metadata.policyId, "sensitive-90d")

        // Verify component was added to entity
        let retrieved = await world.getComponent(entity, LifecycleMetadataComponent.self)
        XCTAssertNotNil(retrieved)
    }
}

final class GovernanceTests: XCTestCase {

    func testOperatingModes() {
        XCTAssertFalse(OperatingMode.readOnly.canWrite)
        XCTAssertTrue(OperatingMode.assistive.canWrite)
        XCTAssertTrue(OperatingMode.autopilot.canWrite)

        XCTAssertFalse(OperatingMode.readOnly.requiresConfirmation)
        XCTAssertTrue(OperatingMode.assistive.requiresConfirmation)
        XCTAssertFalse(OperatingMode.autopilot.requiresConfirmation)
    }

    func testKillSwitchBlocksWrites() async {
        let killSwitch = KillSwitch()

        // Initially writes are allowed
        var allowed = await killSwitch.isWriteAllowed()
        XCTAssertTrue(allowed)

        // Activate kill switch
        await killSwitch.activate(reason: "Emergency halt", by: "Admin")
        allowed = await killSwitch.isWriteAllowed()
        XCTAssertFalse(allowed)

        // Deactivate
        await killSwitch.deactivate(by: "Admin")
        allowed = await killSwitch.isWriteAllowed()
        XCTAssertTrue(allowed)
    }

    func testKillSwitchProjectOverride() async {
        let killSwitch = KillSwitch()

        // Activate for specific project
        await killSwitch.activateForProject("project-123", by: "Admin")

        // Global writes still allowed
        let globalAllowed = await killSwitch.isWriteAllowed()
        XCTAssertTrue(globalAllowed)

        // Project-specific writes blocked
        let project123Allowed = await killSwitch.isWriteAllowed(forProject: "project-123")
        XCTAssertFalse(project123Allowed)

        // Other projects not affected
        let project456Allowed = await killSwitch.isWriteAllowed(forProject: "project-456")
        XCTAssertTrue(project456Allowed)
    }

    func testWriteGateEvaluatesChecks() async {
        let killSwitch = KillSwitch()
        let writeGate = WriteGate()

        await writeGate.registerCheck(KillSwitchCheck(killSwitch: killSwitch))

        let proposal = WriteProposal(
            principal: "TestSystem",
            module: "TestModule",
            operation: "create"
        )

        // Should pass with kill switch off
        var decision = await writeGate.evaluate(proposal)
        XCTAssertTrue(decision.allowed)

        // Activate kill switch
        await killSwitch.activate(reason: "Test", by: "Test")

        // Should fail with kill switch on
        decision = await writeGate.evaluate(proposal)
        XCTAssertFalse(decision.allowed)
        XCTAssertEqual(decision.failedChecks.count, 1)
        XCTAssertEqual(decision.failedChecks[0].checkId, "kill-switch")
    }

    func testGovernanceControllerInitialization() async {
        let controller = GovernanceController()
        await controller.initialize()

        let status = await controller.status()
        XCTAssertEqual(status.operatingMode, .assistive)
        XCTAssertFalse(status.killSwitchActive)
    }

    func testGovernanceControllerModeChange() async {
        let controller = GovernanceController()
        await controller.initialize()

        await controller.setMode(.autopilot, by: "Admin")

        let status = await controller.status()
        XCTAssertEqual(status.operatingMode, .autopilot)
    }
}
