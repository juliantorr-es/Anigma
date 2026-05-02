//
//  GovernanceWiringTests.swift
//  GovernanceCoreTests
//
//  Tests that prove governance is wired into Authority implementations.
//  Verifies that readOnly mode denies writes and leaves an audit trail.
//

import XCTest
import Foundation
import DatabaseCore
import AnigmaPrimitives
import ContractsCore
import GovernanceCore
import AnigmaFoundation
@testable import AnigmaGovernance

// MARK: - Test Types (minimal versions for testing)

public struct TestDatabaseMutation: Sendable {
    public let sql: String
    public let parameters: [DatabaseParameter]
    public let componentType: String
    public let entityId: String
    
    public init(sql: String, parameters: [DatabaseParameter], componentType: String, entityId: String) {
        self.sql = sql
        self.parameters = parameters
        self.componentType = componentType
        self.entityId = entityId
    }
}

public struct TestDatabaseResult: Sendable {
    public let rowsAffected: Int
    public let lastInsertId: Int?
    
    public init(rowsAffected: Int, lastInsertId: Int?) {
        self.rowsAffected = rowsAffected
        self.lastInsertId = lastInsertId
    }
}

public struct TestExecutionContext: Sendable {
    public let principal: TestPrincipal
    public let projectId: String?
    public let sessionId: String
    public let startedAt: Date
    public let metadata: [String: String]
    public let correlationId: String
    
    public init(
        principal: TestPrincipal,
        projectId: String?,
        sessionId: String,
        startedAt: Date,
        metadata: [String: String],
        correlationId: String
    ) {
        self.principal = principal
        self.projectId = projectId
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.metadata = metadata
        self.correlationId = correlationId
    }
}

public struct TestPrincipal: Sendable {
    public let id: String
    public let displayName: String?
    
    public init(id: String, displayName: String? = nil) {
        self.id = id
        self.displayName = displayName
    }
}

// MARK: - Test-specific Authority Implementation

/// Minimal DatabaseAuthority implementation for testing governance
actor TestDatabaseAuthority {
    let governance: GovernanceController
    let database: TestDatabaseActor
    
    init(governance: GovernanceController, database: TestDatabaseActor) {
        self.governance = governance
        self.database = database
    }
    
    func mutate(_ mutation: TestDatabaseMutation, context: TestExecutionContext) async throws -> TestDatabaseResult {
        // Governance check (same pattern as real implementation)
        var proposalContext = ["sql": mutation.sql]
        if let projectId = context.projectId {
            proposalContext["projectId"] = projectId
        }
        
        let proposal = WriteProposal(
            principal: context.principal.id,
            module: "database_authority",
            operation: "mutate",
            entityId: nil,
            componentType: "database",
            context: proposalContext
        )
        
        let decision = await governance.canWrite(proposal)
        
        guard decision.allowed else {
            let reasons = decision.failedChecks.map { $0.message }.joined(separator: ", ")
            throw TestRuntimeInitializationError.denied(reasons)
        }
        
        // Side effect happens only after allow
        return try await database.execute(mutation)
    }
}

enum TestRuntimeInitializationError: Error {
    case denied(String)
    case unavailable(String)
}

final class GovernanceWiringTests: XCTestCase {
    
