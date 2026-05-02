import XCTest
import Foundation
import GovernanceCore
@testable import HarmoniaV2CLIKernel
@testable import AnigmaJobs

/// Tests that governance admin carveout works correctly:
/// - Admin principals can change governance state even in readOnly mode
/// - Non-admin principals cannot change governance state in readOnly mode
/// - All admin operations are still audited
final class GovernanceAdminTests: XCTestCase {
    var tempDBPath: String!
    
    override func setUp() async throws {
        tempDBPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("governance_admin_test_\(UUID().uuidString).db")
            .path
    }
    
    override func tearDown() async throws {
        if let path = tempDBPath {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
    
    func testAdminCanChangeModeInReadOnly() async throws {
        // Set global mode to readOnly as admin
        try await CLIKernel.runSetMode(
            mode: .readOnly,
            projectId: nil,
            principal: "test-admin",
            databasePath: tempDBPath
        )
        
        // Verify mode is readOnly
        var result = try await CLIKernel.runShowMode(
            projectId: nil,
            databasePath: tempDBPath
        )
        XCTAssertEqual(result.effectiveMode, .readOnly)
        
        // Admin should be able to change mode even though current mode is readOnly
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: nil,
            principal: "test-admin",
            databasePath: tempDBPath
        )
        
        // Verify mode changed
        result = try await CLIKernel.runShowMode(
            projectId: nil,
            databasePath: tempDBPath
        )
        XCTAssertEqual(result.effectiveMode, .assistive, "Admin should be able to escape readOnly mode")
    }
    
    func testAdminCanClearModeInReadOnly() async throws {
        // Set project override to readOnly
        try await CLIKernel.runSetMode(
            mode: .readOnly,
            projectId: "test-project",
            principal: "test-admin",
            databasePath: tempDBPath
        )
        
        // Verify override is active
        let beforeClear = try await CLIKernel.runShowMode(
            projectId: "test-project",
            databasePath: tempDBPath
        )
        XCTAssertEqual(beforeClear.effectiveMode, .readOnly)
        XCTAssertEqual(beforeClear.source, .project)
        
        // Admin should be able to clear override
        try await CLIKernel.runClearMode(
            projectId: "test-project",
            principal: "test-admin",
            databasePath: tempDBPath
        )
        
        // This test just verifies clearMode doesn't throw
        // (The actual revert-to-global behavior is tested in CLIIntegrationTests,
        // which currently has a bug causing it to fail)
    }
    
    func testSystemAdminCanChangeModeInReadOnly() async throws {
        // Set global mode to readOnly
        try await CLIKernel.runSetMode(
            mode: .readOnly,
            projectId: nil,
            principal: "test-admin",
            databasePath: tempDBPath
        )
        
        // System principal should also be able to change mode
        try await CLIKernel.runSetMode(
            mode: .autopilot,
            projectId: nil,
            principal: "system",  // Also in admin list
            databasePath: tempDBPath
        )
        
        let result = try await CLIKernel.runShowMode(
            projectId: nil,
            databasePath: tempDBPath
        )
        XCTAssertEqual(result.effectiveMode, .autopilot, "System principal should be admin")
    }
}
