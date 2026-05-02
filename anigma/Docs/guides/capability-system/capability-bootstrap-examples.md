//
//  CapabilityBootstrapExample.swift
//  Examples
//
//  Example of how to wire capability bootstrap into application entry points.
//

import Foundation
import PlatformCore
import AnigmaCore
import CapabilityCore

/// Example: Bootstrap capabilities in a CLI application
@main
struct ExampleCLI {
    static func main() async throws {
        // Initialize governance
        let governance = GovernanceController()
        await governance.initialize()
        
        // Create adapters
        let governanceAdapter = CapabilityGovernanceAdapter(controller: governance)
        let auditAdapter = CapabilityAuditAdapter(auditLog: governance.auditLog)
        
        // Bootstrap all platform capabilities with governance
        await PlatformCapabilityBootstrap.registerPlatformCapabilities(
            governance: governanceAdapter,
            auditLog: auditAdapter
        )
        
        // Log what was registered
        let capabilities = await PlatformCapabilityBootstrap.registeredCapabilities()
        print("Registered capabilities: \(capabilities.joined(separator: ", "))")
        
        // Example: Use a capability
        let registry = CapabilityRegistry.shared
        if let pdfProvider = await registry.resolve(
            capabilityId: CapabilityIds.pdfRender,
            as: PDFRenderingCapability.self
        ) {
            print("PDF rendering available via: \(pdfProvider.providerId)")
        }
        
        // Run your application logic...
    }
}

/// Example: Bootstrap capabilities in a SwiftUI app
import SwiftUI

@main
struct ExampleApp: App {
    init() {
        // Bootstrap capabilities on app launch
        Task {
            await PlatformCapabilityBootstrap.registerPlatformCapabilities()
            print("Capabilities bootstrapped")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Example: Bootstrap capabilities in a server application
actor ExampleServer {
    private let governance: GovernanceController
    
    init() async {
        // Initialize governance
        self.governance = GovernanceController()
        await governance.initialize()
        
        // Bootstrap capabilities with full governance
        let governanceAdapter = CapabilityGovernanceAdapter(controller: governance)
        let auditAdapter = CapabilityAuditAdapter(auditLog: governance.auditLog)
        
        await PlatformCapabilityBootstrap.registerPlatformCapabilities(
            governance: governanceAdapter,
            auditLog: auditAdapter
        )
    }
    
    func handleRequest() async throws {
        // Use capabilities with governance checks
        let registry = CapabilityRegistry.shared
        
        let capability = await registry.resolveWithGovernance(
            capabilityId: CapabilityIds.compression,
            as: CompressionCapability.self,
            principal: "server@example.com",
            governance: CapabilityGovernanceAdapter(controller: governance),
            auditLog: CapabilityAuditAdapter(auditLog: governance.auditLog)
        )
        
        if let compression = capability {
            // Use compression capability
            let data = Data("Hello, World!".utf8)
            let compressed = try await compression.compress(data, algorithm: .lz4)
            print("Compressed: \(compressed.count) bytes")
        }
    }
}

/// Example: Testing with capabilities
import XCTest

final class CapabilityTests: XCTestCase {
    override func setUp() async throws {
        // Bootstrap capabilities before each test
        await PlatformCapabilityBootstrap.registerPlatformCapabilities()
    }
    
    func testPDFRendering() async throws {
        let registry = CapabilityRegistry.shared
        let provider = await registry.resolve(
            capabilityId: CapabilityIds.pdfRender,
            as: PDFRenderingCapability.self
        )
        XCTAssertNotNil(provider, "PDF provider should be available")
    }
}