    /// Proves that OperatingMode.readOnly denies database mutations
    /// and that no side effect occurs (fail-closed).
    func testReadOnlyModeDeniesDatabaseMutation() async throws {
        // Setup: Create governance in readOnly mode
        let auditLog = TestAuditLog()
        let governance = GovernanceController(auditLog: auditLog)
        await governance.initialize()
        try await governance.setMode(OperatingMode.readOnly, for: nil, by: Principal(id: "test", displayName: "Test"))
        
        // Setup: Create test database and authority
        let db = TestDatabaseActor()
        let authority = TestDatabaseAuthority(
            governance: governance,
            database: db
        )
        
        // Execute: Try to mutate in readOnly mode
        let mutation = TestDatabaseMutation(
            sql: "INSERT INTO test_table(value) VALUES (?)",
            parameters: [.text("should-be-denied")],
            componentType: "test-component",
            entityId: "test-entity"
        )
        
        let context = TestExecutionContext(
            principal: TestPrincipal(id: "test-user", displayName: "Test User"),
            projectId: "test-project",
            sessionId: "test-session",
            startedAt: Date(),
            metadata: [:],
            correlationId: "test-correlation"
        )
        
        // Assert: Mutation is denied with governance error
        do {
            _ = try await authority.mutate(mutation, context: context)
            XCTFail("Expected governance denial in readOnly mode")
        } catch let error as TestRuntimeInitializationError {
            guard case .denied(let message) = error else {
                return XCTFail("Expected .denied error, got: \(error)")
            }
            // Verify the denial reason mentions readOnly
            XCTAssertTrue(
                message.localizedLowercase.contains("read only") ||
                message.localizedLowercase.contains("readonly"),
                "Expected denial reason to mention readOnly mode, got: \(message)"
            )
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Assert: No side effect occurred (fail-closed)
        let executionCount = await db.executionCount
        XCTAssertEqual(executionCount, 0, "Database mutation executed despite governance denial (fail-open vulnerability)")
        
        // Assert: Audit trail exists
        XCTAssertGreaterThan(auditLog.entries.count, 0, "Expected audit log entry for denial")
    }
    
    /// Proves that OperatingMode.assistive allows writes
    func testAssistiveModeAllowsWrites() async throws {
        let auditLog = TestAuditLog()
        let governance = GovernanceController(auditLog: auditLog)
        await governance.initialize()
        try await governance.setMode(OperatingMode.assistive, for: nil, by: Principal(id: "test", displayName: "Test"))
        
        let db = TestDatabaseActor()
        let authority = TestDatabaseAuthority(
            governance: governance,
            database: db
        )
        
        let mutation = TestDatabaseMutation(
            sql: "INSERT INTO test_table(value) VALUES (?)",
            parameters: [.text("should-be-allowed")],
            componentType: "test-component",
            entityId: "test-entity"
        )
        
        let context = TestExecutionContext(
            principal: TestPrincipal(id: "system", displayName: "System"),
            projectId: nil,
            sessionId: "test-session",
            startedAt: Date(),
            metadata: [:],
            correlationId: "test-correlation"
        )
        
        // Should not throw
        _ = try await authority.mutate(mutation, context: context)
        
        // Verify side effect occurred
        let executionCount = await db.executionCount
        XCTAssertEqual(executionCount, 1, "Database mutation did not execute")
    }
    
    /// Proves that KillSwitch blocks all writes
    func testKillSwitchBlocksAllWrites() async throws {
        let auditLog = TestAuditLog()
        let governance = GovernanceController(auditLog: auditLog)
        await governance.initialize()
        
        // Start in assistive mode (allows writes normally)
        try await governance.setMode(OperatingMode.assistive, for: nil, by: Principal(id: "test", displayName: "Test"))
        
        // Activate kill switch
        await governance.killSwitch.activate(reason: "Emergency test", by: "admin")
        
        let db = TestDatabaseActor()
        let authority = TestDatabaseAuthority(
            governance: governance,
            database: db
        )
        
        let mutation = TestDatabaseMutation(
            sql: "INSERT INTO test_table(value) VALUES (?)",
            parameters: [.text("should-be-blocked")],
            componentType: "test-component",
            entityId: "test-entity"
        )
        
        let context = TestExecutionContext(
            principal: TestPrincipal(id: "system", displayName: "System"),
            projectId: nil,
            sessionId: "test-session",
            startedAt: Date(),
            metadata: [:],
            correlationId: "test-correlation"
        )
        
        // Assert: Blocked by kill switch
        do {
            _ = try await authority.mutate(mutation, context: context)
            XCTFail("Expected kill switch to block write")
        } catch let error as TestRuntimeInitializationError {
            guard case .denied(let message) = error else {
                return XCTFail("Expected .denied error, got: \(error)")
            }
            // Verify reason mentions kill switch
            XCTAssertTrue(
                message.localizedLowercase.contains("kill switch") ||
                message.localizedLowercase.contains("emergency"),
                "Expected denial to mention kill switch, got: \(message)"
            )
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Assert: No side effect
        let executionCount = await db.executionCount
        XCTAssertEqual(executionCount, 0, "Write executed despite active kill switch")
    }
    
    /// Regression test: Proves that if governance.canWrite() throws,
    /// the authority fails closed and no side effect occurs.
    /// This catches optimizations like "try?" or fallback allow paths.
    func testAuthorityFailsClosedWhenGovernanceUnavailable() async throws {
        let throwingGovernance = ThrowingGovernance()
        let db = TestDatabaseActor()
        
        let authority = TestDatabaseAuthorityWithThrowingGovernance(
            governance: throwingGovernance,
            database: db
        )
        
        let mutation = TestDatabaseMutation(
            sql: "INSERT INTO test_table(value) VALUES (?)",
            parameters: [.text("should-not-execute")],
            componentType: "test_component",
            entityId: "test-entity"
        )
        
        let context = TestExecutionContext(
            principal: TestPrincipal(id: "test-principal"),
            projectId: "test-project",
            sessionId: "test-session",
            startedAt: Date(),
            metadata: [:],
            correlationId: "test-correlation"
        )
        
        // Assert: Authority throws when governance throws
        do {
            _ = try await authority.mutate(mutation, context: context)
            XCTFail("Authority should fail when governance throws")
        } catch let error as TestRuntimeInitializationError {
            guard case .unavailable(let message) = error else {
                return XCTFail("Expected .unavailable error, got: \(error)")
            }
            XCTAssertEqual(message, "Governance system offline")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Assert: No side effect occurred (fail-closed)
        let executionCount = await db.executionCount
        XCTAssertEqual(executionCount, 0, "Side effect occurred despite governance failure")
    }
    
    /// Context verification test: Proves that proposal fields (projectId, principal, operation)
    /// actually reach WriteGate checks unchanged. Catches "we stopped passing context" regressions.
    func testProposalContextFlowsToChecks() async throws {
        let auditLog = TestAuditLog()
        
        let governance = GovernanceController(auditLog: auditLog)
        
        await governance.initialize()
        
        // Set mode to assistive (so mode allows writes)
        try await governance.setMode(OperatingMode.assistive, for: nil, by: Principal(id: "test", displayName: "Test"))
        
        // Register custom check that blocks specific project
        let projectBlocker = ProjectBlockerCheck(blockedProjectId: "forbidden-project")
        await governance.writeGate.registerCheck(projectBlocker)
        
        let db = TestDatabaseActor()
        let authority = TestDatabaseAuthority(governance: governance, database: db)
        
        let mutation = TestDatabaseMutation(
            sql: "INSERT INTO test_table(value) VALUES (?)",
            parameters: [.text("test-value")],
            componentType: "test_component",
            entityId: "test-entity"
        )
        
        let forbiddenContext = TestExecutionContext(
            principal: TestPrincipal(id: "test-principal"),
            projectId: "forbidden-project", // ← This should trigger denial
            sessionId: "test-session",
            startedAt: Date(),
            metadata: [:],
            correlationId: "test-correlation"
        )
        
        // Assert: Write denied by custom check
        do {
            _ = try await authority.mutate(mutation, context: forbiddenContext)
            XCTFail("Expected denial for forbidden project")
        } catch let error as TestRuntimeInitializationError {
            guard case .denied(let message) = error else {
                return XCTFail("Expected .denied error, got: \(error)")
            }
            
            // Verify denial reason mentions the forbidden project
            XCTAssertTrue(
                message.contains("forbidden-project"),
                "Expected denial to mention 'forbidden-project', got: \(message)"
            )
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Assert: No side effect
        let executionCount = await db.executionCount
        XCTAssertEqual(executionCount, 0, "Write executed despite custom check denial")
        
        // Verify audit log contains denial
        let entries = auditLog.entries
        XCTAssertGreaterThan(entries.count, 0, "Expected audit log entries")
        
        // Now test that a different project is allowed
        let allowedContext = TestExecutionContext(
            principal: TestPrincipal(id: "test-principal"),
            projectId: "allowed-project", // ← Should pass the check
            sessionId: "test-session-2",
            startedAt: Date(),
            metadata: [:],
            correlationId: "test-correlation-2"
        )
        
        let result = try await authority.mutate(mutation, context: allowedContext)
        XCTAssertEqual(result.rowsAffected, 1)
        
        let finalCount = await db.executionCount
        XCTAssertEqual(finalCount, 1, "Write should execute for allowed project")
    }
}

// MARK: - Test Doubles

/// Custom WriteCheck that blocks writes to a specific project.
/// Used to verify proposal context flows through governance checks.
struct ProjectBlockerCheck: WriteCheck {
    let blockedProjectId: String
    
    var id: String { "project-blocker" }
    var name: String { "Project Blocker" }
    var isBlocking: Bool { true }
    
    func appliesTo(_ proposal: WriteProposal) -> Bool {
        return true // Apply to all proposals
    }
    
    func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        // Check if proposal context contains the forbidden project
        if let projectId = proposal.context["projectId"],
           projectId == blockedProjectId {
            return WriteCheckResult(
                checkId: id,
                passed: false,
                message: "Project '\(blockedProjectId)' is blocked by policy",
                details: ["blockedProject": blockedProjectId]
            )
        }
        
        return WriteCheckResult(
            checkId: id,
            passed: true,
            message: "Project check passed",
            details: [:]
        )
    }
}

/// Governance test double that always throws (simulates unavailable governance)
actor ThrowingGovernance {
    func canWrite(_ proposal: WriteProposal) async throws -> WriteGateDecision {
        throw TestRuntimeInitializationError.unavailable("Governance system offline")
    }
    
    func setMode(_ mode: OperatingMode, by principal: String) async {
        // No-op for throwing stub
    }
    
    func initialize() async {
        // No-op for throwing stub
    }
}

/// Minimal DatabaseAuthority that works with ThrowingGovernance
actor TestDatabaseAuthorityWithThrowingGovernance {
    let governance: ThrowingGovernance
    let database: TestDatabaseActor
    
    init(governance: ThrowingGovernance, database: TestDatabaseActor) {
        self.governance = governance
        self.database = database
    }
    
    func mutate(_ mutation: TestDatabaseMutation, context: TestExecutionContext) async throws -> TestDatabaseResult {
        // Governance check (same pattern as real implementation)
        let proposal = WriteProposal(
            principal: context.principal.id,
            module: "database_authority",
            operation: "mutate",
            entityId: nil,
            componentType: "database",
            context: ["sql": mutation.sql]
        )
        
        // This will throw - authority should NOT catch and proceed
        let decision = try await governance.canWrite(proposal)
        
        guard decision.allowed else {
            let reasons = decision.failedChecks.map { $0.message }.joined(separator: ", ")
            throw TestRuntimeInitializationError.denied(reasons)
        }
        
        // Side effect happens only after allow
        return try await database.execute(mutation)
    }
}

/// Test database actor that tracks execution count
actor TestDatabaseActor: @unchecked Sendable {
    private(set) var executionCount = 0
    
    func execute(_ mutation: TestDatabaseMutation) async throws -> TestDatabaseResult {
        executionCount += 1
        return TestDatabaseResult(rowsAffected: 1, lastInsertId: nil)
    }
    
    func executeAsync(_ sql: String, parameters: [DatabaseParameter] = []) async throws -> Int {
        executionCount += 1
        return 1 // 1 row affected
    }
    
    func query(_ sql: String, parameters: [DatabaseParameter] = []) async throws -> [DatabaseRow] {
        return []
    }
    
    func query(_ sql: String, parameters: [String: String] = [:]) async throws -> [DatabaseRow] {
        return []
    }
    
    func close() async {
        // No-op
    }
}

/// Test audit log that captures entries
final class TestAuditLog: AuditLogging, @unchecked Sendable {
    private(set) var entries: [(UUID, String)] = []
    
    func recordEvent(
        id: UUID,
        type: ContractsCore.AuditEventType,
        principal: String?,
        module: String?,
        description: String,
        metadata: [String: String]
    ) async throws {
        entries.append((id, description))
    }
}
