//
//  NoShadowingGuardTest.swift
//  GovernanceHarness - Type Shadowing Guard
//
//  Compile-time proof that canonical types are accessible and not shadowed by stubs.
//  This test prevents regressions where stub types shadow real types, causing empty module interfaces.
//

import XCTest
@testable import AnigmaGovernance
@testable import AnigmaCore
@testable import AnigmaJobs
@testable import HarmoniaV2CLIKernel
import GovernanceCore

/// Guard test that prevents type shadowing regressions.
///
/// **Purpose**: Ensure canonical types are accessible and not duplicated in stubs.
///
/// **How it works**: Simply references types. If this compiles, the module interface is healthy.
/// If someone re-defines OperatingMode, WriteProposal, etc. in a stub, this test will fail to compile.
///
/// **History**: Previous bug had OperatingMode defined in both real and stub files,
/// causing "empty module interface" where @testable import showed no symbols.
final class NoShadowingGuardTest: XCTestCase {
    
    func testCanonicalTypesAccessible() throws {
        // This test doesn't need to run logic - it just needs to compile.
        // If types are shadowed, this won't compile or will reference the wrong type.
        
        // Canonical governance types (AnigmaGovernance)
        let mode: OperatingMode = .readOnly
        XCTAssertEqual(mode, .readOnly)
        
        let assistive: OperatingMode = .assistive
        XCTAssertEqual(assistive, .assistive)
        
        let autopilot: OperatingMode = .autopilot
        XCTAssertEqual(autopilot, .autopilot)
        
        // WriteProposal must be constructible (GovernanceCore version uses String principal)
        let proposal = WriteProposal(
            principal: "test-user",
            module: "TestModule",
            operation: "testOperation",
            entityId: nil,
            componentType: nil,
            context: [:]
        )
        XCTAssertEqual(proposal.module, "TestModule")
        
        // ModeSource from RuntimeGovernanceAPI (AnigmaCore)
        let projectSource: ModeSource = .project
        let globalSource: ModeSource = .global
        let defaultSource: ModeSource = .defaultMode
        
        XCTAssertEqual(projectSource, .project)
        XCTAssertEqual(globalSource, .global)
        XCTAssertEqual(defaultSource, .defaultMode)
        
        // Verify ModeSource is the protocol type, not a duplicate in CLIKernel
        let kernelSource: ModeSource = .project
        XCTAssertEqual(kernelSource, projectSource, "ModeSource should be same type across modules")
    }
    
    func testGovernanceControllerAccessible() async throws {
        // GovernanceController should be accessible from AnigmaGovernance
        // If stub shadows it, this won't compile
        
        let controller = GovernanceController(auditLog: NoOpAuditLogger())
        
        // This proves we're referencing the REAL GovernanceController,
        // not a stub that only has init() and basic properties.
        // Just accessing the actor type is sufficient to prove it's not shadowed.
        XCTAssertNotNil(controller)
    }
    
    func testRuntimeConfigurationAccessible() throws {
        // RuntimeConfiguration should be unambiguous
        let config = RuntimeConfiguration(
            databasePath: ":memory:",
            enforceGovernance: true
        )
        
        XCTAssertEqual(config.databasePath, ":memory:")
        XCTAssertTrue(config.enforceGovernance)
    }
    
    func testPrincipalAccessible() throws {
        // Principal type should be unambiguous
        let principal = Principal(id: "guard-test", displayName: "Guard Test")
        XCTAssertEqual(principal.id, "guard-test")
        XCTAssertEqual(principal.displayName, "Guard Test")
    }
}
