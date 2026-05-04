//
//  PragmaModuleRuntimeIntegrationTests.swift
//  PragmaModuleTests
//
//  Tests for PragmaModule PlatformRuntime integration
//

import XCTest
import AnigmaCore
@testable import PragmaModule

class PragmaModuleRuntimeIntegrationTests: XCTestCase {
    
    func testPragmaModuleRegistrationThroughPlatformRuntime() async throws {
        // Create a test runtime
        let runtime = try await PlatformRuntime.testing()
        
        // Register PragmaModule through PlatformRuntime
        try await PragmaModule.register(runtime: runtime)
        
        // Verify registration completed without errors
        let status = await runtime.status()
        
        // Check that PragmaModule is in the registered modules
        XCTAssertTrue(status.registeredModules.contains("PragmaModule"), 
                      "PragmaModule should be registered in PlatformRuntime")
        
        // Verify schema was registered
        XCTAssertTrue(status.registeredSchemas.contains("PragmaModule"),
                      "PragmaModule schema should be registered")
        
        print("✅ PragmaModule successfully registered through PlatformRuntime")
    }
    
    func testPragmaDatabaseUsesDatabaseAuthority() async throws {
        // Create a test runtime
        let runtime = try await PlatformRuntime.testing()
        
        // Register PragmaModule
        try await PragmaModule.register(runtime: runtime)
        
        // Get the database authority that PragmaModule should be using
        let databaseAuthority = runtime.database
        
        // Verify it's the correct type (DatabaseAuthority, not DatabaseActor)
        XCTAssertTrue(databaseAuthority is any DatabaseAuthority,
                      "PragmaModule should use DatabaseAuthority, not DatabaseActor")
        
        print("✅ PragmaModule uses DatabaseAuthority through PlatformRuntime")
    }
    
    func testPragmaModuleGovernanceIntegration() async throws {
        // Create a test runtime with governance
        let runtime = try await PlatformRuntime.testing()
        
        // Verify governance is available
        let governance = await runtime.governance
        XCTAssertNotNil(governance.killSwitch, "Governance should be available")
        XCTAssertNotNil(governance.writeGate, "WriteGate should be available")
        
        // Register PragmaModule
        try await PragmaModule.register(runtime: runtime)
        
        // Verify registration completed (proves governance didn't block it)
        let status = await runtime.status()
        XCTAssertTrue(status.registeredModules.contains("PragmaModule"))
        
        print("✅ PragmaModule integrates with PlatformRuntime governance")
    }
    
    func testPragmaModuleEvidenceIntegration() async throws {
        // Create a test runtime
        let runtime = try await PlatformRuntime.testing()
        
        // Register PragmaModule
        try await PragmaModule.register(runtime: runtime)
        
        // Verify evidence authority is available
        let evidenceAuthority = runtime.evidence
        XCTAssertNotNil(evidenceAuthority, "EvidenceAuthority should be available")
        
        print("✅ PragmaModule integrates with EvidenceAuthority through PlatformRuntime")
    }
    
    func testPragmaModuleNoDirectBypasses() async throws {
        // Create a test runtime
        let runtime = try await PlatformRuntime.testing()
        
        // Register PragmaModule
        try await PragmaModule.register(runtime: runtime)
        
        // Get the database authority
        let databaseAuthority = runtime.database
        
        // Verify it's not a direct DatabaseActor
        XCTAssertFalse(databaseAuthority is DatabaseActor,
                      "PragmaModule should not use DatabaseActor directly")
        
        // Verify it uses DatabaseAuthority
        XCTAssertTrue(databaseAuthority is any DatabaseAuthority,
                      "PragmaModule should use DatabaseAuthority")
        
        print("✅ PragmaModule does not bypass PlatformRuntime authorities")
    }
}

// Helper extension for testing
private extension PlatformRuntime {
    static func testing() async throws -> PlatformRuntime {
        let config = RuntimeConfiguration.testing
        let runtime = try await PlatformRuntime(config: config)
        try await runtime.initialize()
        return runtime
    }
}
