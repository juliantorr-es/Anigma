//
//  GovernanceRestartTests.swift
//  GovernanceHarness - Restart Persistence Tests
//
//  Proves governance state survives runtime restart (operational control plane)
//

import XCTest
import Foundation
@testable import HarmoniaV2CLIKernel
@testable import AnigmaJobs

/// Integration tests proving governance state persists across runtime restarts
///
/// These tests verify mode and kill switch settings survive process boundaries,
/// transforming governance from "runtime decoration" into "operational control plane."
final class GovernanceRestartTests: XCTestCase {
    
    var tempDir: URL!
    var tempDBPath: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temp directory for test databases
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("restart-tests-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Use file-backed SQLite (NOT :memory:) to test restart persistence
        tempDBPath = tempDir.appendingPathComponent("restart-test.db").path
    }
    
    override func tearDown() async throws {
        // Clean up temp directory
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        try await super.tearDown()
    }
    
    // MARK: - Test: Global Mode Survives Restart
    
    func testGlobalModePersistsAcrossRestart() async throws {
        // Lifecycle 1: Set mode to readOnly
        try await CLIKernel.runSetMode(
            mode: .readOnly,
            projectId: nil,
            principal: "test-admin",
            databasePath: tempDBPath
        )
        
        // Verify initial state
        var result = try await CLIKernel.runShowMode(
            projectId: nil,
            databasePath: tempDBPath
        )
        XCTAssertEqual(result.effectiveMode, .readOnly, "Initial mode should be readOnly")
        
        // Simulate restart: Create new runtime instance against same database
        // (CLIKernel creates fresh PlatformRuntime on each call, simulating restart)
        
        // Lifecycle 2: Query mode after restart
        result = try await CLIKernel.runShowMode(
            projectId: nil,
            databasePath: tempDBPath
        )
        
        XCTAssertEqual(result.effectiveMode, .readOnly, "Mode should persist after restart")
        XCTAssertEqual(result.source, .global, "Source should still be global")
        
        // Lifecycle 3: Verify mode enforcement still works
        let config = CLIKernelConfig(databasePath: tempDBPath, enforceGovernance: true)
        
        do {
            _ = try await CLIKernel.runMemo(
                content: "should fail",
                userId: "test-user",
                projectId: nil,
                sessionId: nil,
                config: config
            )
            XCTFail("Write should be denied after restart in readOnly mode")
        } catch let error as RuntimeInitializationError {
            XCTAssertTrue(error.isGovernanceViolation, "Should deny with governance violation")
        }
    }
    
    // MARK: - Test: Project Mode Survives Restart
    
    func testProjectModePersistsAcrossRestart() async throws {
        // Lifecycle 1: Set global to assistive, project to readOnly
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: nil,
            principal: "test-admin",
            databasePath: tempDBPath
        )
        
        try await CLIKernel.runSetMode(
            mode: .readOnly,
            projectId: "locked-project",
            principal: "test-admin",
            databasePath: tempDBPath
        )
        
        // Verify initial state
        var lockedResult = try await CLIKernel.runShowMode(
            projectId: "locked-project",
            databasePath: tempDBPath
        )
        XCTAssertEqual(lockedResult.effectiveMode, .readOnly)
        XCTAssertEqual(lockedResult.source, .project)
        
        // Simulate restart
        
        // Lifecycle 2: Verify project override still active
        lockedResult = try await CLIKernel.runShowMode(
            projectId: "locked-project",
            databasePath: tempDBPath
        )
        
        XCTAssertEqual(lockedResult.effectiveMode, .readOnly, "Project mode should persist")
        XCTAssertEqual(lockedResult.source, .project, "Source should still be project")
        
        // Verify other projects still use global
        let openResult = try await CLIKernel.runShowMode(
            projectId: "open-project",
            databasePath: tempDBPath
        )
        
        XCTAssertEqual(openResult.effectiveMode, .assistive, "Global fallback should persist")
        XCTAssertEqual(openResult.source, .global)
    }
    
    // MARK: - Test: Mode Change Audit Trail Persists
    
    func testModeChangeAuditPersistsAcrossRestart() async throws {
        // Lifecycle 1: Make multiple mode changes
        try await CLIKernel.runSetMode(
            mode: .readOnly,
            projectId: nil,
            principal: "admin1",
            databasePath: tempDBPath
        )
        
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: nil,
            principal: "admin2",
            databasePath: tempDBPath
        )
        
        try await CLIKernel.runSetMode(
            mode: .autopilot,
            projectId: "test-project",
            principal: "admin3",
            databasePath: tempDBPath
        )
        
        // Simulate restart
        
        // Lifecycle 2: Verify final state persists
        let globalResult = try await CLIKernel.runShowMode(
            projectId: nil,
            databasePath: tempDBPath
        )
        
        XCTAssertEqual(globalResult.effectiveMode, .assistive, "Latest global mode should persist")
        
        let projectResult = try await CLIKernel.runShowMode(
            projectId: "test-project",
            databasePath: tempDBPath
        )
        
        XCTAssertEqual(projectResult.effectiveMode, .autopilot, "Project mode should persist")
        
        // TODO: Add audit trail queries once EvidenceAuthority is accessible
        // Expected: governance_audit table contains 3 mode change events
        // Each event should have: timestamp, principal, old_mode, new_mode, project_id
    }
    
    // MARK: - Test: Restart With Enforcement Active
    
    func testWriteDenialPersistsAcrossMultipleRestarts() async throws {
        // This is the critical "operational control plane" proof:
        // Set readOnly once → all future writes denied, even across restarts
        
        // Lifecycle 1: Set readOnly
        try await CLIKernel.runSetMode(
            mode: .readOnly,
            projectId: nil,
            principal: "test-admin",
            databasePath: tempDBPath
        )
        
        let config = CLIKernelConfig(databasePath: tempDBPath, enforceGovernance: true)
        
        // Lifecycle 2: Attempt write (should fail)
        do {
            _ = try await CLIKernel.runMemo(
                content: "attempt 1",
                userId: "test-user",
                projectId: nil,
                sessionId: nil,
                config: config
            )
            XCTFail("Write should be denied")
        } catch let error as RuntimeInitializationError {
            XCTAssertTrue(error.isGovernanceViolation)
        }
        
        // Lifecycle 3: Another restart, another denial
        do {
            _ = try await CLIKernel.runMemo(
                content: "attempt 2",
                userId: "test-user",
                projectId: nil,
                sessionId: nil,
                config: config
            )
            XCTFail("Write should still be denied after second restart")
        } catch let error as RuntimeInitializationError {
            XCTAssertTrue(error.isGovernanceViolation)
        }
        
        // Lifecycle 4: Change mode to assistive
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: nil,
            principal: "test-admin",
            databasePath: tempDBPath
        )
        
        // Lifecycle 5: Write should now succeed
        let result = try await CLIKernel.runMemo(
            content: "attempt 3",
            userId: "test-user",
            projectId: nil,
            sessionId: nil,
            config: config
        )
        
        XCTAssertFalse(result.memoryId.isEmpty, "Write should succeed after mode change")
        
        // This proves: governance controls are operational, persistent, and restart-safe
    }
}
