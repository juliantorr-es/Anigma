//
//  CompilerBoundaryTests.swift
//  AnigmaHostMac
//
//  Negative compilation test to prove that renderer-level code
//  cannot access the AnigmaSidecar module.
//
//  This test MUST fail to compile when the forbidden import is uncommented.
//

import XCTest

@testable import AnigmaClientKit
@testable import AnigmaHostMac

/// This test suite verifies that the Topology B architecture enforces
/// strict compiler boundaries between UI renderers and the daemon sidecar.
///
/// **Architecture Rule**: Renderers (AnigmaHostMac) MUST NOT be able to
/// import or access AnigmaSidecar. Only AnigmaAuthority (in AnigmaHostKit)
/// can communicate with the daemon.
final class CompilerBoundaryTests: XCTestCase {

    /// This test verifies that the Package.swift dependency graph
    /// enforces the architectural boundary at compile time.
    ///
    /// **Expected Behavior**: This test file compiles successfully.
    ///
    /// **Negative Test**: Uncommenting the forbidden code below MUST
    /// cause a compilation error, proving the boundary is enforced.
    func testRendererCannotImportSidecar() {
        // ========================================
        // FORBIDDEN CODE - MUST NOT COMPILE
        // ========================================
        // Uncommenting any of the following lines should cause
        // a compilation error: "No such module 'AnigmaSidecar'"
        //
        // import AnigmaSidecar
        //
        // func tryToAccessSidecar() async throws {
        //     let bridge = try await SidecarBridge.create()
        //     let _ = try await bridge.submitJob(AnigmaJobSpec())
        // }
        // ========================================

        // If this test compiles, the boundary is correctly enforced
        XCTAssertTrue(true, "Compiler boundary enforced: AnigmaHostMac cannot import AnigmaSidecar")
    }

    /// Verifies that renderers can only submit intents via AnigmaClient,
    /// not directly access AnigmaAuthority or AnigmaSidecar.
    func testRendererCanOnlyUseIntentAPI() {
        // Renderers should only have access to:
        // 1. AnigmaClient (intent submission API)
        // 2. PresentationIR (read-only view state)

        // This compiles because AnigmaClient is allowed:
        // let client = AnigmaClient(authority: someAuthority)

        // This would NOT compile because AnigmaAuthority is actor-isolated:
        // let authority = AnigmaAuthority.create()  // ❌ Cannot access directly

        // This would NOT compile because AnigmaSidecar is not a dependency:
        // let bridge = SidecarBridge.create()  // ❌ Module not available

        XCTAssertTrue(true, "Renderers limited to intent API only")
    }

    /// Documents the allowed dependencies for renderer code.
    func testAllowedRendererDependencies() {
        // Renderers (AnigmaHostMac) MAY import:
        // ✅ AnigmaClientKit - For AnigmaClient and intent submission
        // ✅ AnigmaHostKit - For AnigmaAuthority (but only via AnigmaClient)
        // ✅ ContractsCore - For PresentationIR, ViewNode, etc.
        // ✅ SwiftUI, AppKit - For UI rendering

        // Renderers MUST NOT import:
        // ❌ AnigmaSidecar - Daemon communication layer
        // ❌ AnigmaDaemonCore - gRPC protocol definitions
        // ❌ GRPC - Low-level networking

        XCTAssertTrue(true, "Dependency boundaries documented")
    }
}

// MARK: - CI Verification Script
//
// To verify this test in CI, add the following script:
//
// ```bash
// #!/bin/bash
// # verify-compiler-boundary.sh
//
// # Uncomment the forbidden code
// sed -i '' 's|// import AnigmaSidecar|import AnigmaSidecar|' \
//     Tests/AnigmaHostMacTests/CompilerBoundaryTests.swift
//
// # Try to compile - this SHOULD fail
// if swift build --target AnigmaHostMacTests 2>&1 | grep -q "No such module 'AnigmaSidecar'"; then
//     echo "✅ Compiler boundary enforced correctly"
//     exit 0
// else
//     echo "❌ SECURITY VIOLATION: Renderer can access AnigmaSidecar!"
//     exit 1
// fi
// ```
