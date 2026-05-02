//
//  TestRuntimeFactory.swift
//  GovernanceHarness
//
//  Deterministic test runtime creation with guaranteed schema and seeding.
//  Solves the "test environment is a clown car" problem.
//

import Foundation
import AnigmaCore
import AnigmaGovernance
import GovernanceCore
import DatabaseCore
import AnigmaPrimitives

/// Configuration for test runtime creation
public struct TestRuntimeConfig {
    public let databasePath: String
    public let startMode: OperatingMode
    public let principalId: String
    public let projectId: String?
    public let enableKillSwitch: Bool
    
    public init(
        databasePath: String = ":memory:",
        startMode: OperatingMode = .assistive,
        principalId: String = "test-admin",
        projectId: String? = nil,
        enableKillSwitch: Bool = false
    ) {
        self.databasePath = databasePath
        self.startMode = startMode
        self.principalId = principalId
        self.projectId = projectId
        self.enableKillSwitch = enableKillSwitch
    }
    
    /// Create config with unique temp DB path
    public static func withTempDB(
        startMode: OperatingMode = .assistive,
        principalId: String = "test-admin",
        projectId: String? = nil,
        enableKillSwitch: Bool = false
    ) -> TestRuntimeConfig {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("test-\(UUID().uuidString).db").path
        return TestRuntimeConfig(
            databasePath: dbPath,
            startMode: startMode,
            principalId: principalId,
            projectId: projectId,
            enableKillSwitch: enableKillSwitch
        )
    }
}

/// Test runtime factory - creates deterministic, isolated runtime environments
public actor TestRuntimeFactory {
    
    /// Create a fresh runtime with guaranteed schema and seeding
    /// The runtime automatically initializes with assistive mode if enforceGovernance=true
    public static func makeFreshRuntime(config: TestRuntimeConfig = TestRuntimeConfig()) async throws -> PlatformRuntime {
        
        // Create runtime using stable kernel seam
        // This automatically calls initialize() which:
        // 1. Creates core schemas
        // 2. Creates governance tables (via governance.initialize(using:))
        // 3. Seeds default mode based on enforceGovernance
        let kernelConfig = PlatformRuntime.KernelConfig(
            databasePath: config.databasePath,
            enforceGovernance: true,  // Always enforce governance in tests
            principalId: config.principalId
        )
        
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        
        // Runtime is now ready with:
        // - All tables created
        // - Default mode set to assistive (because enforceGovernance=true)
        // - Governance checks registered
        
        return runtime
    }
    
    /// Cleanup test database file
    public static func cleanup(dbPath: String) {
        guard dbPath != ":memory:" else { return }
        try? FileManager.default.removeItem(atPath: dbPath)
    }
}

// MARK: - Stream Denial Test Helpers

/// Helper utilities for testing governance denial behavior in long-running streams
public enum StreamDenialTestHelper {
    
    /// Verify that a stream terminates with a governance denial when mode flips mid-stream
    /// This is the core invariant: governance denials must terminate streams, not be logged-and-continued
    ///
    /// - Parameters:
    ///   - streamProvider: Closure that produces the stream to test (e.g., indexing, chunk processing)
    ///   - modeFlipper: Closure that flips the mode (called after stream starts)
    ///   - eventExtractor: Closure that extracts the current count from a stream event (e.g., chunksWritten)
    ///   - denialExtractor: Closure that extracts denial info from stream event (error message, violation)
    ///   - flipThreshold: When to flip mode (e.g., flip after 2 chunks processed)
    public static func verifyDenialTerminatesStream<Event>(
        streamProvider: () async throws -> AsyncStream<Event>,
        modeFlipper: () async throws -> Void,
        eventExtractor: (Event) -> (count: Int, isComplete: Bool),
        denialExtractor: (Event) -> (denied: Bool, message: String?, violation: GovernanceViolation?),
        flipThreshold: Int = 2
    ) async throws -> (denied: Bool, violation: GovernanceViolation?, finalCount: Int) {
        
        let stream = try await streamProvider()
        var iterator = stream.makeAsyncIterator()
        
        var currentCount = 0
        var denied = false
        var violation: GovernanceViolation? = nil
        var didFlip = false
        
        while let event = await iterator.next() {
            let (count, isComplete) = eventExtractor(event)
            currentCount = count
            
            // Flip mode once we hit threshold
            if count >= flipThreshold && !didFlip {
                try await modeFlipper()
                didFlip = true
            }
            
            // Check for denial
            let (wasDenied, message, v) = denialExtractor(event)
            if wasDenied {
                denied = true
                violation = v
                break
            }
            
            if isComplete {
                break
            }
        }
        
        return (denied, violation, currentCount)
    }
}
